import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/cart/cart_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_shell_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_tabs.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/orders/list/client_orders_list_widget.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/client_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/common.dart';

/// Inicio del cliente: navegación inferior con Inicio, Buscar, Carrito,
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

  @override
  Widget build(BuildContext context) {
    final shell = Get.find<ClientShellController>();
    final cart = Get.find<CartController>();
    return ClientTheme(
      child: Obx(() {
        final tab = shell.tab.value;
        return Scaffold(
          body: SafeArea(
            // El header amarillo del Inicio llega hasta el borde superior.
            top: tab != ClientTab.discovery,
            bottom: false,
            child: IndexedStack(
              index: tab.index,
              children: [
                const DiscoveryTab(),
                const SearchTab(),
                const CartPage(embedded: true),
                ClientOrdersListWidget(
                  key: ValueKey(shell.ordersVersion.value),
                ),
                const ProfileTab(),
              ],
            ),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tab == ClientTab.discovery)
                CartBar(onTap: () => shell.goTo(ClientTab.cart)),
              ClientNavBar(
                current: tab.index,
                onTap: (i) => shell.goTo(ClientTab.values[i]),
                items: [
                  const NavItem(Icons.home_outlined, 'Inicio'),
                  const NavItem(Icons.search_rounded, 'Buscar'),
                  NavItem(
                    Icons.shopping_cart_outlined,
                    'Carrito',
                    badge: cart.count,
                  ),
                  const NavItem(Icons.receipt_long_outlined, 'Pedidos'),
                  const NavItem(Icons.person_outline_rounded, 'Perfil'),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}
