import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/models/rol.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/roles/roles_controller.dart';

class RolesPage extends StatelessWidget {
  RolesPage({super.key});

  final RolesController con = Get.put(RolesController());
  final HomeController home = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    final roles = con.user.roles;
    final name = (con.user.name?.trim().isNotEmpty ?? false)
        ? con.user.name!.trim()
        : 'Javier';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash Drop'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: home.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFFECB3),
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF4A3200),
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenido, $name',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text('Prototipo multirol de delivery'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Elige una experiencia',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cliente, restaurante y repartidor usan el mismo acceso, con vistas adaptadas para cada operacion.',
            ),
            const SizedBox(height: 22),
            if (roles.isEmpty)
              const Center(child: Text('No tienes roles asignados'))
            else
              ...roles.map(_roleCard),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(Rol role) {
    final style = _roleStyle(role.name ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => con.selectRole(role),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(style.icon, color: style.color, size: 34),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(style.description),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  _RoleStyle _roleStyle(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('restaurante')) {
      return const _RoleStyle(
        Icons.storefront_outlined,
        Color(0xFF2E7D32),
        'Gestiona pedidos, estados y ventas del local.',
      );
    }
    if (normalized.contains('repartidor')) {
      return const _RoleStyle(
        Icons.delivery_dining,
        Color(0xFF1565C0),
        'Revisa rutas, retiros y entregas asignadas.',
      );
    }
    return const _RoleStyle(
      Icons.shopping_bag_outlined,
      Color(0xFFFFB300),
      'Explora productos y arma un pedido rapido.',
    );
  }
}

class _RoleStyle {
  final IconData icon;
  final Color color;
  final String description;

  const _RoleStyle(this.icon, this.color, this.description);
}
