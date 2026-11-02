import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/driver_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/registered_address_resolver.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/order_status.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/illustration.dart';

// ─── Constants & enums ────────────────────────────────────────────────────────

enum _Mode { selecting, delivering }

const int _kMax = 3;
const String _kActiveKey = 'driver_active_orders';

// Los avisos inferiores quedan sobre la barra de navegación del repartidor.
const EdgeInsets _kSnackMargin = EdgeInsets.fromLTRB(12, 0, 12, 96);

// Mismo proveedor que el resto de los mapas de la app (Carto exige API key).
const String _kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

// ─── Page ─────────────────────────────────────────────────────────────────────

class DeliveryOrdersListPage extends StatefulWidget {
  const DeliveryOrdersListPage({super.key});

  @override
  State<DeliveryOrdersListPage> createState() => _DeliveryOrdersListPageState();
}

class _DeliveryOrdersListPageState extends State<DeliveryOrdersListPage> {
  // Permite inyectar un provider (tests); por defecto usa el real.
  final _api = Get.isRegistered<AppProvider>()
      ? Get.find<AppProvider>()
      : AppProvider();
  final _driver = Get.isRegistered<DriverController>()
      ? Get.find<DriverController>()
      : Get.put(DriverController());
  final _box = GetStorage();
  Worker? _availabilityWorker;
  final _coords = <String, LatLng>{};
  LatLng? _driverLocation;

  List<Map<String, dynamic>> _availableOrders = [];
  List<Map<String, dynamic>> _ownRoutes = [];
  final _selectedIds = <int>{};
  final _claimedIds = <int>{};

