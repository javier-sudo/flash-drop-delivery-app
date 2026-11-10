import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/products/list/client_products_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/delivery/home/delivery_home_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/login/login_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/register/register_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/orders/list/restaurant_orders_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/address/address_selector_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/orders/tracking/client_order_tracking_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/roles/roles_page.dart';
import 'package:proyecto_app_delivery_gessof/src/services/background_order_sync_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/connection_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/session_manager.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/connection_banner.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await LocalNotificationsService.instance.initialize();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Workmanager().initialize(backgroundOrderSyncDispatcher);
      await BackgroundOrderSyncService.register();
    } catch (e) {
      debugPrint('No se pudo programar la sincronización en segundo plano: $e');
    }
  }
  final hasSession = await SessionManager.instance.restoreSession();
  runApp(MyApp(initialRoute: hasSession ? '/roles' : '/'));
}

class MyApp extends StatefulWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ConnectionService.instance.resumeForeground();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        ConnectionService.instance.enterBackground();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Flash Drop Delivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: widget.initialRoute,
      // El aviso "Sin conexión" queda sobre cualquier pantalla.
      builder: (context, child) => Stack(
        children: [child ?? const SizedBox.shrink(), const ConnectionBanner()],
      ),
      getPages: [
        GetPage(name: '/', page: () => LoginPage()),
        GetPage(name: '/register', page: () => RegisterPage()),
        GetPage(name: '/home', page: () => HomePage()),
        GetPage(name: '/roles', page: () => RolesPage()),
        GetPage(
          name: '/client/products/list',
          page: () => ClientProductsListPage(),
        ),
        GetPage(
          name: '/restaurant/orders/list',
          page: () => RestaurantOrdersListPage(),
        ),
        GetPage(
          name: '/delivery/orders/list',
          page: () => const DeliveryHomePage(),
        ),
        GetPage(
          name: '/client/orders/tracking',
          page: () => ClientOrderTrackingPage(),
        ),
        GetPage(
          name: '/client/address',
          page: () => const AddressSelectorPage(),
        ),
      ],
      navigatorKey: Get.key,
    );
  }
}
