// lib/src/providers/users_provider.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';

class UsersProvider {
  final String _base = Environment.apiUrl;

  Future<ResponseApi> login({
    required String login,
    required String password,
  }) async {
    final uri = Uri.parse('$_base/auth/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login': login, 'password': password}),
    );

    return _fromResponse(res, mapLoginResult: true);
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
    final res = await http.post(
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

  ResponseApi _fromResponse(http.Response response, {bool mapLoginResult = false}) {
    try {
      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ResponseApi(
          success: false,
          message: body['message']?.toString() ?? 'Error HTTP ${response.statusCode}',
          data: body,
        );
      }
      if (mapLoginResult) {
        return ResponseApi(
          success: true,
          data: {
            'id': body['userId'],
            'name': body['name'],
            'email': body['email'],
            'roles': body['roles'] ?? <dynamic>[],
            'accessToken': body['accessToken'],
            'refreshToken': body['refreshToken'],
          },
        );
      }
      return ResponseApi(success: true, data: body, message: body['message']?.toString());
    } catch (_) {
      return ResponseApi(success: false, message: 'Respuesta invalida del servidor');
    }
  }
}
