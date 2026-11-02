import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
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
    try {
      final rawUser = GetStorage().read('user');
      if (rawUser is! Map || rawUser.isEmpty) return true;

      final roles = _roleNames(Map<String, dynamic>.from(rawUser));
      final futures = <Future<void>>[
        if (_hasClientRole(roles)) _syncClient(),
        if (_hasCommerceRole(roles)) _syncCommerce(),
        if (_hasDeliveryRole(roles)) _syncDelivery(),
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
    await LocalNotificationsService.instance.observeOrders(
      scope: 'client',
      orders: orders,
      notify: true,
    );
  }

  static Future<void> _syncCommerce() async {
    final orders = await _get('/api/orders?view=restaurant');
    await LocalNotificationsService.instance.observeOrders(
      scope: 'commerce',
      orders: orders,
      notify: true,
    );
  }

  static Future<void> _syncDelivery() async {
    final routes = await _get('/api/delivery/routes');
    await LocalNotificationsService.instance.observeOrders(
      scope: 'delivery',
      orders: routes,
      notify: true,
    );
  }

  static Future<List<Map<String, dynamic>>> _get(String path) async {
    final headers = await SessionManager.instance.authorizedHeaders();
    if (!headers.containsKey('Authorization')) return const [];

    final response = await http
        .get(Uri.parse('${Environment.apiUrl}$path'), headers: headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> && decoded.containsKey('data')
        ? decoded['data']
        : decoded;
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

  static bool _hasCommerceRole(Set<String> roles) {
    return roles.any(
      (role) => role.contains('restaurant') || role.contains('comercio'),
    );
  }

  static bool _hasDeliveryRole(Set<String> roles) {
    return roles.any(
      (role) => role.contains('delivery') || role.contains('repartidor'),
    );
  }
}
