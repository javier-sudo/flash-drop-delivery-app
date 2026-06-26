import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';

class AppProvider {
  final String _base = Environment.apiUrl;

  Future<List<Map<String, dynamic>>> getProducts() async {
    final res = await http.get(Uri.parse('$_base/api/products'));
    final body = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(body['data'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getOrders({int? userId}) async {
    final uri = Uri.parse(
      '$_base/api/orders',
    ).replace(queryParameters: userId == null ? null : {'user_id': '$userId'});
    final res = await http.get(uri);
    final body = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(body['data'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getDeliveryRoutes() async {
    final res = await http.get(Uri.parse('$_base/api/delivery/routes'));
    final body = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(body['data'] ?? []);
  }

  Future<ResponseApi> createOrder({
    int? productId,
    int quantity = 1,
    List<Map<String, dynamic>>? items,
    required String address,
    String paymentMethod = 'Efectivo',
    int? userId,
    double? distanceKm,
    int? estimatedMinutes,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/api/orders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (productId != null) 'product_id': productId,
        'quantity': quantity,
        if (items != null) 'items': items,
        'address': address,
        'payment_method': paymentMethod,
        if (userId != null) 'user_id': userId,
        if (distanceKm != null) 'distance_km': distanceKm,
        if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
      }),
    );
    return ResponseApi.fromJson(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>> getOrderDetail(int orderId) async {
    final res = await http.get(Uri.parse('$_base/api/orders/$orderId'));
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<ResponseApi> updateOrderStatus(int orderId, String status) async {
    final res = await http.put(
      Uri.parse('$_base/api/orders/$orderId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
    return ResponseApi.fromJson(jsonDecode(res.body));
  }

  Future<ResponseApi> claimDeliveryOrders({
    required int userId,
    required List<int> orderIds,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/api/delivery/claim'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'order_ids': orderIds}),
    );
    return ResponseApi.fromJson(jsonDecode(res.body));
  }
}
