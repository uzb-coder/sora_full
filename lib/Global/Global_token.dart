import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart';
import '../Global/Api_global.dart';

class TokenController extends GetxController {
  // Faqat xotirada saqlash uchun
  final Map<String, String> _tokens = {}; // role: token
  final activeRole = ''.obs;

  // Token yaroqliligini tekshirish
  bool _isTokenValid(String token) {
    try {
      return !JwtDecoder.isExpired(token);
    } catch (e) {
      debugPrint('❌ Token tekshirishda xatolik: $e');
      return false;
    }
  }

  // API orqali yangi token olish
  Future<String?> _fetchTokenFromApi(String userCode, String pin, String role) async {
    try {
      final loginUrl = Uri.parse('${ApiConfig.baseUrl}/auth/login');
      final res = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_code': userCode,
          'password': pin,
          'role': role,
        }),
      );

      debugPrint('API Response Status: ${res.statusCode} for role: $role');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'];
        if (token != null) {
          _tokens[role] = token; // Xotirada saqlash
          debugPrint('✅ Token olindi va saqlandi: $role');
          return token;
        }
      } else {
        final errorData = jsonDecode(res.body);
        debugPrint('❌ Login xatoligi ($role): ${errorData['message']}');
      }
    } catch (e) {
      debugPrint('❌ API da xatolik ($role): $e');
    }
    return null;
  }

  // Token olish yoki yangilash
  Future<String?> getValidToken(String role, String userCode, String pin) async {
    try {
      // Xotiradagi tokenni tekshirish
      final existingToken = _tokens[role];

      if (existingToken != null && _isTokenValid(existingToken)) {
        debugPrint('✅ Mavjud token yaroqli: $role');
        return existingToken;
      }

      // Yangi token olish
      debugPrint('🔄 Yangi token olinmoqda: $role');
      return await _fetchTokenFromApi(userCode, pin, role);

    } catch (e) {
      debugPrint('❌ getValidToken da xatolik ($role): $e');
      return null;
    }
  }

  // Barcha rollar uchun tokenlarni olish
  Future<void> refreshAllTokensIfExpired(String userCode, String pin) async {
    final roles = ['afitsant', 'kassir', 'admin'];

    for (String role in roles) {
      await getValidToken(role, userCode, pin);
    }

    debugPrint('🔄 Barcha tokenlar yangilandi');
  }

  // Hozirgi role tokenini olish
  String? getToken(String role) {
    final token = _tokens[role];
    if (token != null && _isTokenValid(token)) {
      activeRole.value = role;
      return token;
    }
    return null;
  }

  // Tokenlarni tozalash
  void clearAllTokens() {
    _tokens.clear();
    activeRole.value = '';
    debugPrint('🗑️ Barcha tokenlar o\'chirildi');
  }

  // Token ma'lumotlarini olish (debug uchun)
  void printTokenStatus() {
    debugPrint('📊 Token holati:');
    _tokens.forEach((role, token) {
      final isValid = _isTokenValid(token);
      debugPrint('  $role: ${isValid ? "✅ Yaroqli" : "❌ Eskirgan"}');
    });
  }
}