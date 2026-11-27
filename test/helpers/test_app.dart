import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/services/notifications/notice_store.dart';
import 'package:proyecto_app_delivery_gessof/src/data/demo_backend.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';

/// Provider falso: delega en el backend demo (sin red y sin imágenes remotas).
class FakeProvider extends AppProvider {
  DemoBackend get _demo => DemoBackend.instance;
  List<Map<String, dynamic>>? lastOrderItems;
  String? lastReceptionMode;
  double? lastLatitude;
  double? lastLongitude;
  String? lastCommune;
  Set<int>? coveredRestaurantIds;
  bool storeOpen = true;
  Object? problemOrderId;
  String? problemReason;
  String? problemStatus;
  final List<int> availableLimits = [];
  List<Map<String, dynamic>> _quoteProducts = [];

  static List<Map<String, dynamic>> _noImages(
    List<Map<String, dynamic>> rows,
  ) => rows.map((r) => {...r, 'image': ''}).toList();

  @override
  Future<List<Map<String, dynamic>>> getProducts() async {
    _quoteProducts = _noImages(await _demo.products());
    return _quoteProducts;
  }

  @override
  Future<List<Map<String, dynamic>>> getRestaurants() async => _noImages(
    await _demo.restaurants(),
  ).map((r) => {...r, 'open': storeOpen}).toList();
  @override
  Future<List<Map<String, dynamic>>> getCoveredRestaurants({
    required double latitude,
    required double longitude,
  }) async {
    final stores = await getRestaurants();
    return coveredRestaurantIds == null
        ? stores
        : stores
              .where((store) => coveredRestaurantIds!.contains(store['id']))
              .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getOrders({String? view}) =>
      _demo.orders(view: view);
  @override
  Future<Map<String, dynamic>> getOrderDetail(Object orderId) =>
      _demo.orderDetail(orderId);
  @override
  Future<ResponseApi> updateOrderStatus(
    Object orderId,
    String status, {
    String? deliveryPin,
  }) => _demo.updateStatus(orderId, status);
  @override
  Future<ResponseApi> deliverOrder(Object orderId, String code) =>
      _demo.deliver(orderId, code);
  @override
  Future<ResponseApi> releaseOrder(Object orderId, String reason) async {
    problemOrderId = orderId;
    problemReason = reason;
    problemStatus = 'release';
    return ResponseApi(
      success: false,
      statusCode: 409,
      message: 'Estado cambiado',
    );
  }

  @override
  Future<ResponseApi> cancelAfterPickup(
    Object orderId,
    String reason,
    String status,
  ) async {
    problemOrderId = orderId;
    problemReason = reason;
    problemStatus = status;
    return ResponseApi(
      success: false,
      statusCode: 409,
      message: 'Estado cambiado',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getDeliveryRoutes() => _demo.routes();
  @override
  Future<List<Map<String, dynamic>>> getAvailableDeliveryOrders({
    required int restaurantId,
    int limit = 5,
  }) {
    availableLimits.add(limit);
    return _demo.availableForDelivery(restaurantId);
  }

  @override
  Future<ResponseApi> claimDeliveryOrders({required List<int> orderIds}) =>
      _demo.claim(orderIds);
  @override
  Future<Map<String, dynamic>> quoteOrder({
    required List<Map<String, dynamic>> items,
    required double latitude,
    required double longitude,
  }) async {
    final products = _quoteProducts;
    final subtotal = items.fold<double>(0, (sum, item) {
      final product = products.firstWhere((p) => p['id'] == item['product_id']);
      return sum +
          (product['price'] as num).toDouble() *
              (item['quantity'] as num).toInt();
    });
    return {
      'subtotal': subtotal,
      'deliveryFee': 2500,
      'total': subtotal + 2500,
    };
  }

  @override
  Future<ResponseApi> createOrder({
    Object? productId,
    int quantity = 1,
    List<Map<String, dynamic>>? items,
    required String address,
    String paymentMethod = 'Efectivo',
    String receptionMode = 'SEGURO',
    double? distanceKm,
    int? estimatedMinutes,
    double? latitude,
    double? longitude,
    String? commune,
    String? idempotencyKey,
  }) {
    lastOrderItems = items;
    lastReceptionMode = receptionMode;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastCommune = commune;
    return _demo.createOrder(
      items: items ?? [],
      address: address,
      paymentMethod: paymentMethod,
      receptionMode: receptionMode,
      estimatedMinutes: estimatedMinutes,
    );
  }
}

/// GetStorage necesita un directorio: se simula path_provider.
Future<void> initTestStorage() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = await Directory.systemTemp.createTemp('flashdrop_test');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => dir.path,
      );
  await GetStorage.init();
  // Tokens y PIN viven en almacenamiento seguro: en tests, en memoria.
  FlutterSecureStorage.setMockInitialValues({});
  // Estado de avisos compartido entre isolates: en tests, en memoria.
  NoticeStore.instance = MemoryNoticeStore();
}

/// Monta una página en un teléfono de 1080x2400 y espera la latencia demo.
Future<FakeProvider> pumpPage(
  WidgetTester tester,
  Widget page, {
  bool seed = false,
}) async {
  final provider = Get.put<AppProvider>(FakeProvider()) as FakeProvider;
  DemoBackend.instance.reset(seed: seed);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GetMaterialApp(theme: AppTheme.light(), home: page));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  return provider;
}
