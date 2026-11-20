import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/users_provider.dart';

/// Recuperación de contraseña (F4): la app solo pide el correo. El enlace que
/// envía Auth abre la página /recuperar-clave de la web, donde se crea la
/// contraseña nueva.
class ForgotPasswordController extends GetxController {
  static const int maxEmailLength = 254;
  static const Duration resendCooldown = Duration(seconds: 60);

  final emailController = TextEditingController();

  // Permite inyectar un provider (tests); por defecto usa el real.
  final UsersProvider _users = Get.isRegistered<UsersProvider>()
      ? Get.find<UsersProvider>()
      : UsersProvider();

  final isSending = false.obs;

  /// Correo al que se pidió el enlace; null mientras no se envía.
  final sentTo = RxnString();
  final errorText = RxnString();

  /// Segundos que faltan para poder reenviar.
  final cooldown = 0.obs;

  Timer? _cooldownTimer;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    final email = args is Map ? args['email']?.toString().trim() ?? '' : '';
    if (email.isNotEmpty && GetUtils.isEmail(email)) {
      emailController.text = email;
    }
  }

  @override
  void onClose() {
    _cooldownTimer?.cancel();
    emailController.dispose();
    super.onClose();
  }

  /// Devuelve el mensaje de error o null si el correo es válido.
  static String? validateEmail(String email) {
    if (email.isEmpty) return 'Ingresa tu correo';
    if (email.length > maxEmailLength) return 'El correo es demasiado largo';
    if (!GetUtils.isEmail(email)) return 'El correo no es válido';
    return null;
  }

  Future<void> send() async {
    // La espera solo frena el reenvío al mismo correo; Auth además limita
    // las solicitudes por IP y por correo.
    if (isSending.value || (sentTo.value != null && cooldown.value > 0)) {
      return;
    }
    final email = emailController.text.trim().toLowerCase();
    final invalid = validateEmail(email);
    if (invalid != null) {
      errorText.value = invalid;
      return;
    }

    errorText.value = null;
    isSending.value = true;
    try {
      final result = Environment.useDemoMode
          ? await _demoRequest()
          : await _users.requestPasswordReset(email);
      switch (result) {
        case PasswordResetRequestResult.sent:
          sentTo.value = email;
          _startCooldown();
        case PasswordResetRequestResult.invalidEmail:
          errorText.value = 'Revisa el correo ingresado.';
        case PasswordResetRequestResult.tooManyRequests:
          errorText.value =
              'Hiciste demasiadas solicitudes. Espera unos minutos e intenta de nuevo.';
        case PasswordResetRequestResult.serverError:
          errorText.value =
              'No pudimos procesar la solicitud. Intenta más tarde.';
        case PasswordResetRequestResult.network:
          errorText.value =
              'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.';
      }
    } finally {
      isSending.value = false;
    }
  }

  /// Vuelve al formulario para escribir otro correo.
  void useAnotherEmail() {
    _cooldownTimer?.cancel();
    cooldown.value = 0;
    sentTo.value = null;
    errorText.value = null;
  }

  void backToLogin() => Get.back();

  Future<PasswordResetRequestResult> _demoRequest() async {
    await Future.delayed(const Duration(milliseconds: 450));
    return PasswordResetRequestResult.sent;
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    cooldown.value = resendCooldown.inSeconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      cooldown.value -= 1;
      if (cooldown.value <= 0) {
        cooldown.value = 0;
        timer.cancel();
      }
    });
  }
}
