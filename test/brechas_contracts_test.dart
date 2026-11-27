import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proyecto_app_delivery_gessof/src/models/checkout_quote.dart';
import 'package:proyecto_app_delivery_gessof/src/models/courier_position.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/order_status.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/public_order_id.dart';
import 'helpers/test_app.dart';

void main() {
  setUpAll(initTestStorage);
  setUp(() async {
    await GetStorage().erase();
    final payload = base64Url.encode(
      utf8.encode(jsonEncode({'exp': 4102444800})),
    );
    FlutterSecureStorage.setMockInitialValues({
      'flashdrop_access_token': 'test.$payload.signature',
    });
  });

  test('pending payment remains active and is not received or delivered', () {
    final stage = OrderStage.of('Pendiente de pago');
    expect(stage.isClosed, isFalse);
    expect(stage.isAwaitingPayment, isTrue);
    expect(stage.headline, 'Pago pendiente');
    expect(OrderStage.of('Cancelado').message, isNot(contains('Cancelaste')));
  });

  test(
    'reviews accepts only public IDs and the Orders numeric UUID encoding',
    () {
      expect(publicOrderId(78), 78);
      expect(publicOrderId('00000000-0000-0000-0000-00000000004e'), 78);
      expect(publicOrderId('550e8400-e29b-41d4-a716-446655440000'), isNull);
      expect(publicOrderId('FD-78'), isNull);
      expect(publicOrderId(-1), isNull);
    },
  );

  test('quote requires finite nonnegative amounts and a consistent total', () {
    expect(
      CheckoutQuote.fromJson({
        'subtotal': '10000',
        'deliveryFee': 3200,
        'total': 13200,
      }).total,
      13200,
    );
    for (final invalid in [
      {'subtotal': 10000, 'deliveryFee': -1, 'total': 9999},
      {'subtotal': 10000, 'deliveryFee': 3000, 'total': 10000},
      {'subtotal': 10000, 'total': 10000},
      {'subtotal': double.nan, 'deliveryFee': 3000, 'total': 10000},
    ]) {
      expect(() => CheckoutQuote.fromJson(invalid), throwsFormatException);
    }
  });

  test(
    'courier position rejects stale, invalid, future or wrong-route locations',
    () {
      final now = DateTime.utc(2026, 11, 23, 12);
      final valid = {
        'routeId': 42,
        'latitude': -33.45,
        'longitude': -70.65,
        'recordedAt': now.toIso8601String(),
      };
      expect(CourierPosition.fromJson(valid, routeId: 42, now: now), isNotNull);
      for (final invalid in [
        {...valid, 'routeId': 43},
        {...valid, 'latitude': 91},
        {...valid, 'longitude': double.nan},
        {
          ...valid,
          'recordedAt': now
              .subtract(const Duration(seconds: 31))
              .toIso8601String(),
        },
        {
          ...valid,
          'recordedAt': now.add(const Duration(seconds: 6)).toIso8601String(),
        },
      ]) {
        expect(
          CourierPosition.fromJson(invalid, routeId: 42, now: now),
          isNull,
        );
      }
    },
  );

  test(
    'quote and payment API use authenticated endpoints and unwrap data',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], startsWith('Bearer test.'));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'paymentStatus': 'PENDIENTE', 'total': 13200},
          }),
          200,
        );
      });
      await http.runWithClient(() async {
        final api = AppProvider();
        await api.quoteOrder(
          items: [
            {'product_id': 1, 'quantity': 2},
          ],
          latitude: -33.45,
          longitude: -70.65,
        );
        expect((await api.getPayment(78))['paymentStatus'], 'PENDIENTE');
        await api.retryPayment(78);
        await api.resolveTestPayment('tx-1', true);
      }, () => client);
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/orders/delivery-quote',
        'GET /api/orders/78/payments',
        'POST /api/orders/78/payments',
        'POST /api/payments/fake/tx-1/resolve',
      ]);
      expect(jsonDecode(requests.first.body)['items'], [
        {'product_id': 1, 'quantity': 2},
      ]);
      expect(jsonDecode(requests.last.body), {'outcome': 'APPROVED'});
    },
  );

  test(
    'order preserves destination, secure reception and idempotency key',
    () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          '{"success":true,"data":{"id":78,"status":"Pendiente de pago"}}',
          201,
        );
      });
      final result = await http.runWithClient(
        () => AppProvider().createOrder(
          items: [
            {'product_id': 1, 'quantity': 1},
          ],
          address: 'Calle de prueba 123',
          latitude: -33.45,
          longitude: -70.65,
          commune: 'Santiago',
          idempotencyKey: 'attempt-1',
        ),
        () => client,
      );
      expect(result.success, isTrue);
      expect(sent.headers['Idempotency-Key'], 'attempt-1');
      final body = jsonDecode(sent.body);
      expect(body['payment_method'], 'Tarjeta');
      expect(body['receptionMode'], 'SEGURO');
      expect(body['commune'], 'Santiago');
      expect(body['latitude'], -33.45);
      expect(body.containsKey('user_id'), isFalse);
    },
  );

  test(
    'profile photo uses own authenticated endpoint, version and handles 404',
    () async {
      var count = 0;
      final client = MockClient((request) async {
        expect(request.url.path, '/auth/profile/photo');
        expect(request.url.queryParameters['v'], 'photo-2');
        expect(request.headers['Authorization'], startsWith('Bearer test.'));
        return count++ == 0
            ? http.Response.bytes([255, 216, 255], 200)
            : http.Response('', 404);
      });
      await http.runWithClient(() async {
        final api = AppProvider();
        expect(await api.getProfilePhoto(version: 'photo-2'), [255, 216, 255]);
        expect(await api.getProfilePhoto(version: 'photo-2'), isNull);
      }, () => client);
    },
  );

  test(
    'profile upload sends multipart file with image MIME, never JSON content type',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/auth/profile/photo');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect(request.headers['Authorization'], startsWith('Bearer test.'));
        final multipart = latin1.decode(request.bodyBytes);
        expect(multipart, contains('name="file"'));
        expect(multipart, contains('content-type: image/jpeg'));
        return http.Response(
          '{"name":"Prueba","photo":"/auth/profile/photo?v=2"}',
          200,
        );
      });
      await http.runWithClient(
        () => AppProvider().uploadProfilePhoto(
          XFile.fromData(
            Uint8List.fromList([255, 216, 255, 0]),
            name: 'photo.jpg',
          ),
        ),
        () => client,
      );
    },
  );

  test(
    'profile photo rejects invalid type and size before uploading',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      });
      await http.runWithClient(() async {
        final api = AppProvider();
        await expectLater(
          api.uploadProfilePhoto(
            XFile.fromData(Uint8List.fromList([71, 73, 70]), name: 'photo.gif'),
          ),
          throwsFormatException,
        );
        await expectLater(
          api.uploadProfilePhoto(
            XFile.fromData(Uint8List(2 * 1024 * 1024 + 1), name: 'big.jpg'),
          ),
          throwsFormatException,
        );
      }, () => client);
      expect(requests, 0);
    },
  );

  test(
    'profile delete accepts empty 204 and update never sends email or photo',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return request.method == 'DELETE'
            ? http.Response('', 204)
            : http.Response('{"name":"Prueba"}', 200);
      });
      await http.runWithClient(() async {
        await AppProvider().deleteProfilePhoto();
        await AppProvider().updateProfile(
          name: 'Prueba',
          lastName: 'QA',
          phone: '+56912345678',
        );
      }, () => client);
      expect(jsonDecode(requests.last.body), {
        'name': 'Prueba',
        'lastName': 'QA',
        'phone': '+56912345678',
      });
    },
  );

  test(
    'reviews uses public numeric ID and lets server select target identity',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/reviews');
        expect(jsonDecode(request.body), {
          'orderId': 78,
          'targetType': 'TIENDA',
          'rating': 5,
          'comment': 'Bien',
        });
        return http.Response('{"id":1,"rating":5}', 201);
      });
      await http.runWithClient(
        () => AppProvider().createReview(
          orderId: 78,
          targetType: 'TIENDA',
          rating: 5,
          comment: ' Bien ',
        ),
        () => client,
      );
    },
  );

  test(
    'release and post-pickup cancellation preserve reason and public order ID',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('{"success":true}', 200);
      });
      await http.runWithClient(() async {
        await AppProvider().releaseOrder(78, 'No puedo retirar');
        await AppProvider().cancelAfterPickup(78, 'Incidencia', 'Cancelado');
      }, () => client);
      expect(requests.first.url.path, '/api/orders/78/release');
      expect(jsonDecode(requests.first.body), {'reason': 'No puedo retirar'});
      expect(requests.last.url.path, '/api/orders/78/cancel-after-pickup');
      expect(jsonDecode(requests.last.body), {
        'reason': 'Incidencia',
        'status': 'Cancelado',
      });
    },
  );

  test(
    'profile 413, 429 and 503 fail without accepting a false success',
    () async {
      for (final code in [413, 429, 503]) {
        final client = MockClient(
          (_) async => http.Response('{"message":"Unavailable"}', code),
        );
        await http.runWithClient(() async {
          await expectLater(AppProvider().getProfile(), throwsException);
        }, () => client);
      }
    },
  );
}
