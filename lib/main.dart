import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:workmanager/workmanager.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/products/list/client_products_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/delivery/orders/list/delivery_orders_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/login/login_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/register/register_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/orders/list/restaurant_orders_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/address/address_selector_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/orders/tracking/client_order_tracking_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/roles/roles_page.dart';
import 'package:proyecto_app_delivery_gessof/src/services/session_manager.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/connection_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/background_order_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await LocalNotificationsService.instance.initialize();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Workmanager().initialize(backgroundOrderSyncDispatcher);
    await BackgroundOrderSyncService.register();
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFB300)),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        useMaterial3: true,
      ),
      initialRoute: widget.initialRoute,
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
          page: () => DeliveryOrdersListPage(),
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
