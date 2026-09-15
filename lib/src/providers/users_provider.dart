// lib/src/providers/users_provider.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';

class UsersProvider {
  final String _base = Environment.apiUrl;

  Future<ResponseApi> login({
    required String login,
    required String password,
  }) async {
    final uri = Uri.parse('$_base/api/auth/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login': login, 'password': password}),
    );

    return ResponseApi.fromJson(jsonDecode(res.body));
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
    final uri = Uri.parse('$_base/api/auth/register');

    final req = http.MultipartRequest('POST', uri)
      ..fields['email'] = email
      ..fields['rut'] = rut ?? ''
      ..fields['name'] = name
      ..fields['last_name'] = lastName
      ..fields['phone'] = phone
      ..fields['password'] = password;

    if (image != null) {
      final ext = p.extension(image.path).toLowerCase();
      final mediaType = _mediaTypeFromExt(ext);
      req.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          image.path,
          contentType: mediaType, // ayuda al backend (avif/webp/etc.)
        ),
      );
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    // Manejo simple de códigos HTTP
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ResponseApi.fromJson(json.decode(res.body));
    }

    // Si vino error con JSON
    try {
      final j = json.decode(res.body);
      return ResponseApi.fromJson(j);
    } catch (_) {
      // Si no es JSON, devuelvo un ResponseApi genérico
      return ResponseApi(
        success: false,
        message:
            'Error HTTP ${res.statusCode}: ${res.reasonPhrase ?? 'sin detalle'}',
        data: res.body,
      );
    }
  }

  // si luego quieres actualizar solo la foto:
  Future<ResponseApi> updatePhoto({
    required File image,
    required String token, // 'JWT ...'
  }) async {
    final uri = Uri.parse('$_base/api/users/photo');
    final ext = p.extension(image.path).toLowerCase();
    final mediaType = _mediaTypeFromExt(ext);

    final req = http.MultipartRequest('PUT', uri)
      ..headers['Authorization'] = token
      ..files.add(
        await http.MultipartFile.fromPath(
          'photo',
          image.path,
          contentType: mediaType,
        ),
      );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return ResponseApi.fromJson(json.decode(res.body));
  }

  MediaType _mediaTypeFromExt(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.webp':
        return MediaType('image', 'webp');
      case '.gif':
        return MediaType('image', 'gif');
      case '.avif':
        return MediaType('image', 'avif');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}
