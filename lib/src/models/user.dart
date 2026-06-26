import 'dart:convert';

import 'package:proyecto_app_delivery_gessof/src/models/rol.dart';

User userFromJson(String str) => User.fromJson(json.decode(str));
String userToJson(User data) => json.encode(data.toJson());

class User {
  int? id;
  String email;
  String? rut;
  String? name;
  String? lastName;
  String phone;
  String? photo;
  String? sessionToken;
  List<Rol> roles;

  User({
    this.id,
    required this.email,
    this.rut,
    this.name,
    this.lastName,
    required this.phone,
    this.photo,
    this.sessionToken,
    List<Rol>? roles,
  }) : roles = roles ?? [];

  factory User.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    return User(
      id: json['id'] is String ? int.tryParse(json['id']) : json['id'],
      email: json['email']?.toString() ?? '',
      rut: json['rut']?.toString(),
      name: json['name']?.toString(),
      lastName:
          json['last_name']?.toString() ??
          json['lastName']?.toString() ??
          json['lastname']?.toString(),
      phone: json['phone']?.toString() ?? '',
      photo: json['photo']?.toString() ?? json['image']?.toString(),
      sessionToken: json['session_token']?.toString(),
      roles: _parseRoles(rawRoles),
    );
  }

  static List<Rol> _parseRoles(dynamic rawRoles) {
    if (rawRoles is! List) return [];
    return rawRoles.map((role) {
      if (role is Map) {
        return Rol.fromJson(Map<String, dynamic>.from(role));
      }
      return Rol(id: null, name: role.toString(), image: '', route: '/home');
    }).toList();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'rut': rut,
    'name': name,
    'lastName': lastName,
    'phone': phone,
    'photo': photo,
    'session_token': sessionToken,
    'roles': roles.map((role) => role.toJson()).toList(),
  };
}
