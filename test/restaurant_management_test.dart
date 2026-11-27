import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/products_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/sales_summary_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

class RestaurantManagementFake extends AppProvider {
  Map<String, dynamic>? saved;
  Object? savedId;
  Object? disabledId;
  String? requestedRange;
  @override
  Future<List<Map<String, dynamic>>> getMyProducts() async => [
    {
      'id': 10,
      'categoryId': 3,
      'name': 'Pizza',
      'description': 'Queso',
      'price': 5000,
      'image': 'products/2026/11/550e8400-e29b-41d4-a716-446655440000.jpg',
      'available': true,
      'dimension': 4,
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> getCategories() async => [
    {'id': 3, 'name': 'Comida'},
  ];
  @override
  Future<void> saveMyProduct(Map<String, dynamic> product, {Object? id}) async {
    saved = product;
    savedId = id;
  }

  @override
  Future<void> deactivateMyProduct(Object id) async {
    disabledId = id;
  }

  @override
  Future<Map<String, dynamic>> getMyRestaurant() async => {'id': 2};
  @override
  Future<Map<String, dynamic>> getSalesSummary(
    Object restaurantId,
    String range,
  ) async {
    requestedRange = range;
    return {
      'totalOrders': 3,
      'totalRevenue': 12000,
      'averageTicket': 4000,
      'topProducts': [
        {'productName': 'Pizza', 'quantitySold': 3, 'revenue': 12000},
      ],
    };
  }
}

void main() {
  testWidgets('crear producto valida nombre y precio antes de guardar', (
    tester,
  ) async {
    final api = RestaurantManagementFake();
    await tester.pumpWidget(
      MaterialApp(home: RestaurantProductsPage(provider: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Producto'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar producto'));
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();
    expect(api.saved, isNull);
    expect(find.text('Selecciona una categoría.'), findsOneWidget);
  });
  testWidgets('editar producto conserva la clave de imagen y la categoría', (
    tester,
  ) async {
    final api = RestaurantManagementFake();
    await tester.pumpWidget(
      MaterialApp(home: RestaurantProductsPage(provider: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pizza'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar producto'));
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();
    expect(api.savedId, 10);
    expect(api.saved?['categoryId'], 3);
    expect(api.saved?['dimension'], 4);
    expect(
      api.saved?['image'],
      'products/2026/11/550e8400-e29b-41d4-a716-446655440000.jpg',
    );
  });

  testWidgets('desactivar producto requiere confirmación', (tester) async {
    final api = RestaurantManagementFake();
    await tester.pumpWidget(
      MaterialApp(home: RestaurantProductsPage(provider: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Desactivar'));
    await tester.pumpAndSettle();
    expect(api.disabledId, isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();
    expect(api.disabledId, 10);
  });

  testWidgets('ventas consulta el periodo seleccionado', (tester) async {
    final api = RestaurantManagementFake();
    await tester.pumpWidget(MaterialApp(home: SalesSummaryPage(provider: api)));
    await tester.pumpAndSettle();
    expect(api.requestedRange, 'week');
    expect(find.text('Pizza'), findsOneWidget);
    await tester.tap(find.text('24 h'));
    await tester.pumpAndSettle();
    expect(api.requestedRange, 'day');
  });
}
