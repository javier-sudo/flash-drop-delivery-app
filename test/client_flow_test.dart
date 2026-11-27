import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/products/list/client_products_list_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

import 'helpers/test_app.dart';

void main() {
  setUpAll(initTestStorage);

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    await GetStorage().write('delivery_address', {
      'address': 'Av. Providencia 2000, Providencia',
      'lat': -33.45,
      'lng': -70.66,
      'commune': 'Providencia',
    });
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
    expect(find.text('Comercios cerca de ti'), findsOneWidget);
    expect(find.text('Hamburguesas'), findsWidgets);
    expect(find.text('FLASH CLUB'), findsNothing);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('elegir una categoría filtra los comercios y se puede quitar', (
    tester,
  ) async {
    await pumpClientHome(tester);
    await tester.tap(find.text('Pizzas').first);
    await tester.pumpAndSettle();
    expect(find.text('Pizzas cerca de ti'), findsOneWidget);
    expect(find.text('Pizza Norte'), findsWidgets);
    expect(find.text('Sushi Kento'), findsNothing);

    await tester.tap(find.text('Quitar filtro'));
    await tester.pumpAndSettle();
    expect(find.text('Comercios cerca de ti'), findsOneWidget);
  });

  testWidgets('Buscar muestra comercios y productos que coinciden', (
    tester,
  ) async {
    await pumpClientHome(tester);
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Búsquedas populares'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'burger');
    await tester.pumpAndSettle();
    expect(find.text('Comercios'), findsOneWidget);
    expect(find.text('Urban Burger'), findsWidgets);
    expect(find.text('Burger doble'), findsOneWidget);
    expect(find.textContaining('Productos ('), findsOneWidget);
  });

  testWidgets('abrir un restaurante y agregar un producto llena el carrito', (
    tester,
  ) async {
    await pumpClientHome(tester);

    await tester.ensureVisible(find.text('Urban Burger').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Urban Burger').first);
    await tester.pumpAndSettle();
    expect(find.text('Burger doble'), findsOneWidget);
    expect(find.text('Calificación'), findsOneWidget);

    await tester.tap(find.text('Burger doble'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar al pedido'), findsOneWidget);

    await tester.tap(find.byTooltip('Agregar uno'));
    await tester.pump();
    await tester.tap(find.text('Agregar al pedido'));
    await tester.pumpAndSettle();

    final cart = Get.find<CartController>();
    expect(cart.count, 2);
    expect(cart.subtotal, 8990 * 2);
    expect(find.text('Ver carrito'), findsOneWidget);

    // El selector de la tarjeta suma y resta sin abrir el detalle.
    await tester.ensureVisible(find.byTooltip('Sumar uno').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sumar uno').first);
    await tester.pump();
    expect(cart.count, 3);
    await tester.tap(find.byTooltip('Restar uno').first);
    await tester.pump();
    expect(cart.count, 2);
  });

  testWidgets('el carrito vacío invita a explorar comercios', (tester) async {
    await pumpClientHome(tester);
    await tester.tap(find.text('Carrito'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no agregas nada'), findsOneWidget);

    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();
    expect(find.text('Comercios cerca de ti'), findsOneWidget);
  });

  testWidgets('sin dirección pide seleccionarla antes de mostrar el catálogo', (
    tester,
  ) async {
    await GetStorage().remove('delivery_address');
    await pumpClientHome(tester);
    expect(find.text('Elegir direccion'), findsOneWidget);
    expect(find.text('Urban Burger'), findsNothing);
  });

  testWidgets(
    'cambiar a una dirección sin cobertura conserva el carrito y bloquea la compra',
    (tester) async {
      final provider = await pumpClientHome(tester);
      await tester.ensureVisible(find.text('Urban Burger').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Urban Burger').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Burger doble'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar al pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver carrito'));
      await tester.pumpAndSettle();

      provider.coveredRestaurantIds = {};
      await GetStorage().write('delivery_address', {
        'address': 'Direccion lejana 123',
        'commune': 'Maipu',
        'lat': -34.0,
        'lng': -70.7,
      });
      await tester.pumpAndSettle();

      final button = find.widgetWithText(
        FilledButton,
        'SIN COBERTURA PARA ESTA DIRECCION',
      );
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(Get.find<CartController>().count, 1);
      expect(provider.lastOrderItems, isNull);
      expect(Get.find<CatalogController>().products, isEmpty);

      // Returning to discovery also offers a way to change the address.
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Sin comercios con cobertura'), findsOneWidget);
      expect(find.text('Cambiar direccion'), findsOneWidget);
    },
  );

  testWidgets(
    'confirmar el pedido envía los ítems, vacía el carrito y abre Mis pedidos',
    (tester) async {
      await GetStorage().write('delivery_address', {
        'address': 'Direccion anterior, Maipu',
        'lat': -33.5,
        'lng': -70.7,
        'commune': 'Maipu',
      });
      final provider = await pumpClientHome(tester);
      await tester.ensureVisible(find.text('Urban Burger').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Urban Burger').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Burger doble'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar al pedido'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver carrito'));
      await tester.pumpAndSettle();
      expect(find.text('Tu carrito'), findsOneWidget);
      expect(find.text('PIN obligatorio para la entrega'), findsOneWidget);

      // Address text is read-only: the selected pin and commune travel together.
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.tap(find.textContaining('PEDIR AHORA'));
      // Geocoder (sin plugin en tests) + latencia demo + navegación.
      await tester.pumpAndSettle(const Duration(seconds: 6));

      expect(provider.lastOrderItems, [
        {'product_id': 101, 'quantity': 1},
      ]);
      expect(provider.lastReceptionMode, 'SEGURO');
      final savedAddress = GetStorage().read('delivery_address') as Map;
      expect(savedAddress['address'], 'Direccion anterior, Maipu');
      expect(savedAddress['lat'], -33.5);
      expect(savedAddress['lng'], -70.7);
      expect(provider.lastLatitude, -33.5);
      expect(provider.lastLongitude, -70.7);
      expect(provider.lastCommune, 'Maipu');
      expect(Get.find<CartController>().count, 0);
      expect(find.text('Mis pedidos'), findsWidgets);
      expect(find.textContaining('Urban Burger'), findsWidgets);
      expect(find.text('¡Pedido confirmado!'), findsWidgets);
      expect(find.text('Nuevo pedido'), findsOneWidget);
    },
  );
}
