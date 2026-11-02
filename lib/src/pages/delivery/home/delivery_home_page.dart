import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/driver_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/models/user.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/delivery/orders/list/delivery_orders_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/illustration.dart';

const _kDark = Color(0xFF0D1117);

/// Inicio del repartidor: Pedidos, Historial y Perfil (navegación inferior
/// oscura). Mantiene la ruta /delivery/orders/list.
class DeliveryHomePage extends StatefulWidget {
  const DeliveryHomePage({super.key});

  @override
  State<DeliveryHomePage> createState() => _DeliveryHomePageState();
}

class _DeliveryHomePageState extends State<DeliveryHomePage> {
  int _tab = 0;
  int _historyVersion = 0;

  @override
  void initState() {
    super.initState();
    Get.put(HomeController());
    if (!Get.isRegistered<DriverController>()) Get.put(DriverController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const DeliveryOrdersListPage(),
          _HistoryTab(key: ValueKey(_historyVersion)),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : const Color(0xFF8B9AAD),
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? _kDark
                  : const Color(0xFF8B9AAD),
            ),
          ),
        ),
        child: NavigationBar(
          backgroundColor: _kDark,
          indicatorColor: AppColors.primary,
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() {
            // El historial se recarga al entrar (puede haber entregas nuevas).
            if (i == 1) _historyVersion++;
            _tab = i;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined),
              label: 'Pedidos',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Historial ────────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({super.key});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final _api = Get.isRegistered<AppProvider>()
      ? Get.find<AppProvider>()
      : AppProvider();
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final routes = await _api.getDeliveryRoutes();
    return routes
        .where((r) => '${r['status']}'.toLowerCase().contains('entregado'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: _kDark,
        foregroundColor: Colors.white,
        title: const Text(
          'Historial',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo cargar el historial'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final routes = snapshot.data ?? [];
          final total = routes.fold<double>(
            0,
            (s, r) => s + toDouble(r['total']),
          );
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _SummaryTile(
                      label: 'Entregas',
                      value: '${routes.length}',
                      icon: Icons.task_alt,
                    ),
                    const SizedBox(width: 12),
                    _SummaryTile(
                      label: 'Monto entregado',
                      value: clp(total),
                      icon: Icons.payments_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (routes.isEmpty)
                  const IllustratedMessage(
                    illustration: AppIllustration.emptyOrders,
                    title: 'Aún no tienes entregas',
                    message: 'Las rutas que completes aparecerán aquí.',
                    size: 150,
                  )
                else
                  for (final r in routes)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4ED),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r['code'] ?? 'Pedido'} · ${r['restaurantName'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${r['deliveryAddress'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (r['total'] != null)
                            Text(
                              clp(r['total']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF8B9AAD), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Perfil ───────────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final driver = Get.find<DriverController>();
    final raw = GetStorage().read('user');
    final user = User.fromJson(
      raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw),
    );
    final name = [
      user.name,
      user.lastName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');

    return Scaffold(
      backgroundColor: _kDark,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white24, width: 6),
                ),
                alignment: Alignment.center,
                child: Text(
                  (name.isEmpty ? 'R' : name[0]).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: _kDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                name.isEmpty ? 'Repartidor' : name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (user.email.isNotEmpty)
              Center(
                child: Text(
                  user.email,
                  style: const TextStyle(color: Color(0xFF8B9AAD)),
                ),
              ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.only(left: 16, right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Obx(
                () => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Estado',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    driver.available.value
                        ? 'Disponible para recibir pedidos'
                        : 'Desconectado',
                    style: TextStyle(
                      color: driver.available.value
                          ? AppColors.primary
                          : const Color(0xFF8B9AAD),
                    ),
                  ),
                  value: driver.available.value,
                  onChanged: driver.setAvailable,
                  activeColor: _kDark,
                  activeTrackColor: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (user.roles.length > 1)
              _DarkOption(
                icon: Icons.swap_horiz,
                label: 'Cambiar rol',
                onTap: home.changeRole,
              ),
            _DarkOption(
              icon: Icons.logout,
              label: 'Cerrar sesión',
              onTap: home.signOut,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _DarkOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF6B6B) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: Icon(icon, color: color),
          title: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: color.withValues(alpha: 0.6),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
