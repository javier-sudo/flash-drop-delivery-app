import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/users_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/services/delivery_address_store.dart';

/// Sesión del usuario: el perfil queda en GetStorage y los tokens en
/// almacenamiento seguro. Renueva el access token antes de que venza.
class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  static const _accessTokenKey = 'flashdrop_access_token';
  static const _refreshTokenKey = 'flashdrop_refresh_token';

  /// Claves locales de la sesión: se borran al salir para que el siguiente
  /// usuario del equipo no herede rol, dirección ni ruta activa.
  static const sessionKeys = [
    'user',
    'token',
    'selected_role',
    'deliveryAddress',
    'delivery_address',
    'saved_addresses',
    DeliveryAddressStore.ownerKey,
    'driver_active_orders',
    'checkout_attempt',
  ];

  final _storage = GetStorage();
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  UsersProvider? _usersProvider;
  Future<String?>? _refreshing;

  UsersProvider get _users => _usersProvider ??= UsersProvider();

  @visibleForTesting
  set usersProvider(UsersProvider? provider) => _usersProvider = provider;

  Future<bool> restoreSession() async {
    final rawUser = _storage.read('user');
    if (rawUser is! Map || rawUser.isEmpty) return false;

    await _migrateLegacySession(Map<String, dynamic>.from(rawUser));
    if (await accessToken(forceRefresh: true) == null) {
      await clearSession();
      return false;
    }
    try {
      await DeliveryAddressStore.instance.restoreCurrent(migrateLegacy: true);
    } catch (_) {
      await DeliveryAddressStore.instance.clearActive();
      debugPrint('No se pudieron restaurar las direcciones guardadas.');
    }
    return true;
  }

  Future<Map<String, String>> authorizedHeaders() async {
    final token = await accessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> saveAuthenticatedSession(Map<String, dynamic> payload) async {
    final accessToken = payload['accessToken']?.toString();
    final refreshToken = payload['refreshToken']?.toString();
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw const FormatException('La respuesta de sesión no contiene tokens');
    }

    final user = Map<String, dynamic>.from(payload)
      ..remove('accessToken')
      ..remove('refreshToken')
      ..remove('token')
      ..remove('session_token');
    try {
      await DeliveryAddressStore.instance.archiveCurrent();
    } catch (_) {
      debugPrint('No se pudo respaldar la dirección de la sesión anterior.');
    }
    await DeliveryAddressStore.instance.clearActive();
    await _storage.write('user', user);
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.remove('token');
    try {
      await DeliveryAddressStore.instance.restoreCurrent();
    } catch (_) {
      await DeliveryAddressStore.instance.clearActive();
      debugPrint('No se pudieron restaurar las direcciones de esta cuenta.');
    }
  }

  Future<void> clearSession({bool forgetAddresses = false}) async {
    try {
      if (forgetAddresses) {
        await DeliveryAddressStore.instance.forgetCurrent();
      } else {
        await DeliveryAddressStore.instance.archiveCurrent();
      }
    } catch (_) {
      // Preference storage must never prevent clearing authentication.
      debugPrint('No se pudo actualizar el respaldo local de direcciones.');
    }
    await Future.wait([
      for (final key in sessionKeys) _storage.remove(key),
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
    ]);
  }

  Future<String?> accessToken({bool forceRefresh = false}) async {
    final token = await _secureStorage.read(key: _accessTokenKey);
    if (token == null || token.isEmpty) return null;
    // El backend demo no emite JWT ni tiene /auth/refresh.
    if (Environment.useDemoMode) return token;
    if (!forceRefresh && !_expiresSoon(token)) return token;

    final refreshed = await _refresh();
    if (refreshed != null) return refreshed;

    // A rejected refresh token clears the session. For a transient network
    // failure, keep the existing token so the next retry can recover.
    final currentRefreshToken = await _secureStorage.read(
      key: _refreshTokenKey,
    );
    return currentRefreshToken == null || currentRefreshToken.isEmpty
        ? null
        : token;
  }

  Future<void> _migrateLegacySession(Map<String, dynamic> user) async {
    final storedAccessToken = await _secureStorage.read(key: _accessTokenKey);
    final storedRefreshToken = await _secureStorage.read(key: _refreshTokenKey);
    final legacyAccessToken =
        _storage.read('token')?.toString() ??
        user['accessToken']?.toString() ??
        user['token']?.toString() ??
        user['session_token']?.toString();
    final legacyRefreshToken = user['refreshToken']?.toString();

    if ((storedAccessToken == null || storedAccessToken.isEmpty) &&
        legacyAccessToken != null &&
        legacyAccessToken.isNotEmpty) {
      await _secureStorage.write(
        key: _accessTokenKey,
        value: legacyAccessToken,
      );
    }
    if ((storedRefreshToken == null || storedRefreshToken.isEmpty) &&
        legacyRefreshToken != null &&
        legacyRefreshToken.isNotEmpty) {
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: legacyRefreshToken,
      );
    }

    user
      ..remove('accessToken')
      ..remove('refreshToken')
      ..remove('token')
      ..remove('session_token');
    await _storage.write('user', user);
    await _storage.remove('token');
  }

  Future<String?> _refresh() {
    return _refreshing ??= _refreshToken().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<String?> _refreshToken() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final result = await _users.refreshSession(refreshToken);
    if (result.isSuccess) {
      await _secureStorage.write(
        key: _accessTokenKey,
        value: result.accessToken,
      );
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: result.refreshToken,
      );
      return result.accessToken;
    }
    if (result.isInvalid) {
      // La app, el servicio en primer plano y el sondeo de segundo plano
      // comparten los tokens. Si otro renovó primero, este refresh token ya
      // fue rotado: se usa el nuevo en vez de cerrar la sesión.
      final current = await _secureStorage.read(key: _refreshTokenKey);
      if (current != null && current.isNotEmpty && current != refreshToken) {
        return _secureStorage.read(key: _accessTokenKey);
      }
      await clearSession();
    }
    return null;
  }

  bool _expiresSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      final expiresAt = decoded is Map ? decoded['exp'] : null;
      if (expiresAt is! num) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        expiresAt.toInt() * 1000,
      );
      return DateTime.now().isAfter(
        expiry.subtract(const Duration(minutes: 1)),
      );
    } catch (_) {
      return true;
    }
  }
}
