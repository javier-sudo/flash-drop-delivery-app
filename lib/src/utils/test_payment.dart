String? simulatedPaymentTransaction(Object? raw) {
  final uri = Uri.tryParse('${raw ?? ''}');
  if (uri == null ||
      uri.scheme != 'fake' ||
      uri.host != 'flashdrop-pay' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.pathSegments.length != 1) {
    return null;
  }
  final transaction = uri.pathSegments.single;
  return RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(transaction)
      ? transaction
      : null;
}

String? pendingSimulatedPayment(Map<String, dynamic> payment, {DateTime? now}) {
  if ('${payment['paymentStatus']}'.toUpperCase() != 'PENDIENTE' ||
      '${payment['orderStatus']}'.toLowerCase() != 'pendiente de pago') {
    return null;
  }
  final expires = DateTime.tryParse('${payment['paymentExpiresAt']}');
  if (expires == null || !expires.isAfter(now ?? DateTime.now())) return null;
  return simulatedPaymentTransaction(payment['paymentUrl']);
}

bool testOrderIsConfirmed(Map<String, dynamic> payment) =>
    '${payment['paymentStatus']}'.toUpperCase() == 'APROBADO' &&
    const [
      'nuevo pedido',
      'preparando',
      'listo para retiro',
      'retirado',
      'en camino',
      'entregado',
    ].contains('${payment['orderStatus']}'.toLowerCase());
