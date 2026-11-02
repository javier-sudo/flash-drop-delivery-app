import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';

class ClientOrdersListWidget extends StatefulWidget {
  const ClientOrdersListWidget({super.key});

  @override
  State<ClientOrdersListWidget> createState() => _ClientOrdersListWidgetState();
}

class _ClientOrdersListWidgetState extends State<ClientOrdersListWidget> {
  final _appProvider = AppProvider();
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  _ClientOrderFilter _filter = _ClientOrderFilter.active;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
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
      await LocalNotificationsService.instance.observeOrders(
        scope: 'client',
        orders: data,
        notify: silent,
      );
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
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off, size: 52, color: Color(0xFF9EA5AD)),
          const SizedBox(height: 12),
          Center(child: Text(_error!)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    if (_orders.isEmpty) return const _EmptyState();

    final active =
        _orders
            .where((o) => !_OrderStatus.of('${o['status']}').isDelivered)
            .toList()
          ..sort(_compareOrders);
    final history =
        _orders
            .where((o) => _OrderStatus.of('${o['status']}').isDelivered)
            .toList()
          ..sort((a, b) => _orderTime(b).compareTo(_orderTime(a)));
    final visible = switch (_filter) {
      _ClientOrderFilter.all => [
        ..._orders,
      ]..sort((a, b) => _orderTime(b).compareTo(_orderTime(a))),
      _ClientOrderFilter.active => active,
      _ClientOrderFilter.delivered => history,
    };

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _SectionLabel(
            title: _filter == _ClientOrderFilter.delivered
                ? 'Historial'
                : 'Tus pedidos',
            count: visible.length,
            dot: _filter == _ClientOrderFilter.delivered
                ? const Color(0xFF9EA5AD)
                : const Color(0xFF1769C2),
          ),
          const SizedBox(height: 12),
          _ClientOrderFilterBar(
            selected: _filter,
            activeCount: active.length,
            deliveredCount: history.length,
            onChanged: (filter) => setState(() => _filter = filter),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            _FilteredEmptyState(filter: _filter)
          else
            ...visible.map(
              (o) => _OrderCard(
                order: o,
                onTap: () =>
                    Get.toNamed('/client/orders/tracking', arguments: o['id']),
              ),
            ),
        ],
      ),
    );
  }

  int _compareOrders(Map<String, dynamic> a, Map<String, dynamic> b) {
    return _orderTime(b).compareTo(_orderTime(a));
  }
}

enum _ClientOrderFilter { all, active, delivered }

// ─── Status helper ────────────────────────────────────────────────────────────

class _OrderStatus {
  final int step;
  final bool isDelivered;
  final Color color;

  const _OrderStatus({
    required this.step,
    required this.isDelivered,
    required this.color,
  });

  factory _OrderStatus.of(String status) {
    final s = status.toLowerCase();
    if (s.contains('entregado')) {
      return const _OrderStatus(
        step: 4,
        isDelivered: true,
        color: Color(0xFF12643D),
      );
    }
    if (s.contains('camino') || s.contains('retirado')) {
      return const _OrderStatus(
        step: 3,
        isDelivered: false,
        color: Color(0xFF1565C0),
      );
    }
    if (s.contains('listo')) {
      return const _OrderStatus(
        step: 2,
        isDelivered: false,
        color: Color(0xFF8A5700),
      );
    }
    if (s.contains('preparando')) {
      return const _OrderStatus(
        step: 1,
        isDelivered: false,
        color: Color(0xFF8A5700),
      );
    }
    return const _OrderStatus(
      step: 0,
      isDelivered: false,
      color: Color(0xFF1769C2),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

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

class _ClientOrderFilterBar extends StatelessWidget {
  final _ClientOrderFilter selected;
  final int activeCount;
  final int deliveredCount;
  final ValueChanged<_ClientOrderFilter> onChanged;

  const _ClientOrderFilterBar({
    required this.selected,
    required this.activeCount,
    required this.deliveredCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ClientFilterChip(
            label: 'Todos',
            selected: selected == _ClientOrderFilter.all,
            onTap: () => onChanged(_ClientOrderFilter.all),
          ),
          const SizedBox(width: 8),
          _ClientFilterChip(
            label: 'En curso · $activeCount',
            selected: selected == _ClientOrderFilter.active,
            onTap: () => onChanged(_ClientOrderFilter.active),
          ),
          const SizedBox(width: 8),
          _ClientFilterChip(
            label: 'Entregados · $deliveredCount',
            selected: selected == _ClientOrderFilter.delivered,
            onTap: () => onChanged(_ClientOrderFilter.delivered),
          ),
        ],
      ),
    );
  }
}

class _ClientFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ClientFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0F5132) : const Color(0xFF565C64),
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      selectedColor: const Color(0xFFDFF6E8),
      side: BorderSide(
        color: selected ? const Color(0xFF12643D) : const Color(0xFFD7D9DD),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = _OrderStatus.of('${order['status']}');
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

  static const _labels = [
    'Recibido',
    'Preparando',
    'Listo',
    'En camino',
    'Entregado',
  ];
  static const _icons = [
    Icons.receipt_long_outlined,
    Icons.soup_kitchen_outlined,
    Icons.inventory_2_outlined,
    Icons.delivery_dining,
    Icons.home_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (i) {
        final done = i <= step;
        final active = i == step;
        return Expanded(
          child: Column(
            children: [
              Icon(
                _icons[i],
                size: 20,
                color: done
                    ? (active
                          ? const Color(0xFFFFB300)
                          : const Color(0xFF12643D))
                    : const Color(0xFFD6D8DC),
              ),
              const SizedBox(height: 3),
              Text(
                _labels[i],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3CD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 44,
                color: Color(0xFFFFB300),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Aun no tienes pedidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando hagas tu primer pedido lo verás aquí con seguimiento en tiempo real.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6A6F77)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  final _ClientOrderFilter filter;

  const _FilteredEmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final message = filter == _ClientOrderFilter.delivered
        ? 'Aún no tienes pedidos entregados.'
        : 'No tienes pedidos en curso.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(message, style: const TextStyle(color: Color(0xFF6A6F77))),
      ),
    );
  }
}

DateTime _orderTime(Map<String, dynamic> order) {
  return DateTime.tryParse('${order['createdAt'] ?? ''}') ?? DateTime(0);
}

String _clp(dynamic value) {
  final number = double.tryParse('$value') ?? 0;
  return '\$${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
}
