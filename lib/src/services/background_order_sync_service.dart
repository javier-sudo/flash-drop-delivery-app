import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/notifications/notice_store.dart';
import 'package:proyecto_app_delivery_gessof/src/services/notifications/order_notification_rules.dart';
import 'package:proyecto_app_delivery_gessof/src/services/session_manager.dart';
import 'package:workmanager/workmanager.dart';

const _periodicTaskName = 'flashdrop.periodic_order_sync';
const _periodicTaskId = 'flashdrop-periodic-order-sync';

@pragma('vm:entry-point')
void backgroundOrderSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await GetStorage.init();
    await LocalNotificationsService.instance.initialize(
      requestPermission: false,
      handleTaps: false,
    );
    return BackgroundOrderSyncService.sync();
  });
}

class BackgroundOrderSyncService {
  BackgroundOrderSyncService._();

  static Future<void> register() {
    return Workmanager().registerPeriodicTask(
      _periodicTaskId,
      _periodicTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<bool> sync() async {
    // El backend demo vive en memoria del proceso de la app: no hay nada que
    // consultar desde segundo plano.
    if (Environment.useDemoMode) return true;
    try {
      final roles = currentRoles();
      if (roles == null) return true;

      final futures = <Future<void>>[
        if (_hasClientRole(roles)) _syncClient(),
        if (hasCommerceRole(roles)) _syncCommerce(),
        if (hasDeliveryRole(roles)) _syncDelivery(),
      ];
      await Future.wait(futures);
      return true;
    } catch (_) {
      // A later system-scheduled attempt can recover from transient failures.
      return false;
    }
  }

  static Future<void> _syncClient() async {
    final orders = await _get('/api/orders?view=client');
    await LocalNotificationsService.instance.observeClient(orders);
  }

  static Future<void> _syncCommerce() async {
    final orders = await _get('/api/orders?view=restaurant');
    await LocalNotificationsService.instance.observeStore(orders);
  }

  static Future<void> _syncDelivery() async {
    final routes = await _get('/api/delivery/routes');
    // Mismo interruptor "Disponible" que la pantalla (DriverController).
    final isAvailable = await NoticeStore.instance.driverAvailable();
    final available =
        isAvailable && !OrderNotificationRules.hasActiveRoute(routes)
        ? await _availableForDelivery()
        : const <Map<String, dynamic>>[];
    await LocalNotificationsService.instance.observeCourier(
      routes: routes,
      available: available,
      isAvailable: isAvailable,
    );
  }

  /// Pedidos listos para retirar de todos los locales (como la pantalla).
  static Future<List<Map<String, dynamic>>> _availableForDelivery() async {
    final restaurants = await _get('/catalog/restaurants');
    final perRestaurant = await Future.wait(
      restaurants.map((restaurant) {
        final id = int.tryParse('${restaurant['id'] ?? ''}');
        if (id == null) return Future.value(const <Map<String, dynamic>>[]);
        return _get(
          '/api/orders/available-for-delivery?restaurant_id=$id&limit=5',
        );
      }),
    );
    return perRestaurant.expand((orders) => orders).toList();
  }

  /// true si el local del usuario tiene activado "Recibiendo pedidos".
  /// Ante un error devuelve null: quien llama decide sin cambiar nada.
  static Future<bool?> storeAcceptingOrders() async {
    try {
      final data = await _getJson('/api/catalog/my/restaurant');
      if (data is! Map) return null;
      final accepting = data['acceptingOrders'];
      return accepting is bool ? accepting : null;
    } catch (_) {
      return null;
    }
  }

  /// Roles del usuario con sesión, o null si no hay sesión.
  static Set<String>? currentRoles() {
    final rawUser = GetStorage().read('user');
    if (rawUser is! Map || rawUser.isEmpty) return null;
    return _roleNames(Map<String, dynamic>.from(rawUser));
  }

  static Future<Object?> _getJson(String path) async {
    final headers = await SessionManager.instance.authorizedHeaders();
    if (!headers.containsKey('Authorization')) return null;

    final response = await http
        .get(Uri.parse('${Environment.apiUrl}$path'), headers: headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> && decoded.containsKey('data')
        ? decoded['data']
        : decoded;
  }

  static Future<List<Map<String, dynamic>>> _get(String path) async {
    final data = await _getJson(path);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Set<String> _roleNames(Map<String, dynamic> user) {
    final values = <String>{};
    final rawRoles = user['roles'];
    if (rawRoles is List) {
      for (final rawRole in rawRoles) {
        if (rawRole is Map) {
          values.add('${rawRole['name'] ?? ''}'.toLowerCase());
          values.add('${rawRole['route'] ?? ''}'.toLowerCase());
        } else {
          values.add('$rawRole'.toLowerCase());
        }
      }
    }
    return values;
  }

  static bool _hasClientRole(Set<String> roles) {
    return roles.isEmpty || roles.any((role) => role.contains('client'));
  }

  static bool hasCommerceRole(Set<String> roles) {
    return roles.any(
      (role) => role.contains('restaurant') || role.contains('comercio'),
    );
  }

  static bool hasDeliveryRole(Set<String> roles) {
    return roles.any(
      (role) => role.contains('delivery') || role.contains('repartidor'),
    );
  }
}
