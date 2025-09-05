import 'package:flutter/material.dart';

import 'Categroya_UI.dart';
import 'Hall_UI.dart';
import 'Local_UI.dart';

// 🔹 Drawer component (hamma sahifada ishlatish uchun)
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              "Menyu",
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Users"),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const UsersTableScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.pages),
            title: const Text("Zal va Stollar"),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HallTablesPage()),
              );
            },
          ),  ListTile(
            leading: const Icon(Icons.pages),
            title: const Text("Kategorya"),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const CategoryFoodPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Chiqish"),
            onTap: () {
              Navigator.pop(context); // faqat yopish
            },
          ),
        ],
      ),
    );
  }
}

// 🔹 Birinchi sahifa
class FirstPage extends StatelessWidget {
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Birinchi sahifa")),
      drawer: const AppDrawer(), // Drawer shu yerda ishlatiladi
      body: const Center(child: Text("Bu Birinchi sahifa")),
    );
  }
}

// 🔹 Ikkinchi sahifa
class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ikkinchi sahifa")),
      drawer: const AppDrawer(), // Drawer shu yerda ham ishlaydi
      body: const Center(child: Text("Bu Ikkinchi sahifa")),
    );
  }
}
