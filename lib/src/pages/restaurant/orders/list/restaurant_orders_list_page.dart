import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/order_status.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/illustration.dart';

/// Filtros del panel del local. Cada pedido cae en uno (salvo `all`).
enum RestaurantTab {
  all('Todos'),
  incoming('Nuevos'),
  preparing('Preparando'),
  ready('Listos'),
  inTransit('En ruta'),
  delivered('Entregados'),
  closed('Cancelados');

  final String label;
  const RestaurantTab(this.label);
}

/// Estado de un pedido para el panel del local: en qué pestaña va, color y
/// siguiente acción disponible.
class RestaurantOrderStatus {
  final RestaurantTab tab;
  final Color color;
  final String? nextStatus;
  final String? actionLabel;
  final IconData? actionIcon;

  const RestaurantOrderStatus._(
    this.tab,
    this.color, [
    this.nextStatus,
    this.actionLabel,
    this.actionIcon,
  ]);

  factory RestaurantOrderStatus.of(String status) {
    final s = status.toLowerCase();
    if (s == 'cancelado' || s == 'rechazado') {
      return const RestaurantOrderStatus._(
        RestaurantTab.closed,
        Color(0xFF9C2732),
      );
    }
    if (s == 'nuevo pedido') {
      return const RestaurantOrderStatus._(
        RestaurantTab.incoming,
        Color(0xFF1769C2),
        'Preparando',
        'Aceptar',
        Icons.check,
      );
    }
    if (s == 'preparando') {
      return const RestaurantOrderStatus._(
        RestaurantTab.preparing,
        AppColors.primaryDark,
        'Listo para retiro',
        'Marcar listo',
        Icons.inventory_2_outlined,
      );
    }
    if (s.contains('entregado')) {
      return const RestaurantOrderStatus._(
        RestaurantTab.delivered,
        AppColors.success,
      );
    }
    if (s.contains('camino') || s.contains('retirado')) {
      return const RestaurantOrderStatus._(
        RestaurantTab.inTransit,
        Color(0xFF1565C0),
      );
    }
    // Listo para retiro o Asignado: espera al repartidor en el local.
    return const RestaurantOrderStatus._(
      RestaurantTab.ready,
      Color(0xFF6A4FB3),
    );
  }
}

/// "hace 5 min" a partir de createdAt (ISO). Null si no viene o no se entiende.
String? timeAgo(dynamic createdAt, {DateTime? now}) {
  final date = DateTime.tryParse('${createdAt ?? ''}');
  if (date == null) return null;
  final minutes = (now ?? DateTime.now()).difference(date).inMinutes;
  if (minutes < 1) return 'recién';
  if (minutes < 60) return 'hace $minutes min';
  final hours = minutes ~/ 60;
  return hours < 24 ? 'hace $hours h' : 'hace ${hours ~/ 24} d';
}

class RestaurantOrdersListPage extends StatefulWidget {
  const RestaurantOrdersListPage({super.key});

  @override
  State<RestaurantOrdersListPage> createState() =>
      _RestaurantOrdersListPageState();
}

