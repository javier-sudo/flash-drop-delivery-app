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
import 'package:proyecto_app_delivery_gessof/src/theme/client_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/app_image.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/common.dart';

/// Checkout: productos, dirección, forma de pago y confirmación del pedido.
class CartPage extends StatefulWidget {
  /// true cuando vive como pestaña "Carrito" de la navegación inferior.
  final bool embedded;
  const CartPage({super.key, this.embedded = false});

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

  /// Si el cliente escribió la dirección a mano no la pisamos al volver.
  bool _addressEdited = false;
  Worker? _tabWorker;

  @override
  void initState() {
    super.initState();
    // Como pestaña, el estado sobrevive: refresca la dirección elegida en
    // Inicio o Perfil cada vez que se vuelve al carrito.
    if (widget.embedded && Get.isRegistered<ClientShellController>()) {
      _tabWorker = ever(Get.find<ClientShellController>().tab, (tab) {
        if (tab == ClientTab.cart && !_addressEdited && mounted) {
          _addressController.text = _savedAddress();
        }
      });
    }
  }

  String _savedAddress() {
    final raw = _box.read('delivery_address');
    if (raw is Map && '${raw['address'] ?? ''}'.isNotEmpty) {
      return '${raw['address']}';
    }
    return _box.read('deliveryAddress')?.toString() ?? '';
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    await Get.to(() => const AddressSelectorPage());
    if (!mounted) return;
    setState(() {
      _addressEdited = false;
      _addressController.text = _savedAddress();
    });
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
      // Como pestaña el estado sigue vivo: deja el botón listo otra vez.
      setState(() => _placing = false);
      ClientShellController.openTab(ClientTab.orders);
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
    final body = Obx(() {
      if (_cart.lines.isEmpty) {
        return ListView(
          children: [
            if (widget.embedded) const PageTitle('Tu carrito'),
            const _EmptyCart(),
          ],
        );
      }
      final restaurant = _catalog.restaurantById(_cart.restaurantId ?? -1);
      final subtotal = _cart.subtotal;
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (widget.embedded) const PageTitle('Tu carrito'),
          if (restaurant != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: Text(
                restaurant.name,
                style: FD.text(14, weight: FontWeight.w700, color: FD.blue),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              children: [
                for (final line in _cart.lines.values)
                  _CartLineTile(line: line),
              ],
            ),
          ),
          const _Label('Entregar en'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _addressController,
              onChanged: (_) => _addressEdited = true,
              style: FD.text(15),
              decoration: InputDecoration(
                hintText: 'Calle, número y comuna',
                hintStyle: FD.text(15, color: FD.muted),
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: FD.navy,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Elegir en el mapa',
                  onPressed: _pickAddress,
                  icon: const Icon(Icons.map_outlined, color: FD.blue),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: FD.navy, width: 2),
                ),
              ),
            ),
          ),
          const _Label('Forma de pago'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (final entry in _payments.entries)
                  _PaymentOption(
                    label: entry.key == 'Tarjeta'
                        ? 'Tarjeta al recibir'
                        : entry.key,
                    icon: entry.value,
                    selected: _payment == entry.key,
                    onTap: () => setState(() => _payment = entry.key),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: _PinNotice(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _Totals(subtotal: subtotal, total: _cart.total),
          ),
          if (subtotal >= _flashClubMinimum)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _FlashClubNote(),
            ),
        ],
      );
    });

    final orderButton = Obx(() {
      if (_cart.lines.isEmpty) return const SizedBox.shrink();
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: FD.navy, offset: Offset(0, 4)),
              ],
            ),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: FD.yellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: FD.display(17),
                ),
                onPressed: _placing ? null : _placeOrder,
                child: _placing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('PEDIR AHORA · ${clp(_cart.total)}'),
              ),
            ),
          ),
        ),
      );
    });

    return ClientTheme(
      child: Scaffold(
        backgroundColor: FD.cream,
        appBar: widget.embedded
            ? null
            : AppBar(title: const Text('Tu carrito')),
        body: body,
        bottomNavigationBar: orderButton,
      ),
    );
  }
}

/// Monto desde el que Flash Club da envío gratis (solo informativo).
const _flashClubMinimum = 9990;

class _CartLineTile extends StatelessWidget {
  final CartLine line;
  const _CartLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.square(
              dimension: 62,
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
                  style: FD.text(15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  clp(line.total),
                  style: FD.text(14, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
          QtyStepper(
            quantity: line.quantity,
            background: FD.cream,
            onAdd: () => cart.add(line.product),
            onRemove: () => cart.decrement(line.product),
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
        color: FD.navy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FD.yellow,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.lock_outline, color: FD.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PIN obligatorio para la entrega',
                  style: FD.text(14, weight: FontWeight.w800, color: FD.yellow),
                ),
                const SizedBox(height: 2),
                Text(
                  'Al recibir el pedido, comparte con el repartidor el código de 6 dígitos que aparecerá en su seguimiento.',
                  style: FD.text(
                    12.5,
                    color: const Color(0xFFDFE3EC),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashClubNote extends StatelessWidget {
  const _FlashClubNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FD.soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const BoltIcon(size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Con Flash Club este pedido tendría envío gratis.',
              style: FD.text(13, weight: FontWeight.w600, color: FD.brown),
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
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
    child: Text(text, style: FD.section(19)),
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
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? FD.navy : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? FD.yellow : FD.cream,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: FD.navy, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: FD.text(15, weight: FontWeight.w700),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? FD.navy : FD.subtle,
                ),
              ],
            ),
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
      final style = strong
          ? FD.display(19)
          : FD.text(14.5, color: FD.muted, weight: FontWeight.w600);
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

    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          row('Subtotal', subtotal),
          row('Envío', CartController.deliveryFee.toDouble()),
          const Divider(height: 18, color: FD.line),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 24),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: FD.yellow,
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: const BoltIcon(size: 42, color: FD.navy, outlined: false),
          ),
          const SizedBox(height: 18),
          Text(
            'Aún no agregas nada',
            textAlign: TextAlign.center,
            style: FD.display(22),
          ),
          const SizedBox(height: 6),
          Text(
            'Explora comercios y llena tu carrito.',
            textAlign: TextAlign.center,
            style: FD.text(14, color: FD.muted),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FD.navy,
              foregroundColor: FD.yellow,
              minimumSize: const Size(160, 48),
            ),
            onPressed: () => ClientShellController.openTab(ClientTab.discovery),
            child: const Text('Explorar'),
          ),
        ],
      ),
    );
  }
}
