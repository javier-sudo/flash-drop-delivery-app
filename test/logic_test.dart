import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/cart_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/controllers/catalog_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/data/demo_backend.dart';
import 'package:proyecto_app_delivery_gessof/src/data/demo_data.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';

Map<String, dynamic> product(
  int id,
  int restaurantId,
  num price, {
  String category = 'Pizzas',
}) => {
  'id': id,
  'restaurantId': restaurantId,
  'price': price,
  'name': 'P$id',
  'categoryName': category,
};

void main() {
  group('clp', () {
    test('formatea miles con punto y sin decimales', () {
      expect(clp(12990), r'$12.990');
      expect(clp('2500'), r'$2.500');
      expect(clp(1234567.6), r'$1.234.568');
      expect(clp(null), r'$0');
    });
  });

  group('CartController', () {
    late CartController cart;
    setUp(() => cart = CartController());

    test('suma cantidades y calcula totales con envío', () {
      cart.add(product(1, 10, 5000));
      cart.add(product(1, 10, 5000));
      cart.add(product(2, 10, 1500), quantity: 3);
      expect(cart.count, 5);
      expect(cart.subtotal, 14500);
      expect(cart.total, 14500 + CartController.deliveryFee);
      expect(cart.toOrderItems(), [
        {'product_id': 1, 'quantity': 2},
        {'product_id': 2, 'quantity': 3},
      ]);
    });

    test('rechaza productos de otro local sin modificar el carrito', () {
      cart.add(product(1, 10, 5000));
      expect(cart.add(product(9, 99, 100)), AddResult.otherRestaurant);
      expect(cart.count, 1);
      cart.replaceWith(product(9, 99, 100));
      expect(cart.restaurantId, 99);
      expect(cart.count, 1);
    });

    test('decrementar hasta cero quita la línea y el total vuelve a 0', () {
      final p = product(1, 10, 5000);
      cart.add(p, quantity: 2);
      cart.decrement(p);
      expect(cart.quantityOf(p), 1);
      cart.decrement(p);
      expect(cart.lines, isEmpty);
      expect(cart.total, 0);
    });
  });

  group('CatalogController.buildRestaurants', () {
    test(
      'agrupa productos, usa la foto del primer producto y omite locales sin productos',
      () {
        final restaurants = CatalogController.buildRestaurants(
          [
            {'id': '1', 'name': 'Uno', 'address': 'Calle 1'},
            {'id': 2, 'name': 'Sin productos'},
            {
              'id': 3,
              'name': 'Tres',
              'image': 'https://x/tres.png',
              'rating': '4.5',
              'deliveryTime': 30,
            },
          ],
          [
            {...product(1, 1, 100, category: 'A'), 'image': ''},
            {...product(2, 1, 100, category: 'B'), 'image': 'https://x/p2.png'},
            {...product(3, 3, 100), 'image': 'https://x/p3.png'},
          ],
        );
        expect(restaurants.map((r) => r.id), [1, 3]);
        final uno = restaurants.first;
        expect(uno.image, 'https://x/p2.png');
        expect(uno.rating, isNull);
        expect(uno.deliveryTime, isNull);
        expect(uno.categories, ['A', 'B']);
        expect(uno.tagline, 'A • B');
        final tres = restaurants.last;
        expect(tres.image, 'https://x/tres.png');
        expect(tres.rating, 4.5);
        expect(tres.deliveryTime, 30);
      },
    );
  });

  group('DemoBackend', () {
    final demo = DemoBackend.instance;
    setUp(demo.reset);

    test('crea pedidos con totales calculados y los lista', () async {
      final first = DemoData.catalogProducts.first;
      final res = await demo.createOrder(
        items: [
          {'product_id': first['id'], 'quantity': 2},
        ],
        address: 'Av. Providencia 2000',
        paymentMethod: 'Efectivo',
      );
      expect(res.success, isTrue);
      final order = res.data as Map<String, dynamic>;
      expect(order['subtotal'], (first['price'] as num) * 2);
      expect(
        order['total'],
        (first['price'] as num) * 2 + DemoBackend.deliveryFee,
      );
      expect(order['status'], 'Nuevo pedido');

      final orders = await demo.orders();
      expect(orders.single['code'], order['code']);

      final updated = await demo.updateStatus(
        order['id'] as Object,
        'Preparando',
      );
      expect(updated.success, isTrue);
      expect(
        (await demo.orderDetail(order['id'] as Object))['status'],
        'Preparando',
      );
    });

    test('rechaza productos inexistentes', () async {
      final res = await demo.createOrder(
        items: [
          {'product_id': 999999, 'quantity': 1},
        ],
        address: 'x',
        paymentMethod: 'Efectivo',
      );
      expect(res.success, isFalse);
    });
  });
}