  _Mode _mode = _Mode.selecting;
  bool _loading = true;
  bool _claiming = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _refreshDriverLocation();
    // Cada 15 s: pedidos disponibles, estado de la ruta y ubicación propia.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _loadRoutes(silent: true);
      _refreshDriverLocation();
    });
    // Al conectarse/desconectarse se recarga la lista de pedidos.
    _availabilityWorker = ever(_driver.available, (_) {
      if (mounted) _loadRoutes(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _availabilityWorker?.dispose();
    super.dispose();
  }

  // Orders exposes this list specifically for couriers: ready to collect and
  // without a courier. Delivery routes are deliberately not used as a source.
  List<Map<String, dynamic>> get _available => _availableOrders;

  // GET /delivery/routes already scopes the response to the authenticated courier.
  List<Map<String, dynamic>> get _active => _ownRoutes.where((r) {
    final s = r['status'].toString().toLowerCase();
    return !s.contains('entregado') &&
        (s.contains('asignado') ||
            s.contains('camino') ||
            s.contains('retirado'));
  }).toList();

  // Currently selected (before claiming)
  List<Map<String, dynamic>> get _selected => _available
      .where((r) => _selectedIds.contains(r['orderId'] as int))
      .toList();

  // ── DATA ───────────────────────────────────────────────────────────────────

  Future<void> _loadRoutes({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final routesFuture = _api.getDeliveryRoutes();
      // Desconectado: no se piden pedidos nuevos, solo la ruta propia.
      final restaurants = _driver.available.value
          ? await _api.getRestaurants()
          : <Map<String, dynamic>>[];
      final availableByRestaurant = await Future.wait(
        restaurants.map((restaurant) {
          final restaurantId = int.tryParse('${restaurant['id'] ?? ''}');
          return restaurantId == null
              ? Future.value(<Map<String, dynamic>>[])
              : _api.getAvailableDeliveryOrders(restaurantId: restaurantId);
        }),
      );
      final routes = await routesFuture;
      await LocalNotificationsService.instance.observeOrders(
        scope: 'delivery',
        orders: routes,
        notify: silent,
      );
      final availableOrders = availableByRestaurant
          .expand((orders) => orders)
          .toList();
      routes.sort(_compareRoutesByRecency);
      availableOrders.sort(_compareRoutesByRecency);
      if (!mounted) return;

      final stillActive = routes
          .where((r) {
            final s = r['status'].toString().toLowerCase();
            return !s.contains('entregado') &&
                (s.contains('asignado') ||
                    s.contains('camino') ||
                    s.contains('retirado'));
          })
          .map((r) => r['orderId'] as int)
          .toSet();

      setState(() {
        _ownRoutes = routes;
        _availableOrders = availableOrders;
        _selectedIds.removeWhere(
          (id) => !availableOrders.any((r) => r['orderId'] == id),
        );
        if (stillActive.isNotEmpty) {
          _claimedIds
            ..clear()
            ..addAll(stillActive);
          _mode = _Mode.delivering;
          _box.write(_kActiveKey, stillActive.toList());
        } else {
          // All completed — return to selection
          _claimedIds.clear();
          _box.remove(_kActiveKey);
          _mode = _Mode.selecting;
        }
        _loading = false;
      });

      final mapRoutes = _mode == _Mode.delivering
          ? _active
          : _available.take(3).toList();
      await _ensureCoords(mapRoutes);
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'No se pudieron cargar las rutas';
          _loading = false;
        });
      }
    }
  }

  Future<void> _ensureCoords(List<Map<String, dynamic>> routes) async {
    final addrs = <String>{
      for (final r in routes)
        if ('${r['pickupAddress']}'.trim().isNotEmpty) '${r['pickupAddress']}',
      for (final r in routes)
        if ('${r['deliveryAddress']}'.trim().isNotEmpty)
          '${r['deliveryAddress']}',
    };
    for (final addr in addrs) {
      if (_coords.containsKey(addr)) continue;
      // Sin coordenadas confiables la parada no se dibuja (mejor que un punto
      // inventado en el mapa).
      final coordinates = await RegisteredAddressResolver.resolve(addr);
      if (coordinates != null) _coords[addr] = coordinates;
    }
    if (mounted) setState(() {});
  }

  /// Ubicación real del repartidor. Si no da permiso, la ruta sigue usable.
  Future<void> _refreshDriverLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _driverLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      // Sin GPS o sin plugin (tests): se muestra la ruta sin la moto.
    }
  }

  // ── SELECTION ACTIONS ──────────────────────────────────────────────────────

  Future<void> _toggleRoute(Map<String, dynamic> route) async {
    final id = route['orderId'] as int;
    if (_selectedIds.contains(id)) {
      setState(() => _selectedIds.remove(id));
      return;
    }
    if (_selectedIds.length >= _kMax) {
      Get.snackbar(
        'Máximo $_kMax pedidos',
        'Termina tu ruta actual antes de tomar más.',
        snackPosition: SnackPosition.BOTTOM,
        margin: _kSnackMargin,
      );
      return;
    }
    if (_selected.isNotEmpty &&
        _selected.first['pickupAddress'] != route['pickupAddress']) {
      Get.snackbar(
        'Local diferente',
        'Solo puedes agrupar pedidos del mismo punto de retiro.',
        snackPosition: SnackPosition.BOTTOM,
        margin: _kSnackMargin,
      );
      return;
    }
    setState(() => _selectedIds.add(id));
    await _ensureCoords(_selected);
  }

  Future<void> _selectGroup(String pickupAddress) async {
    final ids = _available
        .where((r) => r['pickupAddress'] == pickupAddress)
        .take(_kMax)
        .map((r) => r['orderId'] as int)
        .toSet();
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(ids);
    });
    await _ensureCoords(_selected);
  }

  // Claim = mark En camino (locks orders from other drivers) + switch to delivering
  Future<void> _claimSelected() async {
    if (_selected.isEmpty || _claiming) return;
    setState(() => _claiming = true);
    try {
      final ids = _selected.map((r) => r['orderId'] as int).toSet();
      final response = await _api.claimDeliveryOrders(orderIds: ids.toList());
      if (response.success != true) {
        if (mounted) setState(() => _claiming = false);
        Get.snackbar(
          'No se pudo tomar la ruta',
          response.message ?? 'Actualiza la lista e intenta nuevamente.',
          snackPosition: SnackPosition.BOTTOM,
          margin: _kSnackMargin,
        );
        await _loadRoutes(silent: true);
        return;
      }
      await _box.write(_kActiveKey, ids.toList());
      if (!mounted) return;
      setState(() {
        _claimedIds
          ..clear()
          ..addAll(ids);
        _selectedIds.clear();
        _mode = _Mode.delivering;
        _claiming = false;
      });
      await _loadRoutes(silent: true);
    } catch (_) {
      if (mounted) setState(() => _claiming = false);
      Get.snackbar(
        'Error',
        'No se pudo tomar los pedidos. Intenta nuevamente.',
        snackPosition: SnackPosition.BOTTOM,
        margin: _kSnackMargin,
      );
    }
  }

  // ── DELIVERY ACTIONS ───────────────────────────────────────────────────────

  Future<void> _markPickedUp(Map<String, dynamic> route) async {
    final orderId = route['orderId'] as int?;
    if (orderId == null) {
      _notify('Error', 'El pedido no tiene identificador.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar retiro'),
        content: Text(
          'Confirma que retiraste el pedido en ${route['pickupAddress'] ?? 'el comercio indicado'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar retiro'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final response = await _call(
      () => _api.updateOrderStatus(orderId, 'Retirado'),
    );
    if (response == null) return;
    if (response.success != true) {
      _notify(
        'No se pudo actualizar',
        response.message ?? 'Intenta nuevamente.',
      );
      return;
    }
    _notify(
      'Pedido retirado',
      'Ahora puedes confirmar la entrega al llegar al destino.',
    );
    await _loadRoutes(silent: true);
  }

  /// Entrega con el PIN de 6 dígitos que el cliente ve en su seguimiento.
  Future<void> _markDelivered(Map<String, dynamic> route) async {
    final orderId = route['orderId'] as int?;
    if (orderId == null) {
      _notify('Error', 'El pedido no tiene identificador.');
      return;
    }
    if (!mounted) return;
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => _DeliveryPinDialog(
        address: '${route['deliveryAddress'] ?? 'la dirección indicada'}',
      ),
    );
    if (pin == null) return;
    final response = await _call(() => _api.deliverOrder(orderId, pin));
    if (response == null) return;
    if (response.success != true) {
      final (title, details) = deliveryErrorMessage(response);
      _notify(title, details);
      return;
    }
    _notify(
      '¡Entrega registrada!',
      'El pedido fue entregado y la ruta se actualizará.',
    );
    await _loadRoutes(silent: true);
  }

  /// Ejecuta una acción del repartidor; si no hay red avisa y devuelve null.
  Future<ResponseApi?> _call(Future<ResponseApi> Function() action) async {
    try {
      return await action();
    } catch (e) {
      debugPrint('Acción del repartidor falló: $e');
      _notify('Sin conexión', 'No se pudo actualizar. Intenta nuevamente.');
      return null;
    }
  }

  void _notify(String title, String message) => Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    margin: _kSnackMargin,
  );

  Future<void> _navigate() async {
    final routes = _mode == _Mode.delivering ? _active : _selected;
    if (routes.isEmpty) return;
    final pickup = '${routes.first['pickupAddress']}';
    final deliveries = routes.map((r) => '${r['deliveryAddress']}').toList();
    final q = <String, String>{
      'api': '1',
      'origin': pickup,
      'destination': deliveries.last,
      'travelmode': 'driving',
      'dir_action': 'navigate',
      if (deliveries.length > 1)
        'waypoints': deliveries.take(deliveries.length - 1).join('|'),
    };
    final uri = Uri.https('www.google.com', '/maps/dir/', q);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar('Error', 'No se pudo abrir el navegador.');
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        elevation: 0,
        // Es la raíz de la pestaña Pedidos: sin flecha de volver.
        automaticallyImplyLeading: false,
        title: Text(
          _mode == _Mode.selecting ? 'Pedidos disponibles' : 'En ruta',
          // El titleTextStyle del tema usa color tinta; aquí el fondo es oscuro.
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (_mode == _Mode.selecting)
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loadRoutes,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _loadRoutes)
          : _mode == _Mode.selecting
          ? _selectingView()
          : _deliveringView(),
    );
  }

  // ── SELECTING VIEW ─────────────────────────────────────────────────────────

  Widget _selectingView() {
    final pickups = <String>{
      for (final r in _available) '${r['pickupAddress']}',
    };
    final mapRoutes = _selected.isNotEmpty
        ? _selected
        : _available.take(3).toList();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadRoutes,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            children: [
              Obx(
                () => _StatsBanner(
                  available: _available.length,
                  selected: _selected.length,
                  online: _driver.available.value,
                  onToggle: _driver.setAvailable,
                ),
              ),
              const SizedBox(height: 14),
              if (!_driver.available.value) ...[
                const _OfflineCard(),
                const SizedBox(height: 14),
              ],
              _DeliveryMap(
                routes: mapRoutes,
                coords: _coords,
                fullscreen: false,
              ),
              const SizedBox(height: 16),
              if (pickups.isNotEmpty) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Agrupar por local',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      'Máx. $_kMax pedidos',
                      style: const TextStyle(
                        color: Color(0xFF7B8189),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pickups.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final addr = pickups.elementAt(i);
                      final n = _available
                          .where((r) => r['pickupAddress'] == addr)
                          .length;
                      return ActionChip(
                        avatar: const Icon(Icons.storefront_outlined, size: 16),
                        label: Text(
                          '$n en ${addr.split(',').first}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _selectGroup(addr),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pedidos disponibles',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${_available.length}',
                    style: const TextStyle(color: Color(0xFF7B8189)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Los pedidos tomados por otro repartidor desaparecen automáticamente.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9EA5AD)),
              ),
              const SizedBox(height: 12),
              if (_available.isEmpty)
                const _EmptyRoutes()
              else
                ..._available.map(
                  (route) => _SelectableCard(
                    route: route,
                    selected: _selectedIds.contains(route['orderId'] as int),
                    dimmed:
                        _selectedIds.length >= _kMax &&
                        !_selectedIds.contains(route['orderId'] as int),
                    onTap: () => _toggleRoute(route),
                  ),
                ),
            ],
          ),
        ),
        if (_selected.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ClaimBar(
              count: _selected.length,
              busy: _claiming,
              onClaim: _claimSelected,
            ),
          ),
      ],
    );
  }

  // ── DELIVERING VIEW ────────────────────────────────────────────────────────

  Widget _deliveringView() {
    final routes = _active;
    if (routes.isEmpty) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _DeliveryMap(
            routes: routes,
            coords: _coords,
            driverLocation: _driverLocation,
            fullscreen: true,
          ),
        ),
        Expanded(
          flex: 4,
          child: _ActiveDeliveriesPanel(
            routes: routes,
            onNavigate: _navigate,
            onPickedUp: _markPickedUp,
            onDelivered: _markDelivered,
          ),
        ),
      ],
    );
  }
}

