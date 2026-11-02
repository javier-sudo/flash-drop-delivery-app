import 'dart:convert';

import 'package:http/http.dart' as http;
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
    if (_isDemo) return _demo.restaurants();
    final res = await _send(http.get(Uri.parse('$_base/catalog/restaurants')));
    return List<Map<String, dynamic>>.from(_body(res) ?? []);
  }

  Future<List<Map<String, dynamic>>> getAvailableDeliveryOrders({
    required int restaurantId,
    int limit = 5,
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
    String paymentMethod = 'Efectivo',
    String receptionMode = 'SEGURO',
    double? distanceKm,
    int? estimatedMinutes,
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
        headers: await _headers,
        body: jsonEncode({
          if (productId != null) 'product_id': productId,
          'quantity': quantity,
          if (items != null)
            'items': items
                .map((item) => {...item, 'product_id': item['product_id']})
                .toList(),
          'address': address,
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
        error: body['error']?.toString(),
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
