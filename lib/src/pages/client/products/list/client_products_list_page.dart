import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:proyecto_app_delivery_gessof/src/services/registered_address_resolver.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/address/address_selector_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/orders/list/client_orders_list_widget.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

class ClientProductsListPage extends StatefulWidget {
  const ClientProductsListPage({super.key});

  @override
  State<ClientProductsListPage> createState() => _ClientProductsListPageState();
}

class _ClientProductsListPageState extends State<ClientProductsListPage> {
  static const _allFilter = 'Todos';

  final HomeController con = Get.put(HomeController());
  final AppProvider appProvider = AppProvider();
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> products = [];
  final Map<int, int> cart = {};
  String selectedCategory = _allFilter;
  String selectedRestaurant = _allFilter;
  bool isLoading = true;
  String? errorMessage;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    searchController.addListener(() => setState(() {}));
    _loadProducts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool _hasMultipleRoles() {
    final raw = GetStorage().read('user');
    if (raw == null) return false;
    final user = User.fromJson(Map<String, dynamic>.from(raw));
    return user.roles.length > 1;
  }

  String get _selectedAddress {
    final raw = GetStorage().read('delivery_address');
    if (raw is Map) return raw['address']?.toString() ?? '';
    return '';
  }

  Future<void> _openAddressSelector() async {
    await Get.to(() => const AddressSelectorPage());
    if (mounted) setState(() {});
  }

