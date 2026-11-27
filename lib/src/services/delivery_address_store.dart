import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/delivery_destination.dart';

/// Account-scoped encrypted preferences; active keys remain compatible with the UI.
class DeliveryAddressStore {
  DeliveryAddressStore._();
  static final instance = DeliveryAddressStore._();
  static const ownerKey = 'delivery_address_owner';
  static const activeKeys = [
    'delivery_address',
    'deliveryAddress',
    'saved_addresses',
    ownerKey,
  ];
  final _box = GetStorage();
  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? get currentOwner {
    final user = _box.read('user');
    if (user is! Map) return null;
    final id = '${user['id'] ?? user['userId'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    return '${Environment.apiUrl}|$id';
  }

  String _key(String owner) =>
      'flashdrop_addresses_v1_${Uri.encodeComponent(owner)}';

  Map<String, dynamic>? _entry(Object? raw) {
    if (raw is! Map) return null;
    final address = '${raw['address'] ?? ''}'.trim();
    if (address.isEmpty) return null;
    final latitude = double.tryParse('${raw['lat']}');
    final longitude = double.tryParse('${raw['lng']}');
    return {
      'address': address,
      'commune': '${raw['commune'] ?? ''}'.trim(),
      'lat': latitude != null && latitude.isFinite ? latitude : null,
      'lng': longitude != null && longitude.isFinite ? longitude : null,
      'label': raw['label']?.toString(),
    };
  }

  List<Map<String, dynamic>> _saved(Object? raw) => raw is List
      ? raw.map(_entry).whereType<Map<String, dynamic>>().take(5).toList()
      : [];

  Map<String, dynamic> _snapshot() {
    final legacy = _box.read('deliveryAddress');
    return {
      'selected':
          _entry(_box.read('delivery_address')) ??
          (legacy is String && legacy.trim().isNotEmpty
              ? {'address': legacy.trim()}
              : null),
      'saved': _saved(_box.read('saved_addresses')),
    };
  }

  Future<Map<String, dynamic>?> _read(String owner) async {
    final raw = await _secure.read(key: _key(owner));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> archiveCurrent() async {
    final owner = currentOwner;
    final activeOwner = _box.read(ownerKey);
    if (owner == null || (activeOwner != null && activeOwner != owner)) return;
    // Background isolates may hold an older active snapshot than the selector.
    if (await _read(owner) != null) return;
    final snapshot = _snapshot();
    // An empty active cache must not erase an existing account archive.
    if (snapshot['selected'] == null && (snapshot['saved'] as List).isEmpty) {
      return;
    }
    await _secure.write(key: _key(owner), value: jsonEncode(snapshot));
  }

  Future<void> clearActive() async {
    await Future.wait([for (final key in activeKeys) _box.remove(key)]);
  }

  Future<void> _activate(Map<String, dynamic> snapshot, String? owner) async {
    final selected = _entry(snapshot['selected']);
    await Future.wait([
      _box.write(ownerKey, owner),
      _box.write('saved_addresses', _saved(snapshot['saved'])),
      if (selected != null) ...[
        _box.write('deliveryAddress', selected['address']),
        _box.write('delivery_address', selected),
      ] else ...[
        _box.remove('deliveryAddress'),
        _box.remove('delivery_address'),
      ],
    ]);
  }

  Future<void> restoreCurrent({bool migrateLegacy = false}) async {
    final owner = currentOwner;
    if (owner == null) {
      await clearActive();
      return;
    }
    var snapshot = await _read(owner);
    if (snapshot == null && migrateLegacy) {
      await archiveCurrent();
      snapshot = await _read(owner);
    }
    if (currentOwner != owner) return;
    await clearActive();
    if (currentOwner == owner && snapshot != null) {
      await _activate(snapshot, owner);
    }
  }

  Future<void> select(
    Map<String, dynamic> raw, {
    bool bookmark = false,
    required String? expectedOwner,
  }) async {
    final entry = _entry(raw);
    if (DeliveryDestination.fromStorage(entry) == null) {
      throw const FormatException('Confirma la dirección, el pin y la comuna.');
    }
    final owner = currentOwner;
    if (owner != expectedOwner) {
      throw StateError('La cuenta cambió. Abre nuevamente las direcciones.');
    }
    final activeOwner = _box.read(ownerKey);
    final saved = activeOwner == null || activeOwner == owner
        ? _saved(_box.read('saved_addresses'))
        : <Map<String, dynamic>>[];
    if (bookmark) {
      saved.removeWhere((row) => row['label'] == entry!['label']);
      saved.insert(0, entry!);
    }
    final snapshot = {'selected': entry, 'saved': saved.take(5).toList()};
    // Persist before dismissing the selector; never report an unconfirmed save.
    if (owner != null) {
      await _secure.write(key: _key(owner), value: jsonEncode(snapshot));
    }
    if (owner != currentOwner) {
      throw StateError('La cuenta cambió. Abre nuevamente las direcciones.');
    }
    await _activate(snapshot, owner);
  }

  Future<void> forgetCurrent() async {
    final owner = currentOwner;
    if (owner != null) await _secure.delete(key: _key(owner));
  }
}
