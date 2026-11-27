String? assignedCourierId(Map<String, dynamic> order) {
  final raw = order['deliveryId'];
  if (raw is! String && raw is! num) return null;
  final id = '$raw'.trim();
  if (id.isEmpty ||
      id.toLowerCase() == 'null' ||
      id == '00000000-0000-0000-0000-000000000000') {
    return null;
  }
  final numeric = num.tryParse(id);
  if (numeric != null && (!numeric.isFinite || numeric <= 0)) return null;
  return id;
}