class _RestaurantOrdersListPageState extends State<RestaurantOrdersListPage> {
  final HomeController con = Get.put(HomeController());
  // Permite inyectar un provider (tests); por defecto usa el real.
  final AppProvider appProvider = Get.isRegistered<AppProvider>()
      ? Get.find<AppProvider>()
      : AppProvider();

  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String? errorMessage;
  RestaurantTab tab = RestaurantTab.incoming;
  final Set<Object> _updating = {};
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
      // Avisa de pedidos nuevos y cambios solo en las recargas automáticas.
      await LocalNotificationsService.instance.observeOrders(
        scope: 'commerce',
        orders: data,
        notify: silent,
      );
      data.sort((a, b) => orderTime(b).compareTo(orderTime(a)));
      if (!mounted) return;
      setState(() {
        orders = data;
        loading = false;
        errorMessage = null;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        loading = false;
        errorMessage = 'No se pudieron cargar los pedidos';
      });
    }
  }

  List<Map<String, dynamic>> _ordersIn(RestaurantTab t) =>
      t == RestaurantTab.all
      ? orders
      : orders
            .where((o) => RestaurantOrderStatus.of('${o['status']}').tab == t)
            .toList();

  int _count(String status) =>
      orders.where((o) => '${o['status']}' == status).length;

  Future<void> _changeStatus(Object id, String status) async {
    setState(() => _updating.add(id));
    final ResponseApi response;
    try {
      response = await appProvider.updateOrderStatus(id, status);
    } catch (e) {
      debugPrint('updateOrderStatus falló: $e');
      if (!mounted) return;
      setState(() => _updating.remove(id));
      Get.snackbar(
        'Sin conexión',
        'No se pudo actualizar el pedido. Intenta nuevamente.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _updating.remove(id));
    if (response.success == true) {
      Get.snackbar(
        'Pedido actualizado',
        'El pedido ahora está "$status".',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _loadOrders(silent: true);
    } else {
      Get.snackbar(
        'No se pudo actualizar',
        response.message ?? 'Intenta nuevamente.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = orders.isNotEmpty
        ? '${orders.first['restaurantName']}'
        : (currentUser.name ?? 'Mi comercio');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
            tooltip: 'Cerrar sesión',
            onPressed: con.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _body(restaurantName),
    );
  }

  Widget _body(String restaurantName) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null) {
      return _ErrorState(message: errorMessage!, onRetry: _loadOrders);
    }
    final visible = _ordersIn(tab);
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _StoreHeader(
            name: restaurantName,
            incoming: _count('Nuevo pedido'),
            cooking: _count('Preparando'),
            ready: _count('Listo para retiro'),
          ),
          const SizedBox(height: 18),
          _TabSwitcher(
            selected: tab,
            counts: {
              for (final t in RestaurantTab.values) t: _ordersIn(t).length,
            },
            onChanged: (t) => setState(() => tab = t),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            _EmptyOrders(tab: tab)
          else
            for (final order in visible)
              _OrderCard(
                order: order,
                busy: _updating.contains(order['id']),
                onTap: () => _openOrderDetail(order),
                onAction: (status) =>
                    _changeStatus(order['id'] as Object, status),
              ),
        ],
      ),
    );
  }

  Future<void> _openOrderDetail(Map<String, dynamic> summary) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
                  Navigator.pop(sheetContext);
                  await _changeStatus(summary['id'] as Object, status);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Cabecera ────────────────────────────────────────────────────────────────

class _StoreHeader extends StatelessWidget {
  final String name;
  final int incoming;
  final int cooking;
  final int ready;

