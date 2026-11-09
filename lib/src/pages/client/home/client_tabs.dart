import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/address/address_selector_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_shell_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/restaurant/restaurant_detail_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/client_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/common.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/illustration.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/restaurant_card.dart';

void openRestaurant(RestaurantView r) =>
    Get.to(() => RestaurantDetailPage(restaurant: r));

/// Dirección de entrega guardada (o vacía si aún no elige una).
String savedDeliveryAddress() {
  final raw = GetStorage().read('delivery_address');
  return raw is Map ? '${raw['address'] ?? ''}' : '';
}

/// Contenedor común: estados de carga/error del catálogo y pull to refresh.
class _CatalogScaffold extends StatelessWidget {
  final Widget Function(CatalogController catalog) builder;
  const _CatalogScaffold({required this.builder});

  @override
  Widget build(BuildContext context) {
    final catalog = Get.find<CatalogController>();
    return Obx(() {
      if (catalog.loading.value && catalog.restaurants.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (catalog.error.value != null && catalog.restaurants.isEmpty) {
        return IllustratedMessage(
          illustration: AppIllustration.noConnection,
          title: catalog.error.value!,
          message: 'Revisa tu conexión e intenta de nuevo.',
          actionLabel: 'Reintentar',
          onAction: catalog.load,
        );
      }
      return RefreshIndicator(onRefresh: catalog.load, child: builder(catalog));
    });
  }
}

// ─── Inicio ───────────────────────────────────────────────────────────────────

class DiscoveryTab extends StatefulWidget {
  const DiscoveryTab({super.key});

  @override
  State<DiscoveryTab> createState() => _DiscoveryTabState();
}

class _DiscoveryTabState extends State<DiscoveryTab> {
  /// Categoría elegida en la grilla (null = todas).
  String? _filter;

  static const _maxCategories = 7;

