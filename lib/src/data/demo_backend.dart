import 'dart:math';

import 'package:proyecto_app_delivery_gessof/src/data/demo_data.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';

/// Backend en memoria para el modo prototipo (USE_DEMO_MODE=true).
/// Responde con la misma forma que el API Gateway (Orders y Delivery) para que
/// las pantallas de cliente, restaurante y repartidor funcionen sin servidor.
class DemoBackend {
  DemoBackend._() {
    _seed();
  }
  static final DemoBackend instance = DemoBackend._();

  static const _latency = Duration(milliseconds: 350);
  static const deliveryFee = 2500;

  /// Intentos de PIN antes de renovar el código de entrega.
  static const maxPinAttempts = 3;

  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _routes = [];
  int _sequence = 1040;
  int _routeSequence = 500;
  final _random = Random();

  Future<T> _delay<T>(T value) => Future.delayed(_latency, () => value);

  // ── Catálogo ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> products() =>
      _delay(DemoData.catalogProducts.map(Map<String, dynamic>.from).toList());

  Future<List<Map<String, dynamic>>> restaurants() => _delay(
    DemoData.catalogRestaurants.map(Map<String, dynamic>.from).toList(),
  );

  // ── Orders ────────────────────────────────────────────────────────────────

  /// En demo hay un solo cliente y un solo local por usuario, así que
  /// `view` (client / restaurant) devuelve la misma lista.
  Future<List<Map<String, dynamic>>> orders({String? view}) =>
      _delay(_orders.reversed.map(_summary).toList());

  Future<Map<String, dynamic>> orderDetail(Object id) {
    final order = _findOrder(id);
    if (order == null) return Future.error(Exception('Pedido no encontrado'));
    return _delay(Map<String, dynamic>.from(order));
  }

  Future<ResponseApi> createOrder({
    required List<Map<String, dynamic>> items,
    required String address,
    required String paymentMethod,
    String receptionMode = 'SEGURO',
    int? estimatedMinutes,
  }) {
    final order = _buildOrder(
      items: items,
      address: address,
      paymentMethod: paymentMethod,
      receptionMode: receptionMode,
      estimatedMinutes: estimatedMinutes,
    );
    if (order == null) {
      return _delay(
        ResponseApi(success: false, message: 'Producto no disponible'),
      );
    }
    _orders.add(order);
    return _delay(
      ResponseApi(success: true, message: 'Pedido creado', data: order),
    );
  }

  Future<ResponseApi> updateStatus(Object id, String status) {
    final order = _findOrder(id);
    if (order == null) {
      return _delay(
        ResponseApi(success: false, message: 'Pedido no encontrado'),
      );
    }
    if (status == 'Retirado' && !_isClaimed(order)) {
      return _delay(
        ResponseApi(
          success: false,
          statusCode: 409,
          message: 'El pedido no está asignado a tu ruta',
        ),
      );
    }
    order['status'] = status;
    order['updatedAt'] = DateTime.now().toIso8601String();
    return _delay(ResponseApi(success: true, data: order));
  }

  /// Entrega con PIN: igual que `POST /api/orders/{id}/deliver`.
  Future<ResponseApi> deliver(Object id, String code) {
    final order = _findOrder(id);
    if (order == null || !_isClaimed(order)) {
      return _delay(
        ResponseApi(
          success: false,
          statusCode: 409,
          message: 'El pedido no está asignado a tu ruta',
        ),
      );
    }
    if (order['status'] != 'Retirado') {
      return _delay(
        ResponseApi(
          success: false,
          statusCode: 409,
          message: 'Primero confirma el retiro en el local',
        ),
      );
    }
    if (order['receptionMode'] == 'SEGURO' && code != order['deliveryCode']) {
      final attempts = ((order['pinAttempts'] as int?) ?? 0) + 1;
      if (attempts >= maxPinAttempts) {
        order['pinAttempts'] = 0;
        order['deliveryCode'] = _newCode();
        return _delay(
          ResponseApi(
            success: false,
            statusCode: 422,
            codeRenewed: true,
            message: 'Se agotaron los intentos y el código se renovó.',
          ),
        );
      }
      order['pinAttempts'] = attempts;
      return _delay(
        ResponseApi(
          success: false,
          statusCode: 422,
          remainingAttempts: maxPinAttempts - attempts,
          message: 'El código no coincide.',
        ),
      );
    }
    order
      ..['status'] = 'Entregado'
      ..['updatedAt'] = DateTime.now().toIso8601String()
      ..remove('pinAttempts');
    return _delay(ResponseApi(success: true, data: order));
  }

  // ── Delivery ──────────────────────────────────────────────────────────────

  /// Pedidos listos para retiro y sin repartidor, de un local.
  Future<List<Map<String, dynamic>>> availableForDelivery(int restaurantId) {
    final claimed = _routes.map((r) => r['orderId']).toSet();
    final list = _orders
        .where(
          (o) =>
              o['restaurantId'] == restaurantId &&
              o['status'] == 'Listo para retiro' &&
              !claimed.contains(o['id']),
        )
        .map(_routeView)
        .toList();
    return _delay(list);
  }

  /// Rutas del repartidor (en demo hay un solo repartidor). El estado de cada
  /// parada es el del pedido: Asignado, Retirado o Entregado.
  Future<List<Map<String, dynamic>>> routes() => _delay(
    _routes.map((r) {
      final order = _findOrder(r['orderId']);
      return {
        ...r,
        if (order != null) 'status': order['status'],
        if (order != null) 'updatedAt': order['updatedAt'],
      };
    }).toList(),
  );

