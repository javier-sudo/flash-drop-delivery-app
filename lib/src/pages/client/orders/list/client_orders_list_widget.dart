import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/client_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/order_status.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/common.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/illustration.dart';

enum _Filter { all, active, delivered }

class ClientOrdersListWidget extends StatefulWidget {
  const ClientOrdersListWidget({super.key});

  @override
  State<ClientOrdersListWidget> createState() => _ClientOrdersListWidgetState();
}

class _ClientOrdersListWidgetState extends State<ClientOrdersListWidget> {
  // Permite inyectar un provider (tests); por defecto usa el real.
  final _appProvider = Get.isRegistered<AppProvider>()
      ? Get.find<AppProvider>()
      : AppProvider();
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadOrders(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _appProvider.getOrders(view: 'client');
      // Solo avisa en las recargas automáticas, no al abrir la pantalla.
      await LocalNotificationsService.instance.observeOrders(
        scope: 'client',
        orders: data,
        notify: silent,
      );
      data.sort((a, b) => orderTime(b).compareTo(orderTime(a)));
      if (!mounted) return;
      setState(() {
        _orders = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'No se pudieron cargar tus pedidos';
          _loading = false;
        });
      }
    }
  }

  void _openTracking(Map<String, dynamic> order) =>
      Get.toNamed('/client/orders/tracking', arguments: order['id']);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      // ListView para que el gesto de "tirar para actualizar" siga disponible.
      return ListView(
        children: [
          const PageTitle('Mis pedidos'),
          const SizedBox(height: 24),
          IllustratedMessage(
            illustration: AppIllustration.noConnection,
            title: _error!,
            message: 'Revisa tu conexión e intenta de nuevo.',
            actionLabel: 'Reintentar',
            onAction: _loadOrders,
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        children: const [PageTitle('Mis pedidos'), _EmptyState()],
      );
    }

    final active = _orders
        .where((o) => !OrderStage.of(o['status']).isClosed)
        .toList();
    final history = _orders
        .where((o) => OrderStage.of(o['status']).isDelivered)
        .toList();
    final closed = _orders.where((o) {
      final stage = OrderStage.of(o['status']);
      return stage.isClosed && !stage.isDelivered;
    }).toList();
    final showActive = _filter != _Filter.delivered;
    final showHistory = _filter != _Filter.active;
    final shown =
        (showActive ? active.length : 0) +
        (showHistory ? history.length : 0) +
        (_filter == _Filter.all ? closed.length : 0);

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const PageTitle('Mis pedidos'),
          const SizedBox(height: 12),
          _FilterBar(
            value: _filter,
            activeCount: active.length,
            deliveredCount: history.length,
            onChanged: (f) => setState(() => _filter = f),
          ),
          if (shown == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                _filter == _Filter.delivered
                    ? 'Aún no tienes pedidos entregados.'
                    : 'No tienes pedidos en curso.',
                textAlign: TextAlign.center,
                style: FD.text(14, color: FD.muted),
              ),
            ),
          if (showActive && active.isNotEmpty) ...[
            const SectionTitle('En curso', bolt: true),
            for (final o in active)
              _ActiveOrderCard(order: o, onTap: () => _openTracking(o)),
          ],
          if (showHistory && history.isNotEmpty) ...[
            const SectionTitle('Historial'),
            for (final o in history)
              _PastOrderCard(order: o, onTap: () => _openTracking(o)),
          ],
          if (_filter == _Filter.all && closed.isNotEmpty) ...[
            const SectionTitle('Cancelados y rechazados'),
            for (final o in closed)
              _PastOrderCard(order: o, onTap: () => _openTracking(o)),
          ],
        ],
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final _Filter value;
  final int activeCount;
  final int deliveredCount;
  final ValueChanged<_Filter> onChanged;

  const _FilterBar({
    required this.value,
    required this.activeCount,
    required this.deliveredCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (_Filter.all, 'Todos'),
      (_Filter.active, 'En curso · $activeCount'),
      (_Filter.delivered, 'Entregados · $deliveredCount'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          for (final (filter, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: value == filter,
                onSelected: (_) => onChanged(filter),
                showCheckmark: false,
                labelStyle: FD.text(
                  13,
                  weight: FontWeight.w700,
                  color: value == filter ? FD.yellow : FD.navy,
                ),
                selectedColor: FD.navy,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: value == filter ? FD.navy : const Color(0xFFE3DFD4),
                  width: 1.5,
                ),
                shape: const StadiumBorder(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pedido en curso: tarjeta amarilla con titular, llegada estimada y barras
/// de avance (una por etapa).
class _ActiveOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _ActiveOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stage = OrderStage.of(order['status']);
    final minutes = num.tryParse('${order['estimatedMinutes'] ?? ''}')?.round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Material(
        color: FD.yellow,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              const Positioned(
                right: -24,
                top: -24,
                child: Opacity(
                  opacity: 0.18,
                  child: BoltIcon(size: 120, color: FD.navy, outlined: false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
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
                    Text(stage.headline, style: FD.display(24)),
                    const SizedBox(height: 2),
                    Text(
                      '${order['restaurantName'] ?? 'Comercio'}'
                      '${minutes == null ? '' : ' · Llega aprox. en $minutes min'}',
                      style: FD.text(13.5, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    StageProgressBars(step: stage.step),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Flexible(
                          child: _StatusPill(text: '${order['status']}'),
                        ),
                        const SizedBox(width: 8),
                        const Spacer(),
                        Text(
                          'Seguimiento',
                          style: FD.text(13, weight: FontWeight.w800),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: FD.navy,
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
}

/// Pedido entregado: tarjeta blanca compacta.
class _PastOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _PastOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FD.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              OrderStage.of(order['status']).isDelivered
                  ? Icons.check_rounded
                  : Icons.cancel_outlined,
              color: FD.navy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order['restaurantName'] ?? 'Comercio'}',
                  style: FD.text(15, weight: FontWeight.w700),
                ),
                Text(
                  '${order['code'] ?? ''} · ${order['status']}',
                  style: FD.text(12.5, color: FD.muted),
                ),
              ],
            ),
          ),
          Text(
            _clp(order['total']),
            style: FD.text(15, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FD.navy,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FD.text(11.5, weight: FontWeight.w700, color: FD.yellow),
      ),
    );
  }
}

/// Cinco barras, una por etapa del pedido: las completadas en marino.
class StageProgressBars extends StatelessWidget {
  final int step;
  final Color done;
  final Color pending;

  const StageProgressBars({
    super.key,
    required this.step,
    this.done = FD.navy,
    this.pending = const Color(0x400E1A35),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < OrderStage.labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 6,
              decoration: BoxDecoration(
                color: i <= step ? done : pending,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const IllustratedMessage(
      illustration: AppIllustration.emptyOrders,
      title: 'Aún no tienes pedidos',
      message:
          'Cuando hagas tu primer pedido lo verás aquí con seguimiento en tiempo real.',
    );
  }
}

String _clp(dynamic value) {
  final number = double.tryParse('$value') ?? 0;
  return '\$${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
}
