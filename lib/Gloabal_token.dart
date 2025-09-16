// Kassir uchun alohida Token Manager
import 'Offisant/Controller/usersCOntroller.dart';

class KassirTokenManager {
  static final KassirTokenManager _instance = KassirTokenManager._internal();
  factory KassirTokenManager() => _instance;
  KassirTokenManager._internal();

  String? _kassirToken;
  User? _kassirUser;

  // Kassir tokenini saqlash
  void setKassirToken(String token, User user) {
    _kassirToken = token;
    _kassirUser = user;
    print("✅ Kassir token saqlandi: ${user.userCode} - ${token.substring(0, 20)}...");
  }

  // Kassir tokenini olish
  String? getKassirToken() {
    print("🔑 Kassir token olinmoqda: ${_kassirToken?.substring(0, 20) ?? 'Yo\'q'}...");
    return _kassirToken;
  }

  // Kassir ma'lumotlarini olish
  User? getKassirUser() => _kassirUser;

  // Token mavjudligini tekshirish
  bool hasKassirToken() {
    bool hasToken = _kassirToken != null && _kassirToken!.isNotEmpty;
    print("🔍 Kassir token mavjudmi: $hasToken");
    return hasToken;
  }

  // Kassir tokenini tozalash
  void clearKassirToken() {
    print("🗑️ Kassir token tozalanmoqda...");
    _kassirToken = null;
    _kassirUser = null;
  }
}