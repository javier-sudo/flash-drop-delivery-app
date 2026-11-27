class CheckoutQuote {
  const CheckoutQuote({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  });
  final double subtotal;
  final double deliveryFee;
  final double total;

  factory CheckoutQuote.fromJson(Map<String, dynamic> data) {
    double read(String key) {
      final value = double.tryParse('${data[key]}');
      if (value == null || !value.isFinite || value < 0) {
        throw const FormatException('Cotización inválida.');
      }
      return value;
    }

    final subtotal = read('subtotal');
    final delivery = read('deliveryFee');
    final total = read('total');
    if ((subtotal + delivery - total).abs() > 0.01) {
      throw const FormatException('El total de la cotización no coincide.');
    }
    return CheckoutQuote(
      subtotal: subtotal,
      deliveryFee: delivery,
      total: total,
    );
  }
}
