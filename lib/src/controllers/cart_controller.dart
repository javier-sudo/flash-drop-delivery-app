import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';

enum AddResult { added, otherRestaurant }

/// Carrito compartido entre pantallas. Solo admite productos de un local por
/// pedido (misma regla que aplicaba el catálogo anterior).
class CartController extends GetxController {
  static const deliveryFee = 2500;

  /// productId -> línea del carrito
  final lines = <int, CartLine>{}.obs;

  int? get restaurantId =>
      lines.isEmpty ? null : toInt(lines.values.first.product['restaurantId']);

  int get count => lines.values.fold(0, (sum, l) => sum + l.quantity);

  double get subtotal => lines.values.fold(0, (sum, l) => sum + l.total);

  double get total => lines.isEmpty ? 0 : subtotal + deliveryFee;

  int quantityOf(Map<String, dynamic> product) =>
      lines[toInt(product['id'])]?.quantity ?? 0;

  AddResult add(Map<String, dynamic> product, {int quantity = 1}) {
    final id = toInt(product['id']);
    if (id == null || quantity < 1) return AddResult.added;
    if (restaurantId != null &&
        restaurantId != toInt(product['restaurantId'])) {
      return AddResult.otherRestaurant;
    }
    lines[id] = CartLine(
      product: product,
      quantity: (lines[id]?.quantity ?? 0) + quantity,
    );
    return AddResult.added;
  }

  void decrement(Map<String, dynamic> product) {
    final id = toInt(product['id']);
    final current = lines[id];
    if (id == null || current == null) return;
    if (current.quantity <= 1) {
      lines.remove(id);
    } else {
      lines[id] = CartLine(
        product: current.product,
        quantity: current.quantity - 1,
      );
    }
  }

  /// Vacía el carrito y agrega el producto (al cambiar de local).
  void replaceWith(Map<String, dynamic> product, {int quantity = 1}) {
    lines.clear();
    add(product, quantity: quantity);
  }

  void clear() => lines.clear();

  /// Ítems con el formato que espera POST /api/orders.
  List<Map<String, dynamic>> toOrderItems() => lines.entries
      .map((e) => {'product_id': e.key, 'quantity': e.value.quantity})
      .toList();
}

class CartLine {
  final Map<String, dynamic> product;
  final int quantity;

  const CartLine({required this.product, required this.quantity});

  double get total => toDouble(product['price']) * quantity;
}
