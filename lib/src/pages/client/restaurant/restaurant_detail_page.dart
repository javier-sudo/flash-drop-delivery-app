import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_shell_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/client_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/app_image.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/common.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/restaurant_card.dart';

/// Menú de un comercio: portada, tarjeta de datos, categorías y productos
/// en grilla de dos columnas.
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
        alignment: 0.12,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final topPadding = MediaQuery.paddingOf(context).top;
    return ClientTheme(
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _StoreHeader(restaurant: r, topPadding: topPadding),
            ),
            if (_categories.length > 1)
              SliverPersistentHeader(
                pinned: true,
                delegate: _CategoryBarDelegate(
                  categories: _categories,
                  active: _activeCategory ?? _categories.first,
                  onSelected: _scrollTo,
                  topPadding: topPadding,
                ),
              ),
            for (final category in _categories) ...[
              SliverToBoxAdapter(
                key: _sectionKeys[category],
                child: SectionTitle(
                  _categories.length > 1 ? category : 'Productos',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.6,
                  ),
                  delegate: SliverChildListDelegate([
                    for (final product in r.productsIn(category))
                      ProductGridCard(product: product),
                  ]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: CartBar(
            onTap: () => ClientShellController.openTab(ClientTab.cart),
          ),
        ),
      ),
    );
  }
}

/// Portada con botón volver y tarjeta de datos montada sobre la foto.
class _StoreHeader extends StatelessWidget {
  final RestaurantView restaurant;
  final double topPadding;
  const _StoreHeader({required this.restaurant, required this.topPadding});

  static const _coverHeight = 240.0;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _coverHeight,
          child: AppImage(r.image, fallbackIcon: Icons.storefront),
        ),
        Positioned(top: topPadding + 12, left: 14, child: const _BackButton()),
        Container(
          margin: const EdgeInsets.fromLTRB(14, _coverHeight - 30, 14, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140E1A35),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TagPill('Restaurante', background: FD.yellow),
              const SizedBox(height: 10),
              Text(r.name, style: FD.display(26)),
              const SizedBox(height: 4),
              Text(
                r.tagline,
                style: FD.text(13.5, color: FD.muted, height: 1.35),
              ),
              if (r.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    r.address,
                    style: FD.text(12.5, color: FD.subtle),
                  ),
                ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: FD.line),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Stat(
                    value: r.rating == null
                        ? 'Nuevo'
                        : '★ ${r.rating!.toStringAsFixed(1)}',
                    label: 'Calificación',
                  ),
                  _Stat(value: storeEta(r), label: 'Entrega'),
                  _Stat(value: storeFee, label: 'Envío'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: FD.text(15, weight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: FD.text(11.5, color: FD.muted)),
      ],
    ),
  );
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Volver',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        shadowColor: const Color(0x330E1A35),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: Get.back,
          child: const SizedBox.square(
            dimension: 42,
            child: Icon(Icons.arrow_back_rounded, color: FD.navy),
          ),
        ),
      ),
    );
  }
}

/// Barra fija de categorías. Al quedar anclada arriba muestra "volver",
/// porque el botón de la portada ya salió de la pantalla.
class _CategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final String? active;
  final ValueChanged<String> onSelected;
  final double topPadding;

  _CategoryBarDelegate({
    required this.categories,
    required this.active,
    required this.onSelected,
    required this.topPadding,
  });

  static const _barHeight = 62.0;

  @override
  double get minExtent => _barHeight + topPadding;
  @override
  double get maxExtent => _barHeight + topPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final pinned = overlapsContent || shrinkOffset > 0;
    return Container(
      color: FD.cream,
      padding: EdgeInsets.only(top: topPadding),
      child: Row(
        children: [
          if (pinned)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: const _BackButton(),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  selectedColor: FD.navy,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected ? FD.navy : const Color(0xFFE3DFD4),
                    width: 1.5,
                  ),
                  shape: const StadiumBorder(),
                  labelStyle: FD.text(
                    13,
                    weight: FontWeight.w700,
                    color: selected ? FD.yellow : FD.navy,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryBarDelegate old) =>
      old.active != active ||
      old.categories != categories ||
      old.topPadding != topPadding;
}
