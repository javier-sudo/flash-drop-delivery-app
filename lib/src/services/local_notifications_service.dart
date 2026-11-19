import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/services/notifications/notice_store.dart';
import 'package:proyecto_app_delivery_gessof/src/services/notifications/order_notification_rules.dart';

/// Avisos locales de pedidos (F9).
///
/// Qué se avisa lo deciden las reglas puras de [OrderNotificationRules]; este
/// servicio guarda su estado entre consultas y muestra los avisos en Android.
/// En web y escritorio solo se lleva el registro.
class LocalNotificationsService {
  LocalNotificationsService._();

  static final instance = LocalNotificationsService._();

  static const _newOrdersChannel = AndroidNotificationChannel(
    'flashdrop_new_orders',
    'Pedidos nuevos',
    description: 'Pedidos nuevos del local y pedidos disponibles para retirar.',
    importance: Importance.high,
  );

  static const _myOrdersChannel = AndroidNotificationChannel(
    'flashdrop_my_orders',
    'Mis pedidos',
    description: 'Cambios de estado de los pedidos que hiciste.',
    importance: Importance.high,
  );

  /// Canal anterior a F9: se borra para que no quede duplicado en Ajustes.
  static const _legacyChannelId = 'order_updates';

  static const _stateKeys = {
    'client': 'client',
    'store': 'store',
    'courierRoutes': 'courier_routes',
    'courierAvailable': 'courier_available',
  };