// ─── _StatsBanner ─────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final int available;
  final int selected;
  final bool online;
  final ValueChanged<bool> onToggle;

  const _StatsBanner({
    required this.available,
    required this.selected,
    required this.online,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1117), Color(0xFF1A2535)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  color: Color(0xFFFFB300),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      online ? 'Turno activo' : 'Desconectado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      online
                          ? '$available pedidos disponibles'
                          : 'No recibes pedidos nuevos',
                      style: const TextStyle(
                        color: Color(0xFF8B9AAD),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$selected elegido${selected > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: online
                        ? const Color(0xFF34C759)
                        : const Color(0xFF8B9AAD),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Disponible',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch(
                  value: online,
                  onChanged: onToggle,
                  activeColor: const Color(0xFF1A1A1A),
                  activeTrackColor: const Color(0xFFFFB300),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: const IllustratedMessage(
        illustration: AppIllustration.noConnection,
        title: 'Estás desconectado',
        message: 'Activa "Disponible" para ver pedidos listos para retiro.',
        size: 130,
      ),
    );
  }
}

// ─── _DeliveryMap ──────────────────────────────────────────────────────────────

class _DeliveryMap extends StatelessWidget {
  final List<Map<String, dynamic>> routes;
  final Map<String, LatLng> coords;
  final LatLng? driverLocation;
  final bool fullscreen;

