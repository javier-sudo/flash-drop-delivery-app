import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/order_status.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/app_image.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/orders/list/restaurant_orders_list_page.dart';

void main() {
  test('rutas de catalogo se resuelven contra el gateway', () {
    expect(
      resolveImageSource('/catalog/images/test.png'),
      '${Environment.apiUrl}/catalog/images/test.png',
    );
    expect(
      resolveImageSource('catalog/images/test.png'),
      '${Environment.apiUrl}/catalog/images/test.png',
    );
    expect(resolveImageSource('assets/img/test.png'), 'assets/img/test.png');
    expect(
      resolveImageSource('https://example.com/test.png'),
      'https://example.com/test.png',
    );
    expect(resolveImageSource('//example.com/test.png'), isNull);
    expect(resolveImageSource(''), isNull);
  });

  test('cancelados y rechazados son terminales sin marcarse entregados', () {
    for (final value in ['Cancelado', 'Rechazado']) {
      final stage = OrderStage.of(value);
      expect(stage.isClosed, isTrue);
      expect(stage.isDelivered, isFalse);
      expect(stage.label.toLowerCase(), value.toLowerCase());
      expect(RestaurantOrderStatus.of(value).tab, RestaurantTab.closed);
    }
    expect(OrderStage.of('Nuevo pedido').isClosed, isFalse);
    expect(OrderStage.of('Entregado').isDelivered, isTrue);
  });
}
