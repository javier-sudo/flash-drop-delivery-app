import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/services/notifications/order_notification_rules.dart';

Map<String, dynamic> order(
  Object id,
  String status, {
  String? code,
  String? restaurant,
  String? deliveryCode,
  String? receptionMode,
}) => {
  'orderId': id,
  'status': status,
  if (code != null) 'code': code,
  if (restaurant != null) 'restaurantName': restaurant,
  if (deliveryCode != null) 'deliveryCode': deliveryCode,
  if (receptionMode != null) 'receptionMode': receptionMode,
};

/// Simula guardar el estado en GetStorage (ida y vuelta por JSON).
Map<String, dynamic> persist(NoticeBatch batch) =>
    jsonDecode(jsonEncode(batch.state)) as Map<String, dynamic>;

void main() {
  final t0 = DateTime(2026, 11, 19, 12);

  group('repartidor: pedidos disponibles', () {
    test('la primera consulta solo registra, no avisa', () {
      final batch = OrderNotificationRules.courierAvailable(
        null,
        [order(1, 'LISTO_PARA_RETIRO', restaurant: 'Sushi')],
        canTake: true,
        now: t0,
      );
      expect(batch.show, isEmpty);
      expect(batch.state['seen'], ['1']);
    });

    test('un pedido nuevo muestra un solo aviso agrupado que suena', () {
      final s0 = persist(
        OrderNotificationRules.courierAvailable(
          null,
          [],
          canTake: true,
          now: t0,
        ),
      );
      final batch = OrderNotificationRules.courierAvailable(
        s0,
        [
          order(1, 'LISTO_PARA_RETIRO', restaurant: 'Sushi'),
          order(2, 'LISTO_PARA_RETIRO', restaurant: 'Sushi'),
          order(3, 'PREPARANDO', restaurant: 'Pizza'),
        ],
        canTake: true,
        now: t0,
      );
      expect(batch.show, hasLength(1));
      final n = batch.show.single;
      expect(n.id, OrderNotificationRules.courierAvailableNoticeId);
      expect(n.alert, isTrue);
      expect(n.title, '3 pedidos disponibles');
      expect(n.body, 'Sushi (2), Pizza · toca para ver');
      expect(n.channel, NoticeChannel.newOrders);
    });

    test('dentro de 2 minutos se actualiza el texto sin volver a sonar', () {
      var state = persist(
        OrderNotificationRules.courierAvailable(
          null,
          [],
          canTake: true,
          now: t0,
        ),
      );
      state = persist(
        OrderNotificationRules.courierAvailable(
          state,
          [order(1, 'LISTO_PARA_RETIRO')],
          canTake: true,
          now: t0,
        ),
      );
      final batch = OrderNotificationRules.courierAvailable(
        state,
        [order(1, 'LISTO_PARA_RETIRO'), order(2, 'LISTO_PARA_RETIRO')],
        canTake: true,
        now: t0.add(const Duration(seconds: 90)),
      );
      expect(batch.show.single.alert, isFalse);
      expect(batch.show.single.title, '2 pedidos disponibles');
    });

    test('pasados 2 minutos un pedido nuevo vuelve a sonar', () {
      var state = persist(
        OrderNotificationRules.courierAvailable(
          null,
          [],
          canTake: true,
          now: t0,
        ),
      );
      state = persist(
        OrderNotificationRules.courierAvailable(
          state,
          [order(1, 'X')],
          canTake: true,
          now: t0,
        ),
      );
      final batch = OrderNotificationRules.courierAvailable(
        state,
        [order(1, 'X'), order(2, 'X')],
        canTake: true,
        now: t0.add(const Duration(minutes: 2)),
      );
      expect(batch.show.single.alert, isTrue);
    });

    test('si otro repartidor toma uno, se actualiza el número en silencio', () {
      var state = persist(
        OrderNotificationRules.courierAvailable(
          null,
          [order(1, 'X'), order(2, 'X')],
          canTake: true,
          now: t0,
        ),
      );
      final batch = OrderNotificationRules.courierAvailable(
        state,
        [order(2, 'X')],
        canTake: true,
        now: t0.add(const Duration(minutes: 10)),
      );
      expect(batch.show.single.alert, isFalse);
      expect(batch.show.single.title, '1 pedido disponible');
      state = persist(batch);
      // Sin cambios no se vuelve a mostrar nada.
      final same = OrderNotificationRules.courierAvailable(
        state,
        [order(2, 'X')],
        canTake: true,
        now: t0.add(const Duration(minutes: 11)),
      );
      expect(same.show, isEmpty);
      expect(same.cancel, isEmpty);
    });

    test('sin pedidos disponibles se quita el aviso', () {
      final state = persist(
        OrderNotificationRules.courierAvailable(
          null,
          [order(1, 'X')],
          canTake: true,
          now: t0,
        ),
      );
      final batch = OrderNotificationRules.courierAvailable(
        state,
        [],
        canTake: true,
        now: t0,
      );
      expect(batch.show, isEmpty);
      expect(batch.cancel, [OrderNotificationRules.courierAvailableNoticeId]);
    });

    test('no disponible o con ruta activa no avisa y quita el aviso', () {
      final state = persist(
        OrderNotificationRules.courierAvailable(
          null,
          [],
          canTake: true,
          now: t0,
        ),
      );
      final batch = OrderNotificationRules.courierAvailable(
        state,
        [order(1, 'X')],
        canTake: false,
        now: t0,
      );
      expect(batch.show, isEmpty);
      expect(batch.cancel, [OrderNotificationRules.courierAvailableNoticeId]);
      // Al volver a estar disponible no se avisa lo que ya vio.
      final back = OrderNotificationRules.courierAvailable(
        persist(batch),
        [order(1, 'X')],
        canTake: true,
        now: t0.add(const Duration(minutes: 5)),
      );
      expect(back.show, isEmpty);
    });

    test('con muchos locales resume los primeros tres', () {
      final state = persist(
        OrderNotificationRules.courierAvailable(
          null,
          [],
          canTake: true,
          now: t0,
        ),
      );
      final batch = OrderNotificationRules.courierAvailable(
        state,
        [for (var i = 1; i <= 5; i++) order(i, 'X', restaurant: 'Local $i')],
        canTake: true,
        now: t0,
      );
      expect(
        batch.show.single.body,
        'Local 1, Local 2, Local 3 y 2 más · toca para ver',
      );
    });

    test('hasActiveRoute ignora rutas terminadas', () {
      expect(
        OrderNotificationRules.hasActiveRoute([
          order(1, 'ENTREGADO'),
          order(2, 'CANCELADO'),
        ]),
        isFalse,
      );
      expect(
        OrderNotificationRules.hasActiveRoute([order(3, 'EN_CAMINO')]),
        isTrue,
      );
    });
  });

  group('repartidor: ruta propia', () {
    test('avisa si un pedido de su ruta se cancela', () {
      final state = persist(
        OrderNotificationRules.courierRoutes(null, [
          order(5, 'EN_CAMINO', code: 'FD-5'),
        ]),
      );
      final batch = OrderNotificationRules.courierRoutes(state, [
        order(5, 'CANCELADO', code: 'FD-5'),
      ]);
      expect(batch.show.single.title, 'Pedido FD-5 cancelado');
    });

    test('no avisa los cambios que hace él mismo', () {
      final state = persist(
        OrderNotificationRules.courierRoutes(null, [order(5, 'RETIRADO')]),
      );
      final batch = OrderNotificationRules.courierRoutes(state, [
        order(5, 'EN_CAMINO'),
      ]);
      expect(batch.show, isEmpty);
    });
  });

  group('tienda', () {
    test('la primera consulta no avisa los pedidos que ya había', () {
      final batch = OrderNotificationRules.store(null, [
        order(1, 'NUEVO_PEDIDO'),
      ]);
      expect(batch.show, isEmpty);
      expect(batch.cancel, isEmpty);
    });

    test('cada pedido nuevo tiene su propio aviso con sonido', () {
      final state = persist(OrderNotificationRules.store(null, []));
      final batch = OrderNotificationRules.store(state, [
        order(1, 'NUEVO_PEDIDO', code: 'FD-1'),
        order(2, 'NUEVO_PEDIDO', code: 'FD-2'),
      ]);
      expect(batch.show, hasLength(2));
      expect(batch.show.map((n) => n.title), [
        'Nuevo pedido FD-1',
        'Nuevo pedido FD-2',
      ]);
      expect(batch.show.every((n) => n.alert), isTrue);
      expect(batch.show[0].id, isNot(batch.show[1].id));
      expect(batch.cancel, [OrderNotificationRules.storeSummaryNoticeId]);
    });

    test('con 3 o más pedidos nuevos agrega un resumen silencioso', () {
      final state = persist(OrderNotificationRules.store(null, []));
      final batch = OrderNotificationRules.store(state, [
        for (var i = 1; i <= 3; i++) order(i, 'NUEVO_PEDIDO'),
      ]);
      final summary = batch.show.where((n) => n.isGroupSummary).single;
      expect(summary.id, OrderNotificationRules.storeSummaryNoticeId);
      expect(summary.title, '3 pedidos nuevos');
      expect(summary.alert, isFalse);
    });

    test('al aceptar un pedido se quita su aviso', () {
      final state = persist(
        OrderNotificationRules.store(null, [order(1, 'NUEVO_PEDIDO')]),
      );
      final batch = OrderNotificationRules.store(state, [
        order(1, 'PREPARANDO'),
      ]);
      expect(batch.show, isEmpty);
      final newOrder = OrderNotificationRules.store(
        persist(OrderNotificationRules.store(null, [])),
        [order(1, 'NUEVO_PEDIDO')],
      ).show.single;
      expect(batch.cancel, contains(newOrder.id));
    });

    test('avisa si un pedido en curso se cancela', () {
      final state = persist(
        OrderNotificationRules.store(null, [
          order(1, 'PREPARANDO', code: 'FD-1'),
        ]),
      );
      final batch = OrderNotificationRules.store(state, [
        order(1, 'CANCELADO', code: 'FD-1'),
      ]);
      expect(batch.show.single.title, 'Pedido FD-1 cancelado');
      expect(batch.show.single.priority, NoticePriority.high);
    });

    test('un pedido que aparece ya pagado y preparando no se avisa', () {
      final state = persist(OrderNotificationRules.store(null, []));
      final batch = OrderNotificationRules.store(state, [
        order(9, 'PREPARANDO'),
      ]);
      expect(batch.show, isEmpty);
    });
  });

  group('cliente', () {
    Map<String, dynamic> seed(List<Map<String, dynamic>> orders) =>
        persist(OrderNotificationRules.client(null, orders));

    test('la primera consulta no avisa', () {
      expect(
        OrderNotificationRules.client(null, [order(1, 'EN_CAMINO')]).show,
        isEmpty,
      );
    });

    test('preparando avisa en silencio', () {
      final batch = OrderNotificationRules.client(
        seed([order(1, 'NUEVO_PEDIDO', code: 'FD-1')]),
        [order(1, 'PREPARANDO', code: 'FD-1')],
      );
      expect(batch.show.single.priority, NoticePriority.silent);
      expect(batch.show.single.route, '/client/orders/tracking');
      expect(jsonDecode(batch.show.single.payload)['orderId'], '1');
    });

    test('listo para retiro no avisa', () {
      final batch = OrderNotificationRules.client(
        seed([order(1, 'PREPARANDO')]),
        [order(1, 'LISTO_PARA_RETIRO')],
      );
      expect(batch.show, isEmpty);
    });

    test('en camino avisa con prioridad alta y sin mostrar el código', () {
      final batch = OrderNotificationRules.client(
        seed([order(1, 'LISTO_PARA_RETIRO')]),
        [order(1, 'RETIRADO', deliveryCode: '4821')],
      );
      final n = batch.show.single;
      expect(n.title, 'Tu pedido va en camino');
      expect(n.priority, NoticePriority.high);
      expect(n.body, isNot(contains('4821')));
      expect(n.body, contains('código'));
    });

    test('de retirado a en camino no se repite el aviso', () {
      final batch = OrderNotificationRules.client(
        seed([order(1, 'RETIRADO')]),
        [order(1, 'EN_CAMINO')],
      );
      expect(batch.show, isEmpty);
    });

    test('rechazado y cancelado avisan con prioridad alta', () {
      for (final status in ['RECHAZADO', 'CANCELADO']) {
        final batch = OrderNotificationRules.client(
          seed([order(1, 'NUEVO_PEDIDO')]),
          [order(1, status)],
        );
        expect(batch.show.single.priority, NoticePriority.high, reason: status);
      }
    });

    test('si el código se renueva en camino, avisa sin mostrarlo', () {
      final batch = OrderNotificationRules.client(
        seed([order(1, 'EN_CAMINO', deliveryCode: '1111')]),
        [order(1, 'EN_CAMINO', deliveryCode: '2222')],
      );
      final n = batch.show.single;
      expect(n.title, 'Tu código de entrega cambió');
      expect(n.body, isNot(contains('2222')));
    });

    test('el estado guardado no contiene el código en claro', () {
      final state = seed([order(1, 'EN_CAMINO', deliveryCode: '4821')]);
      expect(jsonEncode(state), isNot(contains('4821')));
    });

    test('los ids de aviso son estables y no chocan con los fijos', () {
      final a = OrderNotificationRules.client(
        seed([order(1, 'NUEVO_PEDIDO')]),
        [order(1, 'PREPARANDO')],
      ).show.single.id;
      final b = OrderNotificationRules.client(
        seed([order(1, 'NUEVO_PEDIDO')]),
        [order(1, 'PREPARANDO')],
      ).show.single.id;
      expect(a, b);
      expect(a, greaterThanOrEqualTo(10000));
    });
  });
}