  const _DeliveryMap({
    required this.routes,
    required this.coords,
    this.driverLocation,
    required this.fullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[];
    final markers = <Marker>[];

    if (routes.isNotEmpty) {
      final pickupAddr = '${routes.first['pickupAddress']}';
      final pickup = coords[pickupAddr];
      if (pickup != null) {
        points.add(pickup);
        markers.add(_pickupMarker(pickup));
        // En demo (web, sin GPS) la moto parte en el local para la presentación.
        if (fullscreen && driverLocation == null && Environment.useDemoMode) {
          markers.add(_driverMarker(pickup));
        }
      }
      for (var i = 0; i < routes.length; i++) {
        final coord = coords['${routes[i]['deliveryAddress']}'];
        if (coord == null) continue;
        points.add(coord);
        markers.add(_deliveryMarker(coord, i + 1));
      }
    }
    if (driverLocation != null) markers.add(_driverMarker(driverLocation!));

    final map = FlutterMap(
      key: ValueKey(
        points.map((p) => '${p.latitude},${p.longitude}').join('|'),
      ),
      options: MapOptions(
        initialCenter: points.isEmpty
            ? const LatLng(-33.4372, -70.6506)
            : points.first,
        initialZoom: points.length <= 1 ? 13 : 12,
        initialCameraFit: points.length > 1
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.all(54),
              )
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: _kTileUrl,
          userAgentPackageName: 'com.javier.proyecto_app_delivery_gessof',
        ),
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: fullscreen ? 7 : 5.5,
                color: const Color(0xFF00A8FF),
                borderStrokeWidth: fullscreen ? 4 : 2,
                borderColor: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
          ],
        ),
      ],
    );

    final mapStack = Stack(
      children: [
        Positioned.fill(child: map),
        Positioned(
          left: 14,
          right: 14,
          top: 14,
          child: _MapRouteBadge(count: routes.length, fullscreen: fullscreen),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: _MapLegendPanel(fullscreen: fullscreen),
        ),
      ],
    );

    if (fullscreen) return mapStack;

    // Preview mode
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mapa del recorrido',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            const _LegendDot(color: Color(0xFF16824B), label: 'Local'),
            const SizedBox(width: 10),
            const _LegendDot(color: Color(0xFF0C9AF8), label: 'Entrega'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(height: 220, child: mapStack),
        ),
        if (routes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Selecciona pedidos para ver el recorrido estimado.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9EA5AD)),
            ),
          ),
      ],
    );
  }

  // Pines en forma de gota: la punta queda abajo al centro, por eso
  // alignment topCenter (el dibujo crece hacia arriba desde el punto).
  static Marker _driverMarker(LatLng point) => Marker(
    point: point,
    width: 52,
    height: 56,
    alignment: Alignment.topCenter,
    child: const MapPin(MapPinKind.rider, size: 52),
  );

  static Marker _pickupMarker(LatLng point) => Marker(
    point: point,
    width: 46,
    height: 50,
    alignment: Alignment.topCenter,
    child: const MapPin(MapPinKind.store, size: 46),
  );

  static Marker _deliveryMarker(LatLng point, int number) => Marker(
    point: point,
    width: 46,
    height: 46,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C9AF8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ),
    ),
  );
}

