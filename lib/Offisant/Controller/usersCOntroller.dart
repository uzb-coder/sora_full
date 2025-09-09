import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../DB/Servis/db_helper.dart';
import '../../Global/Api_global.dart';

/// USER MODELI
import 'dart:convert';

class User {
  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final String userCode;
  final String? password; // 👈 Local uchun PIN
  final bool isActive;
  final List<String> permissions;
  final int percent;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.userCode,
    this.password,
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
      password: json['password'], // agar backend yuborsa
      isActive: json['is_active'] ?? false,
      permissions: List<String>.from(json['permissions'] ?? []),
      percent: json['percent'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'user_code': userCode,
      'password': password,
      'is_active': isActive ? 1 : 0,
      'permissions': jsonEncode(permissions),
      'percent': percent,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    List<String> perms = [];
    try {
      if (map['permissions'] != null) {
        final decoded = jsonDecode(map['permissions']);
        if (decoded is List) {
          perms = List<String>.from(decoded);
        }
      }
    } catch (_) {}
    return User(
      id: map['id'] ?? '',
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      role: map['role'] ?? '',
      userCode: map['user_code'] ?? '',
      password: map['password'],
      isActive: (map['is_active'] ?? 0) == 1,
      permissions: perms,
      percent: map['percent'] ?? 0,
    );
  }
}


class UserController {
  static const String baseUrl = "${ApiConfig.baseUrl}";

  static Future<List<User>> getAllUsers({bool forceRefresh = false}) async {
    try {
      // 1) Avval localdan olish
      if (!forceRefresh) {
        final localUsers = await DBHelper.getUsers();
        if (localUsers.isNotEmpty) {
          print("📦 Local DB dan ${localUsers.length} ta foydalanuvchi olindi");
          return localUsers;
        } else {
          print("📦 Local DB bo‘sh, serverdan olib kelinadi...");
        }
      }

      // 2) Serverdan olish
      print("🌐 Serverga so‘rov yuborilmoqda: $baseUrl/users");
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
      );

      print("📡 Javob status: ${response.statusCode}");

      if (response.statusCode == 200) {
        print("✅ Server javobi: ${response.body}");

        final List<dynamic> jsonList = json.decode(response.body);
        final users = jsonList.map((json) => User.fromJson(json)).toList();

        // Local DB ni yangilash
        await DBHelper.clearUsers();
        await DBHelper.insertUsers(users);

        print("💾 Local DB yangilandi: ${users.length} ta foydalanuvchi");
        return users;
      } else {
        throw Exception('❌ Server xatolik: ${response.statusCode}');
      }
    } catch (e, s) {
      // 3) Internet bo‘lmasa yoki boshqa xato bo‘lsa
      print("⚠️ So‘rovda xato: $e");
      print("📍 Trace: $s");

      final localUsers = await DBHelper.getUsers();
      print("📦 Local fallback: ${localUsers.length} ta foydalanuvchi qaytarildi");
      return localUsers;
    }
  }
}
