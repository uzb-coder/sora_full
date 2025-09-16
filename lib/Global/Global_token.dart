import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../Global/Api_global.dart';

class TokenController extends GetxController {
  final _storage = const FlutterSecureStorage();
  final tokens = <String, String>{}.obs; // role: token
  final activeRole = ''.obs;

  // Hamma tokenlarni tekshirish va eskirganini yangilash
  Future<void> refreshAllTokensIfExpired(String userCode, String pin) async {
    for (var role in ['afitsant', 'kassir', 'admin']) {
      String tokenKey = '${role}_token_${userCode}';
      final storedToken = await _storage.read(key: tokenKey);

      if (storedToken != null && !JwtDecoder.isExpired(storedToken)) {
        tokens[role] = storedToken;
      } else {
        final newToken = await _fetchTokenFromApi(userCode, pin, role);
        if (newToken != null) {
          await _storage.write(key: tokenKey, value: newToken);
          tokens[role] = newToken;
        }
      }
    }
  }

  // API orqali token olish
  Future<String?> _fetchTokenFromApi(String userCode, String pin, String role) async {
    try {
      final loginUrl = Uri.parse('${ApiConfig.baseUrl}/auth/login');
      final res = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_code': userCode, 'password': pin, 'role': role}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        activeRole.value = role;
        return data['token'];
      }
    } catch (e) {
      print('Token olishda xatolik: $e');
    }
    return null;
  }

  // Hozirgi role tokenini olish
  Future<String?> getToken(String role) async {
    return tokens[role];
  }

  // Tokenni tozalash
  Future<void> clearToken(String role, String userCode) async {
    String tokenKey = '${role}_token_${userCode}';
    await _storage.delete(key: tokenKey);
    tokens.remove(role);
  }
}
