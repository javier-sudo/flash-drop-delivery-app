import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/products/list/client_products_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

import 'helpers/test_app.dart';

void main() {
  setUpAll(initTestStorage);

  setUp(() {
    Get.reset();
    Get.testMode = true;
  });

  Future<FakeProvider> pumpClientHome(WidgetTester tester) async {
    // El catálogo se registra dentro del test (reloj simulado) y antes de la
    // página, para que use el provider falso.
    return pumpPage(
      tester,
      Builder(
        builder: (_) {
          if (!Get.isRegistered<CatalogController>()) {
            Get.put(
              CatalogController(provider: Get.find<AppProvider>()),
              permanent: true,
            );
          }
          return ClientProductsListPage();
        },
      ),
    );
  }

  testWidgets('Inicio muestra restaurantes y categorías del catálogo', (
    tester,
  ) async {
    await pumpClientHome(tester);
    expect(find.text('Urban Burger'), findsWidgets);
    expect(find.text('¿Qué se te antoja?'), findsOneWidget);
    expect(find.text('Hamburguesas'), findsWidgets);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('abrir un restaurante y agregar un producto llena el carrito', (
    tester,
  ) async {
    await pumpClientHome(tester);

    await tester.tap(find.text('Urban Burger').first);
    await tester.pumpAndSettle();
    expect(find.text('BURGER DOBLE'), findsOneWidget);

    await tester.tap(find.text('BURGER DOBLE'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar al pedido'), findsOneWidget);

    await tester.tap(find.byTooltip('Agregar uno'));
    await tester.pump();
    await tester.tap(find.text('Agregar al pedido'));
    await tester.pumpAndSettle();

    final cart = Get.find<CartController>();
    expect(cart.count, 2);
    expect(cart.subtotal, 8990 * 2);
    expect(find.text('Ver pedido'), findsOneWidget);
  });

  testWidgets(
    'confirmar el pedido envía los ítems, vacía el carrito y abre Mis pedidos',
    (tester) async {
      final provider = await pumpClientHome(tester);
      await tester.tap(find.text('Urban Burger').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BURGER DOBLE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar al pedido'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver pedido'));
      await tester.pumpAndSettle();
      expect(find.text('Tu pedido'), findsOneWidget);
      expect(find.text('PIN obligatorio para la entrega'), findsOneWidget);

      // Dirección demasiado corta: no debe enviar el pedido.
      await tester.tap(find.textContaining('Confirmar pedido'));
      await tester.pump();
      expect(provider.lastOrderItems, isNull);
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.enterText(
        find.byType(TextField),
        'Av. Providencia 2000, Providencia',
      );
      await tester.tap(find.textContaining('Confirmar pedido'));
      // Geocoder (sin plugin en tests) + latencia demo + navegación.
      await tester.pumpAndSettle(const Duration(seconds: 6));

      expect(provider.lastOrderItems, [
        {'product_id': 101, 'quantity': 1},
      ]);
      expect(provider.lastReceptionMode, 'SEGURO');
      expect(Get.find<CartController>().count, 0);
      expect(find.text('Mis pedidos'), findsWidgets);
      expect(find.text('Urban Burger'), findsWidgets);
      expect(find.text('Nuevo pedido'), findsOneWidget);
    },
  );
}
