import 'package:flutter/material.dart';

/// Etapa de un pedido para el cliente, a partir del estado que entrega Orders.
///
/// Orden: Recibido → Preparando → Listo → En camino → Entregado.
/// "Asignado" (ya tiene repartidor pero sigue en el local) cuenta como Listo y
/// "Retirado" (el repartidor ya lo tiene) como En camino.
class OrderStage {
  final int step;
  final Color color;

  const OrderStage._(this.step, this.color);

  static const labels = [
    'Recibido',
    'Preparando',
    'Listo',
    'En camino',
    'Entregado',
  ];

  static const received = OrderStage._(0, Color(0xFF1769C2));
  static const preparing = OrderStage._(1, Color(0xFF8A5700));
  static const ready = OrderStage._(2, Color(0xFF8A5700));
  static const onTheWay = OrderStage._(3, Color(0xFF1565C0));
  static const delivered = OrderStage._(4, Color(0xFF12643D));

  factory OrderStage.of(Object? status) {
    final s = '${status ?? ''}'.toLowerCase();
    if (s.contains('entregado')) return delivered;
    if (s.contains('camino') || s.contains('retirado')) return onTheWay;
    if (s.contains('listo') || s.contains('asignado')) return ready;
    if (s.contains('preparando')) return preparing;
    return received;
  }

  bool get isDelivered => step == delivered.step;
  String get label => labels[step];

  /// Titular corto de la tarjeta amarilla del pedido.
  String get headline => switch (step) {
    0 => '¡Pedido confirmado!',
    1 => 'Preparando tu pedido',
    2 => 'Listo para retiro',
    3 => 'Va en camino',
    _ => 'Entregado',
  };

  /// Frase para la cabecera del seguimiento.
  String get message => switch (step) {
    0 => 'El comercio recibió tu pedido.',
    1 => 'El local está preparando tu pedido.',
    2 => 'Tu pedido está listo; un repartidor lo retirará pronto.',
    3 => 'Tu pedido va en camino. Ten a mano tu código de entrega.',
    _ => '¡Disfruta tu pedido!',
  };
}

/// Fecha de referencia para ordenar pedidos del más reciente al más antiguo.
DateTime orderTime(Map<String, dynamic> order) {
  final raw =
      order['updatedAt'] ??
      order['createdAt'] ??
      order['created_at'] ??
      order['updated_at'];
  return DateTime.tryParse('$raw') ?? DateTime(0);
}
