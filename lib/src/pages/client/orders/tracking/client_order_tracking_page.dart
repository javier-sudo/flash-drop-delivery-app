import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/registered_address_resolver.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/order_status.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/delivery_code_panel.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/map_tracking_osm.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/illustration.dart';

class ClientOrderTrackingPage extends StatefulWidget {
  const ClientOrderTrackingPage({super.key});

  @override
  State<ClientOrderTrackingPage> createState() =>
      _ClientOrderTrackingPageState();
}

class _ClientOrderTrackingPageState extends State<ClientOrderTrackingPage> {
  // Permite inyectar un provider (tests); por defecto usa el real.
  final _appProvider = Get.isRegistered<AppProvider>()
      ? Get.find<AppProvider>()
      : AppProvider();

  late final Object _orderId;
  Map<String, dynamic> _order = {};
  bool _loading = true;
  String? _error;
  Timer? _timer;

  LatLng? _pickupCoord;
  LatLng? _deliveryCoord;
  bool _geocoding = false;
  bool _geocoded = false;

  @override
  void initState() {
    super.initState();
    _orderId = Get.arguments ?? '';
    _loadOrder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await _appProvider.getOrderDetail(_orderId);
      await LocalNotificationsService.instance.observeOrders(
        scope: 'client',
        orders: [detail],
        notify: silent,
      );
      if (!mounted) return;
      setState(() {
        _order = detail;
        _loading = false;
      });
      _scheduleRefreshIfActive();
      if (!_geocoding) await _geocodeAddresses();
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'No se pudo cargar el pedido';
          _loading = false;
        });
      }
    }
  }

  void _scheduleRefreshIfActive() {
    _timer?.cancel();
    if (!_isDelivered) {
      _timer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _loadOrder(silent: true),
      );
    }
  }

  OrderStage get _stage => OrderStage.of(_order['status']);

  bool get _isDelivered => _stage.isDelivered;

  /// Pedidos con entrega segura (o que ya traen PIN) muestran el código.
  bool get _showsDeliveryCode =>
      !_isDelivered &&
      ('${_order['receptionMode'] ?? _order['reception_mode'] ?? ''}'
                  .toUpperCase() ==
              'SEGURO' ||
          DeliveryCodePanel.codeOf(_order) != null);

  String get _pickupAddress {
    if (_order['restaurantAddress'] is String &&
        (_order['restaurantAddress'] as String).isNotEmpty) {
      return _order['restaurantAddress'] as String;
    }
    final restaurant = _order['restaurant'];
    if (restaurant is Map) {
      final addr = restaurant['address']?.toString() ?? '';
      if (addr.isNotEmpty) return addr;
    }
    final items = _order['items'] as List?;
    if (items != null && items.isNotEmpty) {
      final first = items.first as Map?;
      final addr = first?['restaurantAddress']?.toString() ?? '';
      if (addr.isNotEmpty) return addr;
    }
    return '';
  }

  Future<void> _geocodeAddresses() async {
    _geocoding = true;
    final delivery = '${_order['address'] ?? ''}';
    final pickup = _pickupAddress;

    if (delivery.isNotEmpty) {
      _deliveryCoord = await _geocode(delivery);
    }
    if (pickup.isNotEmpty && pickup != delivery) {
      _pickupCoord = await _geocode(pickup);
    }
    _geocoding = false;
    _geocoded = true;
    if (mounted) setState(() {});
  }

  Future<LatLng?> _geocode(String address) =>
      RegisteredAddressResolver.resolve(address);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Seguimiento' : '${_order['code'] ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadOrder,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 52),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _loadOrder,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final items = List<Map<String, dynamic>>.from(_order['items'] ?? []);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _StatusHeader(statusText: '${_order['status']}', stage: _stage),
        if (_showsDeliveryCode) ...[
          const SizedBox(height: 12),
          DeliveryCodePanel(order: _order),
        ],
        const SizedBox(height: 20),
        _StatusTimeline(currentStep: _stage.step),
        const SizedBox(height: 22),
        _TrackingMap(
          pickupCoord: _pickupCoord,
          deliveryCoord: _deliveryCoord,
          resolving: !_geocoded,
        ),
        const SizedBox(height: 18),
        _InfoCard(
          icon: Icons.location_on_outlined,
          title: 'Dirección de entrega',
          value: '${_order['address'] ?? '-'}',
        ),
        if (_order['estimatedMinutes'] != null) ...[
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.schedule,
            title: 'Tiempo estimado',
            value: '${_order['estimatedMinutes']} min',
          ),
        ],
        if (_order['paymentMethod'] != null) ...[
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.payments_outlined,
            title: 'Forma de pago',
            value: '${_order['paymentMethod']}',
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Tu pedido',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...items.map((item) => _ItemRow(item: item)),
        const Divider(height: 28),
        _TotalRow(label: 'Subtotal', value: _order['subtotal']),
        const SizedBox(height: 6),
        _TotalRow(label: 'Envío', value: _order['deliveryFee']),
        const SizedBox(height: 4),
        _TotalRow(label: 'Total', value: _order['total'], strong: true),
      ],
    );
  }
}

