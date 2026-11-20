import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/services/background_order_sync_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/notifications/notice_store.dart';

/// Para qué rol corre el servicio en primer plano.
enum WatchMode { none, courier, store, both }

/// Servicio en primer plano de F9 (Android, tipo `specialUse`).
///
/// Mientras el repartidor está "Disponible" o el local está "Recibiendo
/// pedidos", consulta los pedidos cada [interval] aunque la app esté cerrada,
/// y muestra un aviso fijo y silencioso "Servicio activo". Sin él, Android
/// solo deja consultar cada 15 minutos (Workmanager).
///
/// Corre en su propio isolate: comparte con la app solo lo que está en disco
/// (sesión, [NoticeStore]).
class OrderWatchService {
  OrderWatchService._();

  static const interval = Duration(seconds: 30);

  /// Cada cuántas consultas el servicio revisa si debe seguir (≈ 5 min).
  static const recheckEveryTicks = 10;

  static const _serviceId = 4210;
  static bool _initialized = false;

  static bool get isSupported =>
      LocalNotificationsService.isSupported && !Environment.useDemoMode;

  /// Se llama una vez en `main`, antes de `runApp`.
  static void init() {
    if (!isSupported || _initialized) return;
    try {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'flashdrop_active_service',
          channelName: 'Servicio activo',
          channelDescription:
              'Aviso fijo mientras estás disponible o recibiendo pedidos.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(
            interval.inMilliseconds,
          ),
          allowWakeLock: true,
          // Si la persona cierra la app desde recientes, se sigue avisando.
          stopWithTask: false,
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Servicio en primer plano no disponible: $e');
    }
  }

  /// Regla de cuándo corre el servicio. [storeAccepting] null = no se pudo
  /// consultar: se asume abierto, perder un pedido cuesta más que un aviso
  /// fijo de más.
  static WatchMode decide({
    required Set<String>? roles,
    required bool driverAvailable,
    required bool? storeAccepting,
  }) {
    if (roles == null) return WatchMode.none;
    final courier =
        BackgroundOrderSyncService.hasDeliveryRole(roles) && driverAvailable;
    final store =
        BackgroundOrderSyncService.hasCommerceRole(roles) &&
        (storeAccepting ?? true);
    if (courier && store) return WatchMode.both;
    if (courier) return WatchMode.courier;
    if (store) return WatchMode.store;
    return WatchMode.none;
  }

  static Future<WatchMode> currentMode() async {
    final roles = BackgroundOrderSyncService.currentRoles();
    if (roles == null) return WatchMode.none;
    final isStore = BackgroundOrderSyncService.hasCommerceRole(roles);
    return decide(
      roles: roles,
      driverAvailable: await NoticeStore.instance.driverAvailable(),
      storeAccepting: isStore
          ? await BackgroundOrderSyncService.storeAcceptingOrders()
          : false,
    );
  }

  /// Arranca, actualiza o detiene el servicio según el estado actual.
  /// Se llama al abrir la app, al cambiar "Disponible" y al entrar a las
  /// pantallas de pedidos del local o del repartidor.
  static Future<void> refresh() async {
    if (!_initialized) return;
    try {
      final mode = await currentMode();
      final running = await FlutterForegroundTask.isRunningService;
      if (mode == WatchMode.none) {
        if (running) await FlutterForegroundTask.stopService();
        return;
      }
      final text = notificationFor(mode);
      final result = running
          ? await FlutterForegroundTask.updateService(
              notificationTitle: text.title,
              notificationText: text.body,
              notificationInitialRoute: text.route,
            )
          : await FlutterForegroundTask.startService(
              serviceId: _serviceId,
              serviceTypes: const [ForegroundServiceTypes.specialUse],
              notificationTitle: text.title,
              notificationText: text.body,
              notificationInitialRoute: text.route,
              callback: orderWatchCallback,
            );
      if (result is ServiceRequestFailure) {
        debugPrint(
          'No se pudo iniciar el servicio de pedidos: ${result.error}',
        );
      }
    } catch (e) {
      debugPrint('No se pudo actualizar el servicio de pedidos: $e');
    }
  }

  static Future<void> stop() async {
    if (!_initialized) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('No se pudo detener el servicio de pedidos: $e');
    }
  }

  static ({String title, String body, String route}) notificationFor(
    WatchMode mode,
  ) {
    return switch (mode) {
      WatchMode.courier => (
        title: 'Disponible para pedidos',
        body: 'Te avisamos cuando haya pedidos para retirar.',
        route: '/delivery/orders/list',
      ),
      WatchMode.store || WatchMode.both => (
        title: 'Recibiendo pedidos',
        body: 'Te avisamos de cada pedido nuevo.',
        route: '/restaurant/orders/list',
      ),
      WatchMode.none => (title: '', body: '', route: '/roles'),
    };
  }
}

@pragma('vm:entry-point')
void orderWatchCallback() {
  FlutterForegroundTask.setTaskHandler(OrderWatchTaskHandler());
}

/// Lo que hace el servicio en su isolate: la misma consulta que el sondeo de
/// segundo plano, pero cada 30 segundos.
class OrderWatchTaskHandler extends TaskHandler {
  bool _busy = false;
  int _ticks = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await GetStorage.init();
    await LocalNotificationsService.instance.initialize(
      requestPermission: false,
      handleTaps: false,
    );
    await _tick();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _tick();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _tick() async {
    // Si una consulta tarda más que el intervalo, no se encima otra.
    if (_busy) return;
    _busy = true;
    try {
      await BackgroundOrderSyncService.sync();
      _ticks++;
      if (_ticks % OrderWatchService.recheckEveryTicks == 0 &&
          await OrderWatchService.currentMode() == WatchMode.none) {
        // Sesión cerrada, "No disponible" o local cerrado desde la web.
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Consulta del servicio de pedidos falló: $e');
    } finally {
      _busy = false;
    }
  }
}
