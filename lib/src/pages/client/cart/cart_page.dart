import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/address/address_selector_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_shell_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/order_delivery_code_store.dart';
import 'package:proyecto_app_delivery_gessof/src/services/registered_address_resolver.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/app_image.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/illustration.dart';

/// Checkout: productos, dirección, forma de pago y confirmación del pedido.
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  static const _payments = {
    'Efectivo': Icons.payments_outlined,
    'Tarjeta': Icons.credit_card,
    'Transferencia': Icons.account_balance_outlined,
  };

  final _cart = Get.find<CartController>();
  final _catalog = Get.find<CatalogController>();
  final _box = GetStorage();
  // Permite inyectar un provider (tests); por defecto usa el real.
  final _api = Get.isRegistered<AppProvider>()
      ? Get.find<AppProvider>()
      : AppProvider();
  late final _addressController = TextEditingController(text: _savedAddress());

  /// Todo pedido nuevo se entrega con PIN: el repartidor lo pide al cliente.
  static const _receptionMode = 'SEGURO';

  String _payment = 'Efectivo';
  bool _placing = false;

  String _savedAddress() {
    final raw = _box.read('delivery_address');
    if (raw is Map && '${raw['address'] ?? ''}'.isNotEmpty) {
      return '${raw['address']}';
    }
    return _box.read('deliveryAddress')?.toString() ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    await Get.to(() => const AddressSelectorPage());
    if (mounted) setState(() => _addressController.text = _savedAddress());
  }

  Future<void> _placeOrder() async {
    final address = _addressController.text.trim();
    if (address.length < 6) {
      Get.snackbar(
        'Dirección incompleta',
        'Indica calle, número y comuna.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    setState(() => _placing = true);
    final restaurant = _catalog.restaurantById(_cart.restaurantId ?? -1);
    final estimate = await _estimateRoute(
      restaurant?.address ?? restaurant?.name ?? '',
      address,
    );
    final ResponseApi response;
    try {
      response = await _api.createOrder(
        items: _cart.toOrderItems(),
        address: address,
        paymentMethod: _payment,
        receptionMode: _receptionMode,
        distanceKm: estimate.$1,
        estimatedMinutes: estimate.$2,
      );
    } catch (e) {
      // Timeout o sin red: el carrito se conserva para reintentar.
      debugPrint('createOrder falló: $e');
      if (!mounted) return;
      setState(() => _placing = false);
      Get.snackbar(
        'Sin conexión',
        'No pudimos enviar tu pedido. Revisa tu conexión e intenta nuevamente.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!mounted) return;
    if (response.success == true) {
      await _rememberAddress(address);
      await _rememberDeliveryCode(response.data);
      _cart.clear();
      // Vuelve a la pantalla principal del cliente (cierra checkout y menú)
      // y abre "Mis pedidos".
      Get.until(
        (route) =>
            route.settings.name == '/client/products/list' || route.isFirst,
      );
      Get.find<ClientShellController>().goTo(ClientTab.orders);
      Get.snackbar(
        '¡Pedido confirmado!',
        'Puedes seguirlo en Mis pedidos.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      setState(() => _placing = false);
      Get.snackbar(
        'No se pudo crear',
        response.message ?? 'Intenta nuevamente.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Guarda el PIN en almacenamiento seguro si Orders lo devolvió al crear.
  Future<void> _rememberDeliveryCode(dynamic data) async {
    if (data is! Map) return;
    final id = data['id'] ?? data['orderId'];
    final code = data['deliveryCode'] ?? data['delivery_code'];
    if (id == null || code is! String) return;
    try {
      await OrderDeliveryCodeStore.save(id, code);
    } catch (e) {
      debugPrint('No se pudo guardar el código de entrega: $e');
    }
  }

  Future<void> _rememberAddress(String address) async {
    await _box.write('deliveryAddress', address);
    final raw = _box.read('delivery_address');
    final updated = raw is Map
        ? (Map<String, dynamic>.from(raw)..['address'] = address)
        : {'address': address, 'label': null, 'lat': null, 'lng': null};
    await _box.write('delivery_address', updated);
  }

  /// Distancia y minutos estimados. Si el geocoder no responde, usa valores
  /// por defecto: nunca bloquea el checkout.
  Future<(double, int)> _estimateRoute(String pickup, String delivery) async {
    try {
      final from = await RegisteredAddressResolver.resolve(pickup);
      final to = await RegisteredAddressResolver.resolve(delivery);
      if (from != null && to != null) {
        const calculator = Distance();
        final directKm = calculator.as(LengthUnit.Kilometer, from, to);
        final roadKm = (directKm * 1.25).clamp(0.5, 80.0).toDouble();
        final minutes = ((roadKm / 22) * 60 + 8).round().clamp(10, 180);
        return (double.parse(roadKm.toStringAsFixed(2)), minutes);
      }
    } catch (_) {}
    return (3.2, 20);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu pedido')),
      body: Obx(() {
        if (_cart.lines.isEmpty) return const _EmptyCart();
        final restaurant = _catalog.restaurantById(_cart.restaurantId ?? -1);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (restaurant != null)
              Text(
                restaurant.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            const SizedBox(height: 8),
            for (final line in _cart.lines.values) _CartLineTile(line: line),
            const SizedBox(height: 18),
            const _Label('Entregar en'),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: 'Calle, número y comuna',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Elegir en el mapa',
                  onPressed: _pickAddress,
                  icon: const Icon(Icons.map_outlined),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _Label('Forma de pago'),
            for (final entry in _payments.entries)
              _PaymentOption(
                label: entry.key == 'Tarjeta'
                    ? 'Tarjeta al recibir'
                    : entry.key,
                icon: entry.value,
                selected: _payment == entry.key,
                onTap: () => setState(() => _payment = entry.key),
              ),
            const SizedBox(height: 14),
            const _PinNotice(),
            const SizedBox(height: 18),
            _Totals(subtotal: _cart.subtotal, total: _cart.total),
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        if (_cart.lines.isEmpty) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _placing ? null : _placeOrder,
                child: _placing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Confirmar pedido · ${clp(_cart.total)}'),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final CartLine line;
  const _CartLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 60,
              height: 60,
              child: AppImage('${line.product['image'] ?? ''}'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${line.product['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  clp(line.total),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Quitar uno',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => cart.decrement(line.product),
                  icon: const Icon(Icons.remove, size: 18),
                ),
                Text(
                  '${line.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                IconButton(
                  tooltip: 'Agregar uno',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => cart.add(line.product),
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinNotice extends StatelessWidget {
  const _PinNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Color(0xFF8A5700), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PIN obligatorio para la entrega',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6A4300),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Al recibir el pedido, comparte con el repartidor el código de 6 dígitos que aparecerá en su seguimiento.',
                  style: TextStyle(color: Color(0xFF6A4300), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
    ),
  );
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primaryDark : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primaryDark : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  final double subtotal;
  final double total;
  const _Totals({required this.subtotal, required this.total});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, double value, {bool strong = false}) {
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
            Text(clp(value), style: style),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          row('Subtotal', subtotal),
          row('Envío', CartController.deliveryFee.toDouble()),
          const Divider(height: 18),
          row('Total', total, strong: true),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const IllustratedMessage(
      illustration: AppIllustration.emptyCart,
      title: 'Tu carrito está vacío',
      message: 'Agrega productos desde un restaurante.',
    );
  }
}
