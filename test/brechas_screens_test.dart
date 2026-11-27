import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/account/profile_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/account/reviews_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/orders/payment_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'helpers/test_app.dart';

class ScreensApi extends AppProvider {
  bool failPayment = false;
  bool failReviews = false;
  String status = 'PENDIENTE';
  String orderStatus = 'Pendiente de pago';
  String url = 'fake://flashdrop-pay/tx-1';
  int resolved = 0;
  int retries = 0;
  int reviewCount = 0;
  int? rating;
  String? comment;
  Map<String, dynamic>? savedProfile;
  Completer<Map<String, dynamic>>? pendingProfileUpdate;
  @override
  Future<Map<String, dynamic>> getPayment(Object id) async {
    if (failPayment) throw StateError('Sin red');
    return {
      'paymentStatus': status,
      'orderStatus': orderStatus,
      'paymentUrl': url,
      'paymentExpiresAt': DateTime.now()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> resolveTestPayment(
    String transaction,
    bool approved,
  ) async {
    expect(transaction, 'tx-1');
    resolved++;
    status = approved ? 'APROBADO' : 'RECHAZADO';
    if (approved) orderStatus = 'Preparando';
    return {};
  }

  @override
  Future<Map<String, dynamic>> retryPayment(Object id) async {
    retries++;
    status = 'PENDIENTE';
    return {'paymentUrl': url};
  }

  @override
  Future<Map<String, dynamic>> pendingReviews(Object orderId) async {
    if (failReviews) throw StateError('Sin red');
    return {
      'pending': reviewCount == 0
          ? [
              {'targetType': 'TIENDA', 'targetId': 1},
            ]
          : [],
      'completed': reviewCount == 0
          ? []
          : [
              {'rating': rating, 'targetType': 'TIENDA', 'comment': comment},
            ],
    };
  }

  @override
  Future<Map<String, dynamic>> createReview({
    required int orderId,
    required String targetType,
    required int rating,
    String? comment,
  }) async {
    expect(orderId, 78);
    expect(targetType, 'TIENDA');
    reviewCount++;
    this.rating = rating;
    this.comment = comment;
    return {};
  }

  @override
  Future<Map<String, dynamic>> getProfile() async => {
    'name': 'Cliente',
    'lastName': 'Prueba',
    'phone': '+56912345678',
    'email': 'qa@example.test',
  };
  @override
  Future<Uint8List?> getProfilePhoto({String? version}) async => null;
  @override
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String lastName,
    required String phone,
  }) async {
    if (pendingProfileUpdate != null) return pendingProfileUpdate!.future;
    savedProfile = {'name': name, 'lastName': lastName, 'phone': phone};
    return {...await getProfile(), ...savedProfile!};
  }
}

