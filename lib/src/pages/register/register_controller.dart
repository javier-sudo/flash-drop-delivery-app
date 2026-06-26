import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proyecto_app_delivery_gessof/src/data/demo_data.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/users_provider.dart';
import 'package:sn_progress_dialog/progress_dialog.dart';

class RegisterController extends GetxController {
  final emailController = TextEditingController();
  final rutController = TextEditingController();
  final nameController = TextEditingController();
  final lastnameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final isLoading = false.obs;
  final ImagePicker picker = ImagePicker();
  final _box = GetStorage();
  final UsersProvider usersProvider = UsersProvider();
  File? imagenFile;

  @override
  void onClose() {
    emailController.dispose();
    rutController.dispose();
    nameController.dispose();
    lastnameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  Future<void> register(BuildContext context) async {
    final email = emailController.text.trim();
    final rut = rutController.text.trim();
    final name = nameController.text.trim();
    final lastname = lastnameController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (!isValidForm(email, name, lastname, phone, password, confirm)) return;

    final progressDialog = ProgressDialog(context: context);
    progressDialog.show(max: 100, msg: 'Creando perfil demo...');

    try {
      isLoading.value = true;

      if (Environment.useDemoMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        final demoUser = DemoData.user(name: name, email: email, phone: phone)
          ..['lastName'] = lastname
          ..['rut'] = rut.isEmpty ? '12.345.678-9' : rut;

        await _box.write('user', demoUser);
        await _box.write('token', demoUser['session_token']);
        Get.offAllNamed('/roles');
        return;
      }

      final registerResp = await usersProvider.registerWithImage(
        email: email,
        rut: rut.isEmpty ? null : rut,
        name: name,
        lastName: lastname,
        phone: phone,
        password: password,
        image: imagenFile,
      );

      if (registerResp.success == true) {
        final loginResp = await usersProvider.login(
          login: email,
          password: password,
        );
        if (loginResp.success == true) {
          final map = (loginResp.data is Map)
              ? Map<String, dynamic>.from(loginResp.data)
              : <String, dynamic>{};
          await _box.write('user', map);
          final token = map['token'] ?? map['session_token'];
          if (token != null) await _box.write('token', token);
          Get.offAllNamed('/roles');
        } else {
          Get.offAllNamed('/');
        }
      } else {
        Get.snackbar(
          'Registro fallido',
          registerResp.message ?? 'No se pudo registrar',
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'No se pudo conectar al backend: $e');
    } finally {
      isLoading.value = false;
      progressDialog.close();
    }
  }

  bool isValidForm(
    String email,
    String name,
    String lastname,
    String phone,
    String password,
    String confirmPassword,
  ) {
    if (email.isEmpty) {
      Get.snackbar('Validacion', 'Debes ingresar tu correo');
      return false;
    }
    if (!GetUtils.isEmail(email)) {
      Get.snackbar('Validacion', 'El correo no tiene un formato valido');
      return false;
    }
    if (name.isEmpty) {
      Get.snackbar('Validacion', 'Debes ingresar tu nombre');
      return false;
    }
    if (lastname.isEmpty) {
      Get.snackbar('Validacion', 'Debes ingresar tu apellido');
      return false;
    }
    if (phone.isEmpty) {
      Get.snackbar('Validacion', 'Debes ingresar tu telefono');
      return false;
    }
    if (password.length < 6) {
      Get.snackbar(
        'Validacion',
        'La contrasena debe tener al menos 6 caracteres',
      );
      return false;
    }
    if (confirmPassword != password) {
      Get.snackbar('Validacion', 'Las contrasenas no coinciden');
      return false;
    }
    return true;
  }

  Future<void> selectImage(ImageSource imageSource) async {
    final image = await picker.pickImage(source: imageSource);
    if (image != null) {
      imagenFile = File(image.path);
      update();
    }
  }

  void showAlertDialog(BuildContext context) {
    final alertDialog = AlertDialog(
      title: const Text('Selecciona una opcion'),
      actions: [
        ElevatedButton(
          onPressed: () {
            Get.back();
            selectImage(ImageSource.gallery);
          },
          child: const Text('Galeria'),
        ),
        ElevatedButton(
          onPressed: () {
            Get.back();
            selectImage(ImageSource.camera);
          },
          child: const Text('Camara'),
        ),
      ],
    );
    showDialog(context: context, builder: (_) => alertDialog);
  }
}
