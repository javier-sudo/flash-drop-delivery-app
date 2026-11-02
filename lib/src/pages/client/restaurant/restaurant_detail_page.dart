import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/cart/cart_page.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/app_image.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/common.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/product_sheet.dart';

/// Menú de un restaurante: portada, pestañas de categoría y productos.
class RestaurantDetailPage extends StatefulWidget {
  final RestaurantView restaurant;
  const RestaurantDetailPage({super.key, required this.restaurant});

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  late final List<String> _categories = widget.restaurant.categories;
  late final Map<String, GlobalKey> _sectionKeys = {
    for (final c in _categories) c: GlobalKey(),
  };
  String? _activeCategory;

  void _scrollTo(String category) {
    setState(() => _activeCategory = category);
    final ctx = _sectionKeys[category]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        alignment: 0.05,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: _RoundButton(icon: Icons.arrow_back, onTap: Get.back),
            // El título solo aparece con la barra contraída (sobre la foto no se lee).
            title: Builder(
              builder: (context) {
                final settings = context
                    .dependOnInheritedWidgetOfExactType<
                      FlexibleSpaceBarSettings
                    >();
                final collapsed =
                    settings == null ||
                    settings.currentExtent <= settings.minExtent + 12;
                return AnimatedOpacity(
                  opacity: collapsed ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    r.deliveryTime != null
                        ? 'Entrega ${r.deliveryTime} min'
                        : r.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                );
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(r.image, fallbackIcon: Icons.storefront),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          r.address,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  if (r.deliveryTime != null)
                    _InfoChip(
                      icon: Icons.schedule,
                      text: '${r.deliveryTime} min',
                    ),
                  if (r.rating != null)
                    _InfoChip(
                      icon: Icons.star_rounded,
                      text: r.rating!.toStringAsFixed(1),
                      color: AppColors.star,
                    ),
                  _InfoChip(
                    icon: Icons.delivery_dining,
                    text: 'Envío ${clp(CartController.deliveryFee)}',
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _CategoryBarDelegate(
              categories: _categories,
              active:
                  _activeCategory ??
                  (_categories.isEmpty ? null : _categories.first),
              onSelected: _scrollTo,
            ),
          ),
          for (final category in _categories)
            SliverToBoxAdapter(
              child: Padding(
                key: _sectionKeys[category],
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    for (final product in r.productsIn(category))
                      ProductTile(
                        product: product,
                        onTap: () => showProductSheet(context, product),
                      ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: CartBar(onTap: () => Get.to(() => const CartPage())),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: IconButton.filled(
        tooltip: 'Volver',
        style: IconButton.styleFrom(backgroundColor: Colors.white),
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.ink),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.text,
    this.color = AppColors.primaryDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ],
    );
  }
}

class _CategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final String? active;
  final ValueChanged<String> onSelected;

  _CategoryBarDelegate({
    required this.categories,
    required this.active,
    required this.onSelected,
  });

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = categories[i];
          final selected = c == active;
          return ChoiceChip(
            label: Text(c),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(c),
            selectedColor: AppColors.primarySoft,
            backgroundColor: AppColors.background,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.line,
            ),
            shape: const StadiumBorder(),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primaryDark : AppColors.muted,
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryBarDelegate old) =>
      old.active != active || old.categories != categories;
}
