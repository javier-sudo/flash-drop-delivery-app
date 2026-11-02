import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OrderDeliveryCodeStore {
  static const _prefix = 'flashdrop_order_delivery_code_';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _key(Object orderId) => '$_prefix$orderId';

  static Future<void> save(Object orderId, String code) async {
    final normalized = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) return;
    await _storage.write(key: _key(orderId), value: normalized);
  }

  static Future<String?> read(Object orderId) =>
      _storage.read(key: _key(orderId));

  static Future<void> delete(Object orderId) =>
      _storage.delete(key: _key(orderId));
}
