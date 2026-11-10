import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import 'package:proyecto_app_delivery_gessof/src/pages/client/orders/list/client_orders_list_widget.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/registered_address_resolver.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/client_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/order_status.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/delivery_code_panel.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/map_tracking_osm.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/common.dart';
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
  bool _updating = false;
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
    if (!_stage.isClosed) {
      _timer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _loadOrder(silent: true),
      );
    }
  }

  OrderStage get _stage => OrderStage.of(_order['status']);

  bool get _isDelivered => _stage.isDelivered;

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text('¿Quieres cancelar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updating = true);
    try {
      final result = await _appProvider.updateOrderStatus(
        _orderId,
        'Cancelado',
      );
      if (!mounted) return;
      if (result.success != true) {
        Get.snackbar(
          'No se pudo cancelar',
          result.message ?? 'Actualiza e intenta nuevamente.',
        );
      }
      await _loadOrder(silent: true);
    } catch (_) {
      if (!mounted) return;
      Get.snackbar(
        'No se pudo confirmar',
        'Revisa el estado antes de reintentar.',
      );
      await _loadOrder(silent: true);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  /// Pedidos con entrega segura (o que ya traen PIN) muestran el código.
  bool get _showsDeliveryCode =>
      !_stage.isClosed &&
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
    return ClientTheme(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_loading ? 'Seguimiento' : '${_order['code'] ?? ''}'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loadOrder,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _body(context),
      ),
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
              const Icon(Icons.cloud_off, size: 52, color: FD.navy),
              const SizedBox(height: 12),
              Text(_error!, style: FD.text(15, weight: FontWeight.w600)),
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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
      children: [
        _StatusHero(order: _order, stage: _stage),
        if ('${_order['status']}'.toLowerCase() == 'nuevo pedido') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _updating ? null : _cancelOrder,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar pedido'),
          ),
        ],
        if (_showsDeliveryCode) ...[
          const SizedBox(height: 12),
          DeliveryCodePanel(order: _order),
        ],
        const SizedBox(height: 12),
        if (!_stage.isClosed || _isDelivered)
          _StepsCard(currentStep: _stage.step),
        const SizedBox(height: 12),
        _TrackingMap(
          pickupCoord: _pickupCoord,
          deliveryCoord: _deliveryCoord,
          resolving: !_geocoded,
        ),
        const SizedBox(height: 12),
        WhiteCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          radius: 20,
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.location_on_outlined,
                title: 'Dirección de entrega',
                value: '${_order['address'] ?? '-'}',
              ),
              if (_order['estimatedMinutes'] != null)
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  title: 'Tiempo estimado',
                  value: '${_order['estimatedMinutes']} min',
                ),
              if (_order['paymentMethod'] != null)
                _InfoRow(
                  icon: Icons.payments_outlined,
                  title: 'Forma de pago',
                  value: '${_order['paymentMethod']}',
                  last: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        WhiteCard(
          padding: const EdgeInsets.all(16),
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu pedido', style: FD.section(19)),
              const SizedBox(height: 6),
              ...items.map((item) => _ItemRow(item: item)),
              const Divider(height: 24, color: FD.line),
              _TotalRow(label: 'Subtotal', value: _order['subtotal']),
              const SizedBox(height: 6),
              _TotalRow(label: 'Envío', value: _order['deliveryFee']),
              const SizedBox(height: 6),
              _TotalRow(label: 'Total', value: _order['total'], strong: true),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Cabecera amarilla ────────────────────────────────────────────────────────

class _StatusHero extends StatelessWidget {
  final Map<String, dynamic> order;
  final OrderStage stage;

  const _StatusHero({required this.order, required this.stage});

  @override
  Widget build(BuildContext context) {
    final minutes = order['estimatedMinutes'];
    return Container(
      padding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FD.yellow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido ${order['code'] ?? ''} · ${_clp(order['total'])}',
                      style: FD.text(
                        12.5,
                        weight: FontWeight.w700,
                        color: FD.brown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(stage.headline, style: FD.display(26)),
                    const SizedBox(height: 4),
                    Text(
                      stage.message,
                      style: FD.text(
                        13.5,
                        weight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: stage.step < 0
                    ? const Icon(Icons.cancel_outlined, size: 38)
                    : OrderStepImage(step: stage.step, size: 46),
              ),
            ],
          ),
          if (!stage.isClosed && minutes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: FD.navy,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Llega aprox. en $minutes min',
                style: FD.text(12, weight: FontWeight.w700, color: FD.yellow),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (stage.step >= 0) StageProgressBars(step: stage.step),
          const SizedBox(height: 8),
          Text(
            '${order['status']}',
            style: FD.text(12, weight: FontWeight.w700, color: FD.brown),
          ),
        ],
      ),
    );
  }
}

// ─── Pasos del pedido ─────────────────────────────────────────────────────────

class _StepsCard extends StatelessWidget {
  final int currentStep;
  const _StepsCard({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = OrderStage.labels;
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estado del pedido', style: FD.section(19)),
          const SizedBox(height: 8),
          for (var i = 0; i < labels.length; i++)
            _StepRow(
              index: i,
              label: labels[i],
              done: i < currentStep,
              active: i == currentStep,
              last: i == labels.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String label;
  final bool done;
  final bool active;
  final bool last;

  const _StepRow({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final reached = done || active;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Punto numerado y línea que lo une con el siguiente paso.
          SizedBox(
            width: 30,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: active
                        ? FD.yellow
                        : done
                        ? FD.navy
                        : FD.cream,
                    shape: BoxShape.circle,
                    border: active
                        ? Border.all(color: FD.navy, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: FD.yellow,
                        )
                      : Text(
                          '${index + 1}',
                          style: FD.text(
                            12,
                            weight: FontWeight.w800,
                            color: reached ? FD.navy : FD.subtle,
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: done ? FD.navy : FD.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                label,
                style: FD.text(
                  15,
                  weight: active ? FontWeight.w800 : FontWeight.w600,
                  color: reached ? FD.navy : FD.subtle,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: OrderStepImage(
              step: index,
              size: active ? 34 : 28,
              pending: !reached,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mapa ─────────────────────────────────────────────────────────────────────

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
    return WhiteCard(
      padding: const EdgeInsets.all(12),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mapa de seguimiento', style: FD.section(19)),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    _LegendItem(color: Color(0xFF16824B), label: 'Comercio'),
                    SizedBox(width: 12),
                    _LegendItem(color: FD.yellow, label: 'Tu dirección'),
                  ],
                ),
              ],
            ),
          ),
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
      ),
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
        Text(label, style: FD.text(11, color: FD.muted)),
      ],
    );
  }
}

// ─── Datos y productos ────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool last;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: FD.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FD.soft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: FD.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FD.text(11.5, color: FD.muted)),
                Text(value, style: FD.text(14.5, weight: FontWeight.w700)),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: FD.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '${item['quantity']}x',
              style: FD.text(11.5, weight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${item['name']}',
              style: FD.text(14.5, weight: FontWeight.w700),
            ),
          ),
          Text(
            _clp(item['total']),
            style: FD.text(14, weight: FontWeight.w600),
          ),
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
    final style = strong
        ? FD.display(19)
        : FD.text(14.5, color: FD.muted, weight: FontWeight.w600);
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
