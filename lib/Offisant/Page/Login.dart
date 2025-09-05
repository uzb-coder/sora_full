import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../DB/Servis/db_helper.dart';
import '../../Global/Api_global.dart';
import '../../Admin/Page/Home_page.dart';
import '../../Kassir/Page/Home.dart';
import '../Controller/usersCOntroller.dart';
import 'Users_page.dart';
import '../../Offisant/Page/Home.dart';

class LoginScreen extends StatefulWidget {
  final User user;
  const LoginScreen({super.key, required this.user});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late String _timeString;
  late String _dateString;
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _syncTimer;

  static const String baseUrl = "${ApiConfig.baseUrl}";

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateDateTime());

    // 🔄 Har 1 soatda avtomatik foydalanuvchilarni sync qilish
    _syncTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      try {
        final users = await UserController.getAllUsers(forceRefresh: true);
        debugPrint("✅ Avto-sync: ${users.length} ta foydalanuvchi yangilandi");
      } catch (e) {
        debugPrint("⚠️ Avto-sync xatolik: $e");
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _updateDateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = DateFormat('H:mm:ss').format(now);
      _dateString = DateFormat("EEEE, d MMMM y", 'ru').format(now);
    });
  }

  // 🔹 Tokenni saqlash
  Future<void> saveToken(String key, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, token);
  }

  // 🔹 Tokenni olish
  Future<String?> getToken(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  bool isTokenValid(String token) {
    try {
      return !JwtDecoder.isExpired(token);
    } catch (_) {
      return false;
    }
  }

  // 🔹 Serverdan token olish
  Future<String?> _getTokenFromApi(String userCode, String pin, String role) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_code': userCode,
          'password': pin,
          'role': role,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['token'];
      } else {
        final err = jsonDecode(res.body);
        setState(() {
          _errorMessage = err['message'] ?? "❌ PIN noto‘g‘ri yoki foydalanuvchi topilmadi.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "⚠️ Server bilan bog‘lanishda xatolik.";
      });
    }
    return null;
  }

  // 🔹 Login qilish
  Future<void> _login() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tokenKey = "${widget.user.role}_${widget.user.userCode}_token";

    try {
      // 1) Local DB dan tekshirish
      final localUser = await DBHelper.getUserByCode(widget.user.userCode);
      if (localUser != null && localUser.password == pin) {
        debugPrint("✅ Offline login ishladi");
        final storedToken = await getToken(tokenKey);
        if (storedToken != null && isTokenValid(storedToken)) {
          _navigateByRole(widget.user.role, storedToken);
          return;
        }
      }

      // 2) Online login
      final token = await _getTokenFromApi(widget.user.userCode, pin, widget.user.role);
      if (token != null) {
        await saveToken(tokenKey, token);
        await DBHelper.updateUserWithPin(widget.user.id, pin);
        debugPrint("✅ Online login va token saqlandi");
        _navigateByRole(widget.user.role, token);
      }
    } catch (e) {
      setState(() => _errorMessage = "Xatolik: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateByRole(String role, String token) {
    Widget page;
    switch (role) {
      case "afitsant":
        page = PosScreen(user: widget.user, token: token);
        break;
      case "kassir":
        page = KassirPage(user: widget.user, token: token);
        break;
      case "admin":
        page = ManagerHomePage(user: widget.user, token: token);
        break;
      default:
        setState(() => _errorMessage = "Noma’lum foydalanuvchi roli: $role");
        return;
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  void _onPinChanged(String value) async {
    final requiredLength = widget.user.password?.length; // ✅ foydalanuvchining parol uzunligi

    if (value.length == requiredLength) {
      await _login();
    }
  }


  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
        );
        setState(() => _errorMessage = null);
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade400, // 🔹 Orqa fon shu
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildClock(),
                  const SizedBox(height: 30),
                  _buildLoginPanel(),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClock() {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(_timeString,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(_dateString, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLoginPanel() {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        children: [
          _buildUserInfo(),
          const SizedBox(height: 15),
          _buildPinField(),
          const SizedBox(height: 20),
          _buildNumpad(),
          const SizedBox(height: 20),
          _buildActionButtons(), // 🔹 Вход tugmasi saqlanadi
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF144D37), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.white, size: 40),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${widget.user.firstName} ${widget.user.lastName}",
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              Text(widget.user.role.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPinField() {
    return TextField(
      controller: _pinController,
      readOnly: true,
      textAlign: TextAlign.center,
      obscureText: true,
      obscuringCharacter: '•',
      style: const TextStyle(fontSize: 24, letterSpacing: 10),
      onChanged: _onPinChanged, // 🔹 PIN kiritilganda tekshiradi
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: "PIN kodni kiriting",
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildNumpad() {
    final keys = ['1','2','3','4','5','6','7','8','9','C','0','DEL'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemBuilder: (context, i) {
        final key = keys[i];
        return ElevatedButton(
          onPressed: () {
            if (key == 'DEL') {
              if (_pinController.text.isNotEmpty) {
                _pinController.text =
                    _pinController.text.substring(0, _pinController.text.length - 1);
              }
            } else if (key == 'C') {
              _pinController.clear();
            } else {
              _pinController.text += key;
              _onPinChanged(_pinController.text); // 🔹 Har raqam yozilganda tekshiradi
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: key == 'C' || key == 'DEL' ? Colors.grey[300] : Colors.white,
          ),
          child: key == 'DEL'
              ? const Icon(Icons.backspace_outlined, color: Colors.black)
              : Text(key,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListPage()));
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: BorderSide(color: Colors.grey.shade400),
            ),
            child: const Text("Назад", style: TextStyle(fontSize: 18, color: Colors.black54)),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF144D37),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: _isLoading
                ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Вход",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
