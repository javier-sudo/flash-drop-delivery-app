import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';

/// Vista de un restaurante para la interfaz, armada con /catalog/restaurants
/// y /catalog/products. Los campos opcionales (foto, rating, tiempo) quedan
/// en null si el backend no los entrega.
class RestaurantView {
  final int id;
  final String name;
  final String address;
  final String? image;
  final String? description;
  final double? rating;
  final int? deliveryTime;
  final List<Map<String, dynamic>> products;

  RestaurantView({
    required this.id,
    required this.name,
    required this.address,
    required this.products,
    this.image,
    this.description,
    this.rating,
    this.deliveryTime,
  });

  /// Categorías en el orden en que aparecen sus productos.
  List<String> get categories =>
      products.map((p) => '${p['categoryName']}').toSet().toList();

  List<Map<String, dynamic>> productsIn(String category) =>
      products.where((p) => '${p['categoryName']}' == category).toList();

  /// Línea de subtítulo tipo "Hamburguesas • Acompañamientos".
  String get tagline => description?.isNotEmpty == true
      ? description!
      : categories.take(3).join(' • ');
}

class CategoryView {
  final String name;
  final String? image;
  final int count;
  CategoryView({required this.name, required this.count, this.image});
}

class CatalogController extends GetxController {
  CatalogController({AppProvider? provider})
    : _provider = provider ?? AppProvider();

  final AppProvider _provider;

  final restaurants = <RestaurantView>[].obs;
  final products = <Map<String, dynamic>>[].obs;
  final loading = true.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final results = await Future.wait([
        _provider.getProducts(),
        _provider.getRestaurants(),
      ]);
      products.assignAll(results[0]);
      restaurants.assignAll(buildRestaurants(results[1], results[0]));
    } catch (_) {
      error.value = 'No se pudo conectar con el backend';
    } finally {
      loading.value = false;
    }
  }

  /// Une restaurantes y productos. Público para poder probarlo sin red.
  static List<RestaurantView> buildRestaurants(
    List<Map<String, dynamic>> rawRestaurants,
    List<Map<String, dynamic>> rawProducts,
  ) {
    final byRestaurant = <int, List<Map<String, dynamic>>>{};
    for (final p in rawProducts) {
      final id = toInt(p['restaurantId']);
      if (id != null) byRestaurant.putIfAbsent(id, () => []).add(p);
    }
    return rawRestaurants
        .map((r) {
          final id = toInt(r['id']);
          if (id == null) return null;
          final items = byRestaurant[id] ?? [];
          final firstImage = items
              .map((p) => '${p['image'] ?? ''}')
              .where((img) => img.isNotEmpty)
              .firstOrNull;
          return RestaurantView(
            id: id,
            name: '${r['name'] ?? 'Restaurante'}',
            address: '${r['address'] ?? ''}',
            image: _nonEmpty(r['image']) ?? _nonEmpty(r['logo']) ?? firstImage,
            description: _nonEmpty(r['description']),
            rating: r['rating'] == null ? null : toDouble(r['rating']),
            deliveryTime: toInt(r['deliveryTime']),
            products: items,
          );
        })
        .whereType<RestaurantView>()
        .where((r) => r.products.isNotEmpty)
        .toList();
  }

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  List<CategoryView> get categories {
    final map = <String, CategoryView>{};
    for (final p in products) {
      final name = '${p['categoryName'] ?? 'Otros'}';
      final current = map[name];
      map[name] = CategoryView(
        name: name,
        count: (current?.count ?? 0) + 1,
        image: current?.image ?? _nonEmpty(p['image']),
      );
    }
    return map.values.toList();
  }

  RestaurantView? restaurantById(int id) =>
      restaurants.where((r) => r.id == id).firstOrNull;

  RestaurantView? restaurantOf(Map<String, dynamic> product) =>
      restaurantById(toInt(product['restaurantId']) ?? -1);

  List<RestaurantView> restaurantsWithCategory(String category) =>
      restaurants.where((r) => r.categories.contains(category)).toList();

  /// Comercios cuyo nombre, descripción o categorías coinciden.
  List<RestaurantView> searchRestaurants(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return restaurants.where((r) {
      final text = [r.name, r.description ?? '', ...r.categories].join(' ');
      return text.toLowerCase().contains(q);
    }).toList();
  }

  /// Busca por nombre de producto, restaurante o categoría.
  List<Map<String, dynamic>> searchProducts(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return products.where((p) {
      final restaurant = restaurantOf(p)?.name ?? '';
      return '${p['name']}'.toLowerCase().contains(q) ||
          '${p['categoryName']}'.toLowerCase().contains(q) ||
          restaurant.toLowerCase().contains(q);
    }).toList();
  }
}
