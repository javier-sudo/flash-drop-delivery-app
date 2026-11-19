import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/models/delivery_destination.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

import 'helpers/test_app.dart';

Map<String, dynamic> destination(double lat) => {
  'address': 'Calle de prueba 123',
  'commune': 'Providencia',
  'lat': lat,
  'lng': -70.66,
};

class CoverageProvider extends AppProvider {
  final replies = <double, Completer<List<Map<String, dynamic>>>>{};
  @override
  Future<List<Map<String, dynamic>>> getProducts() async => [
    {'id': 1, 'restaurantId': 1, 'name': 'Burger', 'categoryName': 'Comida'},
    {'id': 2, 'restaurantId': 2, 'name': 'Pizza', 'categoryName': 'Pizza'},
  ];
  @override
  Future<List<Map<String, dynamic>>> getCoveredRestaurants({
    required double latitude,
    required double longitude,
  }) => replies.putIfAbsent(latitude, () => Completer()).future;
}

void main() {
  setUpAll(initTestStorage);
  setUp(() async {
    Get.reset();
    await GetStorage().erase();
  });

  test(
    'destination requires a pin, commune and address; rejects non-finite coordinates',
    () {
      expect(DeliveryDestination.fromStorage(destination(-33.45)), isNotNull);
      for (final raw in [
        null,
        {},
        {...destination(-33.45), 'commune': ''},
        {...destination(-33.45), 'lat': null},
        destination(91),
        destination(double.nan),
      ]) {
        expect(DeliveryDestination.fromStorage(raw), isNull);
      }
    },
  );

  test('without a selected address the catalog stays empty', () async {
    final catalog = CatalogController(provider: CoverageProvider());
    await catalog.load();
    expect(catalog.needsAddress.value, isTrue);
    expect(catalog.products, isEmpty);
  });

  test('changing pin or commune creates a different destination', () {
    final selected = DeliveryDestination.fromStorage(destination(-33.45));
    expect(selected, DeliveryDestination.fromStorage(destination(-33.45)));
    expect(selected, isNot(DeliveryDestination.fromStorage(destination(-34))));
    expect(
      selected,
      isNot(
        DeliveryDestination.fromStorage({
          ...destination(-33.45),
          'commune': 'Santiago',
        }),
      ),
    );
  });

  test(
    'only covered stores contribute products, search and categories',
    () async {
      await GetStorage().write('delivery_address', destination(-33.45));
      final api = CoverageProvider();
      final catalog = CatalogController(provider: api);
      final loading = catalog.load();
      api.replies[-33.45]!.complete([
        {'id': 1, 'name': 'Local uno', 'deliveryRadiusKm': 5},
      ]);
      await loading;
      expect(catalog.restaurants.map((r) => r.id), [1]);
      expect(catalog.products.map((p) => p['id']), [1]);
      expect(catalog.searchProducts('Pizza'), isEmpty);
      expect(catalog.categories.map((c) => c.name), ['Comida']);
    },
  );

  test(
    'a late response for the old address cannot overwrite the new address',
    () async {
      final api = CoverageProvider();
      final catalog = CatalogController(provider: api);
      await GetStorage().write('delivery_address', destination(-33.45));
      final oldLoad = catalog.load();
      await GetStorage().write('delivery_address', destination(-34));
      final newLoad = catalog.load();
      api.replies[-34]!.complete([]);
      await newLoad;
      api.replies[-33.45]!.complete([
        {'id': 1, 'name': 'Old local'},
      ]);
      await oldLoad;
      expect(catalog.restaurants, isEmpty);
      expect(catalog.loading.value, isFalse);
    },
  );

  test(
    'provider sends coverage query and real destination in createOrder',
    () async {
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          final api = AppProvider();
          await api.getCoveredRestaurants(latitude: -33.45, longitude: -70.66);
          await api.createOrder(
            address: 'Calle de prueba 123',
            items: [
              {'product_id': 1, 'quantity': 1},
            ],
            latitude: -33.45,
            longitude: -70.66,
            commune: 'Providencia',
          );
        },
        () => MockClient((request) async {
          requests.add(request);
          return http.Response(
            request.method == 'GET' ? '[]' : '{"success":true,"data":{}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      expect(requests.first.url.queryParameters, {
        'latitude': '-33.45',
        'longitude': '-70.66',
      });
      final body = jsonDecode(requests.last.body) as Map;
      expect(body['latitude'], -33.45);
      expect(body['longitude'], -70.66);
      expect(body['commune'], 'Providencia');
    },
  );

  test(
    'failed coverage refresh never keeps the previous stores visible',
    () async {
      await GetStorage().write('delivery_address', destination(-33.45));
      final api = CoverageProvider();
      final catalog = CatalogController(provider: api);
      final firstLoad = catalog.load();
      api.replies[-33.45]!.complete([
        {'id': 1, 'name': 'Local'},
      ]);
      await firstLoad;
      expect(catalog.restaurants, isNotEmpty);

      await GetStorage().write('delivery_address', destination(-34));
      final secondLoad = catalog.load();
      expect(catalog.restaurants, isEmpty);
      api.replies[-34]!.completeError(Exception('offline'));
      await secondLoad;
      expect(catalog.products, isEmpty);
      expect(catalog.error.value, isNotNull);
      expect(catalog.loading.value, isFalse);
    },
  );
}
