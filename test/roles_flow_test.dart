import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/driver_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/data/demo_backend.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/delivery/home/delivery_home_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/delivery/orders/list/delivery_orders_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/orders/list/restaurant_orders_list_page.dart';

import 'helpers/test_app.dart';

/// Resuelve un future del backend demo avanzando el reloj falso del test.
Future<T> _settle<T>(WidgetTester tester, Future<T> future) async {
  await tester.pump(const Duration(milliseconds: 400));
  return future;
}

/// Avanza lo justo para que responda el backend demo y aparezca el aviso
/// (un pumpAndSettle largo lo dejaría pasar de largo).
Future<void> _awaitSnackbar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Cierra el aviso actual y deja la pantalla quieta.
Future<void> _dismissSnackbar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

/// Escribe el PIN en el diálogo de entrega y confirma.
Future<void> _submitPin(WidgetTester tester, String pin) async {
  await tester.enterText(find.byType(TextField), pin);
  await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrega'));
  await _awaitSnackbar(tester);
}

void main() {
  setUpAll(initTestStorage);

  setUp(() {
    Get.reset();
    Get.testMode = true;
  });

  group('Restaurante', () {
    testWidgets('rechaza un pedido nuevo solo despues de confirmar', (
      tester,
    ) async {
      await pumpPage(tester, const RestaurantOrdersListPage(), seed: true);
      await tester.tap(find.text('Camila Torres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rechazar pedido'));
      await tester.pumpAndSettle();
      expect(find.text('¿Quieres rechazar este pedido?'), findsOneWidget);
      await tester.tap(find.text('Rechazar').last);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Nuevos (0)'), findsOneWidget);
    });

    testWidgets('filtra por estado y acepta un pedido nuevo', (tester) async {
      await pumpPage(tester, const RestaurantOrdersListPage(), seed: true);

      // Seed: 1 nuevo, 1 preparando, 3 listos, 1 entregado.
      expect(find.text('Todos (6)'), findsOneWidget);
      expect(find.text('Nuevos (1)'), findsOneWidget);
      expect(find.text('Preparando (1)'), findsOneWidget);
      expect(find.text('Listos (3)'), findsOneWidget);
      expect(find.text('En ruta (0)'), findsOneWidget);
      expect(find.text('Entregados (1)'), findsOneWidget);
      expect(find.text('Camila Torres'), findsOneWidget);
      expect(find.textContaining('hace 3 min'), findsOneWidget);

      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      expect(find.text('Nuevos (0)'), findsOneWidget);
      expect(find.text('Preparando (2)'), findsOneWidget);
      expect(find.text('No hay pedidos nuevos'), findsOneWidget);

      await tester.ensureVisible(find.text('Preparando (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preparando (2)'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Camila Torres'),
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Camila Torres'), findsOneWidget);
      expect(find.text('Marcar listo'), findsWidgets);

      await tester.ensureVisible(find.text('En ruta (0)'));
      await tester.tap(find.text('En ruta (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No hay pedidos en ruta'), findsOneWidget);
    });
  });

  group('Repartidor', () {
    testWidgets(
      'toma un pedido, lo retira, falla el PIN, lo entrega y queda en el historial',
      (tester) async {
        await pumpPage(tester, const DeliveryHomePage(), seed: true);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(find.text('Turno activo'), findsOneWidget);
        expect(find.text('3 pedidos disponibles'), findsOneWidget);

        // Selecciona el primer pedido disponible y toma la ruta.
        final card = find.textContaining('Retirar:').first;
        final mainList = find
            .descendant(
              of: find.byType(RefreshIndicator),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(card, 250, scrollable: mainList);
        await tester.drag(mainList, const Offset(0, -150));
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await tester.tap(find.textContaining('Iniciar ruta'));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Asignado: primero se confirma el retiro en el local.
        expect(find.text('Entregar'), findsNothing);
        await tester.tap(find.text('Retirar').first);
        await tester.pumpAndSettle();
        expect(find.text('Confirmar retiro'), findsWidgets);
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar retiro'));
        await _awaitSnackbar(tester);
        expect(find.text('Pedido retirado'), findsOneWidget);
        await _dismissSnackbar(tester);

        final route = (await _settle(
          tester,
          DemoBackend.instance.routes(),
        )).single;
        expect(route['status'], 'Retirado');
        final order = await _settle(
          tester,
          DemoBackend.instance.orderDetail(route['orderId'] as Object),
        );
        final pin = order['deliveryCode'] as String;

        // PIN con formato inválido: el diálogo no se cierra.
        await tester.tap(find.text('Entregar').first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '12');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Confirmar entrega'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ingresa los 6 dígitos del código.'), findsOneWidget);

        // PIN equivocado: lo rechaza el backend y quedan intentos.
        final wrong = pin == '000000' ? '111111' : '000000';
        await _submitPin(tester, wrong);
        expect(find.text('Código incorrecto'), findsOneWidget);
        expect(find.textContaining('Intentos restantes: 2.'), findsOneWidget);
        await _dismissSnackbar(tester);

        // PIN correcto.
        await tester.tap(find.text('Entregar').first);
        await tester.pumpAndSettle();
        await _submitPin(tester, pin);
        expect(find.text('¡Entrega registrada!'), findsOneWidget);
        await _dismissSnackbar(tester);

        // Historial: una entrega.
        await tester.tap(find.text('Historial'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(find.text('Aún no tienes entregas'), findsNothing);
        expect(find.text('1'), findsWidgets);

        // Deja terminar los avisos (snackbars) antes de cerrar el test.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('desconectado no carga pedidos nuevos', (tester) async {
      await pumpPage(tester, const DeliveryHomePage(), seed: true);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      Get.find<DriverController>().setAvailable(false);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Desconectado'), findsOneWidget);
      expect(find.textContaining('Estás desconectado'), findsOneWidget);
      expect(find.textContaining('Retirar:'), findsNothing);

      Get.find<DriverController>().setAvailable(true);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('3 pedidos disponibles'), findsOneWidget);
    });
  });

  group('DemoBackend: entrega con PIN', () {
    late DemoBackend demo;
    late int id;

    setUp(() async {
      demo = DemoBackend.instance..reset(seed: true);
      final available = await demo.availableForDelivery(1);
      expect(
        available.length,
        2,
        reason: 'Urban Burger tiene 2 pedidos listos en el seed',
      );
      id = available.first['orderId'] as int;
    });

    test('doble toma rechazada y retiro solo de pedidos propios', () async {
      final other = (await demo.availableForDelivery(1)).last['orderId'];
      expect((await demo.claim([id])).success, isTrue);
      expect(
        (await demo.claim([id])).success,
        isFalse,
        reason: 'no se puede tomar dos veces',
      );
      expect((await demo.availableForDelivery(1)).length, 1);
      expect((await demo.routes()).single['status'], 'Asignado');

      final notMine = await demo.updateStatus(other as Object, 'Retirado');
      expect(notMine.success, isFalse);
      expect(notMine.statusCode, 409);
    });

    test('no se entrega sin retirar antes', () async {
      await demo.claim([id]);
      final code = (await demo.orderDetail(id))['deliveryCode'] as String;
      final response = await demo.deliver(id, code);
      expect(response.success, isFalse);
      expect(response.statusCode, 409);
    });

    test('PIN errado descuenta intentos y al tercero se renueva', () async {
      await demo.claim([id]);
      await demo.updateStatus(id, 'Retirado');
      final code = (await demo.orderDetail(id))['deliveryCode'] as String;
      expect(code, matches(RegExp(r'^\d{6}$')));
      final wrong = code == '000000' ? '111111' : '000000';

      final first = await demo.deliver(id, wrong);
      expect(first.statusCode, 422);
      expect(first.remainingAttempts, 2);
      expect((await demo.deliver(id, wrong)).remainingAttempts, 1);

      final third = await demo.deliver(id, wrong);
      expect(third.statusCode, 422);
      expect(third.codeRenewed, isTrue);
      final renewed = (await demo.orderDetail(id))['deliveryCode'] as String;

      if (renewed != code) {
        expect(
          (await demo.deliver(id, code)).success,
          isFalse,
          reason: 'el código anterior ya no sirve',
        );
      }
      final ok = await demo.deliver(id, renewed);
      expect(ok.success, isTrue);
      expect((await demo.orderDetail(id))['status'], 'Entregado');
      expect((await demo.routes()).single['status'], 'Entregado');
    });
  });

  group('Repartidor: reglas', () {
    test('routeNeedsPickup según el estado de la parada', () {
      expect(routeNeedsPickup({'status': 'Asignado'}), isTrue);
      expect(routeNeedsPickup({'status': 'Listo para retiro'}), isTrue);
      expect(routeNeedsPickup({'status': 'Retirado'}), isFalse);
      expect(routeNeedsPickup({'status': 'En camino'}), isFalse);
    });

    test('mensajes de error de la entrega', () {
      expect(
        deliveryErrorMessage(
          ResponseApi(success: false, statusCode: 422, remainingAttempts: 2),
        ),
        ('Código incorrecto', 'Intentos restantes: 2.'),
      );
      final renewed = deliveryErrorMessage(
        ResponseApi(success: false, statusCode: 422, codeRenewed: true),
      );
      expect(renewed.$1, 'Código renovado');
      expect(renewed.$2, contains('nuevo código'));
      expect(
        deliveryErrorMessage(ResponseApi(success: false, statusCode: 423)).$1,
        'Entrega bloqueada',
      );
      expect(
        deliveryErrorMessage(ResponseApi(success: false, statusCode: 409)).$1,
        'Pedido no disponible',
      );
      expect(
        deliveryErrorMessage(ResponseApi(success: false, statusCode: 500)),
        ('No se pudo actualizar', 'Intenta nuevamente.'),
      );
    });
  });

  test('timeAgo y estados del local', () {
    final now = DateTime(2026, 10, 29, 12, 0);
    expect(timeAgo('2026-10-29T11:55:00', now: now), 'hace 5 min');
    expect(timeAgo('2026-10-29T09:00:00', now: now), 'hace 3 h');
    expect(timeAgo(null, now: now), isNull);
    expect(RestaurantOrderStatus.of('Nuevo pedido').nextStatus, 'Preparando');
    expect(
      RestaurantOrderStatus.of('Preparando').nextStatus,
      'Listo para retiro',
    );
    expect(RestaurantOrderStatus.of('Entregado').tab, RestaurantTab.delivered);
    expect(RestaurantOrderStatus.of('Retirado').tab, RestaurantTab.inTransit);
    expect(RestaurantOrderStatus.of('Asignado').tab, RestaurantTab.ready);
    expect(RestaurantOrderStatus.of('Listo para retiro').nextStatus, isNull);
  });
}
