/// Reviews uses the public numeric ID; Orders may return its encoded UUID.
int? publicOrderId(Object? value) {
  final raw = '${value ?? ''}';
  final numeric = int.tryParse(raw);
  if (numeric != null && numeric > 0) return numeric;
  final uuid = RegExp(
    r'^00000000-0000-0000-0000-([0-9a-fA-F]{12})$',
  ).firstMatch(raw);
  final id = uuid == null ? null : int.tryParse(uuid.group(1)!, radix: 16);
  return id != null && id > 0 ? id : null;
}