  const _StoreHeader({
    required this.name,
    required this.incoming,
    required this.cooking,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.storefront,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'Local abierto · recibiendo pedidos',
                      style: TextStyle(color: Color(0xFFB8BEC6), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'Nuevos', value: incoming, highlight: incoming > 0),
              const SizedBox(width: 10),
              _Stat(label: 'En cocina', value: cooking),
              const SizedBox(width: 10),
              _Stat(label: 'Listos', value: ready),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final bool highlight;
  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: highlight ? AppColors.ink : Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: highlight ? AppColors.ink : const Color(0xFFB8BEC6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  final RestaurantTab selected;
  final Map<RestaurantTab, int> counts;
  final ValueChanged<RestaurantTab> onChanged;

  const _TabSwitcher({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Seis filtros no caben a lo ancho de un teléfono: se desplazan.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in RestaurantTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: t == selected
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${t.label} (${counts[t] ?? 0})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: t == selected ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Tarjeta de pedido ───────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  const _OrderCard({
    required this.order,
    required this.busy,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final status = '${order['status']}';
    final meta = RestaurantOrderStatus.of(status);
    final ago = timeAgo(order['createdAt']);
    final itemsCount = order['itemsCount'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pedido ${order['code']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(text: status, color: meta.color),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Cliente',
                value: '${order['clientName'] ?? '-'}',
              ),
              _InfoRow(label: 'Monto', value: clp(order['total'])),
              if (order['paymentMethod'] != null)
                _InfoRow(label: 'Pago', value: '${order['paymentMethod']}'),
              if (itemsCount != null)
                _InfoRow(label: 'Productos', value: '$itemsCount'),
              const Divider(height: 22, color: AppColors.line),
              Row(
                children: [
                  if (ago != null) ...[
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: meta.tab == RestaurantTab.incoming
                          ? const Color(0xFFC62828)
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        ago,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: meta.tab == RestaurantTab.incoming
                              ? const Color(0xFFC62828)
                              : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (meta.nextStatus != null)
                    FilledButton.icon(
                      onPressed: busy ? null : () => onAction(meta.nextStatus!),
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(meta.actionIcon, size: 18),
                      label: Text(meta.actionLabel!),
                      style: FilledButton.styleFrom(
                        backgroundColor: meta.tab == RestaurantTab.incoming
                            ? AppColors.ink
                            : AppColors.primary,
                        foregroundColor: meta.tab == RestaurantTab.incoming
                            ? Colors.white
                            : AppColors.ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    )
                  else
                    const Text(
                      'Ver detalle',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

// ─── Detalle ─────────────────────────────────────────────────────────────────

class _OrderDetail extends StatelessWidget {
  final Map<String, dynamic> order;
  final Future<void> Function(String status) onStatusChanged;

  const _OrderDetail({required this.order, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final client = Map<String, dynamic>.from(order['client'] ?? {});
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final status = '${order['status']}';
    final meta = RestaurantOrderStatus.of(status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido ${order['code']}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusPill(text: status, color: meta.color),
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
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                _Section(
                  icon: Icons.person_outline,
                  title: 'Cliente',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${client['name'] ?? order['clientName'] ?? 'Cliente'}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ('${client['phone'] ?? ''}'.isNotEmpty)
                        Text('${client['phone']}'),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text('${order['address']}')),
                        ],
                      ),
                    ],
                  ),
                ),
                _Section(
                  icon: Icons.receipt_long_outlined,
                  title: 'Detalle del pedido',
                  child: Column(
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${item['quantity']}x',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
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
                                    if ('${item['description'] ?? ''}'
                                            .isNotEmpty &&
                                        '${item['description']}' != 'null')
                                      Text(
                                        '${item['description']}',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(clp(item['total'])),
                            ],
                          ),
                        ),
                      const Divider(height: 22),
                      _TotalRow(label: 'Subtotal', value: order['subtotal']),
                      _TotalRow(label: 'Envío', value: order['deliveryFee']),
                      _TotalRow(
                        label: 'Total',
                        value: order['total'],
                        strong: true,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Text('Pago: ${order['paymentMethod'] ?? '-'}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (meta.nextStatus != null)
            SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () => onStatusChanged(meta.nextStatus!),
                  icon: Icon(meta.actionIcon),
                  label: Text(
                    meta.nextStatus == 'Preparando'
                        ? 'Aceptar y preparar'
                        : 'Marcar listo para retiro',
                  ),
                ),
              ),
            ),
          if ('${order['status']}'.toLowerCase() == 'nuevo pedido')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Rechazar pedido'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Rechazar pedido'),
                      content: const Text('¿Quieres rechazar este pedido?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Volver'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Rechazar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) await onStatusChanged('Rechazado');
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(clp(value), style: style),
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final RestaurantTab tab;
  const _EmptyOrders({required this.tab});

  @override
  Widget build(BuildContext context) {
    final text = switch (tab) {
      RestaurantTab.all => 'Este comercio aún no tiene pedidos',
      RestaurantTab.incoming => 'No hay pedidos nuevos',
      RestaurantTab.preparing => 'No hay pedidos en preparación',
      RestaurantTab.ready => 'No hay pedidos listos para retiro',
      RestaurantTab.inTransit => 'No hay pedidos en ruta',
      RestaurantTab.delivered => 'Aún no hay pedidos entregados',
      RestaurantTab.closed => 'No hay pedidos cancelados o rechazados',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: IllustratedMessage(
        illustration: AppIllustration.emptyOrders,
        title: text,
        message: 'Los pedidos nuevos aparecen aquí automáticamente.',
        size: 150,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

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
