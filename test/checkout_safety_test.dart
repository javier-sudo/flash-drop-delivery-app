import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/cart/cart_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/delivery/orders/list/delivery_orders_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'helpers/test_app.dart';

const product = {
  'id': 1,
  'restaurantId': 1,
  'name': 'Prueba',
  'price': 10000,
  'image': '',
  'categoryName': 'Comida',
};

class CheckoutApi extends AppProvider {
  final keys = <String?>[];
  double fee = 3200;
  bool quoteFails = false;
  @override
  Future<List<Map<String, dynamic>>> getProducts() async => [product];
  @override
  Future<List<Map<String, dynamic>>> getCoveredRestaurants({
    required double latitude,
    required double longitude,
  }) async => [
    {'id': 1, 'name': 'Local QA', 'address': '', 'open': true},
  ];
  @override
  Future<Map<String, dynamic>> quoteOrder({
    required List<Map<String, dynamic>> items,
    required double latitude,
    required double longitude,
  }) async {
    if (quoteFails) throw StateError('Sin cotizacion');
    final subtotal = 10000 * (items.single['quantity'] as int);
    return {'subtotal': subtotal, 'deliveryFee': fee, 'total': subtotal + fee};
  }

  @override
  Future<ResponseApi> createOrder({
    Object? productId,
    int quantity = 1,
    List<Map<String, dynamic>>? items,
    required String address,
    String paymentMethod = 'Tarjeta',
    String receptionMode = 'SEGURO',
    double? distanceKm,
    int? estimatedMinutes,
    double? latitude,
    double? longitude,
    String? commune,
    String? idempotencyKey,
  }) async {
    expect(paymentMethod, 'Tarjeta');
    keys.add(idempotencyKey);
    throw StateError('Respuesta perdida despues de enviar');
  }
}

class LockedRouteApi extends AppProvider {
  bool blocked = false;
  int routeLoads = 0;
  @override
  Future<List<Map<String, dynamic>>> getRestaurants() async => [];
  @override
  Future<List<Map<String, dynamic>>> getDeliveryRoutes() async {
    routeLoads++;
    return blocked
        ? []
        : [
            {
              'id': 42,
              'orderId': 78,
              'code': 'FD-78',
              'status': 'Retirado',
              'pickupAddress': '',
              'deliveryAddress': '',
            },
          ];
  }

  @override
  Future<ResponseApi> deliverOrder(Object id, String code) async {
    blocked = true;
    return ResponseApi(
      success: false,
      statusCode: 423,
      message: 'El pedido fue cancelado por intentos agotados.',
      remainingAttempts: 0,
    );
  }
}

void main() {
  setUpAll(initTestStorage);
  setUp(() async {
    Get.reset();
    Get.testMode = true;
    await GetStorage().erase();
    await GetStorage().write('delivery_address', {
      'address': 'Calle QA 123',
      'commune': 'Santiago',
      'lat': -33.45,
      'lng': -70.65,
    });
  });
  tearDown(Get.reset);

  Future<void> pumpCheckout(WidgetTester tester, CheckoutApi api) async {
    Get.put<AppProvider>(api);
    Get.put(CartController()).add(product);
    Get.put(CatalogController(provider: api));
    await tester.pumpWidget(const GetMaterialApp(home: CartPage()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'timeout preserves cart and reuses key until request content changes',
    (tester) async {
      final api = CheckoutApi();
      await pumpCheckout(tester, api);
      expect(find.text('Tarjeta al recibir'), findsNothing);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.textContaining('PEDIR AHORA'));
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }
      expect(api.keys.length, 2);
      expect(api.keys.first, isNotEmpty);
      expect(api.keys.last, api.keys.first);
      expect(Get.find<CartController>().count, 1);
      Get.find<CartController>().add(product);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('PEDIR AHORA'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(api.keys.length, 3);
      expect(api.keys.last, isNot(api.keys.first));
      expect(Get.find<CartController>().count, 2);
    },
  );

  testWidgets(
    'changed quote requires a new confirmation before creating the order',
    (tester) async {
      final api = CheckoutApi();
      await pumpCheckout(tester, api);
      expect(find.textContaining('PEDIR AHORA · \$13.200'), findsOneWidget);
      api.fee = 4200;
      await tester.tap(find.textContaining('PEDIR AHORA'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(api.keys, isEmpty);
      expect(find.textContaining('PEDIR AHORA · \$14.200'), findsOneWidget);
      expect(Get.find<CartController>().count, 1);
    },
  );

  testWidgets(
    'quote failure blocks checkout instead of falling back to a fixed fee',
    (tester) async {
      final api = CheckoutApi()..quoteFails = true;
      await pumpCheckout(tester, api);
      final button = find.widgetWithText(FilledButton, 'PEDIR AHORA · -');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(api.keys, isEmpty);
      api.quoteFails = false;
      await tester.ensureVisible(find.text('Reintentar cotización'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reintentar cotización'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PEDIR AHORA · \$13.200'), findsOneWidget);
    },
  );

  testWidgets(
    '423 reloads routes and removes the automatically cancelled delivery',
    (tester) async {
      final api = LockedRouteApi();
      Get.put<AppProvider>(api);
      await tester.pumpWidget(
        const GetMaterialApp(home: DeliveryOrdersListPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Entregar'), findsOneWidget);
      await tester.tap(find.text('Entregar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrega'));
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(api.blocked, isTrue);
      expect(api.routeLoads, greaterThanOrEqualTo(2));
      expect(find.text('Entregar'), findsNothing);
      expect(GetStorage().read('driver_active_orders'), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
