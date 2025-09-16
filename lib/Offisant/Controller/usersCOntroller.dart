import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../Global/Api_global.dart';

class User {
  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final String userCode;
  final bool isActive;
  final List<String> permissions;
  final int percent;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.userCode,
    required this.isActive,
    required this.permissions,
    required this.percent,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      role: json['role'] ?? '',
      userCode: json['user_code'] ?? '',
      isActive: json['is_active'] ?? false,
      permissions: List<String>.from(json['permissions'] ?? []),
      percent: json['percent'] ?? 0,
    );
  }
}

class UserController {

  static const String baseUrl = "${ApiConfig.baseUrl}";

 static Future<List<User>> getAllUsers() async {

   final response = await http.get(
     Uri.parse('$baseUrl/users'),
     headers: {
       'Content-Type': 'application/json',
     },
   );

   if (response.statusCode == 200) {
     print(response.body);
     print(response.body);
     final List<dynamic> jsonList = json.decode(response.body);
     return jsonList.map((json) => User.fromJson(json)).toList();
   } else {
     throw Exception('Foydalanuvchilarni yuklashda xatolik: ${response.statusCode}');
   }
 }
}