// ─── Status header ────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final String statusText;
  final OrderStage stage;

  const _StatusHeader({required this.statusText, required this.stage});

  @override
  Widget build(BuildContext context) {
    final color = stage.color;
    final bg = switch (stage.step) {
      0 => const Color(0xFFEEF3FF),
      3 => const Color(0xFFE8F0FE),
      4 => const Color(0xFFE6F4ED),
      _ => const Color(0xFFFFF8E1),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: OrderStepImage(step: stage.step, size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(stage.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status timeline ──────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final int currentStep;

  const _StatusTimeline({required this.currentStep});

  static const _labels = OrderStage.labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final filled = (i ~/ 2) < currentStep;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: filled
                      ? const Color(0xFFFFB300)
                      : const Color(0xFFE0E2E6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }
          final step = i ~/ 2;
          final done = step <= currentStep;
          final active = step == currentStep;
          return _StepDot(
            step: step,
            label: _labels[step],
            done: done,
            active: active,
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int step;
  final String label;
  final bool done;
  final bool active;

  const _StepDot({
    required this.step,
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // El paso actual se destaca con un halo ámbar; los pendientes van en gris.
        // Alto fijo para que todas las etiquetas queden a la misma altura.
        SizedBox(
          height: 50,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 50 : 38,
              height: active ? 50 : 38,
              padding: EdgeInsets.all(active ? 6 : 3),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFFFF3CD) : Colors.transparent,
                shape: BoxShape.circle,
                border: active
                    ? Border.all(color: const Color(0xFFFFB300), width: 2)
                    : null,
              ),
              child: OrderStepImage(step: step, size: 38, pending: !done),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w900 : FontWeight.w400,
            color: done ? const Color(0xFF1E2025) : const Color(0xFFB0B5BB),
          ),
        ),
      ],
    );
  }
}

// ─── Tracking map ─────────────────────────────────────────────────────────────

class _TrackingMap extends StatelessWidget {
  final LatLng? pickupCoord;
  final LatLng? deliveryCoord;
  final bool resolving;

  const _TrackingMap({
    required this.pickupCoord,
    required this.deliveryCoord,
    required this.resolving,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mapa de seguimiento',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            _LegendItem(color: const Color(0xFF16824B), label: 'Comercio'),
            const SizedBox(width: 12),
            _LegendItem(color: const Color(0xFFFFB300), label: 'Tu dirección'),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 220,
            child: MapTrackingWidget(
              pickupLocation: pickupCoord,
              deliveryLocation: deliveryCoord,
              resolving: resolving,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ─── Info / item widgets ──────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF9EA5AD)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9EA5AD),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${item['quantity']}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${item['name']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(_clp(item['total'])),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool strong;

  const _TotalRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: strong ? 18 : 15,
      fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(_clp(value), style: style),
      ],
    );
  }
}

String _clp(dynamic value) {
  final number = double.tryParse('$value') ?? 0;
  return '\$${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
}
