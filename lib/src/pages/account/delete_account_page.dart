import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, this.provider});
  final AppProvider? provider;
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (password.text.isEmpty || busy) {
      setState(() => error = 'Ingresa tu contraseña.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Tu cuenta se desactivará y tus datos personales se eliminarán. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api =
          widget.provider ??
          (Get.isRegistered<AppProvider>()
              ? Get.find<AppProvider>()
              : AppProvider());
      final response = await api.deleteAccount(password.text);
      if (!mounted) return;
      if (response.success == true ||
          response.error == 'ACCOUNT_DELETION_IN_PROGRESS') {
        await Get.find<HomeController>().signOut(forgetAddresses: true);
        Get.snackbar(
          'Solicitud recibida',
          'Tu cuenta está desactivada y la eliminación de datos continúa en segundo plano.',
        );
        return;
      }
      final text = switch (response.error) {
        'ACCOUNT_HAS_ACTIVE_PROCESSES' =>
          'Tienes pedidos en curso. Cancélalos o espera a que terminen.',
        'AUTH_INVALID_CREDENTIALS' => 'La contraseña no es correcta.',
        'AUTH_TOKEN_INVALID' => 'Tu sesión venció. Inicia sesión nuevamente.',
        _ => switch (response.statusCode) {
          429 => 'Demasiados intentos. Espera unos minutos.',
          503 => 'No pudimos verificar tus pedidos. Intenta más tarde.',
          _ => 'No se pudo procesar la solicitud. Intenta nuevamente.',
        },
      };
      setState(() => error = text);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo confirmar la solicitud. Antes de reintentar, intenta iniciar sesión de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Eliminar mi cuenta')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Se eliminarán tu perfil y tus datos personales. Los pedidos terminados se conservan sin tus datos como registro del comercio. Esta acción no se puede deshacer.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: password,
          obscureText: true,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Contraseña',
            border: OutlineInputBorder(),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Procesando...' : 'Eliminar mi cuenta'),
        ),
      ],
    ),
  );
}
