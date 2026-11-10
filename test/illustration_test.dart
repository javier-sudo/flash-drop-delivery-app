import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/illustration.dart';

void main() {
  test('cada ilustración, pin e ícono apunta a un archivo que existe', () {
    final assets = [
      ...AppIllustration.values.map((e) => e.asset),
      ...MapPinKind.values.map((e) => e.asset),
      ...AddressIcon.values.map((e) => e.asset),
    ];
    for (final asset in assets) {
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: 'falta $asset');
      if (asset.endsWith('.svg')) {
        final svg = file.readAsStringSync();
        expect(svg, startsWith('<svg'), reason: '$asset no es un SVG');
        expect(
          svg,
          contains('viewBox'),
          reason: '$asset no escala sin viewBox',
        );
      } else {
        // Firma PNG: los pines, íconos y el error son imágenes propias.
        expect(file.readAsBytesSync().take(4), [0x89, 0x50, 0x4E, 0x47]);
      }
    }
  });

  test('no quedan archivos de terceros que exijan atribución', () {
    expect(File('assets/illustrations/NOTICE.md').existsSync(), isFalse);
    final svgs = Directory('assets/illustrations')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.svg'))
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(svgs, {
      'empty_cart.svg',
      'empty_orders.svg',
      'empty_address.svg',
      'search_empty.svg',
      'location_permission.svg',
      'no_connection.svg',
    });
  });

  test('el pubspec declara las carpetas de ilustraciones', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final dir in ['states', 'markers', 'address']) {
      expect(pubspec, contains('assets/illustrations/$dir/'));
    }
  });

  test('la etiqueta de la dirección elige su ícono', () {
    expect(AddressLabelIcon.kindOf('Casa'), AddressIcon.home);
    expect(AddressLabelIcon.kindOf(' trabajo '), AddressIcon.work);
    expect(AddressLabelIcon.kindOf('Donde mi abuela'), AddressIcon.other);
  });

  test('cada paso del pedido tiene su imagen y el pubspec la declara', () {
    for (final art in OrderStepArt.values) {
      expect(
        File(art.asset).existsSync(),
        isTrue,
        reason: 'falta ${art.asset}',
      );
    }
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/img/steps/'),
    );
    expect(OrderStepArt.of(0), OrderStepArt.received);
    expect(OrderStepArt.of(2), OrderStepArt.ready);
    expect(OrderStepArt.of(3), OrderStepArt.onTheWay);
    // Fuera de rango usa el paso más cercano en vez de fallar.
    expect(OrderStepArt.of(-1), OrderStepArt.received);
    expect(OrderStepArt.of(9), OrderStepArt.delivered);
  });

  testWidgets('OrderStepImage atenúa en gris solo los pasos pendientes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            OrderStepImage(step: 0),
            OrderStepImage(step: 4, pending: true),
          ],
        ),
      ),
    );
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(ColorFiltered),
        matching: find.byType(Opacity),
      ),
      findsOneWidget,
    );
  });

  testWidgets('IllustratedMessage muestra ilustración, textos y acción', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: IllustratedMessage(
            illustration: AppIllustration.noConnection,
            title: 'Sin conexión',
            message: 'Revisa tu red.',
            actionLabel: 'Reintentar',
            onAction: () => retried++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Revisa tu red.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retried, 1);
  });

  testWidgets('sin acción no se dibuja el botón', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IllustratedMessage(
            illustration: AppIllustration.emptyCart,
            title: 'Tu carrito está vacío',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsNothing);
  });
}
