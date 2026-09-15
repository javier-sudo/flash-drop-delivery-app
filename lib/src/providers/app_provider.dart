import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';

class AppProvider {
  final String _base = Environment.apiUrl;
  final GetStorage _storage = GetStorage();

  Map<String, String> get _headers {
    final token = _storage.read('token')?.toString();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
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

  Future<List<Map<String, dynamic>>> getProducts() async {
    final responses = await Future.wait([
      http.get(Uri.parse('$_base/catalog/products')),
      http.get(Uri.parse('$_base/catalog/restaurants')),
    ]);
    final products = List<Map<String, dynamic>>.from(_body(responses[0]) ?? []);
    final restaurants = List<Map<String, dynamic>>.from(
      _body(responses[1]) ?? [],
    );
    final restaurantsById = {
      for (final restaurant in restaurants) '${restaurant['id']}': restaurant,
    };

    return products.map((product) {
      final restaurant = restaurantsById['${product['restaurantId']}'];
      return {
        ...product,
        'categoryName':
            product['categoryName'] ??
            'Categoria ${product['categoryId'] ?? ''}',
        'restaurantName':
            product['restaurantName'] ??
            restaurant?['name'] ??
            'Restaurante ${product['restaurantId'] ?? ''}',
        'restaurantAddress':
            product['restaurantAddress'] ?? restaurant?['address'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getOrders({int? userId}) async {
    // Orders currently exposes user_id as UUID, while Auth emits a numeric
    // userId. The authenticated identity is already carried by the JWT, so
    // avoid sending an incompatible query parameter from the mobile client.
    final res = await http.get(
      Uri.parse('$_base/api/orders'),
      headers: _headers,
    );
    return List<Map<String, dynamic>>.from(_body(res) ?? []);
  }

  Future<List<Map<String, dynamic>>> getDeliveryRoutes() async {
    final res = await http.get(
      Uri.parse('$_base/api/delivery/routes'),
      headers: _headers,
    );
    return List<Map<String, dynamic>>.from(_body(res) ?? []);
  }

  Future<ResponseApi> createOrder({
    Object? productId,
    int quantity = 1,
    List<Map<String, dynamic>>? items,
    required String address,
    String paymentMethod = 'Efectivo',
    double? distanceKm,
    int? estimatedMinutes,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/api/orders'),
      headers: _headers,
      body: jsonEncode({
        if (productId != null) 'product_id': productId,
        'quantity': quantity,
        if (items != null)
          'items': items
              .map((item) => {...item, 'product_id': item['product_id']})
              .toList(),
        'address': address,
        'payment_method': paymentMethod,
        if (distanceKm != null) 'distance_km': distanceKm,
        if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
      }),
    );
    return _response(res);
  }

  Future<Map<String, dynamic>> getOrderDetail(Object orderId) async {
    final res = await http.get(
      Uri.parse('$_base/api/orders/$orderId'),
      headers: _headers,
    );
    return Map<String, dynamic>.from(_body(res) ?? {});
  }

  Future<ResponseApi> updateOrderStatus(Object orderId, String status) async {
    final res = await http.put(
      Uri.parse('$_base/api/orders/$orderId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return _response(res);
  }

  Future<ResponseApi> claimDeliveryOrders({
    required int userId,
    required List<int> orderIds,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/api/delivery/claim'),
      headers: _headers,
      body: jsonEncode({'user_id': userId, 'order_ids': orderIds}),
    );
    return _response(res);
  }

  Future<ResponseApi> updateRouteStatus(int routeId, String status) async {
    final res = await http.put(
      Uri.parse('$_base/api/delivery/routes/$routeId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
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
      );
    } catch (_) {
      return ResponseApi(
        success: false,
        message: 'Respuesta invalida del servidor',
      );
    }
  }
}
