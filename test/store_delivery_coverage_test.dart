import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/store_delivery_coverage_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

class StoreCoverageProvider extends AppProvider {
  final calls = <String>[];
  double? savedRadius;
  bool failRadius = false;
  bool failLoading = false;

  @override
  Future<Map<String, dynamic>> getMyRestaurant() async {
    if (failLoading) throw Exception('offline');
    return {
      'name': 'Local de prueba',
      'latitude': -33.45,
      'longitude': -70.66,
      'deliveryRadiusKm': 5,
    };
  }

  @override
  Future<Map<String, dynamic>> updateStoreLocation({
    required double latitude,
    required double longitude,
  }) async {
    calls.add('location');
    return {};
  }

  @override
  Future<Map<String, dynamic>> updateStoreDeliveryRadius(
    double radiusKm,
  ) async {
    calls.add('radius');
    if (failRadius) throw Exception('offline');
    savedRadius = radiusKm;
    return {'deliveryRadiusKm': radiusKm};
  }
}

void main() {
  setUp(() {
    Get.reset();
  });

  Future<void> open(WidgetTester tester, StoreCoverageProvider api) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(home: StoreDeliveryCoveragePage(provider: api)),
    );
    await tester.pump();
  }

  testWidgets('merchant selects 10 km and saves location before radius', (
    tester,
  ) async {
    final api = StoreCoverageProvider();
    await open(tester, api);
    await tester.ensureVisible(find.text('10 km'));
    await tester.tap(find.text('10 km'));
    await tester.ensureVisible(find.text('Guardar zona'));
    await tester.tap(find.text('Guardar zona'));
    await tester.pump();
    expect(api.savedRadius, 10);
    expect(api.calls, ['location', 'radius']);
    expect(find.text('Zona de despacho guardada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid radius never sends configuration', (tester) async {
    final api = StoreCoverageProvider();
    await open(tester, api);
    final radius = find.widgetWithText(TextFormField, 'Radio de despacho');
    await tester.ensureVisible(radius);
    await tester.enterText(radius, '51');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.ensureVisible(find.text('Guardar zona'));
    await tester.tap(find.text('Guardar zona'));
    await tester.pump();
    expect(find.text('Entre 1 y 50 km, hasta 2 decimales'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('partial save reports failure and permits retry', (tester) async {
    final api = StoreCoverageProvider()..failRadius = true;
    await open(tester, api);
    await tester.ensureVisible(find.text('Guardar zona'));
    await tester.tap(find.text('Guardar zona'));
    await tester.pump();
    expect(
      find.text(
        'Ubicacion guardada, pero no se pudo guardar el radio. Reintenta.',
      ),
      findsOneWidget,
    );
    expect(api.savedRadius, isNull);
    api.failRadius = false;
    await tester.pumpAndSettle();
    final retry = find.text('Guardar zona', skipOffstage: false);
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pump();
    expect(api.savedRadius, 5);
  });

  testWidgets(
    'failed load can be retried without losing access to the screen',
    (tester) async {
      final api = StoreCoverageProvider()..failLoading = true;
      await open(tester, api);
      expect(
        find.text('No se pudo cargar la zona de despacho.'),
        findsOneWidget,
      );
      api.failLoading = false;
      await tester.tap(find.text('Recargar'));
      await tester.pump();
      expect(find.text('Local de prueba'), findsOneWidget);
    },
  );
}
