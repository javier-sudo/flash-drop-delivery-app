import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/app_image.dart';

/// Título de sección con botón "Ver todo" opcional.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.primaryDark, size: 26),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
        if (onSeeAll != null)
          Material(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'Ver todo',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cabecera con la dirección de entrega y el acceso al carrito.
class LocationHeader extends StatelessWidget {
  final String address;
  final VoidCallback onAddressTap;
  final VoidCallback onCartTap;

  const LocationHeader({
    super.key,
    required this.address,
    required this.onAddressTap,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onAddressTap,
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Entregar en',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      Text(
                        address.isEmpty ? 'Elige tu dirección' : address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Obx(
          () => IconButton(
            tooltip: 'Ver carrito',
            onPressed: onCartTap,
            icon: Badge(
              isLabelVisible: cart.count > 0,
              backgroundColor: AppColors.primary,
              textColor: AppColors.ink,
              label: Text('${cart.count}'),
              child: const Icon(Icons.shopping_cart_outlined, size: 28),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila de producto del menú: foto, nombre, descripción, precio y botón +.
class ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final String? subtitle;

  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    final description = '${product['description'] ?? ''}'.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: 92,
                height: 92,
                child: AppImage('${product['image'] ?? ''}'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${product['name']}'.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 13,
                      ),
                    ),
                  if (description.isNotEmpty && description != 'null') ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    clp(product['price']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Obx(() {
              final qty = cart.quantityOf(product);
              return Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: qty > 0 ? AppColors.primary : AppColors.ink,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: qty > 0
                    ? Text(
                        '$qty',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      )
                    : const Icon(Icons.add, color: Colors.white, size: 24),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Barra inferior "Ver pedido" visible cuando hay productos en el carrito.
class CartBar extends StatelessWidget {
  final VoidCallback onTap;
  const CartBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Obx(() {
      if (cart.count == 0) return const SizedBox.shrink();
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: onTap,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${cart.count}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Ver pedido')),
                  Text(clp(cart.subtotal)),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Tarjeta de categoría: foto redondeada con nombre debajo.
class CategoryTile extends StatelessWidget {
  final String name;
  final String? image;
  final VoidCallback onTap;

  const CategoryTile({
    super.key,
    required this.name,
    required this.onTap,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 118,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 82,
                width: double.infinity,
                child: AppImage(image),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