  /// Claves de GetStorage anteriores a F9: se borran al cerrar sesión.
  static const _legacyKeys = [
    'order_statuses_client',
    'order_statuses_commerce',
    'order_statuses_delivery',
  ];

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// [handleTaps] es false en segundo plano: ahí no hay app para navegar.
  Future<void> initialize({
    bool requestPermission = true,
    bool handleTaps = true,
  }) async {
    if (_initialized || !isSupported) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: handleTaps
            ? (response) => openFromPayload(response.payload)
            : null,
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_newOrdersChannel);
      await android?.createNotificationChannel(_myOrdersChannel);
      await android?.deleteNotificationChannel(_legacyChannelId);
      if (requestPermission) {
        await android?.requestNotificationsPermission();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Notificaciones locales no disponibles: $e');
    }
  }

  /// Payload del aviso que abrió la app desde cerrada, si lo hubo.
  Future<String?> launchPayload() async {
    if (!_initialized) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  /// Abre la pantalla del aviso. Si no hay sesión, la app ya arranca en el
  /// login y el aviso se ignora.
  static void openFromPayload(String? payload) {
    final target = parsePayload(payload);
    if (target == null) return;
    if (GetStorage().read('user') is! Map) return;
    final orderId = target.orderId;
    Get.toNamed(
      target.route,
      arguments: orderId == null ? null : int.tryParse(orderId) ?? orderId,
    );
  }

  /// Valida el payload: solo se navega a las pantallas de pedidos.
  @visibleForTesting
  static ({String route, String? orderId})? parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final data = jsonDecode(payload);
      if (data is! Map) return null;
      final route = data['route'];
      const allowed = {
        '/client/orders/tracking',
        '/restaurant/orders/list',
        '/delivery/orders/list',
      };
      if (route is! String || !allowed.contains(route)) return null;
      final orderId = data['orderId'];
      // El seguimiento del cliente necesita el pedido.
      if (route == '/client/orders/tracking' && orderId == null) return null;
      return (route: route, orderId: orderId?.toString());
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ roles

  /// [partial]: la lista trae solo algunos pedidos (p. ej. el seguimiento de
  /// uno), así que no se olvidan los demás.
  Future<void> observeClient(
    List<Map<String, dynamic>> orders, {
    bool notify = true,
    bool partial = false,
  }) {
    return _apply('client', notify, (previous) {
      final batch = OrderNotificationRules.client(previous, orders);
      if (!partial || previous == null) return batch;
      return NoticeBatch(
        show: batch.show,
        cancel: batch.cancel,
        state: {
          'statuses': {
            ...?(previous['statuses'] as Map?),
            ...batch.state['statuses'] as Map,
          },
          'codes': {
            ...?(previous['codes'] as Map?),
            ...batch.state['codes'] as Map,
          },
        },
      );
    });
  }

  Future<void> observeStore(
    List<Map<String, dynamic>> orders, {
    bool notify = true,
  }) {
    return _apply(
      'store',
      notify,
      (previous) => OrderNotificationRules.store(previous, orders),
    );
  }

  /// [available] se ignora si el repartidor está "No disponible" o tiene una
  /// ruta en curso: en ese caso se quita el aviso de pedidos disponibles.
  Future<void> observeCourier({
    required List<Map<String, dynamic>> routes,
    required List<Map<String, dynamic>> available,
    required bool isAvailable,
    bool notify = true,
    DateTime? now,
  }) async {
    await _apply(
      'courierRoutes',
      notify,
      (previous) => OrderNotificationRules.courierRoutes(previous, routes),
    );
    final canTake =
        isAvailable && !OrderNotificationRules.hasActiveRoute(routes);
    await _apply(
      'courierAvailable',
      notify,
      (previous) => OrderNotificationRules.courierAvailable(
        previous,
        available,
        canTake: canTake,
        now: now ?? DateTime.now(),
      ),
    );
  }

  /// Olvida lo visto y quita los avisos (al cerrar sesión).
  Future<void> reset() async {
    final legacy = GetStorage();
    for (final key in _legacyKeys) {
      await legacy.remove(key);
    }
    try {
      for (final key in _stateKeys.values) {
        await NoticeStore.instance.remove(key);
      }
    } catch (e) {
      debugPrint('No se pudo borrar el estado de los avisos: $e');
    }
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  // ------------------------------------------------------------------ interno

  Future<void> _apply(
    String scope,
    bool notify,
    NoticeBatch Function(Map<String, dynamic>? previous) rules,
  ) {
    // En un mismo isolate las consultas van una tras otra: dos pantallas que
    // leen el mismo estado a la vez avisarían lo mismo dos veces.
    // La cola es por zona: una consulta de otra zona que nunca terminó (p. ej.
    // un test que acabó a mitad) no debe trabar las siguientes.
    if (!identical(_queueZone, Zone.current)) {
      _queueZone = Zone.current;
      _queue = Future.value();
    }
    final run = _queue.then((_) => _applyNow(scope, notify, rules));
    _queue = run.catchError((_) {});
    return run;
  }

  Future<void> _queue = Future.value();
  Zone? _queueZone;

  Future<void> _applyNow(
    String scope,
    bool notify,
    NoticeBatch Function(Map<String, dynamic>? previous) rules,
  ) async {
    // Un fallo de los avisos nunca debe romper la pantalla de pedidos.
    try {
      final key = _stateKeys[scope]!;
      final previous = await NoticeStore.instance.readState(key);
      final batch = rules(previous);
      await NoticeStore.instance.writeState(key, batch.state);

      for (final id in batch.cancel) {
        await _cancel(id);
      }
      // Al abrir la pantalla no se avisa: la persona ya está mirando.
      if (!notify) return;
      for (final notice in batch.show) {
        await _show(notice);
      }
    } catch (e) {
      debugPrint('No se pudieron procesar los avisos ($scope): $e');
    }
  }

  Future<void> _cancel(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> _show(OrderNotice notice) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        notice.id,
        notice.title,
        notice.body,
        NotificationDetails(android: androidDetailsFor(notice)),
        payload: notice.payload,
      );
    } catch (e) {
      debugPrint('No se pudo mostrar la notificación: $e');
    }
  }

  @visibleForTesting
  static AndroidNotificationDetails androidDetailsFor(OrderNotice notice) {
    final channel = notice.channel == NoticeChannel.newOrders
        ? _newOrdersChannel
        : _myOrdersChannel;
    final silent = notice.priority == NoticePriority.silent;
    return AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: silent ? Importance.low : Importance.high,
      priority: switch (notice.priority) {
        NoticePriority.high => Priority.high,
        NoticePriority.normal => Priority.defaultPriority,
        NoticePriority.silent => Priority.low,
      },
      // Un aviso que se reemplaza suena solo la primera vez que aparece.
      onlyAlertOnce: !notice.alert,
      silent: silent || !notice.alert,
      groupKey: notice.groupKey,
      setAsGroupSummary: notice.isGroupSummary,
      category: AndroidNotificationCategory.status,
      // El texto no muestra datos sensibles, pero con la pantalla bloqueada
      // solo se ve el título.
      visibility: NotificationVisibility.private,
      autoCancel: true,
    );
  }
}
