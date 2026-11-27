import 'package:flutter/material.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';

class SalesSummaryPage extends StatefulWidget {
  const SalesSummaryPage({super.key, required this.provider});
  final AppProvider provider;
  @override
  State<SalesSummaryPage> createState() => _SalesSummaryPageState();
}

class _SalesSummaryPageState extends State<SalesSummaryPage> {
  String range = 'week';
  Map<String, dynamic>? summary;
  bool loading = true;
  String? error;
  int requestId = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = ++requestId;
    final selectedRange = range;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final restaurant = await widget.provider.getMyRestaurant();
      final restaurantId = restaurant['id'];
      if (restaurantId == null) throw const FormatException();
      final result = await widget.provider.getSalesSummary(
        restaurantId,
        selectedRange,
      );
      if (mounted && id == requestId) setState(() => summary = result);
    } catch (_) {
      if (mounted && id == requestId) {
        setState(() => error = 'No se pudo cargar el resumen de ventas.');
      }
    } finally {
      if (mounted && id == requestId) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ventas')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'day', label: Text('24 h')),
            ButtonSegment(value: 'week', label: Text('7 días')),
            ButtonSegment(value: 'month', label: Text('30 días')),
          ],
          selected: {range},
          onSelectionChanged: (values) {
            setState(() => range = values.first);
            load();
          },
        ),
        const SizedBox(height: 20),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null) ...[
          Text(error!),
          TextButton(onPressed: load, child: const Text('Reintentar')),
        ] else if (summary != null) ...[
          ListTile(
            title: const Text('Pedidos entregados'),
            trailing: Text('${summary!['totalOrders'] ?? 0}'),
          ),
          ListTile(
            title: const Text('Ventas de productos'),
            trailing: Text(clp(toDouble(summary!['totalRevenue']))),
          ),
          ListTile(
            title: const Text('Ticket promedio'),
            trailing: Text(clp(toDouble(summary!['averageTicket']))),
          ),
          const Divider(),
          const ListTile(title: Text('Productos más vendidos')),
          for (final item in (summary!['topProducts'] as List? ?? []))
            if (item is Map)
              ListTile(
                title: Text('${item['productName'] ?? 'Producto'}'),
                subtitle: Text('${item['quantitySold'] ?? 0} vendidos'),
                trailing: Text(clp(toDouble(item['revenue']))),
              ),
        ],
      ],
    ),
  );
}
