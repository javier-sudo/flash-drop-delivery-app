import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/services/local_notifications_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/notifications/order_notification_rules.dart';

void main() {
  group('payload del aviso', () {
    test('abre el seguimiento del pedido', () {
      final target = LocalNotificationsService.parsePayload(
        '{"route":"/client/orders/tracking","orderId":"12"}',
      );
      expect(target?.route, '/client/orders/tracking');
      expect(target?.orderId, '12');
    });

    test('la lista del repartidor no necesita pedido', () {
      final target = LocalNotificationsService.parsePayload(
        '{"route":"/delivery/orders/list"}',
      );
      expect(target?.route, '/delivery/orders/list');
      expect(target?.orderId, isNull);
    });

    test('rechaza rutas fuera de las pantallas de pedidos', () {
      for (final payload in [
        '{"route":"/roles"}',
        '{"route":"/client/orders/tracking"}',
        '{"route":1}',
        '[]',
        'no es json',
        '',
        null,
      ]) {
        expect(
          LocalNotificationsService.parsePayload(payload),
          isNull,
          reason: '$payload',
        );
      }
    });
  });

  group('detalles de Android', () {
    OrderNotice notice({
      NoticeChannel channel = NoticeChannel.newOrders,
      NoticePriority priority = NoticePriority.high,
      bool alert = true,
    }) => OrderNotice(
      id: 1,
      channel: channel,
      priority: priority,
      alert: alert,
      title: 't',
      body: 'b',
      route: '/delivery/orders/list',
    );

    test('el aviso agrupado actualizado no vuelve a sonar', () {
      final d = LocalNotificationsService.androidDetailsFor(
        notice(alert: false),
      );
      expect(d.onlyAlertOnce, isTrue);
      expect(d.silent, isTrue);
      expect(d.channelId, 'flashdrop_new_orders');
    });

    test('un aviso nuevo suena con prioridad alta', () {
      final d = LocalNotificationsService.androidDetailsFor(notice());
      expect(d.silent, isFalse);
      expect(d.priority, Priority.high);
    });

    test('los avisos silenciosos del cliente van en su canal sin sonar', () {
      final d = LocalNotificationsService.androidDetailsFor(
        notice(
          channel: NoticeChannel.myOrders,
          priority: NoticePriority.silent,
        ),
      );
      expect(d.channelId, 'flashdrop_my_orders');
      expect(d.silent, isTrue);
      expect(d.importance, Importance.low);
    });
  });
}
