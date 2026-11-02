import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/order_status.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      // ListView para que el gesto de "tirar para actualizar" siga disponible.
      return ListView(
        children: [
          const SizedBox(height: 40),
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

    if (_orders.isEmpty) return const _EmptyState();

    final active = _orders
        .where((o) => !OrderStage.of(o['status']).isDelivered)
        .toList();
    final history = _orders
        .where((o) => OrderStage.of(o['status']).isDelivered)
        .toList();
    final showActive = _filter != _Filter.delivered;
    final showHistory = _filter != _Filter.active;
    final shown =
        (showActive ? active.length : 0) + (showHistory ? history.length : 0);

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _FilterBar(
            value: _filter,
            activeCount: active.length,
            deliveredCount: history.length,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 14),
          if (shown == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                _filter == _Filter.delivered
                    ? 'Aún no tienes pedidos entregados.'
                    : 'No tienes pedidos en curso.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF7B8189)),
              ),
            ),
          if (showActive && active.isNotEmpty) ...[
            _SectionLabel(
              title: 'En curso',
              count: active.length,
              dot: const Color(0xFF1769C2),
            ),
            const SizedBox(height: 10),
            ...active.map(
              (o) => _OrderCard(
                order: o,
                onTap: () =>
                    Get.toNamed('/client/orders/tracking', arguments: o['id']),
              ),
            ),
            const SizedBox(height: 22),
          ],
          if (showHistory && history.isNotEmpty) ...[
            _SectionLabel(
              title: 'Historial',
              count: history.length,
              dot: const Color(0xFF9EA5AD),
            ),
            const SizedBox(height: 10),
            ...history.map(
              (o) => _OrderCard(
                order: o,
                onTap: () =>
                    Get.toNamed('/client/orders/tracking', arguments: o['id']),
              ),
            ),
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
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: value == filter
                      ? const Color(0xFF1E2025)
                      : const Color(0xFF6A6F77),
                ),
                selectedColor: const Color(0xFFFFE08A),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: value == filter
                      ? const Color(0xFFFFB300)
                      : const Color(0xFFE4E7EC),
                ),
                shape: const StadiumBorder(),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final int count;
  final Color dot;

  const _SectionLabel({
    required this.title,
    required this.count,
    required this.dot,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
        Text('$count', style: const TextStyle(color: Color(0xFF7B8189))),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = OrderStage.of(order['status']);
    final restaurant = '${order['restaurantName'] ?? 'Comercio'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      restaurant,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusPill(text: '${order['status']}', color: meta.color),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.receipt_outlined,
                    size: 15,
                    color: Color(0xFF9EA5AD),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${order['code']}',
                    style: const TextStyle(color: Color(0xFF6A6F77)),
                  ),
                  const Spacer(),
                  Text(
                    _clp(order['total']),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              if (!meta.isDelivered) ...[
                const SizedBox(height: 12),
                _MiniTimeline(step: meta.step),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Ver seguimiento',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniTimeline extends StatelessWidget {
  final int step;

  const _MiniTimeline({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = OrderStage.labels;
    return Row(
      children: List.generate(labels.length, (i) {
        final done = i <= step;
        final active = i == step;
        return Expanded(
          child: Column(
            children: [
              // Alto fijo: el paso activo es más grande sin desalinear las etiquetas.
              SizedBox(
                height: 30,
                child: Center(
                  child: OrderStepImage(
                    step: i,
                    size: active ? 30 : 22,
                    pending: !done,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w400,
                  color: done
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFB0B5BB),
                ),
              ),
            ],
          ),
        );
      }),
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
