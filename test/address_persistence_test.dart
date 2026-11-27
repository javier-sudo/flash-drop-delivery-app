import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_tabs.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/address/address_selector_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/home/home_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/services/session_manager.dart';
import 'package:proyecto_app_delivery_gessof/src/services/delivery_address_store.dart';
import 'package:proyecto_app_delivery_gessof/src/models/delivery_destination.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/users_provider.dart';
import 'helpers/test_app.dart';

const addressA = {
  'address': 'Calle de prueba 123',
  'commune': 'Santiago',
  'lat': -33.45,
  'lng': -70.65,
  'label': 'Casa',
};
Map<String, dynamic> account(int id) => {
  'id': id,
  'name': 'Usuario QA',
  'email': 'qa$id@example.test',
  'accessToken': 'test-access',
  'refreshToken': 'test-refresh',
};

class _RefreshSession extends UsersProvider {
  _RefreshSession({this.accepted = true});
  final bool accepted;
  @override
  Future<SessionRefreshResult> refreshSession(String refreshToken) async =>
      accepted
      ? const SessionRefreshResult.success(
          accessToken: 'restored-access',
          refreshToken: 'restored-refresh',
        )
      : const SessionRefreshResult.failure(401);
}

void main() {
  setUpAll(initTestStorage);
  setUp(() async {
    Get.reset();
    Get.testMode = true;
    await GetStorage().erase();
    FlutterSecureStorage.setMockInitialValues({});
    SessionManager.instance.usersProvider = null;
  });
  tearDown(() {
    SessionManager.instance.usersProvider = null;
    Get.reset();
  });

  Future<void> openSelector(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Get.to(() => const AddressSelectorPage()),
              child: const Text('Abrir direcciones'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir direcciones'));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'confirming an address waits for persistence and returns to the caller',
    (tester) async {
      final session = SessionManager.instance;
      final store = DeliveryAddressStore.instance;
      await session.saveAuthenticatedSession(account(7));
      await store.select(addressA, expectedOwner: store.currentOwner);
      await openSelector(tester);
      await tester.tap(find.text('Usar esta dirección'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir direcciones'), findsOneWidget);
      await store.clearActive();
      await store.restoreCurrent();
      final restored = GetStorage().read('delivery_address') as Map;
      expect(restored['address'], addressA['address']);
      expect(restored['commune'], addressA['commune']);
      expect(restored['lat'], addressA['lat']);
      expect(restored['lng'], addressA['lng']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saving Casa closes the selector and keeps its bookmark across sessions',
    (tester) async {
      final session = SessionManager.instance;
      final store = DeliveryAddressStore.instance;
      await session.saveAuthenticatedSession(account(7));
      await store.select(addressA, expectedOwner: store.currentOwner);
      await openSelector(tester);
      await tester.tap(find.text('Casa'));
      await tester.pumpAndSettle();
      expect(find.byType(AddressSelectorPage), findsNothing);
      await session.clearSession();
      await session.saveAuthenticatedSession(account(7));
      expect((GetStorage().read('saved_addresses') as List).single, addressA);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a selector opened by another account cannot save into the new session',
    (tester) async {
      final session = SessionManager.instance;
      final store = DeliveryAddressStore.instance;
      await session.saveAuthenticatedSession(account(7));
      await store.select(addressA, expectedOwner: store.currentOwner);
      await openSelector(tester);
      await session.saveAuthenticatedSession(account(8));
      await tester.tap(find.text('Usar esta dirección'));
      await tester.pumpAndSettle();
      expect(GetStorage().read('delivery_address'), isNull);
      expect(find.byType(AddressSelectorPage), findsOneWidget);
      expect(
        find.text('Tu sesión cambió. Vuelve a abrir las direcciones.'),
        findsOneWidget,
      );
    },
  );

  test(
    'selection is durable before logout and restores after active cache is gone',
    () async {
      final session = SessionManager.instance;
      final store = DeliveryAddressStore.instance;
      final box = GetStorage();
      await session.saveAuthenticatedSession(account(7));
      await store.select(
        addressA,
        bookmark: true,
        expectedOwner: store.currentOwner,
      );
      await store.clearActive();
      session.usersProvider = _RefreshSession();
      expect(await session.restoreSession(), isTrue);
      expect(box.read('delivery_address'), addressA);
      expect(box.read('saved_addresses'), [addressA]);
    },
  );

  test('logout cannot overwrite the durable choice with a stale active snapshot', () async {
    final session = SessionManager.instance;
    final store = DeliveryAddressStore.instance;
    await session.saveAuthenticatedSession(account(7));
    await store.select(addressA, expectedOwner: store.currentOwner);
    await GetStorage().write('delivery_address', {...addressA, 'address': 'Direccion antigua 456'});
    await session.clearSession();
    await session.saveAuthenticatedSession(account(7));
    expect(GetStorage().read('delivery_address'), addressA);
  });

  test(
    'switching accounts never inherits addresses and restores each account separately',
    () async {
      final session = SessionManager.instance;
      final store = DeliveryAddressStore.instance;
      final box = GetStorage();
      await session.saveAuthenticatedSession(account(7));
      await store.select(
        addressA,
        bookmark: true,
        expectedOwner: store.currentOwner,
      );
      final ownerA = store.currentOwner;
      await session.saveAuthenticatedSession(account(8));
      expect(box.read('delivery_address'), isNull);
      expect(box.read('saved_addresses'), isNull);
      final addressB = {
        ...addressA,
        'address': 'Otra calle de prueba 456',
        'label': 'Trabajo',
      };
      await store.select(
        addressB,
        bookmark: true,
        expectedOwner: store.currentOwner,
      );
      await expectLater(
        store.select(addressA, expectedOwner: ownerA),
        throwsStateError,
      );
      expect(box.read('delivery_address'), addressB);
      await session.saveAuthenticatedSession(account(7));
      expect(box.read('delivery_address'), addressA);
      expect(box.read('saved_addresses'), [addressA]);
      await session.saveAuthenticatedSession(account(8));
      expect(box.read('delivery_address'), addressB);
    },
  );

  test(
    'invalid refresh clears authentication without losing account preferences',
    () async {
      final session = SessionManager.instance;
      final store = DeliveryAddressStore.instance;
      await session.saveAuthenticatedSession(account(7));
      await store.select(addressA, expectedOwner: store.currentOwner);
      session.usersProvider = _RefreshSession(accepted: false);
      expect(await session.accessToken(forceRefresh: true), isNull);
      expect(GetStorage().read('delivery_address'), isNull);
      expect(GetStorage().read('user'), isNull);
      await session.saveAuthenticatedSession(account(7));
      expect(GetStorage().read('delivery_address'), addressA);
    },
  );

  test('account deletion also forgets the encrypted address book', () async {
    final session = SessionManager.instance;
    final store = DeliveryAddressStore.instance;
    await session.saveAuthenticatedSession(account(7));
    await store.select(
      addressA,
      bookmark: true,
      expectedOwner: store.currentOwner,
    );
    await session.clearSession(forgetAddresses: true);
    await session.saveAuthenticatedSession(account(7));
    expect(GetStorage().read('delivery_address'), isNull);
    expect(GetStorage().read('saved_addresses'), isNull);
  });

  test(
    'address archive is secure, bounds bookmarks and does not invent missing coordinates',
    () async {
      final session = SessionManager.instance;
      final store = DeliveryAddressStore.instance;
      await session.saveAuthenticatedSession(account(7));
      for (var i = 0; i < 7; i++) {
        await store.select(
          {...addressA, 'label': 'Lugar $i'},
          bookmark: true,
          expectedOwner: store.currentOwner,
        );
      }
      expect((GetStorage().read('saved_addresses') as List).length, 5);
      final secretValues = await const FlutterSecureStorage().readAll();
      expect(
        secretValues.entries
            .where((entry) => entry.key.startsWith('flashdrop_addresses_v1_'))
            .single
            .value,
        contains('Calle de prueba 123'),
      );
      expect(
        GetStorage().getKeys().where(
          (key) => '$key'.startsWith('flashdrop_addresses_v1_'),
        ),
        isEmpty,
      );
      await expectLater(
        store.select({
          'address': 'Calle sin confirmar 123',
        }, expectedOwner: store.currentOwner),
        throwsFormatException,
      );
    },
  );

  test(
    'legacy addresses keep their text but still require a real pin and commune',
    () async {
      final session = SessionManager.instance;
      final store = DeliveryAddressStore.instance;
      await session.saveAuthenticatedSession(account(7));
      await GetStorage().write('deliveryAddress', 'Calle antigua 123');
      await store.restoreCurrent(migrateLegacy: true);
      final selected = GetStorage().read('delivery_address') as Map;
      expect(selected['address'], 'Calle antigua 123');
      expect(selected['lat'], isNull);
      expect(selected['lng'], isNull);
      expect(DeliveryDestination.fromStorage(selected), isNull);
    },
  );

  test(
    'same account recovers its selected address and bookmarks after logout',
    () async {
      final session = SessionManager.instance;
      final box = GetStorage();
      await session.saveAuthenticatedSession(account(7));
      await box.write('delivery_address', addressA);
      await box.write('saved_addresses', [addressA]);
      await session.clearSession();
      expect(box.read('delivery_address'), isNull);
      await session.saveAuthenticatedSession(account(7));
      expect(box.read('delivery_address'), addressA);
      expect(box.read('saved_addresses'), [addressA]);
    },
  );

  testWidgets(
    'profile reflects an address changed while its tab stays mounted',
    (tester) async {
      await SessionManager.instance.saveAuthenticatedSession(account(7));
      Get.put(HomeController());
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: ProfileTab())),
      );
      await tester.pumpAndSettle();
      await GetStorage().write('delivery_address', addressA);
      await tester.pumpAndSettle();
      expect(find.textContaining('Calle de prueba 123'), findsOneWidget);
    },
  );
}
