import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Estado de los avisos compartido entre la app, el servicio en primer plano
/// y el sondeo de segundo plano.
///
/// Cada uno corre en su propio isolate. GetStorage guarda una copia en memoria
/// por isolate, así que uno no vería lo que avisó el otro y el aviso saldría
/// repetido. [SharedPreferencesAsync] no guarda copia: siempre lee del disco.
abstract class NoticeStore {
  static NoticeStore instance = PrefsNoticeStore();

  Future<Map<String, dynamic>?> readState(String key);
  Future<void> writeState(String key, Map<String, dynamic> state);
  Future<void> remove(String key);

  /// Interruptor "Disponible" del repartidor (lo lee también el servicio).
  Future<bool> driverAvailable();
  Future<void> setDriverAvailable(bool value);
}

class PrefsNoticeStore implements NoticeStore {
  static const _prefix = 'flashdrop.notices.';
  static const _driverAvailableKey = 'flashdrop.driver_available';

  final _prefs = SharedPreferencesAsync();

  @override
  Future<Map<String, dynamic>?> readState(String key) async {
    final raw = await _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      // Estado dañado: se trata como primera consulta (no avisa nada).
      return null;
    }
  }

  @override
  Future<void> writeState(String key, Map<String, dynamic> state) =>
      _prefs.setString('$_prefix$key', jsonEncode(state));

  @override
  Future<void> remove(String key) => _prefs.remove('$_prefix$key');

  @override
  Future<bool> driverAvailable() async =>
      await _prefs.getBool(_driverAvailableKey) ?? true;

  @override
  Future<void> setDriverAvailable(bool value) =>
      _prefs.setBool(_driverAvailableKey, value);
}

/// Para pruebas: guarda en memoria, con ida y vuelta por JSON como el disco.
class MemoryNoticeStore implements NoticeStore {
  final values = <String, String>{};
  bool available = true;

  @override
  Future<Map<String, dynamic>?> readState(String key) async {
    final raw = values[key];
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<void> writeState(String key, Map<String, dynamic> state) async =>
      values[key] = jsonEncode(state);

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<bool> driverAvailable() async => available;

  @override
  Future<void> setDriverAvailable(bool value) async => available = value;
}
