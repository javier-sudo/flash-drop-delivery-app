import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/client_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/app_image.dart';

/// Abre el detalle del producto y lo agrega al carrito.
Future<void> showProductSheet(
  BuildContext context,
  Map<String, dynamic> product,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ClientTheme(child: _ProductSheet(product: product)),
  );
}

/// Agrega al carrito; si es de otro local pregunta antes de reemplazar.
Future<bool> addToCartWithConfirm(
  BuildContext context,
  Map<String, dynamic> product, {
  int quantity = 1,
}) async {
  final cart = Get.find<CartController>();
  if (cart.add(product, quantity: quantity) == AddResult.added) return true;
  final replace = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Empezar un pedido nuevo?'),
      content: const Text(
        'Tu carrito tiene productos de otro local. Solo puedes pedir a un local por pedido.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Vaciar y agregar'),
        ),
      ],
    ),
  );
  if (replace == true) {
    cart.replaceWith(product, quantity: quantity);
    return true;
  }
  return false;
}

class _ProductSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  const _ProductSheet({required this.product});

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final price = toDouble(product['price']);
    final description = '${product['description'] ?? ''}'.trim();

    return Container(
      decoration: const BoxDecoration(
        color: FD.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: AppImage('${product['image'] ?? ''}'),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filled(
                  tooltip: 'Cerrar',
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: FD.navy),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${product['name']}', style: FD.display(24)),
                const SizedBox(height: 4),
                Text(clp(price), style: FD.text(18, weight: FontWeight.w800)),
                if (description.isNotEmpty && description != 'null') ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: FD.text(15, color: FD.muted, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 24, indent: 20, endIndent: 20, color: FD.line),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  _Stepper(
                    value: _quantity,
                    onChanged: (v) => setState(() => _quantity = v),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          final added = await addToCartWithConfirm(
                            context,
                            product,
                            quantity: _quantity,
                          );
                          if (added && context.mounted) Navigator.pop(context);
                        },
                        child: Row(
                          children: [
                            const Expanded(child: Text('Agregar al pedido')),
                            Text(clp(price * _quantity)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _Stepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quitar uno',
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, color: FD.navy),
          ),
          Text('$value', style: FD.text(16, weight: FontWeight.w800)),
          IconButton(
            tooltip: 'Agregar uno',
            onPressed: value < 20 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, color: FD.navy),
          ),
        ],
      ),
    );
  }
}
