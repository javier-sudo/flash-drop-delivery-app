import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/account/reviews_page.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/restaurant/store_delivery_coverage_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';

class _ReviewsApi extends AppProvider {
  final pending = <Map<String, dynamic>>[
    {'targetType': 'TIENDA'},
    {'targetType': 'REPARTIDOR'},
  ];
  final completed = <Map<String, dynamic>>[];
  bool failPost = false;
  bool failRefresh = false;
  Completer<void>? postGate;
  int posts = 0;
  @override
  Future<Map<String, dynamic>> pendingReviews(Object orderId) async {
    if (failRefresh) throw StateError('offline');
    return {'pending': List.of(pending), 'completed': List.of(completed)};
  }

  @override
  Future<Map<String, dynamic>> createReview({
    required int orderId,
    required String targetType,
    required int rating,
    String? comment,
  }) async {
    posts++;
    if (failPost) throw StateError('offline');
    if (postGate != null) await postGate!.future;
    final review = {
      'targetType': targetType,
      'rating': rating,
      'comment': comment,
    };
    pending.removeWhere((target) => target['targetType'] == targetType);
    completed.add(review);
    return review;
  }

  @override
  Future<Map<String, dynamic>> getMyRestaurant() async => {
    'name': 'Flash Restaurant Demo',
    'address': 'Av. Providencia 2000, Providencia',
    'latitude': -33.45,
    'longitude': -70.66,
    'deliveryRadiusKm': 10,
  };
}

const _previewDir = String.fromEnvironment('UI_PREVIEW_DIR');
const _fontDir = String.fromEnvironment('UI_PREVIEW_FONT_DIR');

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (_previewDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_previewDir).create(recursive: true);
    await File(
      '$_previewDir/$name.png',
    ).writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (_previewDir.isEmpty || _fontDir.isEmpty) return;
    final loader = FontLoader('Roboto');
    for (final face in ['regular', 'medium', 'bold', 'black']) {
      loader.addFont(
        File(
          '$_fontDir/roboto-$face.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<GlobalKey> open(
    WidgetTester tester,
    _ReviewsApi api, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final base = AppTheme.light();
    final previewTheme = base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'Roboto',
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: 'Roboto'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: previewTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: ReviewsPage(orderId: 78, provider: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  testWidgets(
    'opens stars and comment directly and retains independent drafts per target',
    (tester) async {
      final api = _ReviewsApi();
      final key = await open(tester, api);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byTooltip('5 estrellas'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await _capture(tester, key, 'calificar-inicio');
      await tester.tap(find.byTooltip('5 estrellas'));
      await tester.enterText(
        find.byType(TextField),
        'Muy rico y llegó en buen estado.',
      );
      await tester.pumpAndSettle();
      await _capture(tester, key, 'calificar-comentario');
      await tester.tap(find.text('Repartidor'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      await tester.tap(find.byTooltip('4 estrellas'));
      await tester.enterText(find.byType(TextField), 'Muy amable.');
      await tester.tap(find.text('Comercio'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Muy rico y llegó en buen estado.',
      );
      expect(find.text('Excelente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed submit preserves draft and requires refresh before retry',
    (tester) async {
      final api = _ReviewsApi()..failPost = true;
      await open(tester, api);
      await tester.tap(find.byTooltip('4 estrellas'));
      await tester.enterText(find.byType(TextField), 'Mi comentario');
      await tester.tap(find.text('Enviar calificación'));
      await tester.pumpAndSettle();
      expect(api.posts, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Mi comentario',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar calificación'),
            )
            .onPressed,
        isNull,
      );
      api.failPost = false;
      await tester.tap(find.byTooltip('Actualizar calificaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar calificación'));
      await tester.pumpAndSettle();
      expect(api.posts, 2);
      expect(api.completed.single['rating'], 4);
      expect(find.text('¿Cómo estuvo la entrega?'), findsOneWidget);
    },
  );

  testWidgets(
    'accepted submit never reopens the same target if refresh fails',
    (tester) async {
      final api = _ReviewsApi()..pending.removeLast();
      await open(tester, api);
      await tester.tap(find.byTooltip('5 estrellas'));
      await tester.pump();
      api.failRefresh = true;
      await tester.tap(find.text('Enviar calificación'));
      await tester.pumpAndSettle();
      expect(api.posts, 1);
      expect(find.text('Gracias por calificar'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('5/5'), findsOneWidget);
    },
  );

  testWidgets(
    'submission disables duplicate requests and all editing until finished',
    (tester) async {
      final gate = Completer<void>();
      final api = _ReviewsApi()..postGate = gate;
      await open(tester, api);
      await tester.tap(find.byTooltip('5 estrellas'));
      await tester.pump();
      await tester.tap(find.text('Enviar calificación'));
      await tester.pump();
      expect(api.posts, 1);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == '5 estrellas',
              ),
            )
            .onPressed,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(api.posts, 1);
    },
  );

  testWidgets('small phone supports large text and keyboard without overflow', (
    tester,
  ) async {
    final api = _ReviewsApi();
    await open(tester, api, size: const Size(320, 640), textScale: 1.5);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Comentario con teclado abierto.',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getBottomRight(
            find.widgetWithText(FilledButton, 'Enviar calificación'),
          )
          .dy,
      lessThanOrEqualTo(380),
    );
  });

  testWidgets('submitted review shows confirmation, full stars and comment', (
    tester,
  ) async {
    final api = _ReviewsApi()
      ..pending.clear()
      ..completed.add({
        'targetType': 'TIENDA',
        'rating': 5,
        'comment': 'Muy rico y llegó en buen estado.',
      });
    final key = await open(tester, api);
    expect(find.text('Tu opinión ya está guardada'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await _capture(tester, key, 'calificacion-enviada');
    expect(tester.takeException(), isNull);
  });

  testWidgets('coverage controls fit a small phone with accessible text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: StoreDeliveryCoveragePage(provider: _ReviewsApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    scroll.jumpTo(scroll.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Latitud del local'), findsNothing);
    expect(find.byType(DropdownButtonFormField<double>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
