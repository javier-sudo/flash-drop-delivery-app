import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final HomeController con = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    final name = con.user.name ?? 'Usuario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash Drop'),
        actions: [
          IconButton(
            tooltip: 'Cambiar rol',
            onPressed: con.changeRole,
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: con.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, $name',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona un rol para mostrar el flujo del prototipo.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: con.changeRole,
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Ver roles disponibles'),
            ),
          ],
        ),
      ),
    );
  }
}
