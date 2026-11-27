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
  Object? deliveryId,
}) => {
  'orderId': id,
  'status': status,
  if (code != null) 'code': code,
  if (restaurant != null) 'restaurantName': restaurant,
  if (deliveryCode != null) 'deliveryCode': deliveryCode,
  if (receptionMode != null) 'receptionMode': receptionMode,
  'deliveryId': deliveryId,
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
        order(2, 'Preparando'),
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
      expect(summary.title, '3 pedidos por preparar');
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

    test('un pedido nuevo ya pagado en Preparando avisa con sonido', () {
      final state = persist(OrderNotificationRules.store(null, []));
      final batch = OrderNotificationRules.store(state, [
        order(9, 'Preparando', code: 'FD-9'),
      ]);
      expect(batch.show.single.title, 'Nuevo pedido FD-9');
      expect(batch.show.single.alert, isTrue);
      expect(batch.show.single.body, isNot(contains('confirmación')));
    });

    test('aprobar un pago pendiente avisa una sola vez a la tienda', () {
      for (final pending in ['Pendiente de pago', 'PENDIENTE_PAGO']) {
        final state = persist(
          OrderNotificationRules.store(null, [order(9, pending)]),
        );
        final batch = OrderNotificationRules.store(state, [
          order(9, 'Preparando'),
        ]);
        expect(batch.show, hasLength(1));
        expect(batch.show.single.alert, isTrue);
        final repeated = OrderNotificationRules.store(persist(batch), [
          order(9, 'Preparando'),
        ]);
        expect(repeated.show, isEmpty);
      }
    });

    test('un pedido sin pagar no avisa ni aumenta el resumen', () {
      final state = persist(OrderNotificationRules.store(null, []));
      final batch = OrderNotificationRules.store(state, [
        order(1, 'Pendiente de pago'),
        order(2, 'PENDIENTE_PAGO'),
        order(3, 'Pendiente de pago'),
      ]);
      expect(batch.show, isEmpty);
    });

    test('el resumen incluye los pedidos pagados en Preparando', () {
      final state = persist(OrderNotificationRules.store(null, []));
      final batch = OrderNotificationRules.store(state, [
        order(1, 'Preparando'),
        order(2, 'Preparando'),
        order(3, 'Preparando'),
      ]);
      expect(batch.show.where((n) => !n.isGroupSummary), hasLength(3));
      final summary = batch.show.where((n) => n.isGroupSummary).single;
      expect(summary.title, '3 pedidos por preparar');
      expect(summary.alert, isFalse);
    });

    test(
      'al dejarlo listo quita el aviso del pedido recibido en Preparando',
      () {
        final received = OrderNotificationRules.store(
          persist(OrderNotificationRules.store(null, [])),
          [order(9, 'Preparando')],
        );
        final ready = OrderNotificationRules.store(persist(received), [
          order(9, 'Listo para retiro'),
        ]);
        expect(ready.show, isEmpty);
        expect(ready.cancel, contains(received.show.single.id));
      },
    );
  });

  group('tienda: asignacion de repartidor', () {
    Map<String, dynamic> seed(List<Map<String, dynamic>> orders) =>
        persist(OrderNotificationRules.store(null, orders));

    test('avisa una vez aunque tomar el pedido no cambie su estado', () {
      final ready = order(78, 'Listo para retiro', code: 'FD-78');
      final assigned = {...ready, 'deliveryId': 12};
      final batch = OrderNotificationRules.store(seed([ready]), [assigned]);
      final notice = batch.show.single;
      expect(notice.title, 'Repartidor asignado a FD-78');
      expect(notice.alert, isTrue);
      expect(notice.priority, NoticePriority.high);
      expect(notice.route, '/restaurant/orders/list');
      expect(notice.orderId, '78');
      expect(notice.payload, isNot(contains('deliveryId')));
      final repeated = OrderNotificationRules.store(persist(batch), [assigned]);
      expect(repeated.show, isEmpty);
      expect(repeated.state['assignments'], {'78': '12'});
    });

    test('primera consulta no avisa de asignaciones antiguas', () {
      final batch = OrderNotificationRules.store(null, [
        order(78, 'Listo para retiro', deliveryId: 12),
      ]);
      expect(batch.show, isEmpty);
    });

    test(
      'actualizar desde un APK sin historial de asignaciones solo crea la base',
      () {
        final batch = OrderNotificationRules.store(
          {
            'statuses': {'78': 'Listo para retiro'},
          },
          [order(78, 'Listo para retiro', deliveryId: 12)],
        );
        expect(batch.show, isEmpty);
        expect(batch.state['assignments'], {'78': '12'});
      },
    );

    test(
      'no anuncia asignaciones en pedidos terminados ni estados anteriores al retiro',
      () {
        for (final status in [
          'Entregado',
          'Cancelado',
          'Rechazado',
          'Preparando',
          'Nuevo pedido',
          'Pendiente de pago',
        ]) {
          final batch = OrderNotificationRules.store(
            seed([order(78, 'Listo para retiro')]),
            [order(78, status, deliveryId: 12)],
          );
          expect(
            batch.show.where((n) => n.title.startsWith('Repartidor asignado')),
            isEmpty,
            reason: status,
          );
        }
      },
    );

    test('soltar cancela el aviso y volver a tomar permite un nuevo aviso', () {
      final ready = order(78, 'Listo para retiro');
      final assigned = {...ready, 'deliveryId': 12};
      final first = OrderNotificationRules.store(seed([ready]), [assigned]);
      final released = OrderNotificationRules.store(persist(first), [ready]);
      expect(released.show, isEmpty);
      expect(released.cancel, contains(first.show.single.id));
      final again = OrderNotificationRules.store(persist(released), [assigned]);
      expect(again.show.single.id, first.show.single.id);
      expect(again.show.single.alert, isTrue);
    });

    test(
      'un cambio de repartidor asignado se anuncia sin duplicar el pedido',
      () {
        final batch = OrderNotificationRules.store(
          seed([order(78, 'Listo para retiro', deliveryId: 12)]),
          [order(78, 'Listo para retiro', deliveryId: 13)],
        );
        expect(batch.show, hasLength(1));
        expect(batch.show.single.title, startsWith('Repartidor asignado'));
      },
    );

    test(
      'si el sondeo alcanza a verlo retirado igualmente detecta la toma',
      () {
        final batch = OrderNotificationRules.store(
          seed([order(78, 'Listo para retiro')]),
          [
            order(
              78,
              'Retirado',
              deliveryId: '00000000-0000-0000-0000-000000000012',
            ),
          ],
        );
        expect(batch.show.single.title, startsWith('Repartidor asignado'));
      },
    );

    test('valores de asignacion vacios o nulos no generan avisos', () {
      for (final raw in [
        null,
        '',
        ' ',
        0,
        '0',
        -1,
        'null',
        '00000000-0000-0000-0000-000000000000',
      ]) {
        final batch = OrderNotificationRules.store(
          seed([order(78, 'Listo para retiro')]),
          [order(78, 'Listo para retiro', deliveryId: raw)],
        );
        expect(batch.show, isEmpty, reason: '$raw');
      }
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
