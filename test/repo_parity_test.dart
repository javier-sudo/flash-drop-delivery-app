// Funciones portadas desde la rama main del repo: etapas del pedido, sesión,
// filtros de Mis pedidos y ruta por calles del mapa de seguimiento.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/orders/list/client_orders_list_widget.dart';
import 'package:proyecto_app_delivery_gessof/src/services/session_manager.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/order_status.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/map_tracking_osm.dart';

import 'helpers/test_app.dart';

void main() {
  setUpAll(initTestStorage);

  setUp(() {
    Get.reset();
    Get.testMode = true;
  });

  group('OrderStage', () {
    test('mapea los estados de Orders a las 5 etapas', () {
      expect(OrderStage.of('Nuevo pedido').step, 0);
      expect(OrderStage.of(null).step, 0);
      expect(OrderStage.of('Preparando').step, 1);
      expect(OrderStage.of('Listo para retiro').step, 2);
      expect(OrderStage.of('Asignado').step, 2);
      expect(OrderStage.of('Retirado').step, 3);
      expect(OrderStage.of('En camino').step, 3);
      expect(OrderStage.of('Entregado').isDelivered, isTrue);
      expect(OrderStage.of('Retirado').label, 'En camino');
      expect(OrderStage.labels, hasLength(5));
    });

    test('orderTime prefiere updatedAt y tolera fechas inválidas', () {
      expect(
        orderTime({
          'createdAt': '2026-10-01T10:00:00',
          'updatedAt': '2026-10-02T10:00:00',
        }),
        DateTime(2026, 10, 2, 10),
      );
      expect(orderTime({'created_at': '2026-10-01T10:00:00'}).day, 1);
      expect(orderTime({'createdAt': 'ayer'}), DateTime(0));
    });
  });

  group('SessionManager', () {
    // Se leen dentro de cada test: GetStorage necesita el setUpAll previo.
    late SessionManager session;
    late GetStorage storage;

    setUp(() {
      session = SessionManager.instance;
      storage = GetStorage();
    });

    test('guarda el perfil sin tokens y exige ambos tokens', () async {
      await session.saveAuthenticatedSession({
        'id': 7,
        'name': 'Ana',
        'accessToken': 'a',
        'refreshToken': 'r',
        'session_token': 'legacy',
      });
      final user = Map<String, dynamic>.from(storage.read('user') as Map);
      expect(user, {'id': 7, 'name': 'Ana'});

      expect(
        () => session.saveAuthenticatedSession({'id': 1, 'accessToken': 'a'}),
        throwsFormatException,
      );
    });

    test('cerrar sesión borra rol, dirección, ruta activa y tokens', () async {
      await session.saveAuthenticatedSession({
        'id': 7,
        'accessToken': 'a',
        'refreshToken': 'r',
      });
      for (final key in ['selected_role', 'delivery_address']) {
        await storage.write(key, 'x');
      }
      await storage.write('driver_active_orders', [1, 2]);

      await session.clearSession();

      for (final key in SessionManager.sessionKeys) {
        expect(storage.read(key), isNull, reason: key);
      }
      expect(await session.accessToken(), isNull);
      expect(await session.restoreSession(), isFalse);
    });
  });

  group('Mis pedidos', () {
    testWidgets('filtra entre todos, en curso y entregados', (tester) async {
      await pumpPage(
        tester,
        const Scaffold(body: ClientOrdersListWidget()),
        seed: true,
      );

      // Seed: 5 pedidos en curso y 1 entregado.
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('En curso · 5'), findsOneWidget);
      expect(find.text('Entregados · 1'), findsOneWidget);

      // La fuente de tests es más ancha que la real: el chip puede quedar
      // fuera del scroll horizontal.
      await tester.ensureVisible(find.text('Entregados · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entregados · 1'));
      await tester.pumpAndSettle();
      expect(find.text('Entregado'), findsWidgets);
      expect(find.text('Nuevo pedido'), findsNothing);

      await tester.ensureVisible(find.text('En curso · 5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('En curso · 5'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo pedido'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Ruta por calles (OSRM)', () {
    const from = LatLng(-33.43, -70.65);
    const to = LatLng(-33.42, -70.61);

    test('parseOsrmRoute convierte [lng, lat] y descarta basura', () {
      final route = parseOsrmRoute({
        'routes': [
          {
            'geometry': {
              'coordinates': [
                [-70.65, -33.43],
                [-70.63, -33.425],
                ['x', 1],
                [-70.61],
              ],
            },
          },
        ],
      });
      expect(route, [
        const LatLng(-33.43, -70.65),
        const LatLng(-33.425, -70.63),
      ]);
      expect(parseOsrmRoute({'routes': []}), isEmpty);
      expect(parseOsrmRoute('error'), isEmpty);
    });

    test('roadRoute pide geojson y devuelve [] si OSRM falla', () async {
      late Uri requested;
      final ok = MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'geometry': {
                  'coordinates': [
                    [-70.65, -33.43],
                    [-70.61, -33.42],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      expect(await roadRoute(from, to, client: ok), hasLength(2));
      expect(requested.host, 'router.project-osrm.org');
      expect(requested.path, contains('-70.65,-33.43;-70.61,-33.42'));
      expect(requested.queryParameters['geometries'], 'geojson');

      final down = MockClient((_) async => http.Response('fail', 500));
      expect(await roadRoute(from, to, client: down), isEmpty);
      final offline = MockClient((_) async => throw http.ClientException('x'));
      expect(await roadRoute(from, to, client: offline), isEmpty);
    });

    Future<void> pumpMap(WidgetTester tester, Widget map) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(height: 300, child: map)),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('sin ruta de OSRM avisa que el recorrido es estimado', (
      tester,
    ) async {
      await pumpMap(
        tester,
        MapTrackingWidget(
          pickupLocation: from,
          deliveryLocation: to,
          routeLoader: (_, _) async => const [],
        ),
      );
      expect(find.text('Mostrando recorrido estimado.'), findsOneWidget);
    });

    testWidgets('con ruta de OSRM no muestra avisos', (tester) async {
      await pumpMap(
        tester,
        MapTrackingWidget(
          pickupLocation: from,
          deliveryLocation: to,
          routeLoader: (a, b) async => [a, const LatLng(-33.425, -70.63), b],
        ),
      );
      expect(find.text('Mostrando recorrido estimado.'), findsNothing);
      expect(find.textContaining('No pudimos ubicar'), findsNothing);
    });

    testWidgets('dirección no encontrada: lo dice solo al terminar', (
      tester,
    ) async {
      await pumpMap(
        tester,
        const MapTrackingWidget(pickupLocation: from, resolving: true),
      );
      expect(find.textContaining('No pudimos ubicar'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await pumpMap(tester, const MapTrackingWidget(pickupLocation: from));
      expect(
        find.text('No pudimos ubicar una de las direcciones en el mapa.'),
        findsOneWidget,
      );
    });
  });
}
