import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sora/Global/Api_global.dart';
import 'dart:async';
import '../../Admin/Page/Home_page.dart';
import '../../Global/Global_token.dart';
import '../Controller/usersCOntroller.dart';
import '../../Kassir/Page/Home.dart';
import 'Home.dart';
import 'Users_page.dart';

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

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateDateTime());
  }

  void _updateDateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = DateFormat('H : mm : ss').format(now);
      _dateString = toBeginningOfSentenceCase(
        DateFormat("EEEE, d MMMM y 'г.'", 'ru').format(now),
      )!;
    });
  }

  void _onKeyPressed(String value) {
    if (value == 'delete') {
      if (_pinController.text.isNotEmpty) {
        _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
      }
    } else {
      _pinController.text += value;
    }
  }

  Future<void> _login() async {
    final pin = _pinController.text.trim();

    if (widget.user.userCode.isEmpty || pin.isEmpty) {
      setState(() {
        _errorMessage = "Iltimos, barcha maydonlarni to'ldiring.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tokenController = Get.find<TokenController>();

      // 1️⃣ Barcha role tokenlarini yangilash
      await tokenController.refreshAllTokensIfExpired(widget.user.userCode, pin);

      // 2️⃣ Hozirgi role tokenini olish
      final token = tokenController.getToken(widget.user.role);

      if (token != null) {
        Widget targetPage;
        switch (widget.user.role) {
          case 'afitsant':
            targetPage = PosScreen(user: widget.user, token: token);
            break;
          case 'kassir':
            targetPage = KassirPage(user: widget.user, token: token);
            break;
          case 'admin':
            targetPage = ManagerHomePage(user: widget.user, token: token);
            break;
          default:
            setState(() {
              _errorMessage = "Noma'lum foydalanuvchi roli: ${widget.user.role}";
            });
            return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => targetPage),
        );
      } else {
        setState(() {
          _errorMessage = "Login amalga oshmadi. PIN kodni tekshiring.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Kutilmagan xatolik yuz berdi: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError() {
    if (_errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_errorMessage != null) {
        _showError();
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(color: Color(0xFFE0E0E0))),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF144D37)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClock() {
    return Container(
      width: 400,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        children: [
          Text(
            _timeString,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _dateString,
            style: const TextStyle(fontSize: 18, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPanel() {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEFF2),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildUserInfo(),
          const SizedBox(height: 15),
          _buildPinField(),
          const SizedBox(height: 20),
          _buildNumpad(),
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF144D37), Color(0xFF144D37)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.white, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.user.firstName} ${widget.user.lastName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  widget.user.role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinField() {
    return TextField(
      controller: _pinController,
      readOnly: true,
      showCursor: true,
      cursorColor: Colors.black,
      textAlign: TextAlign.center,
      obscureText: true,
      obscuringCharacter: '•',
      style: const TextStyle(fontSize: 24, letterSpacing: 10),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        hintText: "PIN kodni kiriting",
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
      ),
    );
  }

  Widget _buildNumpad() {
    final List<String> keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      'Стереть', '0', 'delete',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        return _buildNumpadButton(keys[index]);
      },
    );
  }

  Widget _buildNumpadButton(String key) {
    if (key == 'delete') {
      return ElevatedButton(
        onPressed: _isLoading ? null : () => _onKeyPressed('delete'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD6DADE),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.all(16),
        ),
        child: const Icon(Icons.backspace_outlined),
      );
    }

    bool isClearButton = key == 'Стереть';

    return ElevatedButton(
      onPressed: _isLoading ? null : () {
        if (isClearButton) {
          _pinController.clear();
        } else {
          _onKeyPressed(key);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isClearButton ? const Color(0xFFD6DADE) : const Color(0xFFF7F8FA),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      child: Text(key),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserListPage()),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Назад',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: const Color(0xFF144D37),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text(
              'Вход',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}