import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/cart/cart_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_shell_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_tabs.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/orders/list/client_orders_list_widget.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/common.dart';

/// Inicio del cliente: navegación inferior con Inicio, Restaurantes, Buscar,
/// Pedidos y Perfil. Mantiene la ruta /client/products/list.
class ClientProductsListPage extends StatelessWidget {
  ClientProductsListPage({super.key}) {
    Get.put(HomeController());
    // Catálogo y carrito sobreviven a la navegación: se crean una sola vez.
    if (!Get.isRegistered<CatalogController>()) {
      Get.put(CatalogController(), permanent: true);
    }
    if (!Get.isRegistered<CartController>()) {
      Get.put(CartController(), permanent: true);
    }
    Get.put(ClientShellController());
  }

  static const _items = [
    (ClientTab.discovery, Icons.home_outlined, Icons.home, 'Inicio'),
    (
      ClientTab.restaurants,
      Icons.restaurant_outlined,
      Icons.restaurant,
      'Restaurantes',
    ),
    (ClientTab.search, Icons.search, Icons.search, 'Buscar'),
    (
      ClientTab.orders,
      Icons.receipt_long_outlined,
      Icons.receipt_long,
      'Pedidos',
    ),
    (ClientTab.profile, Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final shell = Get.find<ClientShellController>();
    return Obx(() {
      final tab = shell.tab.value;
      final showCartBar = tab == ClientTab.discovery || tab == ClientTab.search;
      return Scaffold(
        appBar: tab == ClientTab.orders
            ? AppBar(title: const Text('Mis pedidos'))
            : null,
        body: SafeArea(
          child: IndexedStack(
            index: tab.index,
            children: [
              const DiscoveryTab(),
              const RestaurantsTab(),
              const SearchTab(),
              ClientOrdersListWidget(key: ValueKey(shell.ordersVersion.value)),
              const ProfileTab(),
            ],
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCartBar)
              CartBar(onTap: () => Get.to(() => const CartPage())),
            BottomNavigationBar(
              currentIndex: tab.index,
              onTap: (i) => shell.goTo(ClientTab.values[i]),
              items: [
                for (final (_, icon, activeIcon, label) in _items)
                  BottomNavigationBarItem(
                    icon: Icon(icon),
                    activeIcon: Icon(activeIcon),
                    label: label,
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
