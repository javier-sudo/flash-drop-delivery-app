import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';

class RestaurantOrdersListPage extends StatefulWidget {
  const RestaurantOrdersListPage({super.key});

  @override
  State<RestaurantOrdersListPage> createState() =>
      _RestaurantOrdersListPageState();
}

class _RestaurantOrdersListPageState extends State<RestaurantOrdersListPage> {
  final HomeController con = Get.put(HomeController());
  final AppProvider appProvider = AppProvider();

  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String? errorMessage;
  _RestaurantOrderFilter _filter = _RestaurantOrderFilter.all;
  Timer? _refreshTimer;

  User get currentUser {
    final raw = GetStorage().read('user');
    return User.fromJson(
      raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw),
    );
  }

  bool get hasMultipleRoles => currentUser.roles.length > 1;

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
        loading = true;
        errorMessage = null;
      });
    }
    try {
      final data = await appProvider.getOrders(view: 'restaurant');
      await LocalNotificationsService.instance.observeOrders(
        scope: 'commerce',
        orders: data,
        notify: silent,
      );
      if (!mounted) return;
      setState(() {
        orders = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          loading = false;
          errorMessage = 'No se pudieron cargar los pedidos';
        });
      }
    }
  }

  int get activeCount => orders.where((order) => !_isDelivered(order)).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos del local'),
        actions: [
          IconButton(
            tooltip: 'Actualizar pedidos',
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
          if (hasMultipleRoles)
            IconButton(
              tooltip: 'Cambiar rol',
              onPressed: con.changeRole,
              icon: const Icon(Icons.swap_horiz),
            ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: con.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadOrders, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.cloud_off_outlined, size: 50),
          const SizedBox(height: 12),
          Center(child: Text(errorMessage!)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    final restaurantName = orders.isNotEmpty
        ? '${orders.first['restaurantName']}'
        : (currentUser.name ?? 'Mi comercio');
    final visibleOrders = orders.where(_matchesFilter).toList()
      ..sort(_compareOrdersByNewest);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _SummaryHeader(
          restaurantName: restaurantName,
          activeCount: activeCount,
          totalCount: orders.length,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                _filter == _RestaurantOrderFilter.all
                    ? 'Pedidos'
                    : _filter.label,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text('${visibleOrders.length} pedidos'),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.sort, size: 16, color: Color(0xFF6A6F77)),
            const SizedBox(width: 6),
            const Text(
              'Más recientes primero; del más reciente al más antiguo',
              style: TextStyle(color: Color(0xFF6A6F77)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _RestaurantOrderFilterBar(
          selected: _filter,
          orders: orders,
          onChanged: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: 16),
        if (visibleOrders.isEmpty)
          _EmptyOrders(filter: _filter)
        else
          ...visibleOrders.map(
            (order) =>
                _OrderCard(order: order, onTap: () => _openOrderDetail(order)),
          ),
      ],
    );
  }

  bool _matchesFilter(Map<String, dynamic> order) {
    final status = '${order['status']}'.toLowerCase();
    return switch (_filter) {
      _RestaurantOrderFilter.all => true,
      _RestaurantOrderFilter.newOrder => status.contains('nuevo'),
      _RestaurantOrderFilter.preparing => status.contains('preparando'),
      _RestaurantOrderFilter.ready => status.contains('listo'),
      _RestaurantOrderFilter.inTransit =>
        status.contains('camino') || status.contains('retirado'),
      _RestaurantOrderFilter.delivered => status.contains('entregado'),
    };
  }

  bool _isDelivered(Map<String, dynamic> order) =>
      '${order['status']}'.toLowerCase().contains('entregado');

  int _compareOrdersByNewest(Map<String, dynamic> a, Map<String, dynamic> b) =>
      _orderTime(b).compareTo(_orderTime(a));

  Future<void> _openOrderDetail(Map<String, dynamic> summary) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.9,
        child: FutureBuilder<Map<String, dynamic>>(
          future: appProvider.getOrderDetail(summary['id']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return const Center(child: Text('No se pudo abrir el pedido'));
            }
            return _OrderDetail(
              order: snapshot.data!,
              onStatusChanged: (status) async {
                final response = await appProvider.updateOrderStatus(
                  summary['id'],
                  status,
                );
                if (!mounted) return;
                if (response.success == true) {
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  Get.snackbar(
                    'Pedido actualizado',
                    'El pedido ahora esta $status.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  await _loadOrders();
                } else {
                  Get.snackbar(
                    'No se pudo actualizar',
                    response.message ?? 'Intenta nuevamente.',
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}

enum _RestaurantOrderFilter {
  all('Todos'),
  newOrder('Nuevos'),
  preparing('Preparando'),
  ready('Listos'),
  inTransit('En ruta'),
  delivered('Entregados');

  final String label;
  const _RestaurantOrderFilter(this.label);
}

class _RestaurantOrderFilterBar extends StatelessWidget {
  final _RestaurantOrderFilter selected;
  final List<Map<String, dynamic>> orders;
  final ValueChanged<_RestaurantOrderFilter> onChanged;

  const _RestaurantOrderFilterBar({
    required this.selected,
    required this.orders,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _RestaurantOrderFilter.values.map((filter) {
          final count = orders.where((order) {
            final status = '${order['status']}'.toLowerCase();
            return switch (filter) {
              _RestaurantOrderFilter.all => true,
              _RestaurantOrderFilter.newOrder => status.contains('nuevo'),
              _RestaurantOrderFilter.preparing => status.contains('preparando'),
              _RestaurantOrderFilter.ready => status.contains('listo'),
              _RestaurantOrderFilter.inTransit =>
                status.contains('camino') || status.contains('retirado'),
              _RestaurantOrderFilter.delivered => status.contains('entregado'),
            };
          }).length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('${filter.label} · $count'),
              selected: selected == filter,
              showCheckmark: false,
              onSelected: (_) => onChanged(filter),
              labelStyle: TextStyle(
                color: selected == filter
                    ? const Color(0xFF0F5132)
                    : const Color(0xFF565C64),
                fontWeight: selected == filter
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
              selectedColor: const Color(0xFFDFF6E8),
              side: BorderSide(
                color: selected == filter
                    ? const Color(0xFF12643D)
                    : const Color(0xFFD7D9DD),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final String restaurantName;
  final int activeCount;
  final int totalCount;

  const _SummaryHeader({
    required this.restaurantName,
    required this.activeCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF123D2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFDCF5E7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.storefront, color: Color(0xFF12643D)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activeCount activos de $totalCount pedidos',
                  style: const TextStyle(color: Color(0xFFC6D8CF)),
                ),
              ],
            ),
          ),
        ],
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
    final ageLabel = _orderAgeLabel(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E4E8)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${order['code']}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  _StatusChip(text: '${order['status']}'),
                ],
              ),
              if (ageLabel != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 15,
                      color: Color(0xFF6A6F77),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      ageLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6A6F77),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: ageLabel == null ? 12 : 10),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 19,
                    backgroundColor: Color(0xFFE8F5ED),
                    child: Icon(Icons.person_outline, color: Color(0xFF12643D)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order['clientName']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${order['address']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _clp(order['total']),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Ver detalle',
                    style: TextStyle(
                      color: Color(0xFF1769C2),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Color(0xFF1769C2)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  final Map<String, dynamic> order;
  final Future<void> Function(String status) onStatusChanged;

  const _OrderDetail({required this.order, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final client = Map<String, dynamic>.from(order['client'] ?? {});
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final navigationBar = MediaQuery.viewPaddingOf(context).bottom;
    final status = '${order['status']}';
    final nextStatus = status == 'Nuevo pedido'
        ? 'Preparando'
        : status == 'Preparando'
        ? 'Listo para retiro'
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 16 + navigationBar),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7D9DD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order['code']}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(text: status),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                const _SectionTitle(
                  icon: Icons.person_outline,
                  text: 'Cliente',
                ),
                Text(
                  '${client['name'] ?? 'Cliente'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ('${client['phone'] ?? ''}'.isNotEmpty)
                  Text('${client['phone']}'),
                if ('${client['email'] ?? ''}'.isNotEmpty)
                  Text('${client['email']}'),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 20),
                    const SizedBox(width: 7),
                    Expanded(child: Text('${order['address']}')),
                  ],
                ),
                const Divider(height: 32),
                const _SectionTitle(
                  icon: Icons.receipt_long_outlined,
                  text: 'Detalle del pedido',
                ),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['name']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if ('${item['description'] ?? ''}'.isNotEmpty)
                                Text(
                                  '${item['description']}',
                                  style: const TextStyle(
                                    color: Color(0xFF6A6F77),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(_clp(item['total'])),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 28),
                _TotalRow(label: 'Subtotal', value: order['subtotal']),
                _TotalRow(label: 'Envio', value: order['deliveryFee']),
                _TotalRow(label: 'Total', value: order['total'], strong: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 20),
                    const SizedBox(width: 7),
                    Text('Pago: ${order['paymentMethod']}'),
                  ],
                ),
              ],
            ),
          ),
          if (nextStatus != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onStatusChanged(nextStatus),
                icon: Icon(
                  nextStatus == 'Preparando'
                      ? Icons.soup_kitchen_outlined
                      : Icons.inventory_2_outlined,
                ),
                label: Text(
                  nextStatus == 'Preparando'
                      ? 'Aceptar y preparar'
                      : 'Marcar listo para retiro',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF12643D)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
    final style = TextStyle(
      fontSize: strong ? 18 : 15,
      fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(_clp(value), style: style),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;

  const _StatusChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final normalized = text.toLowerCase();
    final color = normalized == 'entregado'
        ? const Color(0xFF12643D)
        : normalized.contains('listo')
        ? const Color(0xFF8A5700)
        : const Color(0xFF1769C2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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

class _EmptyOrders extends StatelessWidget {
  final _RestaurantOrderFilter filter;

  const _EmptyOrders({this.filter = _RestaurantOrderFilter.all});

  @override
  Widget build(BuildContext context) {
    final message = filter == _RestaurantOrderFilter.all
        ? 'Este comercio aún no tiene pedidos'
        : 'No hay pedidos ${filter.label.toLowerCase()}.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 52,
            color: Color(0xFF7B8189),
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w900)),
          if (filter == _RestaurantOrderFilter.all) ...[
            const SizedBox(height: 5),
            const Text('Los nuevos pedidos aparecerán aquí automáticamente.'),
          ],
        ],
      ),
    );
  }
}

DateTime _orderTime(Map<String, dynamic> order) {
  return DateTime.tryParse('${order['createdAt'] ?? ''}') ?? DateTime(0);
}

String? _orderAgeLabel(Map<String, dynamic> order) {
  final createdAt = DateTime.tryParse('${order['createdAt'] ?? ''}');
  if (createdAt == null) return null;

  final elapsed = DateTime.now().difference(createdAt.toLocal());
  if (elapsed.isNegative || elapsed.inMinutes == 0) return 'Ingresó recién';
  if (elapsed.inDays >= 1) return 'Hace ${elapsed.inDays} d';
  if (elapsed.inHours >= 1) return 'Hace ${elapsed.inHours} h';
  return 'Hace ${elapsed.inMinutes} min';
}

String _clp(dynamic value) {
  final number = double.tryParse('$value') ?? 0;
  return '\$${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')}';
}