// ─── _SelectableCard ───────────────────────────────────────────────────────────

class _MapRouteBadge extends StatelessWidget {
  final int count;
  final bool fullscreen;

  const _MapRouteBadge({required this.count, required this.fullscreen});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: fullscreen
              ? const Color(0xFF101418).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.near_me, color: Color(0xFFFFB300), size: 18),
            const SizedBox(width: 7),
            Text(
              count == 0
                  ? 'Vista de ruta'
                  : '$count entrega${count > 1 ? 's' : ''}',
              style: TextStyle(
                color: fullscreen ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegendPanel extends StatelessWidget {
  final bool fullscreen;

  const _MapLegendPanel({required this.fullscreen});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: fullscreen ? 0.94 : 0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _LegendDot(color: Color(0xFF101418), label: 'Tu moto'),
            _LegendDot(color: Color(0xFF16824B), label: 'Local'),
            _LegendDot(color: Color(0xFF0C9AF8), label: 'Entrega'),
          ],
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final Map<String, dynamic> route;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.route,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _routeValue(route, 'status', fallback: 'Pendiente');
    final isReady = status.toLowerCase().contains('listo');
    final total = route['total'];

    return GestureDetector(
      onTap: dimmed ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: dimmed ? const Color(0xFFF5F6F8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFFFB300) : const Color(0xFFE4E7EC),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated check circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? const Color(0xFFFFB300)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFFB300)
                        : const Color(0xFFCDD2D9),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 15)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _routeTitle(route),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: dimmed
                                  ? const Color(0xFFADB3BA)
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isReady
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isReady
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _StopRow(
                      color: const Color(0xFF16824B),
                      label: 'Retirar',
                      address: _routeValue(
                        route,
                        'pickupAddress',
                        fallback: 'Local pendiente',
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StopRow(
                      color: const Color(0xFF0C9AF8),
                      label: 'Entregar',
                      address: _routeValue(
                        route,
                        'deliveryAddress',
                        fallback: 'Direccion pendiente',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 13,
                          color: Color(0xFF9EA5AD),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_routeValue(route, 'estimatedMinutes', fallback: '--')} min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7B8189),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.route_outlined,
                          size: 13,
                          color: Color(0xFF9EA5AD),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_routeNumber(route['distanceKm']).toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7B8189),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            total == null ? '' : _clp(total),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: dimmed
                                  ? const Color(0xFFADB3BA)
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _clp(dynamic v) {
    final n = double.tryParse('$v') ?? 0;
    return '\$${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
  }
}

// ─── _ClaimBar ────────────────────────────────────────────────────────────────

class _ClaimBar extends StatelessWidget {
  final int count;
  final bool busy;
  final VoidCallback onClaim;

  const _ClaimBar({
    required this.count,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF2F4F7).withValues(alpha: 0),
            const Color(0xFFF2F4F7),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D1117),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: busy ? null : onClaim,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delivery_dining, color: Colors.white),
            label: Text(
              busy
                  ? 'Tomando pedidos...'
                  : 'Tomar $count pedido${count > 1 ? 's' : ''} · Iniciar ruta',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── _ActiveDeliveriesPanel ────────────────────────────────────────────────────

class _ActiveDeliveriesPanel extends StatelessWidget {
  final List<Map<String, dynamic>> routes;
  final VoidCallback onNavigate;
  final Future<void> Function(Map<String, dynamic>) onPickedUp;
  final Future<void> Function(Map<String, dynamic>) onDelivered;

  const _ActiveDeliveriesPanel({
    required this.routes,
    required this.onNavigate,
    required this.onPickedUp,
    required this.onDelivered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6D8DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                // Expanded + Align: la píldora usa todo el ancho libre y solo se
                // corta si de verdad no cabe (un Spacer le quitaba la mitad).
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C9AF8).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.navigation,
                            color: Color(0xFF0C9AF8),
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'En ruta · ${routes.length} entrega${routes.length > 1 ? 's' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0C9AF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Navegar', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    side: const BorderSide(color: Color(0xFF0C9AF8)),
                    foregroundColor: const Color(0xFF0C9AF8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              itemCount: routes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _ActiveOrderTile(
                route: routes[i],
                stopNumber: i + 1,
                onPickedUp: () => onPickedUp(routes[i]),
                onDelivered: () => onDelivered(routes[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _ActiveOrderTile ─────────────────────────────────────────────────────────

class _ActiveOrderTile extends StatelessWidget {
  final Map<String, dynamic> route;
  final int stopNumber;
  final VoidCallback onPickedUp;
  final VoidCallback onDelivered;

  const _ActiveOrderTile({
    required this.route,
    required this.stopNumber,
    required this.onPickedUp,
    required this.onDelivered,
  });

  @override
  Widget build(BuildContext context) {
    final needsPickup = routeNeedsPickup(route);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF0C9AF8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$stopNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _routeTitle(route),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _routeSubtitle(route),
                  style: const TextStyle(
                    color: Color(0xFF7B8189),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: needsPickup ? onPickedUp : onDelivered,
            style: FilledButton.styleFrom(
              backgroundColor: needsPickup
                  ? const Color(0xFF9A6500)
                  : const Color(0xFF16824B),
              // El tema pinta los FilledButton con texto tinta (pensado para amarillo).
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              needsPickup ? 'Retirar' : 'Entregar',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Entrega con PIN ──────────────────────────────────────────────────────────

class _DeliveryPinDialog extends StatefulWidget {
  final String address;

  const _DeliveryPinDialog({required this.address});

  @override
  State<_DeliveryPinDialog> createState() => _DeliveryPinDialogState();
}

class _DeliveryPinDialogState extends State<_DeliveryPinDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _controller.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _error = 'Ingresa los 6 dígitos del código.');
      return;
    }
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar entrega'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirma que entregaste el pedido en ${widget.address}.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'PIN de entrega del cliente',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Confirmar entrega'),
        ),
      ],
    );
  }
}

/// Título y detalle del aviso cuando Orders rechaza la entrega.
(String, String) deliveryErrorMessage(ResponseApi response) {
  final title = switch (response.statusCode) {
    409 => 'Pedido no disponible',
    423 => 'Entrega bloqueada',
    422 when response.codeRenewed == true => 'Código renovado',
    422 => 'Código incorrecto',
    _ => 'No se pudo actualizar',
  };
  final details = <String>[
    if ((response.message ?? '').trim().isNotEmpty) response.message!.trim(),
    if (response.codeRenewed == true)
      'El cliente ya puede consultar el nuevo código en su app.',
    if (response.remainingAttempts != null &&
        response.codeRenewed != true &&
        response.statusCode == 422 &&
        !(response.message ?? '').toLowerCase().contains('intento'))
      'Intentos restantes: ${response.remainingAttempts}.',
  ].join('\n');
  return (title, details.isEmpty ? 'Intenta nuevamente.' : details);
}

/// Asignado (o listo/pendiente): el repartidor aún debe retirarlo en el local.
bool routeNeedsPickup(Map<String, dynamic> route) {
  final status = _routeValue(route, 'status').toLowerCase();
  return status.contains('asignado') ||
      status.contains('listo para retiro') ||
      status.contains('pendiente');
}

/// Más reciente primero; a igual fecha, la más cercana.
int _compareRoutesByRecency(Map<String, dynamic> a, Map<String, dynamic> b) {
  final byTime = orderTime(b).compareTo(orderTime(a));
  if (byTime != 0) return byTime;
  return _routeNumber(a['distanceKm']).compareTo(_routeNumber(b['distanceKm']));
}

// ─── Small helpers ─────────────────────────────────────────────────────────────

String _routeTitle(Map<String, dynamic> route) {
  final code = _routeValue(route, 'code');
  final restaurant = _routeValue(route, 'restaurantName');
  final pickup = _routeValue(route, 'pickupAddress');
  final locationName = restaurant.isNotEmpty
      ? restaurant
      : pickup.split(',').first.trim();
  final parts = [
    if (code.isNotEmpty) code,
    if (locationName.isNotEmpty) locationName,
  ];
  return parts.isNotEmpty
      ? parts.join(' · ')
      : 'Pedido #${_routeValue(route, 'orderId', fallback: '-')}';
}

String _routeSubtitle(Map<String, dynamic> route) {
  final client = _routeValue(route, 'clientName');
  final address = _routeValue(
    route,
    'deliveryAddress',
    fallback: 'Direccion pendiente',
  );
  return client.isEmpty ? address : '$client · $address';
}

String _routeValue(
  Map<String, dynamic> route,
  String key, {
  String fallback = '',
}) {
  final value = route[key]?.toString().trim();
  return value == null || value.isEmpty || value == 'null' ? fallback : value;
}

double _routeNumber(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class _StopRow extends StatelessWidget {
  final Color color;
  final String label;
  final String address;

  const _StopRow({
    required this.color,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(fontSize: 12, color: Color(0xFF555B63)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    // mainAxisSize.min: dentro de un Wrap, un Row de ancho máximo apila
    // cada ítem en su propia línea y la leyenda tapa el mapa.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _EmptyRoutes extends StatelessWidget {
  const _EmptyRoutes();

  @override
  Widget build(BuildContext context) {
    return const IllustratedMessage(
      illustration: AppIllustration.emptyOrders,
      title: 'Sin pedidos disponibles',
      message: 'Todos los pedidos han sido tomados o entregados.',
      size: 150,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return IllustratedMessage(
      illustration: AppIllustration.noConnection,
      title: message,
      message: 'Revisa tu conexión e intenta de nuevo.',
      actionLabel: 'Reintentar',
      onAction: onRetry,
    );
  }
}
