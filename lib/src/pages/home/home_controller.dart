import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';

class HomeController extends GetxController {
  final _box = GetStorage();
  late User user;

  HomeController() {
    user = User.fromJson(_box.read('user') ?? {});
  }

  void changeRole() {
    Get.offAllNamed('/roles');
  }

  void signOut() {
    _box.remove('user');
    _box.remove('token');
    Get.offNamedUntil('/', (route) => false);
  }
}
