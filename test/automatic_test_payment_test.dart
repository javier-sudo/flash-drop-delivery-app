import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/cart/cart_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_shell_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/orders/payment_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/test_payment.dart';
import 'checkout_safety_test.dart' show CheckoutApi, product;
import 'helpers/test_app.dart';

class AutomaticPaymentApi extends CheckoutApi {
  Map<String, dynamic> payment = {
    'orderStatus': 'Pendiente de pago',
    'paymentStatus': 'PENDIENTE',
    'paymentUrl': 'fake://flashdrop-pay/fake-123',
    'paymentExpiresAt': DateTime.now()
        .add(const Duration(minutes: 10))
        .toIso8601String(),
  };
  int approvals = 0;
  int reads = 0;
  int creates = 0;
  bool failResolution = false;
  bool failReadAfterApproval = false;
  bool activateOrder = true;
  Completer<void>? resolutionGate;

  @override
  Future<Map<String, dynamic>> getPayment(Object id) async {
    expect(id, 78);
    reads++;
    if (failReadAfterApproval && approvals > 0) throw StateError('Sin red');
    return Map.of(payment);
  }

  @override
  Future<Map<String, dynamic>> resolveTestPayment(
    String transactionId,
    bool approved,
  ) async {
    expect(transactionId, 'fake-123');
    expect(approved, isTrue);
    approvals++;
    if (resolutionGate != null) await resolutionGate!.future;
    if (failResolution) throw StateError('Respuesta perdida');
    if (activateOrder) {
      payment = {
        ...payment,
        'paymentStatus': 'APROBADO',
        'orderStatus': 'Nuevo pedido',
      };
    }
    return {'result': activateOrder ? 'ORDER_ACTIVATED' : 'ORDER_NOT_PENDING'};
  }

  @override
  Future<ResponseApi> createOrder({
    Object? productId,
    int quantity = 1,
    List<Map<String, dynamic>>? items,
    required String address,
    String paymentMethod = 'Tarjeta',
    String receptionMode = 'SEGURO',
    double? distanceKm,
    int? estimatedMinutes,
    double? latitude,
    double? longitude,
    String? commune,
    String? idempotencyKey,
  }) async {
    expect(paymentMethod, 'Tarjeta');
    expect(idempotencyKey, isNotEmpty);
    creates++;
    return ResponseApi(
      success: true,
      data: {
        'id': 78,
        'status': 'Pendiente de pago',
        'paymentUrl': payment['paymentUrl'],
        'total': 13200,
      },
    );
  }
}

Widget paymentApp(AutomaticPaymentApi api, {bool automatic = true}) =>
    GetMaterialApp(
      getPages: [
        GetPage(
          name: '/client/orders/tracking',
          page: () => Scaffold(body: Text('Seguimiento ${Get.arguments}')),
        ),
      ],
      home: OrderPaymentPage(
        orderId: 78,
        provider: api,
        autoApproveTestPayment: automatic,
      ),
    );