  @override
  Widget build(BuildContext context) {
    final shell = Get.find<ClientShellController>();
    return _CatalogScaffold(
      builder: (catalog) {
        final categories = catalog.categories
            .take(_maxCategories)
            .map((c) => c.name)
            .toList();
        final stores = _filter == null
            ? catalog.restaurants.toList()
            : catalog.restaurantsWithCategory(_filter!);
        final popular = catalog.products.take(6).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _HomeHeader(
              onAddress: () async {
                await Get.to(() => const AddressSelectorPage());
                if (mounted) setState(() {});
              },
              onCart: () => shell.goTo(ClientTab.cart),
              onSearch: () => shell.goTo(ClientTab.search),
            ),
            _CategoryGrid(
              categories: categories,
              selected: _filter,
              onSelected: (c) => setState(
                () => _filter = c == null || c == _filter ? null : c,
              ),
            ),
            const _FlashClubBanner(),
            SectionTitle(
              _filter == null
                  ? 'Comercios cerca de ti'
                  : '$_filter cerca de ti',
              actionLabel: _filter == null ? null : 'Quitar filtro',
              onAction: () => setState(() => _filter = null),
            ),
            SizedBox(
              height: 238,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: stores.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => StoreCard(
                  restaurant: stores[i],
                  onTap: () => openRestaurant(stores[i]),
                ),
              ),
            ),
            const SectionTitle('Lo más pedido', bolt: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (final p in popular)
                    ProductRow(
                      product: p,
                      storeName: catalog.restaurantOf(p)?.name,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Cabecera amarilla: logo, dirección de entrega, carrito y buscador.
class _HomeHeader extends StatelessWidget {
  final VoidCallback onAddress;
  final VoidCallback onCart;
  final VoidCallback onSearch;

  const _HomeHeader({
    required this.onAddress,
    required this.onCart,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final address = savedDeliveryAddress();
    final cart = Get.find<CartController>();
    return Container(
      color: FD.yellow,
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 14,
        18,
        16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/img/logo_flashdrop_app.png',
                  width: 42,
                  height: 42,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onAddress,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Entregar en', style: FD.text(12, color: FD.brown)),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.isEmpty ? 'Elige tu dirección' : address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FD.text(15, weight: FontWeight.w700),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: FD.navy,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(() => _CartButton(count: cart.count, onTap: onCart)),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onSearch,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1F0E1A35), offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: FD.navy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Busca comercios o productos…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FD.text(15, color: FD.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _CartButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ver carrito',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: FD.navy,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: FD.yellow,
                  size: 22,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: FD.blue,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: FD.yellow, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
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
        ),
      ),
    );
  }
}

/// Grilla de categorías que se monta sobre el borde inferior de la cabecera.
class _CategoryGrid extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final c in categories)
        _CategoryTile(
          label: c,
          icon: categoryIcon(c),
          active: selected == c,
          onTap: () => onSelected(c),
        ),
      _CategoryTile(
        label: 'Todos',
        icon: Icons.grid_view_rounded,
        active: selected == null,
        onTap: () => onSelected(null),
      ),
    ];
    return Stack(
      children: [
        // Continúa el amarillo de la cabecera bajo la tarjeta.
        Container(
          height: 44,
          decoration: const BoxDecoration(
            color: FD.yellow,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
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
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            childAspectRatio: 0.92,
            children: tiles,
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: active ? FD.navy : FD.soft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 26, color: active ? FD.yellow : FD.navy),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FD.text(12, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Promoción de la suscripción. Aún no hay backend: el botón lo avisa.
class _FlashClubBanner extends StatelessWidget {
  const _FlashClubBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      padding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FD.navy,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: -36,
            top: -36,
            child: Opacity(
              opacity: 0.14,
              child: BoltIcon(size: 130, outlined: false),
            ),
          ),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: FD.yellow,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const BoltIcon(
                  size: 24,
                  color: FD.navy,
                  outlined: false,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FLASH CLUB', style: FD.display(17, color: FD.yellow)),
                    const SizedBox(height: 2),
                    Text(
                      'Envíos gratis sobre \$9.990 en cualquier comercio. Desde \$1.990/mes.',
                      style: FD.text(
                        13,
                        color: const Color(0xFFDFE3EC),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: FD.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: FD.text(13, weight: FontWeight.w700),
                ),
                onPressed: () => Get.snackbar(
                  'Flash Club',
                  'Muy pronto podrás suscribirte desde la app.',
                  snackPosition: SnackPosition.BOTTOM,
                ),
                child: const Text('Unirme'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Buscar ───────────────────────────────────────────────────────────────────

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(String value) => setState(() {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
  });

  @override
  Widget build(BuildContext context) {
    return _CatalogScaffold(
      builder: (catalog) {
        final query = _controller.text.trim();
        final stores = catalog.searchRestaurants(query);
        final products = catalog.searchProducts(query);
        // Sugerencias reales: categorías y los primeros productos del catálogo.
        final suggestions = {
          ...catalog.categories.map((c) => c.name),
          ...catalog.products.take(4).map((p) => '${p['name']}'),
        }.take(8);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const PageTitle('Buscar'),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FD.navy, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: FD.navy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        style: FD.text(15),
                        decoration: InputDecoration(
                          hintText: 'Productos o comercios',
                          hintStyle: FD.text(15, color: FD.muted),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (query.isNotEmpty)
                      IconButton(
                        tooltip: 'Limpiar',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(_controller.clear),
                        icon: const Icon(Icons.close_rounded, color: FD.navy),
                      ),
                  ],
                ),
              ),
            ),
            if (query.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                child: Text(
                  'Búsquedas populares',
                  style: FD.text(13, weight: FontWeight.w700, color: FD.muted),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in suggestions)
                      ActionChip(
                        label: Text(s),
                        onPressed: () => _pick(s),
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFFE3DFD4),
                          width: 1.5,
                        ),
                        shape: const StadiumBorder(),
                      ),
                  ],
                ),
              ),
            ] else ...[
              if (stores.isNotEmpty) ...[
                _ResultsLabel('Comercios'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      for (final r in stores)
                        StoreRow(
                          restaurant: r,
                          imageSize: 48,
                          onTap: () => openRestaurant(r),
                        ),
                    ],
                  ),
                ),
              ],
              _ResultsLabel(
                products.isEmpty
                    ? 'Sin productos para esta búsqueda'
                    : 'Productos (${products.length})',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (final p in products)
                      ProductRow(
                        product: p,
                        storeName: catalog.restaurantOf(p)?.name,
                        imageSize: 56,
                        showDescription: false,
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ResultsLabel extends StatelessWidget {
  final String text;
  const _ResultsLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
    child: Text(
      text,
      style: FD.text(13, weight: FontWeight.w700, color: FD.muted),
    ),
  );
}

// ─── Perfil ───────────────────────────────────────────────────────────────────

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final raw = GetStorage().read('user');
    final user = User.fromJson(
      raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw),
    );
    final firstName = (user.name ?? '').trim();
    final address = savedDeliveryAddress();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: FD.yellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  (firstName.isEmpty ? 'U' : firstName[0]).toUpperCase(),
                  style: FD.display(28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName.isEmpty ? 'Mi cuenta' : 'Hola, $firstName',
                      style: FD.display(24),
                    ),
                    if (user.email.isNotEmpty)
                      Text(user.email, style: FD.text(13, color: FD.muted)),
                    if (user.phone.isNotEmpty)
                      Text(user.phone, style: FD.text(13, color: FD.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(14, 18, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              _ProfileRow(
                label: 'Direcciones',
                meta: address.isEmpty ? 'Agregar' : address,
                onTap: () => Get.to(() => const AddressSelectorPage()),
              ),
              _ProfileRow(
                label: 'Mis pedidos',
                onTap: () =>
                    Get.find<ClientShellController>().goTo(ClientTab.orders),
              ),
              if (user.roles.length > 1)
                _ProfileRow(label: 'Cambiar rol', onTap: home.changeRole),
              _ProfileRow(
                label: 'Cerrar sesión',
                onTap: home.signOut,
                danger: true,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String meta;
  final VoidCallback onTap;
  final bool danger;
  final bool last;

  const _ProfileRow({
    required this.label,
    required this.onTap,
    this.meta = '',
    this.danger = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF1EEE6))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: FD.text(
                  15,
                  weight: FontWeight.w600,
                  color: danger ? FD.danger : FD.navy,
                ),
              ),
            ),
            Flexible(
              child: Text(
                '$meta ›'.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FD.text(13, color: FD.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
