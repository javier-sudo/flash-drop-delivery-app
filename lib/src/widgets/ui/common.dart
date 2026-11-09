import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/client_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/app_image.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/product_sheet.dart';

/// Título grande de pantalla ("Buscar", "Tu carrito", "Pedidos").
class PageTitle extends StatelessWidget {
  final String text;
  const PageTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
    child: Text(text, style: FD.display(28)),
  );
}

/// Título de sección con acción opcional a la derecha.
class SectionTitle extends StatelessWidget {
  final String title;
  final bool bolt;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionTitle(
    this.title, {
    super.key,
    this.bolt = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
      child: Row(
        children: [
          if (bolt) ...[const BoltIcon(size: 20), const SizedBox(width: 8)],
          Expanded(child: Text(title, style: FD.section(21))),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: FD.text(13, weight: FontWeight.w700, color: FD.blue),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rayo de la marca (amarillo con borde marino).
class BoltIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool outlined;

  const BoltIcon({
    super.key,
    this.size = 20,
    this.color = FD.yellow,
    this.outlined = true,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _BoltPainter(color: color, outlined: outlined),
  );
}

class _BoltPainter extends CustomPainter {
  final Color color;
  final bool outlined;
  _BoltPainter({required this.color, required this.outlined});

  @override
  void paint(Canvas canvas, Size size) {
    // Mismo trazado del prototipo (viewBox 24x24): M14 2 L5 13 h6 l-2 9 9-12 h-6 z
    final s = size.width / 24;
    final path = Path()
      ..moveTo(14 * s, 2 * s)
      ..lineTo(5 * s, 13 * s)
      ..lineTo(11 * s, 13 * s)
      ..lineTo(9 * s, 22 * s)
      ..lineTo(18 * s, 10 * s)
      ..lineTo(12 * s, 10 * s)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    if (outlined) {
      canvas.drawPath(
        path,
        Paint()
          ..color = FD.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoltPainter old) =>
      old.color != color || old.outlined != outlined;
}

/// Tarjeta blanca redondeada del rediseño.
class WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final VoidCallback? onTap;

  const WhiteCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.margin = EdgeInsets.zero,
    this.radius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Píldora de texto (tipo de comercio, etiquetas).
class TagPill extends StatelessWidget {
  final String text;
  final Color background;
  const TagPill(this.text, {super.key, this.background = Colors.white});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: FD.text(11, weight: FontWeight.w700)),
  );
}

/// Botón cuadrado marino con "+" amarillo.
class AddButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const AddButton({super.key, required this.onTap, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Agregar al carrito',
      child: Material(
        color: FD.navy,
        borderRadius: BorderRadius.circular(size * 0.32),
        child: InkWell(
          borderRadius: BorderRadius.circular(size * 0.32),
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Icon(Icons.add_rounded, color: FD.yellow, size: size * 0.6),
          ),
        ),
      ),
    );
  }
}

/// Selector de cantidad amarillo: vertical en listas, horizontal en grillas.
class QtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool vertical;
  final Color background;

  const QtyStepper({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.vertical = false,
    this.background = FD.yellow,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, VoidCallback onTap) => Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: vertical ? 36 : 30,
          height: vertical ? 30 : 34,
          child: Icon(icon, size: 18, color: FD.navy),
        ),
      ),
    );
    final children = [
      button(Icons.remove_rounded, 'Restar uno', onRemove),
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 14),
        child: Text(
          '$quantity',
          textAlign: TextAlign.center,
          style: FD.text(13, weight: FontWeight.w800),
        ),
      ),
      button(Icons.add_rounded, 'Sumar uno', onAdd),
    ];
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: children.reversed.toList(),
            )
          : Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// "+" o selector de cantidad según si el producto ya está en el carrito.
class CartControl extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool vertical;
  final double size;

  const CartControl({
    super.key,
    required this.product,
    this.vertical = true,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Obx(() {
      final qty = cart.quantityOf(product);
      if (qty == 0) {
        return AddButton(
          size: size,
          onTap: () => addToCartWithConfirm(context, product),
        );
      }
      return QtyStepper(
        quantity: qty,
        vertical: vertical,
        onAdd: () => addToCartWithConfirm(context, product),
        onRemove: () => cart.decrement(product),
      );
    });
  }
}

/// Fila de producto: foto, nombre, comercio, descripción, precio y carrito.
class ProductRow extends StatelessWidget {
  final Map<String, dynamic> product;
  final String? storeName;
  final double imageSize;
  final bool showDescription;

