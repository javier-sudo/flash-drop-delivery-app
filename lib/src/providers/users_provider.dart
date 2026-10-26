// lib/src/providers/users_provider.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/services/connection_service.dart';

class UsersProvider {
  final String _base = Environment.apiUrl;

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
      http.post(
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
        http.post(
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
      http.post(
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
  bool get isInvalid => statusCode == 401 || statusCode == 403;
}
