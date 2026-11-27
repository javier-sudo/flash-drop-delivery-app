// lib/src/providers/users_provider.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/services/connection_service.dart';

class UsersProvider {
  /// [client] permite inyectar un cliente HTTP (tests); por defecto se usa
  /// el del paquete `http`.
  UsersProvider({http.Client? client}) : _client = client;

  final String _base = Environment.apiUrl;
  final http.Client? _client;

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    final client = _client;
    return client != null
        ? client.post(uri, headers: headers, body: body)
        : http.post(uri, headers: headers, body: body);
  }

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      final response = await request.timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 500) {
        ConnectionService.instance.markOnline();
      } else {
        ConnectionService.instance.markOffline();
      }
      return response;
    } catch (_) {
      ConnectionService.instance.markOffline();
      rethrow;
    }
  }

  Future<ResponseApi> login({
    required String login,
    required String password,
  }) async {
    final uri = Uri.parse('$_base/auth/login');
    final res = await _send(
      _post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login': login, 'password': password}),
      ),
    );

    return _fromResponse(res, mapLoginResult: true);
  }

  Future<SessionRefreshResult> refreshSession(String refreshToken) async {
    try {
      final response = await _send(
        _post(
          Uri.parse('$_base/auth/refresh'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        ),
      );
      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : body;
      final accessToken = data['accessToken']?.toString();
      final nextRefreshToken = data['refreshToken']?.toString();

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          accessToken != null &&
          accessToken.isNotEmpty &&
          nextRefreshToken != null &&
          nextRefreshToken.isNotEmpty) {
        return SessionRefreshResult.success(
          accessToken: accessToken,
          refreshToken: nextRefreshToken,
        );
      }
      return SessionRefreshResult.failure(response.statusCode);
    } catch (_) {
      return const SessionRefreshResult.failure(null);
    }
  }

  Future<ResponseApi> registerWithImage({
    required String email,
    String? rut,
    required String name,
    required String lastName, // backend: last_name
    required String phone,
    required String password,
    File? image, // opcional
  }) async {
    final res = await _send(
      _post(
        Uri.parse('$_base/auth/register'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'rut': rut,
          'name': name,
          'lastName': lastName,
          'phone': phone,
          'password': password,
        }),
      ),
    );
    return _fromResponse(res);
  }

  /// Pide el correo de recuperación (`POST /auth/password/forgot`).
  ///
  /// Auth responde 202 sin cuerpo exista o no el correo, así que la app no
  /// puede ni debe distinguir esos casos: solo informa que se procesó.
  Future<PasswordResetRequestResult> requestPasswordReset(String email) async {
    try {
      final res = await _send(
        _post(
          Uri.parse('$_base/auth/password/forgot'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        ),
      );
      final code = res.statusCode;
      if (code >= 200 && code < 300) return PasswordResetRequestResult.sent;
      if (code == 400 || code == 422) {
        return PasswordResetRequestResult.invalidEmail;
      }
      if (code == 429) return PasswordResetRequestResult.tooManyRequests;
      return PasswordResetRequestResult.serverError;
    } catch (_) {
      return PasswordResetRequestResult.network;
    }
  }

  // si luego quieres actualizar solo la foto:
  Future<ResponseApi> updatePhoto({
    required File image,
    required String token, // 'JWT ...'
  }) async {
    return ResponseApi(
      success: false,
      message: 'La API de Auth aun no ofrece carga de foto de perfil.',
    );
  }

  ResponseApi _fromResponse(
    http.Response response, {
    bool mapLoginResult = false,
  }) {
    try {
      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ResponseApi(
          success: false,
          message:
              body['message']?.toString() ??
              'Error HTTP ${response.statusCode}',
          data: body,
        );
      }
      if (mapLoginResult) {
        // El Gateway puede envolver la respuesta en `data`.
        final payload = body['data'] is Map
            ? Map<String, dynamic>.from(body['data'] as Map)
            : body;
        return ResponseApi(
          success: true,
          data: {
            'id': payload['userId'],
            'name': payload['name'],
            'email': payload['email'],
            'roles': payload['roles'] ?? <dynamic>[],
            'accessToken': payload['accessToken'],
            'refreshToken': payload['refreshToken'],
          },
        );
      }
      return ResponseApi(
        success: true,
        data: body,
        message: body['message']?.toString(),
      );
    } catch (_) {
      return ResponseApi(
        success: false,
        message: 'Respuesta invalida del servidor',
      );
    }
  }
}

class SessionRefreshResult {
  final String? accessToken;
  final String? refreshToken;
  final int? statusCode;

  const SessionRefreshResult._({
    required this.accessToken,
    required this.refreshToken,
    required this.statusCode,
  });

  const SessionRefreshResult.success({
    required String accessToken,
    required String refreshToken,
  }) : this._(
         accessToken: accessToken,
         refreshToken: refreshToken,
         statusCode: 200,
       );

  const SessionRefreshResult.failure(int? statusCode)
    : this._(accessToken: null, refreshToken: null, statusCode: statusCode);

  bool get isSuccess => accessToken != null && refreshToken != null;

  /// 401/403: el refresh token ya no sirve y hay que volver a iniciar sesión.
  bool get isInvalid => statusCode == 401 || statusCode == 403;
}

/// Resultado de pedir el correo de recuperación de contraseña.
enum PasswordResetRequestResult {
  /// Auth aceptó la solicitud (no indica si el correo existe).
  sent,

  /// El backend rechazó el formato del correo.
  invalidEmail,

  /// Límite de solicitudes por IP o por correo (HTTP 429).
  tooManyRequests,

  /// Error del servidor o respuesta inesperada.
  serverError,

  /// Sin respuesta: timeout o sin conexión.
  network,
}
