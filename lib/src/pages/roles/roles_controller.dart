import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/data/demo_data.dart';
import 'package:proyecto_app_delivery_gessof/src/models/rol.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';

class RolesController extends GetxController {
  final _box = GetStorage();
  late final User user;

  @override
  void onInit() {
    super.onInit();
    final storedUser = _box.read('user');
    if (storedUser == null) {
      _box.write('user', DemoData.user());
    }
    user = User.fromJson(_box.read('user') ?? DemoData.user());
  }

  void selectRole(Rol role) {
    _box.write('selected_role', role.toJson());
    Get.offAllNamed(role.route ?? '/home');
  }
}
