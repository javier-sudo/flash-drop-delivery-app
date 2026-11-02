import 'package:get/get.dart';

enum ClientTab { discovery, restaurants, search, orders, profile }

/// Pestaña activa de la navegación inferior del cliente.
class ClientShellController extends GetxController {
  final tab = ClientTab.discovery.obs;

  /// Cambia la clave para forzar la recarga de "Mis pedidos" al volver a ella.
  final ordersVersion = 0.obs;

  void goTo(ClientTab value) {
    if (value == ClientTab.orders) ordersVersion.value++;
    tab.value = value;
  }
}
