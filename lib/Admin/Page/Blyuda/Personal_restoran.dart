import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:sora/Global/Api_global.dart';

import '../../../Global/Global_token.dart';

class PersonalRestoran extends StatefulWidget {
  final String token;
  const PersonalRestoran({super.key, required this.token});

  @override
  State<PersonalRestoran> createState() => _UserPageState();
}

class _UserPageState extends State<PersonalRestoran> {
  List<dynamic> users = [];
  bool _isLoading = false; // Loading holati

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }


  Future<void> fetchUsers() async {
    setState(() => _isLoading = true);

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/users"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}', // Bu yerda global token ishlatiladi
      },
    );

    print("🟢 Token getx orqali : ${widget.token}");

    if (res.statusCode == 200) {
      setState(() {
        users = json.decode(res.body);
        _isLoading = false;
      });
    } else {
      print("Xatolik: ${res.statusCode}");
      setState(() => _isLoading = false);
    }
  }


  Future<void> addUser(Map<String, dynamic> userData) async {

    setState(() => _isLoading = true);
    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/users"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: json.encode(userData),
    );
    setState(() => _isLoading = false);

    print("🟢 Token:  2 ${widget.token}");

    if (res.statusCode == 200 || res.statusCode == 201) {
      Navigator.pop(context);
      fetchUsers();
    } else {
      print('Add user error: StatusCode=${res.statusCode}, Body=${res.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foydalanuvchini qo‘shishda xatolik: ${res.statusCode}')),
      );
    }
  }

  Future<void> updateUser(String id, Map<String, dynamic> userData) async {
    setState(() => _isLoading = true);
    final res = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/users/$id"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: json.encode(userData),
    );
    setState(() => _isLoading = false);

    print("🟢 Token: 3 ${widget.token}");

    if (res.statusCode == 200) {
      Navigator.pop(context);
      fetchUsers();
    } else {
      print('Update user error: StatusCode=${res.statusCode}, Body=${res.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foydalanuvchini yangilashda xatolik: ${res.statusCode}')),
      );
    }
  }

  Future<void> deleteUser(String id) async {
    setState(() => _isLoading = true);
    final res = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/users/$id"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    );
    setState(() => _isLoading = false);
    print("🟢 Token: 4  ${widget.token}");

    if (res.statusCode == 200) {
      fetchUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foydalanuvchini o‘chirishda xatolik')),
      );
    }
  }

  void _openEditUserModal(Map<String, dynamic> user) {
    _openUserModal(editUser: user);
  }

  void _openUserModal({Map<String, dynamic>? editUser}) {
    String firstName = editUser?['first_name'] ?? '';
    String lastName = editUser?['last_name'] ?? '';
    String password = '';
    String userCode = editUser?['user_code'] ?? '';
    String selectedRole = editUser?['role'] ?? 'kassir';
    String percentage = (editUser != null && editUser['percent'] != null)
        ? editUser['percent'].toString()
        : '';

    Map<String, bool> permissions = {
      'chek': false,
      'atkaz': false,
      'hisob': false,
    };

    if (editUser != null && editUser['permissions'] != null) {
      List<dynamic> perms = editUser['permissions'];
      for (var key in permissions.keys.toList()) {
        permissions[key] = perms.contains(key);
      }
    }

    final firstNameController = TextEditingController(text: firstName);
    final lastNameController = TextEditingController(text: lastName);
    final passwordController = TextEditingController();
    final userCodeController = TextEditingController(text: userCode);
    final percentageController = TextEditingController(text: percentage);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            alignment: Alignment.center,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              editUser == null ? "Foydalanuvchi qo‘shish" : "Foydalanuvchini tahrirlash",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: firstNameController,
                      decoration: InputDecoration(
                        labelText: 'Ism',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => firstName = v,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Familiya',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => lastName = v,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: editUser == null ? 'Parol' : 'Yangi parol (ixtiyoriy)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => password = v,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: userCodeController,
                      decoration: InputDecoration(
                        labelText: 'Foydalanuvchi kodi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => userCode = v,
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedRole = val;
                              });
                            }
                          },
                          items: [
                            'kassir',
                            'afitsant',
                            'buxgalter',
                            'barmen',
                            'xoctest',
                            'povir',
                            'paner',
                          ].map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          )).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (selectedRole == 'afitsant')
                      TextField(
                        controller: percentageController,
                        decoration: InputDecoration(
                          labelText: 'Foiz (%)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => percentage = v,
                      ),
                    const SizedBox(height: 16),
                    Column(
                      children: permissions.keys.map((key) {
                        return CheckboxListTile(
                          title: Text(key),
                          value: permissions[key],
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (val) {
                            setModalState(() {
                              permissions[key] = val ?? false;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            actions: [
              ElevatedButton(
                onPressed: () {
                  final selectedPermissions = permissions.entries
                      .where((e) => e.value)
                      .map((e) => e.key)
                      .toList();

                  final userData = {
                    "first_name": firstName,
                    "last_name": lastName,
                    "role": selectedRole,
                    "user_code": userCode,
                    "is_active": true,
                  };

                  if (password.isNotEmpty) {
                    userData["password"] = password;
                  }

                  userData['permissions'] = selectedPermissions;

                  if (selectedRole == 'afitsant') {
                    if (percentage.isNotEmpty) {
                      userData['percent'] = double.tryParse(percentage) ?? 0;
                    } else {
                      userData['percent'] = 0;
                    }
                  } else {
                    userData.remove('percent');
                  }

                  if (editUser == null) {
                    addUser(userData);
                  } else {
                    updateUser(editUser['_id'], userData);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "Saqlash",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Oq fon
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _openUserModal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "фойдаланувчи яратиш",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          users.isEmpty && !_isLoading
              ? const Center(child: Text('Foydalanuvchilar mavjud emas'))
              : Padding(
            padding: const EdgeInsets.all(12.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints:
                BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
                  dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.grey[200];
                      }
                      return null; // default
                    },
                  ),
                  dividerThickness: 1,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(
                        label: Text('Ism', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label:
                        Text('Familiya', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Rol', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Kod', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label:
                        Text('Ruxsatlar', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Amallar', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: users.map((user) {
                    return DataRow(cells: [
                      DataCell(Text(user['first_name'] ?? '')),
                      DataCell(Text(user['last_name'] ?? '')),
                      DataCell(Text(user['role'] ?? '')),
                      DataCell(Text(user['user_code'] ?? 'yashirin')),
                      DataCell(Text(
                        (user['permissions'] != null && user['permissions'] is List)
                            ? (user['permissions'] as List).join(', ')
                            : '',
                      )),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              _openEditUserModal(user);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Tasdiqlash'),
                                  content: const Text('Foydalanuvchini o‘chirilsinmi?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                      },
                                      child: const Text('Bekor qilish'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        deleteUser(user['_id']);
                                      },
                                      child: const Text('O‘chirish'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
        },
        label: const Text("Выход"),
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
      ),
    );
  }
}