void main() {
  setUpAll(initTestStorage);
  setUp(() async {
    Get.reset();
    Get.testMode = true;
    await GetStorage().erase();
  });
  tearDown(Get.reset);

  testWidgets(
    'late profile response does not recreate user storage after leaving',
    (tester) async {
      await GetStorage().write('user', {
        'id': 123,
        'roles': ['CLIENTE'],
      });
      final pending = Completer<Map<String, dynamic>>();
      final api = ScreensApi()..pendingProfileUpdate = pending;
      await tester.pumpWidget(
        MaterialApp(home: AccountProfilePage(provider: api)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await GetStorage().erase();
      pending.complete({'id': 123, 'name': 'Usuario anterior'});
      await tester.pump();
      expect(GetStorage().read('user'), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('simulated payment is explicit, shows amount and confirms once', (
    tester,
  ) async {
    final api = ScreensApi();
    await tester.pumpWidget(
      MaterialApp(
        home: OrderPaymentPage(
          orderId: 78,
          total: 13200,
          provider: api,
          autoApproveTestPayment: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Pasarela simulada: no se cobra dinero real.'),
      findsOneWidget,
    );
    expect(find.text('\$13.200'), findsOneWidget);
    await tester.tap(find.text('Aprobar pago de prueba'));
    await tester.pumpAndSettle();
    expect(api.resolved, 1);
    expect(find.text('Pago aprobado'), findsOneWidget);
    expect(find.text('Aprobar pago de prueba'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'rejected payment retries the same order without creating another',
    (tester) async {
      final api = ScreensApi()..status = 'RECHAZADO';
      await tester.pumpWidget(
        MaterialApp(
          home: OrderPaymentPage(
            orderId: 78,
            provider: api,
            autoApproveTestPayment: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reintentar pago'));
      await tester.pumpAndSettle();
      expect(api.retries, 1);
      expect(find.text('Aprobar pago de prueba'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cancelled order hides all payment and retry actions', (
    tester,
  ) async {
    final api = ScreensApi()
      ..status = 'RECHAZADO'
      ..orderStatus = 'Cancelado';
    await tester.pumpWidget(
      MaterialApp(
        home: OrderPaymentPage(
          orderId: 78,
          provider: api,
          autoApproveTestPayment: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reintentar pago'), findsNothing);
    expect(find.text('Aprobar pago de prueba'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'payment lookup failure disables stale test approval and can recover',
    (tester) async {
      final api = ScreensApi()..failPayment = true;
      await tester.pumpWidget(
        MaterialApp(
          home: OrderPaymentPage(
            orderId: 78,
            initialUrl: api.url,
            provider: api,
            autoApproveTestPayment: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final approve = find.widgetWithText(
        FilledButton,
        'Aprobar pago de prueba',
      );
      expect(tester.widget<FilledButton>(approve).onPressed, isNull);
      api.failPayment = false;
      await tester.tap(find.byTooltip('Actualizar pago'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'insecure payment URLs do not get launch or fake approval controls',
    (tester) async {
      final api = ScreensApi()..url = 'http://example.test/payment';
      await tester.pumpWidget(
        MaterialApp(
          home: OrderPaymentPage(
            orderId: 78,
            provider: api,
            autoApproveTestPayment: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ir a pagar'), findsNothing);
      expect(find.text('Aprobar pago de prueba'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reviews require a star and remove the completed target after saving',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = ScreensApi();
      await tester.pumpWidget(
        MaterialApp(home: ReviewsPage(orderId: 78, provider: api)),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('5 estrellas'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar calificación'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('5 estrellas'));
      await tester.enterText(find.byType(TextField), 'Buena entrega');
      await tester.tap(find.text('Enviar calificación'));
      await tester.pumpAndSettle();
      expect(api.reviewCount, 1);
      expect(api.rating, 5);
      expect(find.byTooltip('5 estrellas'), findsNothing);
      expect(find.text('Buena entrega'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reviews failure has a working refresh and no invented pending targets',
    (tester) async {
      final api = ScreensApi()..failReviews = true;
      await tester.pumpWidget(
        MaterialApp(home: ReviewsPage(orderId: 78, provider: api)),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('5 estrellas'), findsNothing);
      api.failReviews = false;
      await tester.tap(find.byTooltip('Actualizar calificaciones'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('5 estrellas'), findsOneWidget);
    },
  );

  testWidgets(
    'profile validates names and phone, preserves roles and never edits email',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await GetStorage().write('user', {
        'roles': ['CLIENTE'],
        'id': 123,
      });
      final api = ScreensApi();
      await tester.pumpWidget(
        MaterialApp(home: AccountProfilePage(provider: api)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('qa@example.test'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(2), '123');
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(api.savedProfile, isNull);
      await tester.enterText(find.byType(TextFormField).at(2), '+56987654321');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(api.savedProfile?['phone'], '+56987654321');
      expect((GetStorage().read('user') as Map)['roles'], ['CLIENTE']);
      expect(tester.takeException(), isNull);
    },
  );
}
