import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/forgot_password/forgot_password_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/forgot_password/forgot_password_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/login/login_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/users_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';

import 'helpers/test_app.dart';

/// Backend falso de Auth: guarda cada solicitud y responde con [status].
class _FakeAuth {
  int status;
  bool fail = false;
  final requests = <http.Request>[];

  _FakeAuth([this.status = 202]);

  MockClient get client => MockClient((request) async {
    requests.add(request);
    if (fail) throw http.ClientException('sin red');
    return http.Response('', status);
  });

  String get lastEmail =>
      (jsonDecode(requests.last.body) as Map<String, dynamic>)['email']
          as String;
}

void main() {
  setUpAll(initTestStorage);

  group('UsersProvider.requestPasswordReset', () {
    Future<PasswordResetRequestResult> call(_FakeAuth auth) =>
        UsersProvider(client: auth.client).requestPasswordReset('a@b.cl');

    test('202 sin cuerpo cuenta como enviado', () async {
      final auth = _FakeAuth(202);
      expect(await call(auth), PasswordResetRequestResult.sent);
      final req = auth.requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, endsWith('/auth/password/forgot'));
      expect(req.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(req.body), {'email': 'a@b.cl'});
    });

    test('mapea 400, 429, 500 y falta de red', () async {
      expect(
        await call(_FakeAuth(400)),
        PasswordResetRequestResult.invalidEmail,
      );
      expect(
        await call(_FakeAuth(429)),
        PasswordResetRequestResult.tooManyRequests,
      );
      expect(
        await call(_FakeAuth(500)),
        PasswordResetRequestResult.serverError,
      );
      expect(
        await call(_FakeAuth()..fail = true),
        PasswordResetRequestResult.network,
      );
    });
  });

  test('validateEmail', () {
    expect(ForgotPasswordController.validateEmail(''), 'Ingresa tu correo');
    expect(
      ForgotPasswordController.validateEmail('no-es-correo'),
      'El correo no es válido',
    );
    expect(
      ForgotPasswordController.validateEmail('${'a' * 250}@b.cl'),
      'El correo es demasiado largo',
    );
    expect(ForgotPasswordController.validateEmail('ana@demo.cl'), isNull);
  });

  group('pantalla de recuperación', () {
    late _FakeAuth auth;

    setUp(() {
      Get.reset();
      Get.testMode = true;
      auth = _FakeAuth();
      Get.put<UsersProvider>(UsersProvider(client: auth.client));
    });

    Future<void> pumpApp(WidgetTester tester, {String initial = '/'}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          initialRoute: initial,
          getPages: [
            GetPage(name: '/', page: () => LoginPage()),
            GetPage(
              name: '/forgot-password',
              page: () => ForgotPasswordPage(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder emailField() => find.byKey(const Key('forgot-email'));

    testWidgets('desde el login: precarga el correo, envía y vuelve', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField).first, 'Ana@Demo.cl');
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();

      expect(find.text('Recuperar contraseña'), findsOneWidget);
      expect(
        tester.widget<TextField>(emailField()).controller!.text,
        'Ana@Demo.cl',
      );

      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();

      // Se envía normalizado y la respuesta no revela si el correo existe.
      expect(auth.requests, hasLength(1));
      expect(auth.lastEmail, 'ana@demo.cl');
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(find.textContaining('Si ana@demo.cl está registrado'), findsOne);
      expect(find.text('Reenviar en 60s'), findsOneWidget);

      await tester.tap(find.text('Volver a iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Flash Drop'), findsOneWidget);
      expect(find.text('Revisa tu correo'), findsNothing);
    });

    testWidgets('correo inválido: muestra el error y no llama al backend', (
      tester,
    ) async {
      await pumpApp(tester, initial: '/forgot-password');

      await tester.tap(find.text('Enviar enlace'));
      await tester.pump();
      expect(find.text('Ingresa tu correo'), findsOneWidget);

      await tester.enterText(emailField(), 'ana@');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pump();
      expect(find.text('El correo no es válido'), findsOneWidget);
      expect(auth.requests, isEmpty);
    });

    testWidgets('reenviar se habilita tras 60 s y otro correo reinicia', (
      tester,
    ) async {
      await pumpApp(tester, initial: '/forgot-password');

      await tester.enterText(emailField(), 'ana@demo.cl');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();
      expect(find.text('Reenviar en 60s'), findsOneWidget);

      // Durante la espera el botón no envía nada.
      await tester.tap(find.text('Reenviar en 60s'));
      await tester.pump();
      expect(auth.requests, hasLength(1));

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Reenviar en 30s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Reenviar enlace'), findsOneWidget);

      await tester.tap(find.text('Reenviar enlace'));
      await tester.pumpAndSettle();
      expect(auth.requests, hasLength(2));

      await tester.tap(find.text('Usar otro correo'));
      await tester.pumpAndSettle();
      expect(find.text('Recuperar contraseña'), findsOneWidget);
      await tester.enterText(emailField(), 'otro@demo.cl');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();
      expect(auth.requests, hasLength(3));
      expect(auth.lastEmail, 'otro@demo.cl');

      // Cierra la espera pendiente antes de terminar el test.
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('429 y sin red muestran el aviso y siguen en el formulario', (
      tester,
    ) async {
      await pumpApp(tester, initial: '/forgot-password');
      await tester.enterText(emailField(), 'ana@demo.cl');

      auth.status = 429;
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();
      expect(find.textContaining('demasiadas solicitudes'), findsOneWidget);
      expect(find.text('Revisa tu correo'), findsNothing);

      auth.fail = true;
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No hay conexión'), findsOneWidget);
      expect(find.text('Revisa tu correo'), findsNothing);
    });
  });
}
