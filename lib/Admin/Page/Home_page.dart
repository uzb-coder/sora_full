import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sora/Admin/Page/Blyuda/zall.dart';
import 'dart:async';

import '../../Kirish.dart';
import '../../Offisant/Controller/usersCOntroller.dart';
import 'Blyuda/Blyuda.dart';
import 'Blyuda/Otdel.dart';
import 'Blyuda/Personal_restoran.dart';
import 'Cilnet_page.dart';
import 'Blyuda/Stollar_page.dart';

class ManagerHomePage extends StatefulWidget {
  final User user;
  final String token;
  const ManagerHomePage({super.key, required this.token, required this.user});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  late String _timeString;
  late String _dateString;

  @override
  void initState() {
    _updateTime();
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
    super.initState();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = DateFormat('HH:mm:ss').format(now);
      _dateString = DateFormat('EEEE, d MMMM y', 'ru_RU').format(now) + " г.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF6b6b6b),
        elevation: 2.0,
        toolbarHeight: 80, // defaultdan kattaroq balandlik berdi
        title: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12), // tepadan va pastdan 12px padding
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hodim : ${widget.user.firstName} | ${widget.user.lastName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_dateString\n$_timeString',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PersonalRestoran(token: widget.token,)));
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 70),
                backgroundColor: const Color(0xFFF5F5F5),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.grey, width: 2),
                ),
                shadowColor: Colors.black.withOpacity(0.2),
                elevation: 6,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Персонал ресторана'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => HallsPage(token: widget.token,)));
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 70),
                backgroundColor: const Color(0xFFF5F5F5),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.grey, width: 2),
                ),
                shadowColor: Colors.black.withOpacity(0.2),
                elevation: 6,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Залы'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: ElevatedButton(
              onPressed: () {
                // Sizning kodlaringiz
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 70),
                backgroundColor: const Color(0xFFF5F5F5),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.grey, width: 2),
                ),
                shadowColor: Colors.black.withOpacity(0.2),
                elevation: 6,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Настройки'),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Color(0xFF333333),  // Oq oraliq uchun oq rang
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        color: const Color(0xFFcccccc),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ClientPage(token: widget.token,)));
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(120, 70),
                    backgroundColor: const Color(0xFFF5F5F5),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.grey, width: 2),
                    ),
                    shadowColor: Colors.black.withOpacity(0.2),
                    elevation: 6,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Клиенты'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => MainScreen(token: widget.token,)));
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(120, 70),
                    backgroundColor: const Color(0xFFF5F5F5),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.grey, width: 2),
                    ),
                    shadowColor: Colors.black.withOpacity(0.2),
                    elevation: 6,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Блюда'),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => WelcomeScreen()));
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 70),
                backgroundColor: const Color(0xFFF5F5F5),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.grey, width: 2),
                ),
                shadowColor: Colors.black.withOpacity(0.2),
                elevation: 6,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Выход'),
            ),
          ],
        ),
      ),
    );
  }
}
