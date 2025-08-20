import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'Offisant/Page/Users_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late String _timeString;
  late String _dateString;
  late Timer _timer;

  @override
  void initState() {
    initializeDateFormatting('uz_UZ', null);
    _timeString = _formatDateTime(DateTime.now(), 'HH:mm');
    _dateString = _formatDateTime(DateTime.now(), 'EEEE, d MMMM, yyyy');

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    final String formattedTime = _formatDateTime(now, 'HH:mm:ss');
    final String formattedDate = _formatDateTime(now, 'EEEE, d MMMM, yyyy');

    setState(() {
      _timeString = formattedTime;
      _dateString = formattedDate;
    });
  }

  String _formatDateTime(DateTime dateTime, String format) {
    return DateFormat(format, 'uz_UZ').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final logoSize = screenWidth * 0.7; // Ekran kengligining 70%
    final timeFontSize = screenWidth * 0.15; // Soat matni fonti
    final dateFontSize = screenWidth * 0.04; // Sana fonti
    final buttonPaddingHorizontal = screenWidth * 0.15;
    final buttonPaddingVertical = screenHeight * 0.04;
    final buttonFontSize = screenWidth * 0.045;

    return Scaffold(
      backgroundColor: const Color(0xffeae3e3),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Container(
                width: logoSize > 350 ? 350 : logoSize,  // maksimal 350 px
                height: logoSize > 350 ? 350 : logoSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: const DecorationImage(
                    image: AssetImage('img/background.jpg'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ClipOval(
                    child: Image.asset(
                      'img/sora_logo_black.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: screenHeight * 0.05),

            Text(
              _timeString,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w200,
                fontSize: timeFontSize > 80 ? 80 : timeFontSize,
                color: Colors.black87,
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: screenHeight * 0.012),

            Text(
              _dateString,
              style: TextStyle(
                fontSize: dateFontSize > 22 ? 22 : dateFontSize,
                fontWeight: FontWeight.w300,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: screenHeight * 0.07),

            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserListPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0d5720),
                  padding: EdgeInsets.symmetric(
                    horizontal: buttonPaddingHorizontal > 50 ? 50 : buttonPaddingHorizontal,
                    vertical: buttonPaddingVertical > 30 ? 30 : buttonPaddingVertical,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: TextStyle(
                    fontSize: buttonFontSize > 18 ? 18 : buttonFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text(
                  'Kirish',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
