import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';

class LocalNotificationsService {
  LocalNotificationsService._();

  static final instance = LocalNotificationsService._();

  static const _channel = AndroidNotificationDetails(
    'order_updates',
    'Actualizaciones de pedidos',
    channelDescription: 'Cambios de estado y nuevos pedidos de Flash Drop.',
    importance: Importance.high,
    priority: Priority.high,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  final _storage = GetStorage();
  bool _initialized = false;

  Future<void> initialize({bool requestPermission = true}) async {
    if (_initialized) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    if (requestPermission) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  Future<void> observeOrders({
    required String scope,
    required List<Map<String, dynamic>> orders,
    required bool notify,
  }) async {
    final key = 'order_statuses_$scope';
    final saved = _storage.read(key);
    final known = saved is Map
        ? Map<String, dynamic>.from(saved)
        : <String, dynamic>{};
    final next = <String, dynamic>{...known};

    for (final order in orders) {
      final id = '${order['id'] ?? order['orderId'] ?? order['code'] ?? ''}';
      final status = '${order['status'] ?? ''}'.trim();
      if (id.isEmpty || status.isEmpty) continue;

      final previous = known[id]?.toString();
      if (notify && previous != null && previous != status) {
        await _show(
          id: id,
          title: _titleFor(scope, order),
          body: 'Estado actualizado: $status',
        );
      } else if (notify && previous == null && scope == 'commerce') {
        await _show(
          id: id,
          title: 'Nuevo pedido',
          body: '${order['code'] ?? 'Pedido'} espera tu confirmación.',
        );
      }
      next[id] = status;
    }
    await _storage.write(key, next);
  }

  Future<void> _show({
    required String id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      '$id:$body'.hashCode & 0x7fffffff,
      title,
      body,
      const NotificationDetails(android: _channel),
    );
  }

  String _titleFor(String scope, Map<String, dynamic> order) {
    if (scope == 'commerce') return 'Pedido ${order['code'] ?? ''}'.trim();
    if (scope == 'delivery') {
      return 'Ruta ${order['code'] ?? order['orderId'] ?? ''}'.trim();
    }
    return 'Pedido ${order['code'] ?? ''}'.trim();
  }
}
