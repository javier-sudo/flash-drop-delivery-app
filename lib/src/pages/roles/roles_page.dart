import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/rol.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/roles/roles_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';

const _kDark = Color(0xFF0D1117);

/// Ancho desde el que los perfiles se muestran en 3 columnas (web/tablet).
const double kRolesWideBreakpoint = 900;

/// Selector de perfil: cabecera de marca oscura y una tarjeta por rol.
class RolesPage extends StatelessWidget {
  RolesPage({super.key});

  final RolesController con = Get.put(RolesController());
  final HomeController home = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    final roles = con.user.roles;
    final name = con.user.name?.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= kRolesWideBreakpoint;
          final maxWidth = wide ? 1080.0 : 560.0;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(name: name, maxWidth: maxWidth, onSignOut: home.signOut),
              _Centered(
                maxWidth: maxWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Elige tu perfil',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Una sola cuenta, con una vista pensada para cada operación.',
                        style: TextStyle(color: AppColors.muted, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      if (roles.isEmpty)
                        const _EmptyRoles()
                      else if (wide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < roles.length; i++) ...[
                                if (i > 0) const SizedBox(width: 16),
                                Expanded(
                                  child: _RoleCard(
                                    role: roles[i],
                                    onTap: () => con.selectRole(roles[i]),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        for (final role in roles)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _RoleCard(
                              role: role,
                              onTap: () => con.selectRole(role),
                            ),
                          ),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            size: 18,
                            color: AppColors.muted,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Puedes cambiar de perfil cuando quieras desde el menú de cada vista.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const _Centered({required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

// ─── Cabecera ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final double maxWidth;
  final VoidCallback onSignOut;

  const _Header({
    required this.name,
    required this.maxWidth,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      decoration: const BoxDecoration(
        color: _kDark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: _Centered(
          maxWidth: maxWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/img/logo_flashdrop_banner.png',
                      width: 44,
                      height: 44,
                      filterQuality: FilterQuality.medium,
                      semanticLabel: 'Flash Drop',
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Flash Drop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    if (Environment.useDemoMode) const _DemoBadge(),
                    IconButton(
                      tooltip: 'Cerrar sesión',
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: _kDark,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isNotEmpty ? 'Hola, $name' : 'Hola',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '¿Con qué perfil quieres entrar hoy?',
                              style: TextStyle(
                                color: Color(0xFF8B9AAD),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'Modo demo',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── Tarjeta de rol ──────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final Rol role;
  final VoidCallback onTap;

  const _RoleCard({required this.role, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = RoleStyle.of(role.name ?? '');
    final title = role.name ?? '';
    // Ink lleva el fondo blanco y la sombra; el InkWell va encima para que el
    // efecto de toque se pinte sobre la tarjeta.
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // La imagen ya trae su propio fondo redondeado; si no
                    // carga, se dibuja el ícono sobre el color del rol.
                    Image.asset(
                      style.image,
                      width: 56,
                      height: 56,
                      filterQuality: FilterQuality.medium,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: style.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(style.icon, color: style.color, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            style.description,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in style.features)
                      _FeatureChip(label: f, color: style.color),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.line),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Entrar como $title',
                        style: TextStyle(
                          color: style.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: style.color,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final Color color;

  const _FeatureChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRoles extends StatelessWidget {
  const _EmptyRoles();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: const Column(
        children: [
          Icon(Icons.lock_outline, color: AppColors.muted, size: 32),
          SizedBox(height: 10),
          Text(
            'No tienes perfiles asignados',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Pide a un administrador que te asigne un rol.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Icono, color, descripción y funciones destacadas de cada rol.
class RoleStyle {
  final IconData icon;
  final String image;
  final Color color;
  final String description;
  final List<String> features;

  const RoleStyle(
    this.icon,
    this.image,
    this.color,
    this.description,
    this.features,
  );

  factory RoleStyle.of(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('restaurante')) {
      return const RoleStyle(
        Icons.storefront_outlined,
        'assets/img/role_restaurant.png',
        Color(0xFF16824B),
        'Recibe pedidos, gestiona la cocina y avisa cuando están listos.',
        ['Pedidos entrantes', 'Estados de cocina', 'Listos para retiro'],
      );
    }
    if (normalized.contains('repartidor')) {
      return const RoleStyle(
        Icons.delivery_dining,
        'assets/img/role_rider.png',
        Color(0xFF0C7FD0),
        'Toma pedidos cercanos, sigue la ruta y registra tus entregas.',
        ['Mapa de ruta', 'Agrupar por local', 'Historial'],
      );
    }
    return const RoleStyle(
      Icons.shopping_bag_outlined,
      'assets/img/role_client.png',
      AppColors.primaryDark,
      'Explora restaurantes, arma tu pedido y síguelo en tiempo real.',
      ['Catálogo por local', 'Carrito y pago', 'Seguimiento'],
    );
  }
}