void main() {
  setUpAll(initTestStorage);
  setUp(() async {
    Get.reset();
    Get.testMode = true;
    await GetStorage().erase();
  });
  tearDown(Get.reset);

  test('only canonical simulated transaction URLs are accepted', () {
    expect(
      simulatedPaymentTransaction('fake://flashdrop-pay/fake-123'),
      'fake-123',
    );
    for (final raw in [
      null,
      '',
      'https://flashdrop-pay/fake-123',
      'fake://other/fake-123',
      'fake://flashdrop-pay/fake-123?x=y',
      'fake://flashdrop-pay/fake-123#x',
      'fake://user@flashdrop-pay/fake-123',
      'fake://flashdrop-pay:123/fake-123',
      'fake://flashdrop-pay/a/b',
      'fake://flashdrop-pay/%2F',
      'fake://flashdrop-pay/',
    ]) {
      expect(simulatedPaymentTransaction(raw), isNull, reason: '$raw');
    }
  });

  test(
    'automatic approval requires a pending order and unexpired server payment',
    () {
      final now = DateTime.utc(2026, 11, 24);
      final valid = {
        'paymentStatus': 'PENDIENTE',
        'orderStatus': 'Pendiente de pago',
        'paymentUrl': 'fake://flashdrop-pay/fake-123',
        'paymentExpiresAt': now
            .add(const Duration(minutes: 1))
            .toIso8601String(),
      };
      expect(pendingSimulatedPayment(valid, now: now), 'fake-123');
      for (final invalid in [
        {...valid, 'paymentStatus': 'APROBADO'},
        {...valid, 'orderStatus': 'Cancelado'},
        {...valid, 'paymentStatus': 'RECHAZADO'},
        {...valid, 'paymentExpiresAt': null},
        {...valid, 'paymentExpiresAt': now.toIso8601String()},
        {...valid, 'paymentUrl': 'https://example.test/payment'},
      ]) {
        expect(pendingSimulatedPayment(invalid, now: now), isNull);
      }
      expect(
        testOrderIsConfirmed({
          'paymentStatus': 'APROBADO',
          'orderStatus': 'Preparando',
        }),
        isTrue,
      );
      for (final status in [
        'Cancelado',
        'Rechazado',
        'Pendiente de pago',
        '',
        'Unknown',
      ]) {
        expect(
          testOrderIsConfirmed({
            'paymentStatus': 'APROBADO',
            'orderStatus': status,
          }),
          isFalse,
        );
      }
    },
  );

  testWidgets('normal payment page never approves automatically', (
    tester,
  ) async {
    final api = AutomaticPaymentApi();
    await tester.pumpWidget(paymentApp(api, automatic: false));
    await tester.pumpAndSettle();
    expect(api.approvals, 0);
    expect(find.text('Aprobar pago de prueba'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'test order approves once and opens tracking only after server confirmation',
    (tester) async {
      final api = AutomaticPaymentApi()..resolutionGate = Completer<void>();
      Get.put(ClientShellController());
      await tester.pumpWidget(paymentApp(api));
      await tester.pump();
      expect(api.approvals, 1);
      expect(find.text('Seguimiento 78'), findsNothing);
      expect(find.text('Pago aprobado'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      expect(api.approvals, 1);
      api.resolutionGate!.complete();
      await tester.pumpAndSettle();
      expect(api.reads, 2);
      expect(find.text('Seguimiento 78'), findsOneWidget);
      expect(Get.find<ClientShellController>().tab.value, ClientTab.orders);
      expect(api.creates, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'an already confirmed order opens tracking without another approval',
    (tester) async {
      final api = AutomaticPaymentApi();
      api.payment.addAll({
        'paymentStatus': 'APROBADO',
        'orderStatus': 'Preparando',
      });
      await tester.pumpWidget(paymentApp(api));
      await tester.pumpAndSettle();
      expect(api.approvals, 0);
      expect(find.text('Seguimiento 78'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'real payments expired payments and cancelled orders cannot auto approve',
    (tester) async {
      for (final override in [
        {'paymentUrl': 'https://example.test/checkout'},
        {
          'paymentExpiresAt': DateTime.now()
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        },
        {'paymentExpiresAt': null},
        {'orderStatus': 'Cancelado'},
        {'paymentStatus': 'RECHAZADO'},
        {'orderStatus': 'Cancelado', 'paymentStatus': 'APROBADO'},
      ]) {
        final api = AutomaticPaymentApi()..payment.addAll(override);
        await tester.pumpWidget(paymentApp(api));
        await tester.pumpAndSettle();
        expect(api.approvals, 0, reason: '$override');
        expect(find.text('Seguimiento 78'), findsNothing);
        expect(find.text('Ir a pagar'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        Get.reset();
        Get.testMode = true;
      }
    },
  );

  testWidgets(
    'failed approval retains the same order and requires explicit retry',
    (tester) async {
      final api = AutomaticPaymentApi()..failResolution = true;
      await tester.pumpWidget(paymentApp(api));
      await tester.pumpAndSettle();
      expect(api.approvals, 1);
      expect(find.textContaining('El pedido se conserva'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(api.approvals, 1);
      expect(find.text('Seguimiento 78'), findsNothing);
      api.failResolution = false;
      await tester.tap(find.text('Reintentar confirmacion'));
      await tester.pumpAndSettle();
      expect(api.approvals, 2);
      expect(api.creates, 0);
      expect(find.text('Seguimiento 78'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'lost verification response recovers with GET without a second approval',
    (tester) async {
      final api = AutomaticPaymentApi()..failReadAfterApproval = true;
      await tester.pumpWidget(paymentApp(api));
      await tester.pumpAndSettle();
      expect(api.approvals, 1);
      expect(find.text('Seguimiento 78'), findsNothing);
      api.failReadAfterApproval = false;
      await tester.tap(find.text('Reintentar confirmacion'));
      await tester.pumpAndSettle();
      expect(api.approvals, 1);
      expect(find.text('Seguimiento 78'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'simulator response alone never pretends that the order was activated',
    (tester) async {
      final api = AutomaticPaymentApi()..activateOrder = false;
      await tester.pumpWidget(paymentApp(api));
      await tester.pumpAndSettle();
      expect(api.approvals, 1);
      expect(find.text('Pendiente de pago'), findsOneWidget);
      expect(find.text('Seguimiento 78'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(api.approvals, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'test APK checkout creates approves and tracks a single order without payment taps',
    (tester) async {
      if (!Environment.autoApproveTestPayments) return;
      final api = AutomaticPaymentApi();
      await GetStorage().write('delivery_address', {
        'address': 'Calle QA 123',
        'commune': 'Santiago',
        'lat': -33.45,
        'lng': -70.65,
      });
      Get.put<AppProvider>(api);
      Get.put(CartController()).add(product);
      Get.put(CatalogController(provider: api));
      Get.put(ClientShellController());
      await tester.pumpWidget(
        GetMaterialApp(
          getPages: [
            GetPage(
              name: '/client/orders/tracking',
              page: () => Scaffold(body: Text('Seguimiento ${Get.arguments}')),
            ),
          ],
          home: const CartPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pago de prueba (automatico)'), findsOneWidget);
      await tester.tap(find.textContaining('PEDIR AHORA'));
      await tester.pumpAndSettle();
      expect(api.creates, 1);
      expect(api.approvals, 1);
      expect(Get.find<CartController>().count, 0);
      expect(find.text('Seguimiento 78'), findsOneWidget);
      expect(api.payment['orderStatus'], 'Nuevo pedido');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
