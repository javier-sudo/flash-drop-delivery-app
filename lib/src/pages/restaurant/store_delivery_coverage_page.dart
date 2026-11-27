import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/registered_address_resolver.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreDeliveryCoveragePage extends StatefulWidget {
  const StoreDeliveryCoveragePage({super.key, this.provider});
  final AppProvider? provider;
  @override
  State<StoreDeliveryCoveragePage> createState() =>
      _StoreDeliveryCoveragePageState();
}

class _StoreDeliveryCoveragePageState extends State<StoreDeliveryCoveragePage> {
  final _form = GlobalKey<FormState>();
  final _map = MapController();
  final _radius = TextEditingController();
  late final _api =
      widget.provider ??
      (Get.isRegistered<AppProvider>()
          ? Get.find<AppProvider>()
          : AppProvider());
  LatLng? _pin;
  String _name = 'Mi comercio';
  String _address = '';
  String? _error;
  bool _loading = true;
  bool _loaded = false;
  bool _saving = false;
  bool _finding = false;
  bool _mapReady = false;
  bool _settingsRequired = false;
  int _locationRevision = 0;

  double? get _radiusKm => double.tryParse(_radius.text.replaceAll(',', '.'));
  bool get _validRadius => _radiusError(_radius.text) == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locationRevision++;
    _radius.dispose();
    _map.dispose();
    super.dispose();
  }

  LatLng? _point(Object? rawLat, Object? rawLng) {
    final lat = double.tryParse('$rawLat');
    final lng = double.tryParse('$rawLng');
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _mapReady = false;
      _loaded = false;
    });
    try {
      final store = await _api.getMyRestaurant();
      if (!mounted) return;
      setState(() {
        _name = '${store['name'] ?? 'Mi comercio'}';
        _address = '${store['address'] ?? ''}';
        _pin = _point(store['latitude'], store['longitude']);
        _radius.text = '${store['deliveryRadiusKm'] ?? ''}';
        _loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar la zona de despacho.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  CameraFit _cameraFit(LatLng point) {
    final meters = (_validRadius ? _radiusKm! : 1) * 1000;
    const distance = Distance();
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([
        distance.offset(point, meters, 0),
        distance.offset(point, meters, 90),
        distance.offset(point, meters, 180),
        distance.offset(point, meters, 270),
      ]),
      padding: const EdgeInsets.all(28),
    );
  }

  void _fitMap() {
    if (_mapReady && _pin != null) _map.fitCamera(_cameraFit(_pin!));
  }

  void _selectPin(LatLng point, {bool fit = false}) {
    if (_saving || _point(point.latitude, point.longitude) == null) return;
    _locationRevision++;
    setState(() {
      _pin = point;
      _finding = false;
      _error = null;
      _settingsRequired = false;
    });
    if (fit) _fitMap();
  }

  Future<void> _findLocation({required bool useGps}) async {
    if (_saving || _finding) return;
    final revision = ++_locationRevision;
    setState(() {
      _finding = true;
      _error = null;
      _settingsRequired = false;
    });
    try {
      final LatLng? point;
      if (useGps) {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw const FormatException(
            'Activa la ubicación del teléfono o marca el local en el mapa.',
          );
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (!mounted || revision != _locationRevision) return;
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          setState(
            () => _settingsRequired =
                permission == LocationPermission.deniedForever,
          );
          throw const FormatException(
            'No hay permiso de ubicación. Puedes marcar el local en el mapa.',
          );
        }
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        point = _point(position.latitude, position.longitude);
      } else {
        point = await RegisteredAddressResolver.resolve(_address);
      }
      if (!mounted || revision != _locationRevision) return;
      if (point == null) {
        throw const FormatException(
          'No encontramos la dirección. Marca la ubicación del local en el mapa.',
        );
      }
      _selectPin(point, fit: true);
    } catch (error) {
      if (mounted && revision == _locationRevision) {
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : 'No pudimos obtener la ubicación. Puedes marcarla en el mapa.',
        );
      }
    } finally {
      if (mounted && revision == _locationRevision) {
        setState(() => _finding = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _finding || !_loaded) return;
    final valid = _form.currentState?.validate() ?? false;
    if (_pin == null) {
      setState(
        () => _error =
            'Marca la ubicación del local en el mapa antes de guardar.',
      );
      return;
    }
    if (!valid) return;
    final pin = _pin!;
    final radius = _radiusKm!;
    setState(() {
      _saving = true;
      _error = null;
    });
    var locationSaved = false;
    try {
      await _api.updateStoreLocation(
        latitude: pin.latitude,
        longitude: pin.longitude,
      );
      locationSaved = true;
      await _api.updateStoreDeliveryRadius(radius);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zona de despacho guardada')),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = locationSaved
              ? 'Ubicacion guardada, pero no se pudo guardar el radio. Reintenta.'
              : 'No se pudo guardar. Revisa la conexion y reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _radiusError(String? text) {
    final raw = (text ?? '').replaceAll(',', '.');
    final value = double.tryParse(raw);
    return value == null ||
            !value.isFinite ||
            value < 1 ||
            value > 50 ||
            !RegExp(r'^\d{1,2}(\.\d{1,2})?$').hasMatch(raw)
        ? 'Entre 1 y 50 km, hasta 2 decimales'
        : null;
  }

  Widget _coverageMap() => ClipRRect(
    key: const ValueKey('coverage-map-panel'),
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      height: 300,
      child: FlutterMap(
        key: const ValueKey('store-coverage-map'),
        mapController: _map,
        options: MapOptions(
          initialCenter: _pin ?? const LatLng(-33.4372, -70.6506),
          initialZoom: 11,
          initialCameraFit: _pin == null ? null : _cameraFit(_pin!),
          onMapReady: () => _mapReady = true,
          onTap: _saving ? null : (_, point) => _selectPin(point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.javier.flashdrop.floci',
          ),
          if (_pin != null && _validRadius)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _pin!,
                  radius: _radiusKm! * 1000,
                  useRadiusInMeter: true,
                  color: const Color(0x222775C8),
                  borderColor: const Color(0xFF2775C8),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
          if (_pin != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _pin!,
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () =>
                    launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final radius = _radiusKm;
    final disabled = _saving || _finding;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Zona de despacho'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: !_loaded || _loading
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: disabled ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _saving ? 'Guardando...' : 'Guardar zona',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(
                    _name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  if (_address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _address,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        height: 1.4,
                      ),
                    ),
                    if (_settingsRequired)
                      TextButton.icon(
                        onPressed: disabled
                            ? null
                            : () => Geolocator.openAppSettings(),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Abrir ajustes'),
                      ),
                    if (!_loaded)
                      TextButton.icon(
                        onPressed: disabled ? null : _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recargar'),
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (_loaded) ...[
                    Row(
                      children: [
                        Icon(
                          _pin == null
                              ? Icons.place_outlined
                              : Icons.check_circle_outline,
                          size: 20,
                          color: _pin == null
                              ? AppColors.muted
                              : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pin == null
                                ? 'Ubicación del local por confirmar'
                                : 'Ubicación del local seleccionada',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _coverageMap(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: disabled
                              ? null
                              : () => _findLocation(useGps: true),
                          icon: const Icon(Icons.my_location, size: 20),
                          label: const Text('Usar mi ubicación'),
                        ),
                        if (_address.isNotEmpty)
                          TextButton.icon(
                            onPressed: disabled
                                ? null
                                : () => _findLocation(useGps: false),
                            icon: const Icon(Icons.search, size: 20),
                            label: const Text('Ubicar por dirección'),
                          ),
                      ],
                    ),
                    if (_finding)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      'Radio de reparto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final presets = [5.0, 10.0, 15.0, 20.0];
                        if (constraints.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(14) > 18) {
                          return DropdownButtonFormField<double>(
                            value: presets.contains(radius) ? radius : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Radio sugerido',
                            ),
                            items: [
                              for (final km in presets)
                                DropdownMenuItem(
                                  value: km,
                                  child: Text('${km.toInt()} km'),
                                ),
                            ],
                            onChanged: disabled
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(
                                      () => _radius.text = '${value.toInt()}',
                                    );
                                    _fitMap();
                                  },
                          );
                        }
                        return SegmentedButton<double>(
                          showSelectedIcon: false,
                          emptySelectionAllowed: true,
                          segments: [
                            for (final km in [5.0, 10.0, 15.0, 20.0])
                              ButtonSegment(
                                value: km,
                                label: Text('${km.toInt()} km'),
                              ),
                          ],
                          selected: [5.0, 10.0, 15.0, 20.0].contains(radius)
                              ? {radius!}
                              : {},
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onSelectionChanged: disabled
                              ? null
                              : (values) {
                                  if (values.isEmpty) return;
                                  setState(
                                    () => _radius.text =
                                        '${values.first.toInt()}',
                                  );
                                  _fitMap();
                                },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _radius,
                      enabled: !disabled,
                      decoration: InputDecoration(
                        labelText: 'Radio de despacho',
                        suffixText: 'km',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _radiusError,
                      onChanged: (_) {
                        setState(() {});
                        if (_validRadius) _fitMap();
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