  Future<ResponseApi> claim(List<int> orderIds) {
    final claimed = _routes.map((r) => r['orderId']).toSet();
    for (final id in orderIds) {
      final order = _findOrder(id);
      if (order == null ||
          order['status'] != 'Listo para retiro' ||
          claimed.contains(id)) {
        return _delay(
          ResponseApi(
            success: false,
            message: 'El pedido $id ya no está disponible',
          ),
        );
      }
    }
    for (final id in orderIds) {
      final order = _findOrder(id)!
        ..['status'] = 'Asignado'
        ..['updatedAt'] = DateTime.now().toIso8601String();
      _routes.add({..._routeView(order), 'id': ++_routeSequence});
    }
    return _delay(ResponseApi(success: true, message: 'Ruta iniciada'));
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  Map<String, dynamic>? _findOrder(Object? id) =>
      _orders.where((o) => '${o['id']}' == '$id').firstOrNull;

  bool _isClaimed(Map<String, dynamic> order) =>
      _routes.any((r) => r['orderId'] == order['id']);

  /// PIN de 6 dígitos (puede empezar con 0).
  String _newCode() => _random.nextInt(1000000).toString().padLeft(6, '0');

  Map<String, dynamic>? _buildOrder({
    required List<Map<String, dynamic>> items,
    required String address,
    required String paymentMethod,
    String receptionMode = 'SEGURO',
    int? estimatedMinutes,
    String status = 'Nuevo pedido',
    String clientName = 'Cliente demo',
    DateTime? createdAt,
  }) {
    final lines = <Map<String, dynamic>>[];
    double subtotal = 0;
    Map<String, dynamic>? restaurant;
    for (final item in items) {
      final product = DemoData.catalogProducts
          .where((p) => p['id'] == item['product_id'])
          .firstOrNull;
      if (product == null) return null;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      final total = (product['price'] as num) * quantity;
      subtotal += total;
      restaurant ??= DemoData.catalogRestaurants.firstWhere(
        (r) => r['id'] == product['restaurantId'],
      );
      lines.add({
        'name': product['name'],
        'description': product['description'],
        'quantity': quantity,
        'total': total,
      });
    }
    final id = ++_sequence;
    return {
      'id': id,
      'code': '#FD-$id',
      'status': status,
      'restaurantId': restaurant?['id'],
      'restaurantName': restaurant?['name'],
      'restaurantAddress': restaurant?['address'],
      'address': address,
      'paymentMethod': paymentMethod,
      'receptionMode': receptionMode,
      if (receptionMode == 'SEGURO') 'deliveryCode': _newCode(),
      'estimatedMinutes': estimatedMinutes ?? restaurant?['deliveryTime'] ?? 30,
      'items': lines,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': subtotal + deliveryFee,
      'clientName': clientName,
      'client': {
        'name': clientName,
        'phone': '+56 9 5555 1212',
        'email': 'cliente@demo.cl',
      },
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Map<String, dynamic> _summary(Map<String, dynamic> o) => {
    for (final key in [
      'id',
      'code',
      'status',
      'restaurantName',
      'address',
      'total',
      'clientName',
      'paymentMethod',
      'createdAt',
      'updatedAt',
    ])
      key: o[key],
    'itemsCount': (o['items'] as List).fold<int>(
      0,
      (s, i) => s + (i['quantity'] as int),
    ),
  };

  /// Forma de las rutas/pedidos que consume la pantalla del repartidor.
  Map<String, dynamic> _routeView(Map<String, dynamic> o) => {
    'orderId': o['id'],
    'code': o['code'],
    'status': o['status'],
    'restaurantName': o['restaurantName'],
    'pickupAddress': o['restaurantAddress'],
    'deliveryAddress': o['address'],
    'clientName': o['clientName'],
    'estimatedMinutes': o['estimatedMinutes'],
    'distanceKm': 2.0 + (o['id'] as int) % 5 * 0.7,
    'total': o['total'],
    'createdAt': o['createdAt'],
    'updatedAt': o['updatedAt'],
  };

  /// Pedidos de ejemplo en cada estado, para que restaurante y repartidor
  /// tengan qué mostrar al abrir la app.
  void _seed() {
    final now = DateTime.now();
    final samples = [
      (
        [101, 104],
        'Nuevo pedido',
        'Camila Torres',
        'Av. Providencia 1200, Providencia',
        3,
      ),
      (
        [102, 102],
        'Preparando',
        'Diego Pérez',
        'Los Leones 850, Providencia',
        14,
      ),
      (
        [103],
        'Listo para retiro',
        'Valentina Rojas',
        'Nueva Costanera 3900, Vitacura',
        22,
      ),
      ([101], 'Listo para retiro', 'Matías Soto', 'Av. Italia 1500, Ñuñoa', 25),
      (
        [301, 303],
        'Listo para retiro',
        'Josefa Muñoz',
        'Av. Apoquindo 3000, Las Condes',
        28,
      ),
      ([401], 'Entregado', 'Tomás Reyes', 'San Diego 900, Santiago', 180),
    ];
    for (final (products, status, client, address, minutesAgo) in samples) {
      final order = _buildOrder(
        items: [
          for (final p in products) {'product_id': p, 'quantity': 1},
        ],
        address: address,
        paymentMethod: 'Efectivo',
        status: status,
        clientName: client,
        createdAt: now.subtract(Duration(minutes: minutesAgo)),
      );
      if (order != null) _orders.add(order);
    }
  }

  /// Solo para tests: deja el backend vacío (o con los pedidos de ejemplo).
  void reset({bool seed = false}) {
    _orders.clear();
    _routes.clear();
    if (seed) _seed();
  }
}
