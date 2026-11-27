import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/store_delivery_coverage_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

class StoreCoverageProvider extends AppProvider {
  final calls = <String>[];
  double? savedRadius;
  bool failRadius = false;
  bool failLoading = false;
  bool hasLocation = true;
  double? savedLatitude;
  double? savedLongitude;

  @override
  Future<Map<String, dynamic>> getMyRestaurant() async {
    if (failLoading) throw Exception('offline');
    return {
      'name': 'Local de prueba',
      'latitude': hasLocation ? -33.45 : null,
      'longitude': hasLocation ? -70.66 : null,
      'deliveryRadiusKm': 5,
    };
  }

  @override
  Future<Map<String, dynamic>> updateStoreLocation({
    required double latitude,
    required double longitude,
  }) async {
    calls.add('location');
    savedLatitude = latitude;
    savedLongitude = longitude;
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

class _LocationFake extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  int reads = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    reads++;
    return Position(
      latitude: -33.51,
      longitude: -70.74,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  final originalLocation = GeolocatorPlatform.instance;
  tearDown(() => GeolocatorPlatform.instance = originalLocation);
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

  testWidgets(
    'coordinates stay internal and an overview map is never saved as a store pin',
    (tester) async {
      final api = StoreCoverageProvider()..hasLocation = false;
      await open(tester, api);
      expect(find.text('Latitud del local'), findsNothing);
      expect(find.text('Longitud del local'), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.tap(find.text('Guardar zona'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
      expect(
        find.text('Marca la ubicación del local en el mapa antes de guardar.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(FlutterMap));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar zona'));
      await tester.pumpAndSettle();
      expect(api.savedLatitude, closeTo(-33.4372, 0.01));
      expect(api.savedLongitude, closeTo(-70.6506, 0.01));
      expect(api.calls, ['location', 'radius']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GPS requires a deliberate tap and never persists before saving',
    (tester) async {
      final gps = _LocationFake();
      GeolocatorPlatform.instance = gps;
      final api = StoreCoverageProvider()..hasLocation = false;
      await open(tester, api);
      expect(gps.reads, 0);
      await tester.ensureVisible(find.text('Usar mi ubicación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar mi ubicación'));
      await tester.pumpAndSettle();
      expect(gps.reads, 1);
      expect(api.calls, isEmpty);
      await tester.tap(find.text('Guardar zona'));
      await tester.pumpAndSettle();
      expect(api.savedLatitude, -33.51);
      expect(api.savedLongitude, -70.74);
    },
  );

  testWidgets('denied GPS retains manual map selection', (tester) async {
    final gps = _LocationFake()..permission = LocationPermission.deniedForever;
    GeolocatorPlatform.instance = gps;
    final api = StoreCoverageProvider()..hasLocation = false;
    await open(tester, api);
    await tester.ensureVisible(find.text('Usar mi ubicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar mi ubicación'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir ajustes'), findsOneWidget);
    expect(gps.reads, 0);
    expect(api.calls, isEmpty);
    await tester.ensureVisible(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Ubicación del local seleccionada'), findsOneWidget);
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