  const ProductRow({
    super.key,
    required this.product,
    this.storeName,
    this.imageSize = 78,
    this.showDescription = true,
  });

  @override
  Widget build(BuildContext context) {
    final description = '${product['description'] ?? ''}'.trim();
    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => showProductSheet(context, product),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.square(
              dimension: imageSize,
              child: AppImage('${product['image'] ?? ''}'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${product['name']}',
                  style: FD.text(15, weight: FontWeight.w700),
                ),
                if (storeName != null)
                  Text(
                    storeName!,
                    style: FD.text(
                      11.5,
                      weight: FontWeight.w600,
                      color: FD.blue,
                    ),
                  ),
                if (showDescription &&
                    description.isNotEmpty &&
                    description != 'null')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FD.text(12.5, color: FD.muted, height: 1.3),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  clp(product['price']),
                  style: FD.text(15, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: CartControl(product: product),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de producto en grilla de dos columnas (menú del comercio).
class ProductGridCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const ProductGridCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final description = '${product['description'] ?? ''}'.trim();
    return WhiteCard(
      padding: const EdgeInsets.all(8),
      onTap: () => showProductSheet(context, product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AppImage('${product['image'] ?? ''}'),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '${product['name']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FD.text(14, weight: FontWeight.w700, height: 1.2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
              child: description.isEmpty || description == 'null'
                  ? const SizedBox.shrink()
                  : Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FD.text(12, color: FD.muted, height: 1.3),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    clp(product['price']),
                    style: FD.text(14, weight: FontWeight.w800),
                  ),
                ),
                CartControl(product: product, vertical: false, size: 34),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra flotante "Ver carrito" visible cuando hay productos.
class CartBar extends StatelessWidget {
  final VoidCallback onTap;
  const CartBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Obx(() {
      if (cart.count == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Material(
          color: FD.navy,
          elevation: 8,
          shadowColor: const Color(0x4D0E1A35),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 26),
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: FD.yellow,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${cart.count}',
                        style: FD.text(13, weight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ver carrito',
                        style: FD.text(
                          15,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      clp(cart.subtotal),
                      style: FD.text(
                        15,
                        weight: FontWeight.w800,
                        color: FD.yellow,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Ítem de la navegación inferior del cliente.
class NavItem {
  final IconData icon;
  final String label;
  final int badge;
  const NavItem(this.icon, this.label, {this.badge = 0});
}

/// Navegación inferior: píldora amarilla en la pestaña activa y contador azul.
class ClientNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int current;
  final ValueChanged<int> onTap;

  const ClientNavBar({
    super.key,
    required this.items,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECE8DE))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _navButton(items[i], i == current, i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton(NavItem item, bool active, int index) {
    final color = active ? FD.navy : FD.subtle;
    return InkResponse(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 30,
                decoration: BoxDecoration(
                  color: active ? FD.yellow : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: color, size: 23),
              ),
              if (item.badge > 0)
                Positioned(
                  top: -6,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: FD.blue,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.badge}',
                      style: FD.text(
                        10,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: FD.text(11, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Icono para una categoría del catálogo (los nombres vienen del backend).
IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  const rules = <(List<String>, IconData)>[
    (
      ['hamburg', 'burger', 'sándwich', 'sandwich'],
      Icons.lunch_dining_outlined,
    ),
    (['pizza'], Icons.local_pizza_outlined),
    (['papa', 'acompa', 'snack', 'frit'], Icons.fastfood_outlined),
    (['bebida', 'jugo', 'drink'], Icons.local_drink_outlined),
    (['postre', 'helado', 'dulce'], Icons.icecream_outlined),
    (['café', 'cafe', 'cafeter'], Icons.coffee_outlined),
    (['sushi', 'roll', 'pescado', 'mar'], Icons.set_meal_outlined),
    (['pasta', 'fideo', 'ramen'], Icons.ramen_dining_outlined),
    (['entrada', 'tapa', 'picoteo'], Icons.tapas_outlined),
    (['ensalada', 'vegan', 'veget', 'salud'], Icons.eco_outlined),
    (['pollo', 'carne', 'parrill', 'asado'], Icons.kebab_dining_outlined),
    (['pan', 'panader'], Icons.bakery_dining_outlined),
    (['farmac'], Icons.medication_outlined),
    (['súper', 'super', 'almac', 'despens'], Icons.shopping_basket_outlined),
  ];
  for (final (keys, icon) in rules) {
    if (keys.any(n.contains)) return icon;
  }
  return Icons.restaurant_outlined;
}
