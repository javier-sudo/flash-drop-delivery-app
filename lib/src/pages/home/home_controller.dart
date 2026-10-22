import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';
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

  Future<void> signOut() async {
    await SessionManager.instance.clearSession();
    Get.offNamedUntil('/', (route) => false);
  }
}
