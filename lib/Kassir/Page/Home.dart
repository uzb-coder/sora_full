import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Offisant/Controller/usersCOntroller.dart';
import '../../Offisant/Page/Home.dart';
import 'Kassr_page.dart';

class KassirPage extends StatefulWidget {
  final User user;
  final token;
  const KassirPage({super.key, required this.user, this.token,});

  @override
  _KassirPageState createState() => _KassirPageState();
}

class _KassirPageState extends State<KassirPage> {
  DateTime _time = DateTime.now();
  bool _showDashboard = false;
  String? _firstName;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUser();
    // Set up timer to update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _time = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Load user data from SharedPreferences
  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstName = prefs.getString('first_name') ?? 'Kassir';
    });
  }

  // Format date in Russian locale
  String _formatDate(DateTime date) {
    final formatter = DateFormat('EEEE, d MMMM yyyy', 'ru_RU');
    return formatter.format(date);
  }

  // Format time in 24-hour format
  String _formatTime(DateTime date) {
    final formatter = DateFormat('HH:mm:ss', 'ru_RU');
    return formatter.format(date);
  }

  @override
  Widget build(BuildContext context) {
    // If dashboard is shown
    if (_showDashboard) {
      return Scaffold(
        body: Stack(
          children: [
            //KassirDashboard(), // Imported dashboard widget
            Positioned(
              top: 10,
              left: 10,
              child: ElevatedButton(
                style: _buttonStyle.copyWith(
                  backgroundColor: WidgetStateProperty.all(const Color(0xFFF0F0F0)),
                  side: WidgetStateProperty.all(
                    const BorderSide(color: Color(0xFF999999), width: 2),
                  ),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _showDashboard = false;
                  });
                },
                child: const Text(
                  '← Назад',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Main KassirPage UI
    return Scaffold(
      backgroundColor: const Color(0xFFC0C0C0),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // User info and time
                Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Кассир: ${_firstName ?? "Kassir"}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        _formatDate(_time),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        _formatTime(_time),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                // Top buttons
                Row(
                  children: [
                    _buildButton(
                      label: 'Главная',
                      onPressed: () {
                        setState(() {
                          _showDashboard = true;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body (empty container with dark background)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bottom buttons
                Row(
                  children: [
                    _buildButton(
                      label: 'Все счета',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => FastUnifiedPendingPaymentsPage1(token: widget.token,)));
                      },
                    ),         _buildButton(
                      label: 'Шот',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => PosScreen(user: widget.user, token: widget.token,)));
                      },
                    ),
                  ],
                ),
                // Exit button
                _buildButton(
                  label: 'Выход',
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Button style and widget
  Widget _buildButton({required String label, required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: ElevatedButton(
        style: _buttonStyle,
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // Button style to mimic React's btnStyle
  final ButtonStyle _buttonStyle = ButtonStyle(
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
    ),
    backgroundColor: WidgetStateProperty.all(Colors.grey[300]),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF999999), width: 3),
      ),
    ),
    elevation: WidgetStateProperty.all(0),
  );
}


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Главная')),
      body: const Center(child: Text('Home Page')),
    );
  }
}