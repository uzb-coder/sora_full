import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sora/Global/Api_global.dart';

class AuthService {
  static const String baseUrl = "${ApiConfig.baseUrl}";

  static String? _userCode;
  static String? _password;

  // Login ma'lumotlarini saqlash
  static void setCredentials(String userCode, String password) {
    _userCode = userCode;
    _password = password;
  }
  // Tokenni local storage (SharedPreferences) ga saqlash
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print("✅ Token localda saqlandi");
  }

  // Local storage dan tokenni olish
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Login qilish va token olish
  static Future<void> loginAndPrintToken() async {
    if (_userCode == null || _password == null) {
      print("❌ Xatolik: userCode yoki password o‘rnatilmagan.");
      return;
    }

    final Uri loginUrl = Uri.parse('$baseUrl/auth/login');

    print("Yuborilayotgan ma'lumot: user_code=$_userCode, password=$_password");

    try {
      final response = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_code': _userCode,
          'password': _password,
        }),
      );

      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String token = data['token'];
        await saveToken(token);
        print("✅ Token muvaffaqiyatli olindi: $token");
      } else {
        print("❌ Login xatolik. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      print("❗ Xatolik yuz berdi: $e");
    }
  }
}
