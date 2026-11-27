import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/store_settings_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/restaurant_card.dart';

class StoreProvider extends AppProvider {
  bool accepting = true;
  bool fail = false;
  List<Map<String, dynamic>> hours = [];
  Map<String, dynamic> get data => {
    'name': 'Local',
    'open': accepting,
    'acceptingOrders': accepting,
    'hours': hours,
  };

  @override
  Future<Map<String, dynamic>> getMyRestaurant() async => data;
  @override
  Future<Map<String, dynamic>> updateMyRestaurantOpen(bool value) async {
    if (fail) throw Exception('error');
    accepting = value;
    return data;
  }

  @override
  Future<Map<String, dynamic>> updateMyRestaurantHours(
    List<Map<String, dynamic>> value,
  ) async {
    hours = value;
    return data;
  }
}

void main() {
  test('catalogo conserva abierto, cerrado y estado desconocido', () {
    final result = CatalogController.buildRestaurants(
      [
        {'id': 1, 'name': 'Abierto', 'open': true},
        {'id': 2, 'name': 'Cerrado', 'open': false},
        {'id': 3, 'name': 'Desconocido'},
      ],
      [
        {'restaurantId': 1, 'categoryName': 'A'},
        {'restaurantId': 2, 'categoryName': 'A'},
        {'restaurantId': 3, 'categoryName': 'A'},
      ],
    );
    expect(result.map((r) => r.isOpen), [true, false, null]);
  });

  testWidgets('la tarjeta identifica un local cerrado', (tester) async {
    final restaurant = RestaurantView(
      id: 1,
      name: 'Local',
      address: '',
      products: [],
      isOpen: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoreRow(restaurant: restaurant, onTap: () {}),
        ),
      ),
    );
    expect(find.text('Cerrado'), findsOneWidget);
  });

  testWidgets('el comercio cambia disponibilidad y guarda horarios', (
    tester,
  ) async {
    final provider = StoreProvider()
      ..hours = [
        {'day': 1, 'opensAt': '22:00', 'closesAt': '02:00'},
      ];
    await tester.pumpWidget(
      MaterialApp(home: StoreSettingsPage(provider: provider)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lunes'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(provider.accepting, false);
    expect(find.text('Local cerrado'), findsOneWidget);
    await tester.tap(find.text('Guardar horarios'));
    await tester.pumpAndSettle();
    expect(provider.hours.single['closesAt'], '02:00');
  });

  testWidgets('si falla el cambio se mantiene la disponibilidad anterior', (
    tester,
  ) async {
    final provider = StoreProvider()..fail = true;
    await tester.pumpWidget(
      MaterialApp(home: StoreSettingsPage(provider: provider)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(provider.accepting, true);
    expect(find.text('No se pudo cambiar la disponibilidad.'), findsOneWidget);
  });
}
