/// Formatea un monto en pesos chilenos: 12990 -> "$12.990".
String clp(dynamic value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? 0;
  final rounded = number.round().abs().toString();
  final withDots = rounded.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '${number < 0 ? '-' : ''}\$$withDots';
}

double toDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

int? toInt(dynamic value) =>
    value is int ? value : int.tryParse('${value ?? ''}');
