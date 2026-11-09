import 'package:flutter/material.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/client_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/app_image.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/common.dart';

/// Datos de entrega que muestran las tarjetas de comercio.
String storeEta(RestaurantView r) =>
    r.deliveryTime != null ? '${r.deliveryTime} min' : '30 min';

String get storeFee => clp(CartController.deliveryFee);

/// Tarjeta grande del carrusel "Comercios cerca de ti".
class StoreCard extends StatelessWidget {
  final RestaurantView restaurant;
  final VoidCallback onTap;
  final double width;

  const StoreCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.width = 270,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 124,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(r.image, fallbackIcon: Icons.storefront),
                    const Positioned(
                      top: 10,
                      left: 10,
                      child: TagPill('Restaurante'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FD.text(17, weight: FontWeight.w700),
                          ),
                        ),
                        if (r.rating != null) _Rating(r.rating!),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FD.text(13, color: FD.muted),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: FD.line),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 15,
                          color: FD.navy,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${storeEta(r)}   ·   Envío $storeFee',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FD.text(12.5, weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila compacta de comercio (lista filtrada y resultados de búsqueda).
class StoreRow extends StatelessWidget {
  final RestaurantView restaurant;
  final VoidCallback onTap;
  final double imageSize;

  const StoreRow({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.imageSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.square(
              dimension: imageSize,
              child: AppImage(r.image, fallbackIcon: Icons.storefront),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: FD.text(15, weight: FontWeight.w700)),
                Text(
                  [
                    'Restaurante',
                    if (r.rating != null) '★ ${r.rating!.toStringAsFixed(1)}',
                  ].join(' · '),
                  style: FD.text(12, color: FD.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${storeEta(r)} · Envío $storeFee',
                  style: FD.text(12, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: FD.navy),
        ],
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  final double value;
  const _Rating(this.value);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB800)),
      const SizedBox(width: 2),
      Text(
        value.toStringAsFixed(1),
        style: FD.text(13, weight: FontWeight.w700),
      ),
    ],
  );
}
