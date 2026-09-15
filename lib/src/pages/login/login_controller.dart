import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/data/demo_data.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/users_provider.dart';

class LoginController extends GetxController {
  final emailController = TextEditingController(text: 'demo@flashdrop.cl');
  final passwordController = TextEditingController(text: '123456');

  final isLoading = false.obs;
  final _box = GetStorage();
  final UsersProvider usersProvider = UsersProvider();
  bool _handledArguments = false;

  @override
  void onInit() {
    super.onInit();
    _applyRouteArguments();
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void goToRegisterPage() => Get.toNamed('/register');
  void goToRolesPage() => Get.offNamedUntil('/roles', (route) => false);

  void _applyRouteArguments() {
    if (_handledArguments) return;
    _handledArguments = true;
    final args = Get.arguments;
    if (args is! Map) return;

    final email = args['email']?.toString().trim() ?? '';
    final message = args['message']?.toString().trim() ?? '';

    if (email.isNotEmpty) {
      emailController.text = email;
      passwordController.clear();
    }

    if (message.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          'Registro completado',
          message,
          snackPosition: SnackPosition.BOTTOM,
        );
      });
    }
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (!isValidForm(email, password)) return;

    try {
      isLoading.value = true;

      if (Environment.useDemoMode) {
        await Future.delayed(const Duration(milliseconds: 550));
        final demoUser = DemoData.user(email: email);
        await _box.write('user', demoUser);
        await _box.write('token', demoUser['session_token']);
        Get.snackbar(
          'Modo prototipo',
          'Sesion iniciada con datos demo',
          snackPosition: SnackPosition.BOTTOM,
        );
        goToRolesPage();
        return;
      }

      final ResponseApi resp = await usersProvider.login(
        login: email,
        password: password,
      );
      if (resp.success == true) {
        final map = (resp.data is Map)
            ? Map<String, dynamic>.from(resp.data)
            : <String, dynamic>{};
        await _box.write('user', map);
        final token = map['token'] ?? map['session_token'];
        if (token != null) await _box.write('token', token);
        goToRolesPage();
      } else {
        Get.snackbar(
          'Login fallido',
          resp.message ?? 'Credenciales invalidas',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'No se pudo conectar al backend: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  bool isValidForm(String email, String password) {
    if (email.isEmpty) {
      Get.snackbar('Validacion', 'Debes ingresar tu correo');
      return false;
    }
    if (!GetUtils.isEmail(email)) {
      Get.snackbar('Validacion', 'El email no es valido');
      return false;
    }
    if (password.isEmpty) {
      Get.snackbar('Validacion', 'Debes ingresar tu contrasena');
      return false;
    }
    return true;
  }
}
