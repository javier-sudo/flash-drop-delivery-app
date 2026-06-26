import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

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
  }

  Future<void> _loadOrders() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final data = await appProvider.getOrders(userId: currentUser.id);
      if (!mounted) return;
      setState(() {
        orders = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'No se pudieron cargar los pedidos';
      });
    }
  }

  int get activeCount => orders
      .where((order) => '${order['status']}'.toLowerCase() != 'entregado')
      .length;

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
        : (currentUser.name ?? 'Mi restaurante');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
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
                'Pedidos recientes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text('${orders.length} pedidos'),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Toca un pedido para revisar cliente, productos y pago.'),
        const SizedBox(height: 14),
        if (orders.isEmpty)
          const _EmptyOrders()
        else
          ...orders.map(
            (order) =>
                _OrderCard(order: order, onTap: () => _openOrderDetail(order)),
          ),
      ],
    );
  }

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
              const SizedBox(height: 12),
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
    final status = '${order['status']}';
    final nextStatus = status == 'Nuevo pedido'
        ? 'Preparando'
        : status == 'Preparando'
        ? 'Listo para retiro'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
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
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 52, color: Color(0xFF7B8189)),
          SizedBox(height: 12),
          Text(
            'Este local aun no tiene pedidos',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 5),
          Text('Los nuevos pedidos apareceran aqui automaticamente.'),
        ],
      ),
    );
  }
}

String _clp(dynamic value) {
  final number = double.tryParse('$value') ?? 0;
  return '\$${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')}';
}
