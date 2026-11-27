import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/delivery_order_sort.dart';

void main() {
  final orders = <Map<String, dynamic>>[
    {'orderId': 23, 'total': 3734, 'distanceKm': null},
    {'orderId': 77, 'total': 20000, 'distanceKm': 8.0},
    {'orderId': 78, 'total': 13490, 'distanceKm': 2.5},
    {'orderId': 32, 'total': null, 'distanceKm': 0.0},
  ];
  List<Object?> ids(DeliveryOrderSort sort) => sortDeliveryOrders(
    orders,
    sort,
  ).map((order) => order['orderId']).toList();

  test('sin fecha ordena por número como aproximación', () {
    expect(ids(DeliveryOrderSort.newest), [78, 77, 32, 23]);
    expect(ids(DeliveryOrderSort.oldest), [23, 32, 77, 78]);
  });

  test('con fechas usa la creación y no la última actualización', () {
    final timed = [
      {
        'orderId': 5,
        'createdAt': '2026-11-16T10:00:00Z',
        'updatedAt': '2026-11-17T10:00:00Z',
      },
      {'orderId': 1, 'createdAt': '2026-11-16T11:00:00Z'},
    ];
    expect(
      sortDeliveryOrders(timed, DeliveryOrderSort.newest).first['orderId'],
      1,
    );
    expect(
      sortDeliveryOrders(timed, DeliveryOrderSort.oldest).first['orderId'],
      5,
    );
  });

  test('si falta alguna fecha usa números para mantener orden coherente', () {
    final mixed = [
      {'orderId': 10, 'createdAt': '2026-11-16T10:00:00Z'},
      {'orderId': 20},
    ];
    expect(
      sortDeliveryOrders(mixed, DeliveryOrderSort.newest).first['orderId'],
      20,
    );
  });

  test('ordena por total y coloca los totales desconocidos al final', () {
    expect(ids(DeliveryOrderSort.highestTotal), [77, 78, 23, 32]);
    expect(ids(DeliveryOrderSort.lowestTotal), [23, 78, 77, 32]);
  });

  test('0 y distancias ausentes quedan al final en ambos sentidos', () {
    expect(ids(DeliveryOrderSort.shortestRoute), [78, 77, 32, 23]);
    expect(ids(DeliveryOrderSort.longestRoute), [77, 78, 32, 23]);
    expect(deliveryOrderDistance({'distanceKm': 0}), isNull);
  });
}