  Future<void> _loadProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await appProvider.getProducts();
      setState(() {
        products = data;
        if (!categories.contains(selectedCategory)) {
          selectedCategory = _allFilter;
        }
        if (!restaurants.contains(selectedRestaurant)) {
          selectedRestaurant = _allFilter;
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'No se pudo conectar con el backend';
        isLoading = false;
      });
    }
  }

  List<String> get categories {
    final names =
        availableProducts
            .map((p) => '${p['categoryName'] ?? 'Sin categoría'}')
            .toSet()
            .toList()
          ..sort();
    return [_allFilter, ...names];
  }

  List<String> get restaurants {
    final names =
        availableProducts
            .map((p) => '${p['restaurantName'] ?? 'Sin local'}')
            .toSet()
            .toList()
          ..sort();
    return [_allFilter, ...names];
  }

  List<Map<String, dynamic>> get availableProducts =>
      products.where(_isAvailableForOrder).toList(growable: false);

  List<Map<String, dynamic>> get filteredProducts {
    final query = searchController.text.trim().toLowerCase();
    final filtered =
        availableProducts.where((product) {
          final name = '${product['name'] ?? ''}'.toLowerCase();
          final restaurant = '${product['restaurantName'] ?? ''}'.toLowerCase();
          final category = '${product['categoryName'] ?? 'Sin categoría'}';
          final matchesText =
              query.isEmpty ||
              name.contains(query) ||
              restaurant.contains(query) ||
              category.toLowerCase().contains(query);
          final matchesCategory =
              selectedCategory == _allFilter || category == selectedCategory;
          final matchesRestaurant =
              selectedRestaurant == _allFilter ||
              restaurant == selectedRestaurant.toLowerCase();
          return matchesText && matchesCategory && matchesRestaurant;
        }).toList()..sort((a, b) {
          final byRestaurant = '${a['restaurantName'] ?? ''}'.compareTo(
            '${b['restaurantName'] ?? ''}',
          );
          if (byRestaurant != 0) return byRestaurant;
          final byCategory = '${a['categoryName'] ?? ''}'.compareTo(
            '${b['categoryName'] ?? ''}',
          );
          if (byCategory != 0) return byCategory;
          return '${a['name'] ?? ''}'.compareTo('${b['name'] ?? ''}');
        });
    return filtered;
  }

  bool _isAvailableForOrder(Map<String, dynamic> product) {
    final raw = product['isAvailable'] ?? product['is_available'];
    if (raw == null) return true;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    return ![
      'false',
      '0',
      'no',
      'agotado',
      'inactive',
    ].contains(raw.toString().trim().toLowerCase());
  }

  Map<String, List<Map<String, dynamic>>> _groupByRestaurant(
    List<Map<String, dynamic>> source,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final product in source) {
      final restaurantId = product['restaurantId']?.toString();
      final restaurantName = '${product['restaurantName'] ?? 'Comercio'}';
      final key = restaurantId?.isNotEmpty == true
          ? restaurantId!
          : restaurantName;
      grouped.putIfAbsent(key, () => []).add(product);
    }
    return grouped;
  }

  bool get _hasActiveFilters =>
      searchController.text.trim().isNotEmpty ||
      selectedCategory != _allFilter ||
      selectedRestaurant != _allFilter;

  bool get _showRestaurantDirectory =>
      selectedRestaurant == _allFilter &&
      selectedCategory == _allFilter &&
      searchController.text.trim().isEmpty;

  List<List<Map<String, dynamic>>> get _restaurantGroups {
    final groups = _groupByRestaurant(availableProducts).values.toList()
      ..sort(
        (a, b) => '${a.first['restaurantName'] ?? ''}'.compareTo(
          '${b.first['restaurantName'] ?? ''}',
        ),
      );
    return groups;
  }

  void _selectRestaurant(String restaurant) {
    setState(() => selectedRestaurant = restaurant);
  }

  void _clearFilters() {
    setState(() {
      searchController.clear();
      selectedCategory = _allFilter;
      selectedRestaurant = _allFilter;
    });
  }

  List<Map<String, dynamic>> get cartProducts =>
      products.where((p) => cart.containsKey(p['id'])).toList();

  int get cartCount => cart.values.fold(0, (sum, q) => sum + q);

  double get cartSubtotal => cartProducts.fold<double>(
    0,
    (sum, p) =>
        sum + (double.tryParse('${p['price']}') ?? 0) * (cart[p['id']] ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final showChangeRole = _hasMultipleRoles();

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedTab == 0 ? 'Catálogo' : 'Mis Pedidos'),
        actions: [
          if (_selectedTab == 0)
            IconButton(
              tooltip: 'Actualizar catálogo',
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
            ),
          if (showChangeRole)
            IconButton(
              tooltip: 'Cambiar rol',
              onPressed: con.changeRole,
              icon: const Icon(Icons.swap_horiz),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: con.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          RefreshIndicator(
            onRefresh: _loadProducts,
            child: _catalogBody(context),
          ),
          const ClientOrdersListWidget(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedTab == 0 && cart.isNotEmpty)
              _CartBar(
                itemCount: cartCount,
                total: cartSubtotal + 2500,
                onPressed: _openCart,
              ),
            NavigationBar(
              selectedIndex: _selectedTab,
              onDestinationSelected: (i) => setState(() => _selectedTab = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: 'Catálogo',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Mis Pedidos',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _catalogBody(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return _ErrorState(onRetry: _loadProducts, message: errorMessage!);
    }

    final filtered = filteredProducts;
    final grouped = _groupByRestaurant(filtered);
    final showRestaurantDirectory = _showRestaurantDirectory;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _AddressBar(address: _selectedAddress, onTap: _openAddressSelector),
        const SizedBox(height: 10),
        _HeroSearch(
          controller: searchController,
          total: showRestaurantDirectory
              ? _restaurantGroups.length
              : filtered.length,
          showingRestaurants: showRestaurantDirectory,
        ),
        const SizedBox(height: 16),
        if (showRestaurantDirectory) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Elige un comercio',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${_restaurantGroups.length} disponibles',
                style: const TextStyle(color: Color(0xFF6A6F77)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Entra a un comercio para revisar su menú.',
            style: TextStyle(color: Color(0xFF6A6F77)),
          ),
          const SizedBox(height: 12),
          if (_restaurantGroups.isEmpty)
            _EmptyProducts(hasActiveFilters: false, onClear: _clearFilters)
          else
            ..._restaurantGroups.map(
              (restaurantProducts) => _RestaurantStoreCard(
                products: restaurantProducts,
                onTap: () => _selectRestaurant(
                  '${restaurantProducts.first['restaurantName'] ?? 'Comercio'}',
                ),
              ),
            ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedRestaurant == _allFilter
                      ? 'Resultados por comercio'
                      : selectedRestaurant,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Comercios'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CategoryFilters(
            categories: categories,
            selected: selectedCategory,
            onSelected: (value) => setState(() => selectedCategory = value),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtrar por comercio',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Limpiar'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _CategoryFilters(
            categories: restaurants,
            selected: selectedRestaurant,
            onSelected: (value) => setState(() => selectedRestaurant = value),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Productos disponibles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Text('${filtered.length} items'),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _EmptyProducts(
              hasActiveFilters: _hasActiveFilters,
              onClear: _clearFilters,
            )
          else
            ...grouped.values.map(
              (restaurantProducts) => _RestaurantProductSection(
                products: restaurantProducts,
                cart: cart,
                onAdd: _addToCart,
                onRemove: (product) => _changeQuantity(product, -1),
              ),
            ),
        ],
      ],
    );
  }

  void _addToCart(Map<String, dynamic> product) {
    if (cartProducts.isNotEmpty &&
        cartProducts.first['restaurantId'] != product['restaurantId']) {
      Get.snackbar(
        'Otro comercio',
        'Finaliza o vacía el pedido actual antes de comprar en otro local.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    _changeQuantity(product, 1);
  }

  void _changeQuantity(Map<String, dynamic> product, int change) {
    final id = product['id'] as int;
    setState(() {
      final next = (cart[id] ?? 0) + change;
      if (next <= 0) {
        cart.remove(id);
      } else {
        cart[id] = next;
      }
    });
  }

  Future<void> _openCart() async {
    final box = GetStorage();
    // Pre-fill from new address system, fall back to legacy key
    String prefillAddress() {
      final raw = box.read('delivery_address');
      if (raw is Map && (raw['address'] ?? '').toString().isNotEmpty) {
        return raw['address'].toString();
      }
      return box.read('deliveryAddress')?.toString() ?? '';
    }

    final addressController = TextEditingController(text: prefillAddress());
    final addressFieldKey = GlobalKey();
    var paymentMethod = 'Efectivo';
    var placingOrder = false;
    var orderConfirmed = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, sheetSetState) {
          // Keep the checkout height stable and lift it above the keyboard.
          // The cart list remains scrollable on smaller phone screens.
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          final navigationBar = MediaQuery.viewPaddingOf(context).bottom;
          final maxHeight = MediaQuery.of(context).size.height * 0.88;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboard),
            child: SizedBox(
              height: maxHeight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 14 + navigationBar),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6D8DC),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tu pedido',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text('${cartProducts.first['restaurantName']}'),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          ...cartProducts.map(
                            (product) => _CartItem(
                              product: product,
                              quantity: cart[product['id']] ?? 0,
                              onAdd: () {
                                _changeQuantity(product, 1);
                                sheetSetState(() {});
                              },
                              onRemove: () {
                                _changeQuantity(product, -1);
                                if (cart.isEmpty) {
                                  Navigator.pop(sheetContext);
                                } else {
                                  sheetSetState(() {});
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            key: addressFieldKey,
                            controller: addressController,
                            textInputAction: TextInputAction.done,
                            onTap: () {
                              final fieldContext =
                                  addressFieldKey.currentContext;
                              if (fieldContext != null) {
                                Scrollable.ensureVisible(
                                  fieldContext,
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  alignment: 0.2,
                                );
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Dirección de entrega',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: paymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Forma de pago',
                              prefixIcon: Icon(Icons.payments_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Efectivo',
                                child: Text('Efectivo'),
                              ),
                              DropdownMenuItem(
                                value: 'Tarjeta',
                                child: Text('Tarjeta al recibir'),
                              ),
                              DropdownMenuItem(
                                value: 'Transferencia',
                                child: Text('Transferencia'),
                              ),
                            ],
                            onChanged: (value) =>
                                paymentMethod = value ?? 'Efectivo',
                          ),
                          const SizedBox(height: 18),
                          _PriceRow(label: 'Subtotal', value: cartSubtotal),
                          const SizedBox(height: 8),
                          const _PriceRow(label: 'Envío', value: 2500),
                          const Divider(height: 24),
                          _PriceRow(
                            label: 'Total',
                            value: cartSubtotal + 2500,
                            strong: true,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: placingOrder
                            ? null
                            : () async {
                                final address = addressController.text.trim();
                                if (address.length < 6) {
                                  Get.snackbar(
                                    'Dirección incompleta',
                                    'Indica calle, número y comuna.',
                                  );
                                  return;
                                }
                                sheetSetState(() => placingOrder = true);
                                final estimate = await _estimateRoute(
                                  '${cartProducts.first['restaurantAddress'] ?? cartProducts.first['restaurantName']}',
                                  address,
                                );
                                final response = await appProvider.createOrder(
                                  items: cartProducts
                                      .map(
                                        (p) => {
                                          'product_id': p['id'],
                                          'quantity': cart[p['id']],
                                        },
                                      )
                                      .toList(),
                                  address: address,
                                  paymentMethod: paymentMethod,
                                  distanceKm: estimate.$1,
                                  estimatedMinutes: estimate.$2,
                                );
                                if (!mounted) return;
                                if (response.success == true) {
                                  await box.write('deliveryAddress', address);
                                  // Keep new address key in sync
                                  final raw = box.read('delivery_address');
                                  if (raw is Map) {
                                    final updated = Map<String, dynamic>.from(
                                      raw,
                                    )..['address'] = address;
                                    await box.write(
                                      'delivery_address',
                                      updated,
                                    );
                                  } else {
                                    await box.write('delivery_address', {
                                      'address': address,
                                      'label': null,
                                      'lat': null,
                                      'lng': null,
                                    });
                                  }
                                  // Close the sheet before updating the parent view.
                                  orderConfirmed = true;
                                  if (sheetContext.mounted) {
                                    FocusScope.of(sheetContext).unfocus();
                                    Navigator.pop(sheetContext);
                                  }
                                } else {
                                  sheetSetState(() => placingOrder = false);
                                  Get.snackbar(
                                    'No se pudo crear',
                                    response.message ?? 'Intenta nuevamente.',
                                  );
                                }
                              },
                        icon: placingOrder
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.shopping_bag_outlined),
                        label: Text(
                          placingOrder
                              ? 'Confirmando...'
                              : 'Confirmar pedido · ${NumberFormatLike.clp(cartSubtotal + 2500)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    // Modal is closed — now safe to update parent state.
    if (orderConfirmed && mounted) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      setState(() {
        cart.clear();
        _selectedTab = 1;
      });
    }
    addressController.dispose();
  }

  Future<(double, int)> _estimateRoute(
    String pickupAddress,
    String deliveryAddress,
  ) async {
    try {
      // Geocoding is a convenience for the estimate, never a reason to leave
      // checkout blocked when the third-party geocoder is unavailable.
      final pickup = await RegisteredAddressResolver.resolve(pickupAddress);
      final delivery = await RegisteredAddressResolver.resolve(deliveryAddress);
      if (pickup != null && delivery != null) {
        const calculator = Distance();
        final directKm = calculator.as(LengthUnit.Kilometer, pickup, delivery);
        final roadKm = (directKm * 1.25).clamp(0.5, 80.0).toDouble();
        final minutes = ((roadKm / 22) * 60 + 8).round().clamp(10, 180);
        return (double.parse(roadKm.toStringAsFixed(2)), minutes);
      }
    } catch (_) {}
    return (3.2, 20);
  }
}

// ─── Catalog widgets ──────────────────────────────────────────────────────────

class _HeroSearch extends StatelessWidget {
  final TextEditingController controller;
  final int total;
  final bool showingRestaurants;

  const _HeroSearch({
    required this.controller,
    required this.total,
    required this.showingRestaurants,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC107), Color(0xFFFFA000)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comida a tu puerta',
            style: TextStyle(
              color: Color(0xFF2C2200),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            showingRestaurants
                ? '$total comercios disponibles para pedir'
                : '$total productos disponibles para pedir',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Buscar producto, categoría o tienda',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: controller.clear,
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryFilters({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final category = categories[index];
          final active = category == selected;
          return ChoiceChip(
            selected: active,
            label: Text(category),
            onSelected: (_) => onSelected(category),
            selectedColor: const Color(0xFFFFECB3),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final price = NumberFormatLike.clp(product['price']);
    final image = '${product['image'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _ProductImage(image: image),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${product['categoryName'] ?? 'Producto'}',
                  style: const TextStyle(
                    color: Color(0xFFFFA000),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${product['name']}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ('${product['description'] ?? ''}'.trim().isNotEmpty)
                  Text(
                    '${product['description']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6A6F77)),
                  ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (quantity == 0)
            IconButton(
              tooltip: 'Agregar al pedido',
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle, color: Color(0xFFFFB300)),
            )
          else
            _QuantityStepper(
              quantity: quantity,
              onAdd: onAdd,
              onRemove: onRemove,
            ),
        ],
      ),
    );
  }
}

class _RestaurantProductSection extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Map<int, int> cart;
  final ValueChanged<Map<String, dynamic>> onAdd;
  final ValueChanged<Map<String, dynamic>> onRemove;

  const _RestaurantProductSection({
    required this.products,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final first = products.first;
    final name = '${first['restaurantName'] ?? 'Comercio'}';
    final address = '${first['restaurantAddress'] ?? ''}'.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: Color(0xFF12643D),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      address.isEmpty
                          ? '${products.length} productos disponibles'
                          : address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6A6F77),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${products.length}',
                style: const TextStyle(
                  color: Color(0xFF6A6F77),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...products.map(
            (product) => _ProductCard(
              product: product,
              quantity: cart[product['id']] ?? 0,
              onAdd: () => onAdd(product),
              onRemove: () => onRemove(product),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantStoreCard extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final VoidCallback onTap;

  const _RestaurantStoreCard({required this.products, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final first = products.first;
    final name = '${first['restaurantName'] ?? 'Comercio'}';
    final address = '${first['restaurantAddress'] ?? ''}'.trim();
    final categories = products
        .map((product) => '${product['categoryName'] ?? ''}'.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  size: 27,
                  color: Color(0xFF12643D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6A6F77),
                        ),
                      ),
                    ],
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        categories,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0E8C58),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      '${products.length} productos disponibles',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF12643D)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QuantityStepper({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Quitar uno',
            onPressed: onRemove,
            icon: const Icon(Icons.remove),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 18,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            tooltip: 'Agregar uno',
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final VoidCallback onPressed;

  const _CartBar({
    required this.itemCount,
    required this.total,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E2E6))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$itemCount',
                    style: const TextStyle(
                      color: Color(0xFF5A3C00),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Ver pedido')),
              Text(NumberFormatLike.clp(total)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final Map<String, dynamic> product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _CartItem({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final lineTotal = (double.tryParse('${product['price']}') ?? 0) * quantity;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${product['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(NumberFormatLike.clp(lineTotal)),
              ],
            ),
          ),
          _QuantityStepper(
            quantity: quantity,
            onAdd: onAdd,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool strong;

  const _PriceRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: strong ? 18 : 15,
      fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(NumberFormatLike.clp(value), style: style),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String image;

  const _ProductImage({required this.image});

  @override
  Widget build(BuildContext context) {
    Widget child = const Icon(
      Icons.fastfood_outlined,
      color: Color(0xFFFFA000),
      size: 34,
    );

    if (image.startsWith('http')) {
      child = Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.fastfood_outlined),
      );
    } else if (image.startsWith('assets/')) {
      child = Image.asset(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.fastfood_outlined),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 82,
        height: 82,
        color: const Color(0xFFFFF3CD),
        child: child,
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onClear;

  const _EmptyProducts({required this.hasActiveFilters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 42),
          SizedBox(height: 10),
          Text(
            hasActiveFilters
                ? 'No encontramos productos con esos filtros'
                : 'No hay productos disponibles por ahora',
            textAlign: TextAlign.center,
          ),
          if (hasActiveFilters) ...[
            SizedBox(height: 10),
            TextButton.icon(
              onPressed: onClear,
              icon: Icon(Icons.filter_alt_off_outlined),
              label: Text('Limpiar filtros'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;

  const _ErrorState({required this.onRetry, required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off, size: 48),
        const SizedBox(height: 12),
        Center(child: Text(message)),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}

class _AddressBar extends StatelessWidget {
  final String address;
  final VoidCallback onTap;

  const _AddressBar({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasAddress
                ? const Color(0xFFFFD54F)
                : const Color(0xFFE8EAED),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFFFFB300), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Entregar en',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9EA5AD)),
                  ),
                  Text(
                    hasAddress ? address : '¿A dónde entregamos?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: hasAddress
                          ? const Color(0xFF1E2025)
                          : const Color(0xFF9EA5AD),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more, color: Color(0xFF9EA5AD), size: 20),
          ],
        ),
      ),
    );
  }
}

class NumberFormatLike {
  static String clp(dynamic value) {
    final number = double.tryParse('$value') ?? 0;
    return '\$${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
  }
}
