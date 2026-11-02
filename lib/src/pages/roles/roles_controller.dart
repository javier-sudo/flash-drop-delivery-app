import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/data/demo_data.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/rol.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';

class RolesController extends GetxController {
  final _box = GetStorage();
  late final User user;

  @override
  void onInit() {
    super.onInit();
    final storedUser = _box.read('user');
    if (storedUser is Map) {
      user = User.fromJson(Map<String, dynamic>.from(storedUser));
      return;
    }
    // En modo demo se puede entrar directo a una vista sin iniciar sesión.
    if (Environment.useDemoMode) {
      _box.write('user', DemoData.user());
      user = User.fromJson(DemoData.user());
      return;
    }
    user = User(email: '', phone: '');
    Get.offAllNamed('/');
  }

  void selectRole(Rol role) {
    _box.write('selected_role', role.toJson());
    Get.offAllNamed(role.route ?? '/home');
  }
}
