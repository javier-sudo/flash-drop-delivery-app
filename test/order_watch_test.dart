// F9: servicio en primer plano, estado compartido de avisos y sesión
// compartida entre isolates.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/users_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/notifications/notice_store.dart';
import 'package:proyecto_app_delivery_gessof/src/services/order_watch_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/session_manager.dart';

import 'helpers/test_app.dart';

Map<String, dynamic> order(Object id, String status) => {
  'orderId': id,
  'status': status,
};

/// Simula que otro isolate renovó la sesión justo antes: el refresh token
/// que llega ya fue rotado y auth responde 401.
class _RotatedElsewhere extends UsersProvider {
  int calls = 0;

  @override
  Future<SessionRefreshResult> refreshSession(String refreshToken) async {
    calls++;
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    await storage.write(key: 'flashdrop_access_token', value: 'nuevo-access');
    await storage.write(key: 'flashdrop_refresh_token', value: 'nuevo-refresh');
    return const SessionRefreshResult.failure(401);
  }
}

class _Rejected extends UsersProvider {
  @override
  Future<SessionRefreshResult> refreshSession(String refreshToken) async =>
      const SessionRefreshResult.failure(401);
}

class _BrokenStore extends MemoryNoticeStore {
  @override
  Future<Map<String, dynamic>?> readState(String key) =>
      Future.error(StateError('disco lleno'));
}

void main() {
  setUpAll(initTestStorage);

  group('cuándo corre el servicio', () {
    test('sin sesión no corre', () {
      expect(
        OrderWatchService.decide(
          roles: null,
          driverAvailable: true,
          storeAccepting: true,
        ),
        WatchMode.none,
      );
    });

    test('repartidor: solo mientras está disponible', () {
      expect(
        OrderWatchService.decide(
          roles: {'repartidor'},
          driverAvailable: true,
          storeAccepting: false,
        ),
        WatchMode.courier,
      );
      expect(
        OrderWatchService.decide(
          roles: {'repartidor'},
          driverAvailable: false,
          storeAccepting: false,
        ),
        WatchMode.none,
      );
    });

    test('local: solo con "Recibiendo pedidos" activo', () {
      expect(
        OrderWatchService.decide(
          roles: {'restaurante'},
          driverAvailable: false,
          storeAccepting: true,
        ),
        WatchMode.store,
      );
      expect(
        OrderWatchService.decide(
          roles: {'restaurante'},
          driverAvailable: true,
          storeAccepting: false,
        ),
        WatchMode.none,
      );
    });

    test('si no se pudo consultar el local, se asume abierto', () {
      expect(
        OrderWatchService.decide(
          roles: {'restaurante'},
          driverAvailable: false,
          storeAccepting: null,
        ),
        WatchMode.store,
      );
    });

    test('un cliente nunca tiene servicio', () {
      expect(
        OrderWatchService.decide(
          roles: {'cliente'},
          driverAvailable: true,
          storeAccepting: true,
        ),
        WatchMode.none,
      );
    });

    test('con ambos roles corre una sola vez', () {
      expect(
        OrderWatchService.decide(
          roles: {'repartidor', 'restaurante'},
          driverAvailable: true,
          storeAccepting: true,
        ),
        WatchMode.both,
      );
      expect(
        OrderWatchService.notificationFor(WatchMode.both).route,
        '/restaurant/orders/list',
      );
    });
  });

  group('estado compartido de avisos', () {
    late MemoryNoticeStore store;
    late LocalNotificationsService service;

    setUp(() {
      service = LocalNotificationsService.instance;
      store = MemoryNoticeStore();
      NoticeStore.instance = store;
    });

    test('el seguimiento de un pedido no olvida los demás', () async {
      await service.observeClient([
        order(1, 'PREPARANDO'),
        order(2, 'NUEVO_PEDIDO'),
      ]);
      await service.observeClient([order(1, 'EN_CAMINO')], partial: true);

      final state = await store.readState('client');
      expect(state!['statuses'], {'1': 'EN_CAMINO', '2': 'NUEVO_PEDIDO'});
    });

    test('la lista completa sí olvida los pedidos que ya no vienen', () async {
      await service.observeClient([order(1, 'X'), order(2, 'Y')]);
      await service.observeClient([order(2, 'Y')]);

      final state = await store.readState('client');
      expect(state!['statuses'], {'2': 'Y'});
    });

    test('dos consultas a la vez se aplican una tras otra', () async {
      await Future.wait([
        service.observeStore([order(1, 'NUEVO_PEDIDO')]),
        service.observeStore([
          order(1, 'NUEVO_PEDIDO'),
          order(2, 'NUEVO_PEDIDO'),
        ]),
      ]);
      final state = await store.readState('store');
      expect(state!['statuses'], {'1': 'NUEVO_PEDIDO', '2': 'NUEVO_PEDIDO'});
    });

    test('el repartidor no disponible guarda lo visto sin avisar', () async {
      await service.observeCourier(
        routes: const [],
        available: [order(5, 'LISTO_PARA_RETIRO')],
        isAvailable: false,
      );
      final state = await store.readState('courier_available');
      expect(state!['seen'], ['5']);
    });

    test('un fallo del almacén no rompe la pantalla', () async {
      NoticeStore.instance = _BrokenStore();
      await expectLater(service.observeClient([order(1, 'X')]), completes);
      // Y la cola sigue funcionando después del fallo.
      NoticeStore.instance = store;
      await service.observeClient([order(1, 'X')]);
      expect(await store.readState('client'), isNotNull);
    });

    test('cerrar sesión borra el estado de todos los roles', () async {
      await service.observeClient([order(1, 'X')]);
      await service.observeStore([order(2, 'Y')]);
      await GetStorage().write('order_statuses_client', {'1': 'X'});

      await service.reset();

      expect(store.values, isEmpty);
      expect(GetStorage().read('order_statuses_client'), isNull);
    });
  });

  group('sesión compartida entre isolates', () {
    late SessionManager session;

    setUp(() => session = SessionManager.instance);
    tearDown(() => session.usersProvider = null);

    test(
      'si otro isolate ya renovó, usa el token nuevo y no cierra sesión',
      () async {
        await session.saveAuthenticatedSession({
          'id': 7,
          'accessToken': 'viejo-access',
          'refreshToken': 'viejo-refresh',
        });
        final provider = _RotatedElsewhere();
        session.usersProvider = provider;

        final token = await session.accessToken(forceRefresh: true);

        expect(provider.calls, 1);
        expect(token, 'nuevo-access');
        expect(GetStorage().read('user'), isNotNull);
      },
    );

    test('un refresh token rechazado de verdad sí cierra la sesión', () async {
      await session.saveAuthenticatedSession({
        'id': 7,
        'accessToken': 'a',
        'refreshToken': 'r',
      });
      session.usersProvider = _Rejected();

      expect(await session.accessToken(forceRefresh: true), isNull);
      expect(GetStorage().read('user'), isNull);
    });
  });
}
