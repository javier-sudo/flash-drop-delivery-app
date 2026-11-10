import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/session_manager.dart';

class HomeController extends GetxController {
  final _box = GetStorage();
  late User user;

  HomeController() {
    user = User.fromJson(_box.read('user') ?? {});
  }

  void changeRole() {
    Get.offAllNamed('/roles');
  }

  /// Cierra la sesión y borra lo que pertenece al usuario: tokens, rol, carrito,
  /// dirección de entrega, ruta activa y estados de pedidos vistos.
  Future<void> signOut() async {
    await SessionManager.instance.clearSession();
    await LocalNotificationsService.instance.reset();
    if (Get.isRegistered<CartController>()) Get.find<CartController>().clear();
    Get.offNamedUntil('/', (route) => false);
  }
}
