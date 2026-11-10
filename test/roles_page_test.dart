import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/data/demo_data.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/roles/roles_page.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';

import 'helpers/test_app.dart';

void main() {
  setUpAll(initTestStorage);

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    await GetStorage().write('user', DemoData.user());
  });

  Future<void> pumpRoles(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        initialRoute: '/roles',
        getPages: [
          GetPage(name: '/roles', page: () => RolesPage()),
          GetPage(
            name: '/restaurant/orders/list',
            page: () => const Scaffold(body: Text('Vista local')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('teléfono: saludo, tres perfiles apilados y sus funciones', (
    tester,
  ) async {
    await pumpRoles(tester, const Size(390, 844));

    expect(find.text('Hola, Javier'), findsOneWidget);
    expect(find.text('Elige tu perfil'), findsOneWidget);
    for (final role in ['Cliente', 'Restaurante', 'Repartidor']) {
      expect(find.text(role), findsOneWidget);
      expect(find.text('Entrar como $role'), findsOneWidget);
    }
    expect(find.text('Mapa de ruta'), findsOneWidget);

    // Apiladas: cada tarjeta queda debajo de la anterior.
    final cliente = tester.getTopLeft(find.text('Cliente'));
    final local = tester.getTopLeft(find.text('Restaurante'));
    expect(local.dy, greaterThan(cliente.dy));
    expect(local.dx, cliente.dx);
  });

  testWidgets('escritorio: los perfiles se muestran en tres columnas', (
    tester,
  ) async {
    await pumpRoles(tester, const Size(1440, 900));

    final cliente = tester.getTopLeft(find.text('Cliente'));
    final local = tester.getTopLeft(find.text('Restaurante'));
    final rider = tester.getTopLeft(find.text('Repartidor'));
    expect(local.dy, cliente.dy);
    expect(rider.dx, greaterThan(local.dx));
  });

  testWidgets('elegir un perfil guarda el rol y abre su vista', (tester) async {
    await pumpRoles(tester, const Size(390, 844));

    // En un teléfono la segunda tarjeta queda bajo el pliegue.
    await tester.ensureVisible(find.text('Entrar como Restaurante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar como Restaurante'));
    await tester.pumpAndSettle();

    expect(find.text('Vista local'), findsOneWidget);
    expect((GetStorage().read('selected_role') as Map)['name'], 'Restaurante');
  });

  test('RoleStyle asigna funciones por rol', () {
    expect(RoleStyle.of('Repartidor').features, contains('Historial'));
    expect(RoleStyle.of('Restaurante').features, contains('Pedidos entrantes'));
    expect(RoleStyle.of('Otro').features, contains('Seguimiento'));
    expect(RoleStyle.of('Cliente').image, 'assets/img/role_client.png');
    expect(RoleStyle.of('Restaurante').image, 'assets/img/role_restaurant.png');
    expect(RoleStyle.of('Repartidor').image, 'assets/img/role_rider.png');
    for (final role in ['Cliente', 'Restaurante', 'Repartidor']) {
      expect(File(RoleStyle.of(role).image).existsSync(), isTrue);
    }
  });
}
