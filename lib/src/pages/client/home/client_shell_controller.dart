import 'package:get/get.dart';

enum ClientTab { discovery, search, cart, orders, profile }

/// Pestaña activa de la navegación inferior del cliente.
class ClientShellController extends GetxController {
  final tab = ClientTab.discovery.obs;

  /// Cambia la clave para forzar la recarga de "Mis pedidos" al volver a ella.
  final ordersVersion = 0.obs;

  void goTo(ClientTab value) {
    if (value == ClientTab.orders) ordersVersion.value++;
    tab.value = value;
  }

  /// Vuelve a la pantalla principal del cliente (cierra menús abiertos) y
  /// muestra la pestaña pedida.
  static void openTab(ClientTab value) {
    Get.until(
      (route) =>
          route.settings.name == '/client/products/list' || route.isFirst,
    );
    if (Get.isRegistered<ClientShellController>()) {
      Get.find<ClientShellController>().goTo(value);
    }
  }
}
