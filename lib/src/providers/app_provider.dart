import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proyecto_app_delivery_gessof/src/data/demo_backend.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/services/connection_service.dart';
import 'package:proyecto_app_delivery_gessof/src/services/session_manager.dart';

class AppProvider {
  final String _base = Environment.apiUrl;

  static const timeout = Duration(seconds: 15);

  Future<Map<String, String>> get _headers =>
      SessionManager.instance.authorizedHeaders();

  /// Toda llamada tiene timeout y alimenta el estado de conexión.
  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      final response = await request.timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 500) {
        ConnectionService.instance.markOnline();
      } else {
        ConnectionService.instance.markOffline();
      }
      return response;
    } catch (_) {
      ConnectionService.instance.markOffline();
      rethrow;
    }
  }

  dynamic _body(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded is Map
            ? decoded['message'] ?? 'Error HTTP ${response.statusCode}'
            : 'Error HTTP ${response.statusCode}',
      );
    }
    return decoded is Map<String, dynamic> && decoded.containsKey('data')
        ? decoded['data']
        : decoded;
  }

  DemoBackend get _demo => DemoBackend.instance;
  bool get _isDemo => Environment.useDemoMode;

  Future<List<Map<String, dynamic>>> getProducts() async {
    if (_isDemo) return _demo.products();
    final responses = await Future.wait([
      _send(http.get(Uri.parse('$_base/catalog/products'))),
      _send(http.get(Uri.parse('$_base/catalog/restaurants'))),
      _send(http.get(Uri.parse('$_base/catalog/categories'))),
    ]);
    final products = List<Map<String, dynamic>>.from(_body(responses[0]) ?? []);
    final restaurants = List<Map<String, dynamic>>.from(
      _body(responses[1]) ?? [],
    );
    final restaurantsById = {
      for (final restaurant in restaurants) '${restaurant['id']}': restaurant,
    };
    final categories = List<Map<String, dynamic>>.from(
      _body(responses[2]) ?? [],
    );
    final categoriesById = {
      for (final category in categories) '${category['id']}': category,
    };

    return products.map((product) {
      final restaurant = restaurantsById['${product['restaurantId']}'];
      final category = categoriesById['${product['categoryId']}'];
      return {
        ...product,
        'categoryName':
            product['categoryName'] ?? category?['name'] ?? 'Sin categoría',
        'restaurantName':
            product['restaurantName'] ??
            restaurant?['name'] ??
            'Comercio ${product['restaurantId'] ?? ''}',
        'restaurantAddress':
            product['restaurantAddress'] ?? restaurant?['address'],
      };
    }).toList();
  }

  /// [view] acota los pedidos al rol: `client` o `restaurant`.
  Future<List<Map<String, dynamic>>> getOrders({String? view}) async {
    if (_isDemo) return _demo.orders(view: view);
    // Orders currently exposes user_id as UUID, while Auth emits a numeric
    // userId. The authenticated identity is already carried by the JWT, so
    // avoid sending an incompatible query parameter from the mobile client.
    final uri = Uri.parse(
      '$_base/api/orders',
    ).replace(queryParameters: view == null ? null : {'view': view});
    final res = await _send(http.get(uri, headers: await _headers));
    return List<Map<String, dynamic>>.from(_body(res) ?? []);
  }

  Future<List<Map<String, dynamic>>> getDeliveryRoutes() async {
    if (_isDemo) return _demo.routes();
    final res = await _send(
      http.get(
        Uri.parse('$_base/api/delivery/routes'),
        headers: await _headers,
      ),
    );
    return List<Map<String, dynamic>>.from(_body(res) ?? []);
  }

  Future<List<Map<String, dynamic>>> getRestaurants() async {
    if (_isDemo) {
      return (await _demo.restaurants())
          .map(
            (r) => {...r, 'open': true, 'acceptingOrders': true, 'hours': []},
          )
          .toList();
    }
    final res = await _send(http.get(Uri.parse('$_base/catalog/restaurants')));
    return List<Map<String, dynamic>>.from(_body(res) ?? []);
  }

  Future<List<Map<String, dynamic>>> getCoveredRestaurants({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$_base/catalog/restaurants').replace(
      queryParameters: {'latitude': '$latitude', 'longitude': '$longitude'},
    );
    final res = await _send(http.get(uri));
    return List<Map<String, dynamic>>.from(_body(res) ?? []);
  }

  Future<Map<String, dynamic>> getMyRestaurant() async {
    final res = await _send(
      http.get(
        Uri.parse('$_base/api/catalog/my/restaurant'),
        headers: await _headers,
      ),
    );
    return Map<String, dynamic>.from(_body(res));
  }

  Future<Map<String, dynamic>> updateStoreLocation({
    required double latitude,
    required double longitude,
  }) async {
    final res = await _send(
      http.put(
        Uri.parse('$_base/api/catalog/my/restaurant/location'),
        headers: await _headers,
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      ),
    );
    return Map<String, dynamic>.from(_body(res));
  }

  Future<Map<String, dynamic>> updateStoreDeliveryRadius(
    double radiusKm,
  ) async {
    final res = await _send(
      http.put(
        Uri.parse('$_base/api/catalog/my/restaurant/delivery-radius'),
        headers: await _headers,
        body: jsonEncode({'deliveryRadiusKm': radiusKm}),
      ),
    );
    return Map<String, dynamic>.from(_body(res));
  }

  Future<List<Map<String, dynamic>>> getMyProducts() async {
    final response = await _send(
      http.get(
        Uri.parse('$_base/api/catalog/my/products'),
        headers: await _headers,
      ),
    );
    return List<Map<String, dynamic>>.from(_body(response));
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _send(
      http.get(Uri.parse('$_base/catalog/categories')),
    );
    return List<Map<String, dynamic>>.from(_body(response));
  }

  Future<void> saveMyProduct(Map<String, dynamic> product, {Object? id}) async {
    final headers = await _headers;
    final response = await _send(
      id == null
          ? http.post(
              Uri.parse('$_base/api/catalog/my/products'),
              headers: headers,
              body: jsonEncode(product),
            )
          : http.put(
              Uri.parse('$_base/api/catalog/my/products/$id'),
              headers: headers,
              body: jsonEncode(product),
            ),
    );
    _body(response);
  }

  Future<void> deactivateMyProduct(Object id) async {
    final response = await _send(
      http.delete(
        Uri.parse('$_base/api/catalog/my/products/$id'),
        headers: await _headers,
      ),
    );
    if (response.statusCode == 204) return;
    _body(response);
  }

  Future<String> uploadMyProductImage(XFile file) async {
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('La imagen debe pesar como máximo 5 MB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('La imagen debe pesar como máximo 5 MB.');
    }
    final String mime;
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      mime = 'image/jpeg';
    } else if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      mime = 'image/png';
    } else if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      mime = 'image/webp';
    } else {
      throw const FormatException('Selecciona una imagen JPEG, PNG o WebP.');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/api/catalog/my/products/image'),
    );
    final headers = await _headers;
    headers.remove('Content-Type');
    request.headers.addAll(headers);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
        contentType: MediaType.parse(mime),
      ),
    );
    final response = await _send(request.send().then(http.Response.fromStream));
    final body = _body(response);
    final key = body is Map ? body['objectKey'] : null;
    if (key is! String || key.isEmpty) {
      throw const FormatException('Respuesta de imagen inválida.');
    }
    return key;
  }

  Future<Map<String, dynamic>> getSalesSummary(
    Object restaurantId,
    String range,
  ) async {
    final uri = Uri.parse(
      '$_base/api/orders/restaurants/$restaurantId/sales-summary',
    ).replace(queryParameters: {'range': range});
    final response = await _send(http.get(uri, headers: await _headers));
    return Map<String, dynamic>.from(_body(response));
  }

  Future<Map<String, dynamic>> updateMyRestaurantOpen(
    bool acceptingOrders,
  ) async {
    final response = await _send(
      http.put(
        Uri.parse('$_base/api/catalog/my/restaurant/open-status'),
        headers: await _headers,
        body: jsonEncode({'acceptingOrders': acceptingOrders}),
      ),
    );
    return Map<String, dynamic>.from(_body(response));
  }

  Future<Map<String, dynamic>> updateMyRestaurantHours(
    List<Map<String, dynamic>> hours,
  ) async {
    final response = await _send(
      http.put(
        Uri.parse('$_base/api/catalog/my/restaurant/hours'),
        headers: await _headers,
        body: jsonEncode({'hours': hours}),
      ),
    );
    return Map<String, dynamic>.from(_body(response));
  }

  Future<List<Map<String, dynamic>>> getAvailableDeliveryOrders({
    required int restaurantId,
    int limit = 50,
  }) async {
    if (_isDemo) return _demo.availableForDelivery(restaurantId);
    final uri = Uri.parse('$_base/api/orders/available-for-delivery').replace(
      queryParameters: {'restaurant_id': '$restaurantId', 'limit': '$limit'},
    );
    final res = await _send(http.get(uri, headers: await _headers));
    return List<Map<String, dynamic>>.from(_body(res) ?? []);
  }

  /// [receptionMode] `SEGURO` pide al repartidor el PIN del cliente al entregar.
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
    if (_isDemo) {
      return _demo.createOrder(
        items:
            items ??
            [
              {'product_id': productId, 'quantity': quantity},
            ],
        address: address,
        paymentMethod: paymentMethod,
        receptionMode: receptionMode,
        estimatedMinutes: estimatedMinutes,
      );
    }
    final res = await _send(
      http.post(
        Uri.parse('$_base/api/orders'),
        headers: {
          ...await _headers,
          if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode({
          if (productId != null) 'product_id': productId,
          'quantity': quantity,
          if (items != null)
            'items': items
                .map((item) => {...item, 'product_id': item['product_id']})
                .toList(),
          'address': address,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (commune != null) 'commune': commune,
          'payment_method': paymentMethod,
          'receptionMode': receptionMode,
          if (distanceKm != null) 'distance_km': distanceKm,
          if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
        }),
      ),
    );
    return _response(res);
  }

  Future<Map<String, dynamic>> getOrderDetail(Object orderId) async {
    if (_isDemo) return _demo.orderDetail(orderId);
    final res = await _send(
      http.get(
        Uri.parse('$_base/api/orders/$orderId'),
        headers: await _headers,
      ),
    );
    return Map<String, dynamic>.from(_body(res) ?? {});
  }

  Future<ResponseApi> updateOrderStatus(
    Object orderId,
    String status, {
    String? deliveryPin,
  }) async {
    if (_isDemo) return _demo.updateStatus(orderId, status);
    final res = await _send(
      http.put(
        Uri.parse('$_base/api/orders/$orderId/status'),
        headers: await _headers,
        body: jsonEncode({
          'status': status,
          if (deliveryPin != null && deliveryPin.isNotEmpty)
            'delivery_pin': deliveryPin,
        }),
      ),
    );
    return _response(res);
  }

  /// Cierra la entrega con el PIN de 6 dígitos que ve el cliente.
  /// Errores: 409 pedido no disponible, 422 código incorrecto (o renovado),
  /// 423 entrega bloqueada.
  Future<ResponseApi> deliverOrder(Object orderId, String code) async {
    if (_isDemo) return _demo.deliver(orderId, code);
    final res = await _send(
      http.post(
        Uri.parse('$_base/api/orders/$orderId/deliver'),
        headers: await _headers,
        body: jsonEncode({'code': code}),
      ),
    );
    return _response(res);
  }

  Future<ResponseApi> releaseOrder(Object orderId, String reason) async {
    final res = await _send(
      http.post(
        Uri.parse('$_base/api/orders/$orderId/release'),
        headers: await _headers,
        body: jsonEncode({'reason': reason}),
      ),
    );
    return _response(res);
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path, {
    Object? body,
  }) async {
    final request = http.Request(method, Uri.parse('$_base$path'));
    request.headers.addAll(await _headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await _send(request.send().then(http.Response.fromStream));
    if (response.statusCode == 204) return {};
    final data = _body(response);
    if (data is! Map) {
      throw const FormatException('Respuesta del servidor inválida.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> quoteOrder({
    required List<Map<String, dynamic>> items,
    required double latitude,
    required double longitude,
  }) => _jsonRequest(
    'POST',
    '/api/orders/delivery-quote',
    body: {'items': items, 'latitude': latitude, 'longitude': longitude},
  );

  Future<Map<String, dynamic>> getPayment(Object orderId) =>
      _jsonRequest('GET', '/api/orders/$orderId/payments');
  Future<Map<String, dynamic>> retryPayment(Object orderId) =>
      _jsonRequest('POST', '/api/orders/$orderId/payments');
  Future<Map<String, dynamic>> resolveTestPayment(
    String transactionId,
    bool approved,
  ) => _jsonRequest(
    'POST',
    '/api/payments/fake/${Uri.encodeComponent(transactionId)}/resolve',
    body: {'outcome': approved ? 'APPROVED' : 'REJECTED'},
  );

  Future<Map<String, dynamic>> getProfile() =>
      _jsonRequest('GET', '/auth/profile');
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String lastName,
    required String phone,
  }) => _jsonRequest(
    'PUT',
    '/auth/profile',
    body: {'name': name, 'lastName': lastName, 'phone': phone},
  );

  Future<Uint8List?> getProfilePhoto({String? version}) async {
    final uri = Uri.parse(
      '$_base/auth/profile/photo',
    ).replace(queryParameters: version == null ? null : {'v': version});
    final response = await _send(http.get(uri, headers: await _headers));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      _body(response);
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> uploadProfilePhoto(XFile file) async {
    if (await file.length() > 2 * 1024 * 1024) {
      throw const FormatException('La foto debe pesar como máximo 2 MB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      throw const FormatException('La foto debe pesar entre 1 byte y 2 MB.');
    }
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
    final png =
        bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == pngSignature[i]).every((v) => v);
    if (!jpeg && !png) {
      throw const FormatException('Selecciona una foto JPEG o PNG.');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/auth/profile/photo'),
    );
    final headers = await _headers;
    headers.remove('Content-Type');
    request.headers.addAll(headers);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
        contentType: MediaType('image', jpeg ? 'jpeg' : 'png'),
      ),
    );
    final response = await _send(request.send().then(http.Response.fromStream));
    return Map<String, dynamic>.from(_body(response));
  }

  Future<void> deleteProfilePhoto() async {
    await _jsonRequest('DELETE', '/auth/profile/photo');
  }

  Future<Map<String, dynamic>> pendingReviews(Object orderId) =>
      _jsonRequest('GET', '/api/reviews/pending/$orderId');
  Future<Map<String, dynamic>> createReview({
    required int orderId,
    required String targetType,
    required int rating,
    String? comment,
  }) => _jsonRequest(
    'POST',
    '/api/reviews',
    body: {
      'orderId': orderId,
      'targetType': targetType,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    },
  );
  Future<Map<String, dynamic>> myReviews({int page = 0}) =>
      _jsonRequest('GET', '/api/users/me/reviews?page=$page&size=20');
  Future<Map<String, dynamic>> targetReviews(
    int restaurantId, {
    int page = 0,
  }) => _jsonRequest(
    'GET',
    '/api/reviews/TIENDA/$restaurantId?page=$page&size=20',
  );
  Future<void> reportCourierLocation(
    double latitude,
    double longitude,
    DateTime recordedAt,
  ) async {
    await _jsonRequest(
      'POST',
      '/api/delivery/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>> routeLocation(Object routeId) =>
      _jsonRequest('GET', '/api/delivery/routes/$routeId/location');

  Future<ResponseApi> cancelAfterPickup(
    Object orderId,
    String reason,
    String status,
  ) async {
    final res = await _send(
      http.post(
        Uri.parse('$_base/api/orders/$orderId/cancel-after-pickup'),
        headers: await _headers,
        body: jsonEncode({'reason': reason, 'status': status}),
      ),
    );
    return _response(res);
  }

  Future<ResponseApi> deleteAccount(String password) async {
    final res = await _send(
      http.delete(
        Uri.parse('$_base/auth/account'),
        headers: await _headers,
        body: jsonEncode({'password': password}),
      ),
    );
    if (res.statusCode == 202) {
      return ResponseApi(success: true, statusCode: 202);
    }
    return _response(res);
  }

  Future<ResponseApi> claimDeliveryOrders({required List<int> orderIds}) async {
    if (_isDemo) return _demo.claim(orderIds);
    final res = await _send(
      http.post(
        Uri.parse('$_base/api/delivery/claim'),
        headers: await _headers,
        // Delivery derives the courier from the JWT. Its public DTO is camelCase.
        body: jsonEncode({'orderIds': orderIds}),
      ),
    );
    return _response(res);
  }

  ResponseApi _response(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      return ResponseApi(
        success:
            response.statusCode >= 200 &&
            response.statusCode < 300 &&
            body['success'] != false,
        message: body['message']?.toString(),
        data: body['data'],
        statusCode: response.statusCode,
        error: (body['code'] ?? body['error'])?.toString(),
        remainingAttempts: (body['remainingAttempts'] as num?)?.toInt(),
        codeRenewed: body['codeRenewed'] as bool?,
      );
    } catch (_) {
      return ResponseApi(
        success: false,
        message: 'Respuesta invalida del servidor',
        statusCode: response.statusCode,
      );
    }
  }
}
