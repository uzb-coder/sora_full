import 'package:flutter/material.dart';

import '../../Offisant/Controller/usersCOntroller.dart';
import '../Servis/db_helper.dart';
import 'Menu.dart';


class UsersTableScreen extends StatefulWidget {
  const UsersTableScreen({super.key});

  @override
  State<UsersTableScreen> createState() => _UsersTableScreenState();
}

class _UsersTableScreenState extends State<UsersTableScreen> {
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = DBHelper.getUsers() as Future<List<User>>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(title: const Text("Foydalanuvchilar")),
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Foydalanuvchi topilmadi"));
          }

          final users = snapshot.data!;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal, // Jadval keng bo‘lsa
            child: DataTable(
              border: TableBorder.all(color: Colors.grey.shade400),
              columns: const [
                DataColumn(label: Text("ID")),
                DataColumn(label: Text("Ism")),
                DataColumn(label: Text("Familiya")),
                DataColumn(label: Text("Rol")),
                DataColumn(label: Text("User Code")),
                DataColumn(label: Text("PIN")),
                DataColumn(label: Text("Faolmi")),
                DataColumn(label: Text("Foiz (%)")),
              ],
              rows: users.map((user) {
                return DataRow(
                  cells: [
                    DataCell(Text(user.id ?? "")),
                    DataCell(Text(user.firstName ?? "")),
                    DataCell(Text(user.lastName ?? "")),
                    DataCell(Text(user.role ?? "")),
                    DataCell(Text(user.userCode ?? "")),
                    DataCell(Text(user.password ?? "")),
                    DataCell(Text(user.isActive == 1 ? "Ha" : "Yo‘q")),
                    DataCell(Text(user.percent?.toString() ?? "0")),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
