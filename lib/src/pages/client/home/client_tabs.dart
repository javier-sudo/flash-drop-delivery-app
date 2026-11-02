import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/address/address_selector_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/cart/cart_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_shell_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/restaurant/restaurant_detail_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/common.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/product_sheet.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/restaurant_card.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/illustration.dart';

void openRestaurant(RestaurantView r) =>
    Get.to(() => RestaurantDetailPage(restaurant: r));

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
        return _ErrorState(
          message: catalog.error.value!,
          onRetry: catalog.load,
        );
      }
      return RefreshIndicator(onRefresh: catalog.load, child: builder(catalog));
    });
  }
}

class _Header extends StatefulWidget {
  const _Header();

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  String get _address {
    final raw = GetStorage().read('delivery_address');
    return raw is Map ? '${raw['address'] ?? ''}' : '';
  }

  @override
  Widget build(BuildContext context) {
    return LocationHeader(
      address: _address,
      onAddressTap: () async {
        await Get.to(() => const AddressSelectorPage());
        if (mounted) setState(() {});
      },
      onCartTap: () => Get.to(() => const CartPage()),
    );
  }
}

// ─── Inicio ───────────────────────────────────────────────────────────────────

class DiscoveryTab extends StatelessWidget {
  const DiscoveryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = Get.find<ClientShellController>();
    return _CatalogScaffold(
      builder: (catalog) {
        final restaurants = catalog.restaurants;
        final topRated = [...restaurants]
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        final popular = catalog.products.take(8).toList();
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _Header(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 300,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: restaurants.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => SizedBox(
                  width: 300,
                  child: RestaurantCard(
                    restaurant: restaurants[i],
                    imageHeight: 150,
                    onTap: () => openRestaurant(restaurants[i]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeader(
                title: '¿Qué se te antoja?',
                onSeeAll: () => shell.goTo(ClientTab.restaurants),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 136,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: catalog.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final c = catalog.categories[i];
                  return CategoryTile(
                    name: c.name,
                    image: c.image,
                    onTap: () =>
                        Get.to(() => CategoryRestaurantsPage(category: c.name)),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeader(
                title: 'Lo más pedido',
                icon: Icons.local_fire_department_outlined,
                onSeeAll: () => shell.goTo(ClientTab.search),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final p in popular)
                    ProductTile(
                      product: p,
                      subtitle: catalog.restaurantOf(p)?.name,
                      onTap: () => showProductSheet(context, p),
                    ),
                ],
              ),
            ),
            if (topRated.isNotEmpty) ...[
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(
                  title: 'Mejor evaluados',
                  icon: Icons.star_outline_rounded,
                ),
              ),
              const SizedBox(height: 12),
              for (final r in topRated.take(3))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: RestaurantCard(
                    restaurant: r,
                    onTap: () => openRestaurant(r),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

// ─── Restaurantes ─────────────────────────────────────────────────────────────

class RestaurantsTab extends StatelessWidget {
  const RestaurantsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _CatalogScaffold(
      builder: (catalog) => ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _Header(),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Explora por categoría',
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 136,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: catalog.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final c = catalog.categories[i];
                return CategoryTile(
                  name: c.name,
                  image: c.image,
                  onTap: () =>
                      Get.to(() => CategoryRestaurantsPage(category: c.name)),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(title: 'Todos los restaurantes'),
          ),
          const SizedBox(height: 12),
          for (final r in catalog.restaurants)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: RestaurantCard(
                restaurant: r,
                imageHeight: 190,
                onTap: () => openRestaurant(r),
              ),
            ),
        ],
      ),
    );
  }
}

/// Restaurantes que venden productos de una categoría.
class CategoryRestaurantsPage extends StatelessWidget {
  final String category;
  const CategoryRestaurantsPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final list = Get.find<CatalogController>().restaurantsWithCategory(
      category,
    );
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (final r in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RestaurantCard(
                restaurant: r,
                onTap: () => openRestaurant(r),
              ),
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

  @override
  Widget build(BuildContext context) {
    return _CatalogScaffold(
      builder: (catalog) {
        final query = _controller.text;
        final results = catalog.searchProducts(query);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const Text(
              'Buscar',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Productos, restaurantes o categorías',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        onPressed: () => setState(_controller.clear),
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (query.trim().isEmpty) ...[
              const Text(
                'Categorías populares',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in catalog.categories)
                    ActionChip(
                      label: Text(c.name),
                      onPressed: () =>
                          setState(() => _controller.text = c.name),
                      backgroundColor: AppColors.primarySoft,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                    ),
                ],
              ),
            ] else if (results.isEmpty)
              const IllustratedMessage(
                illustration: AppIllustration.searchEmpty,
                title: 'Sin resultados para tu búsqueda',
                message: 'Prueba con otro plato, local o categoría.',
              )
            else
              for (final p in results)
                ProductTile(
                  product: p,
                  subtitle: catalog.restaurantOf(p)?.name,
                  onTap: () => showProductSheet(context, p),
                ),
          ],
        );
      },
    );
  }
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
    final name = [
      user.name,
      user.lastName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                (name.isEmpty ? 'U' : name[0]).toUpperCase(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Mi cuenta' : name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (user.email.isNotEmpty)
                    Text(
                      user.email,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  if (user.phone.isNotEmpty)
                    Text(
                      user.phone,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _ProfileOption(
          icon: Icons.location_on_outlined,
          label: 'Mis direcciones',
          onTap: () => Get.to(() => const AddressSelectorPage()),
        ),
        _ProfileOption(
          icon: Icons.receipt_long_outlined,
          label: 'Mis pedidos',
          onTap: () => Get.find<ClientShellController>().goTo(ClientTab.orders),
        ),
        if (user.roles.length > 1)
          _ProfileOption(
            icon: Icons.swap_horiz,
            label: 'Cambiar rol',
            onTap: home.changeRole,
          ),
        _ProfileOption(
          icon: Icons.logout,
          label: 'Cerrar sesión',
          onTap: home.signOut,
          danger: true,
        ),
      ],
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ProfileOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFC62828) : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(icon, color: color),
          title: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return IllustratedMessage(
      illustration: AppIllustration.noConnection,
      title: message,
      message: 'Revisa tu conexión e intenta de nuevo.',
      actionLabel: 'Reintentar',
      onAction: onRetry,
    );
  }
}
