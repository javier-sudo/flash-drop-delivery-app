import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/users_provider.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  static const _accessTokenKey = 'flashdrop_access_token';
  static const _refreshTokenKey = 'flashdrop_refresh_token';

  final _storage = GetStorage();
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _usersProvider = UsersProvider();
  Future<String?>? _refreshing;

  Future<bool> restoreSession() async {
    final rawUser = _storage.read('user');
    if (rawUser is! Map || rawUser.isEmpty) return false;

    await _migrateLegacySession(Map<String, dynamic>.from(rawUser));
    return (await accessToken(forceRefresh: true)) != null;
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
    await _storage.write('user', user);
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.remove('token');
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.remove('user'),
      _storage.remove('token'),
      _storage.remove('selected_role'),
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
    ]);
  }

  Future<String?> accessToken({bool forceRefresh = false}) async {
    final token = await _secureStorage.read(key: _accessTokenKey);
    if (token == null || token.isEmpty) return null;
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

    final result = await _usersProvider.refreshSession(refreshToken);
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
    if (result.isInvalid) await clearSession();
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
