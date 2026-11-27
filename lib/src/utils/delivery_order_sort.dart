enum DeliveryOrderSort {
  newest('Más recientes'),
  oldest('Más antiguos'),
  highestTotal('Mayor total del pedido'),
  lowestTotal('Menor total del pedido'),
  shortestRoute('Menor distancia de ruta'),
  longestRoute('Mayor distancia de ruta');

  const DeliveryOrderSort(this.label);
  final String label;
  bool get usesDistance => this == shortestRoute || this == longestRoute;
}

DateTime? deliveryOrderCreatedAt(Map<String, dynamic> order) {
  final raw = order['createdAt'] ?? order['created_at'];
  return raw == null ? null : DateTime.tryParse('$raw')?.toUtc();
}

double? deliveryOrderDistance(Map<String, dynamic> order) {
  final raw = order['distanceKm'] ?? order['distance_km'];
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  return value != null && value.isFinite && value > 0 ? value : null;
}

double? _total(Map<String, dynamic> order) {
  final raw = order['total'];
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  return value != null && value.isFinite && value >= 0 ? value : null;
}

int? _id(Map<String, dynamic> order) {
  final raw = order['orderId'] ?? order['id'];
  if (raw is int) return raw;
  final value = int.tryParse('$raw');
  if (value != null) return value;
  final code = '${order['code'] ?? ''}';
  final match = RegExp(r'^FD-0*(\d+)$', caseSensitive: false).firstMatch(code);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int _nullableCompare<T>(T? a, T? b, int Function(T, T) compare) {
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  return compare(a, b);
}

List<Map<String, dynamic>> sortDeliveryOrders(
  List<Map<String, dynamic>> orders,
  DeliveryOrderSort sort,
) {
  final sorted = List<Map<String, dynamic>>.of(orders);
  final useDates = sorted.every(
    (order) => deliveryOrderCreatedAt(order) != null,
  );
  int recent(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (useDates) {
      final byDate = deliveryOrderCreatedAt(
        b,
      )!.compareTo(deliveryOrderCreatedAt(a)!);
      if (byDate != 0) return byDate;
    }
    return _nullableCompare<int>(_id(a), _id(b), (x, y) => y.compareTo(x));
  }

  sorted.sort((a, b) {
    final result = switch (sort) {
      DeliveryOrderSort.newest => recent(a, b),
      DeliveryOrderSort.oldest =>
        useDates
            ? deliveryOrderCreatedAt(a)!.compareTo(deliveryOrderCreatedAt(b)!)
            : _nullableCompare<int>(_id(a), _id(b), (x, y) => x.compareTo(y)),
      DeliveryOrderSort.highestTotal => _nullableCompare<double>(
        _total(a),
        _total(b),
        (x, y) => y.compareTo(x),
      ),
      DeliveryOrderSort.lowestTotal => _nullableCompare<double>(
        _total(a),
        _total(b),
        (x, y) => x.compareTo(y),
      ),
      DeliveryOrderSort.shortestRoute => _nullableCompare<double>(
        deliveryOrderDistance(a),
        deliveryOrderDistance(b),
        (x, y) => x.compareTo(y),
      ),
      DeliveryOrderSort.longestRoute => _nullableCompare<double>(
        deliveryOrderDistance(a),
        deliveryOrderDistance(b),
        (x, y) => y.compareTo(x),
      ),
    };
    if (result != 0) return result;
    if (sort == DeliveryOrderSort.oldest) {
      return _nullableCompare<int>(_id(a), _id(b), (x, y) => x.compareTo(y));
    }
    return recent(a, b);
  });
  return sorted;
}
