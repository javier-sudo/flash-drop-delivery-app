import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/orders/list/restaurant_orders_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'helpers/test_app.dart';

class StoreCourierApi extends FakeProvider {
  bool assigned = false;

  @override
  Future<Map<String, dynamic>> getMyRestaurant() async => {
    'id': 1,
    'name': 'Local QA',
    'open': true,
    'acceptingOrders': true,
  };

  @override
  Future<List<Map<String, dynamic>>> getOrders({String? view}) async => [
    {
      'id': 78,
      'code': 'FD-78',
      'status': 'Listo para retiro',
      'clientName': 'Cliente QA',
      'total': 9300,
      'deliveryId': assigned ? 12 : null,
    },
  ];
}

void main() {
  setUpAll(initTestStorage);
  setUp(() {
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  testWidgets('store sees courier assignment without changing ready status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = StoreCourierApi();
    Get.put<AppProvider>(api);
    await tester.pumpWidget(
      const GetMaterialApp(home: RestaurantOrdersListPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin asignar'), findsOneWidget);
    expect(find.text('Listo para retiro'), findsOneWidget);
    api.assigned = true;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('Asignado'), findsOneWidget);
    expect(find.text('Sin asignar'), findsNothing);
    expect(find.text('Listo para retiro'), findsOneWidget);
    expect(find.text('Retirado'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
