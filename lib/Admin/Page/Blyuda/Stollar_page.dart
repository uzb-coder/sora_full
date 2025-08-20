import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sora/Global/Api_global.dart';

import '../Stollarni_joylashuv.dart';

class TablesPage extends StatefulWidget {
  final String token;
  const TablesPage({super.key, required this.token});

  @override
  State<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends State<TablesPage> {
  List<Map<String, dynamic>> tables = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTables();
  }

  Future<void> fetchTables() async {
    final url = Uri.parse("${ApiConfig.baseUrl}/tables/list");

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );
      print("Stollar malumot : ${response.body}");
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          tables = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        print("Xatolik: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Xatolik: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> addNewTable(String number, String guestCount) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/tables/create");

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "number": number,
        "name": number, // name = number
        "guest_count": int.tryParse(guestCount) ?? 0,
        "status": "bo'sh",
        "is_active": true
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      Navigator.of(context).pop();
      fetchTables();
    } else {
      print("Qo‘shishda xatolik: ${response.statusCode}");
      print("Javob: ${response.body}");
    }
  }

  Future<void> deleteTable(String id) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/tables/delete/$id");

    final response = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      fetchTables(); // yangilash
    } else {
      print("O‘chirishda xatolik: ${response.statusCode}");
      print("Javob: ${response.body}");
    }
  }

  Future<void> updateTable(String id, String number, String guestCount) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/tables/update/$id");

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "number": number,
        "name": "Stol $number",
        "capacity": 0,
        "status": "bo'sh",
        "guest_count": int.tryParse(guestCount) ?? 0,
        "is_active": true
      }),
    );
    if (response.statusCode == 200) {
      Navigator.of(context).pop();
      fetchTables();
    } else {
      print("Yangilashda xatolik: ${response.statusCode}");
      print("Javob: ${response.body}");
    }
  }

  void showAddTableModal() {
    final TextEditingController numberController = TextEditingController();
    final TextEditingController guestCountController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Yangi stol qo‘shish", style: TextStyle(color: Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(
                labelText: "Stol raqami yoki nomi",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: guestCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Mehmonlar soni",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF144D37),
            ),
            onPressed: () {
              final number = numberController.text.trim();
              final guestCount = guestCountController.text.trim();
              if (number.isNotEmpty && guestCount.isNotEmpty) {
                addNewTable(number, guestCount);
              }
            },
            child: const Text("Qo‘shish",style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }


  void showEditTableModal(Map<String, dynamic> table) {
    final TextEditingController numberController = TextEditingController(text: table['number'].toString());
    final TextEditingController guestCountController = TextEditingController(text: table['guest_count'].toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Stolni tahrirlash", style: TextStyle(color: Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(
                labelText: "Stol raqami",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: guestCountController,
              decoration: const InputDecoration(
                labelText: "Mehmonlar soni",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            onPressed: () {
              final number = numberController.text.trim();
              final guestCount = guestCountController.text.trim();
              if (number.isNotEmpty && guestCount.isNotEmpty) {
                updateTable(table['id'], number, guestCount);
              }
            },
            child: const Text("Saqlash"),
          ),
        ],
      ),
    );
  }


  void showDeleteConfirmationDialog(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("O‘chirishni tasdiqlang", style: TextStyle(color: Colors.black87)),
        content: const Text("Haqiqatan ham o‘chirmoqchimisiz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Yo‘q"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              deleteTable(id);
            },
            child: const Text("Ha"),
          ),
        ],
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text("Stollar ro'yxati",style: TextStyle(color: Colors.black),),
        automaticallyImplyLeading: false, // standart back tugmasi olib tashlandi
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columnSpacing: 24,
                  dataRowHeight: 60,
                  headingRowHeight: 56,
                  columns: const [
                    DataColumn(label: Text("Nomi")),
                    DataColumn(label: Text("Sig‘imi")),
                    DataColumn(label: Text("Amallar")),
                  ],
                  rows: tables.map((table) {
                    return DataRow(cells: [
                      DataCell(Text(table['number'].toString())),
                      DataCell(Text(table['guest_count'].toString())), // Qo‘shildi
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF144D37)),
                            onPressed: () {
                              showEditTableModal(table);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              showDeleteConfirmationDialog(table['id']);
                            },
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.grey[100],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 60,
              width: 150,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(120, 70),
                  backgroundColor: Color(0xFFF5F5F5),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey, width: 2),
                  ),
                  shadowColor: Colors.black.withOpacity(0.2),
                  elevation: 6,
                  padding: EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.location_on, size: 28),
                label: const Text("Joylashuv"),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => StollarniJoylashuv(token: widget.token,)));
                },
              ),
            ),
            // O'rtadagi Qo'shish buttoni
            SizedBox(
              height: 60,
              width: 150,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(120, 70),
                  backgroundColor: Color(0xFFF5F5F5),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey, width: 2),
                  ),
                  shadowColor: Colors.black.withOpacity(0.2),
                  elevation: 6,
                  padding: EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.add, size: 32),
                label: const Text("Qo'shish"),
                onPressed: showAddTableModal,
              ),
            ),

            // Chapdagi Qaytish buttoni
            SizedBox(
              height: 60,
              width: 150,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(120, 70),
                  backgroundColor: Color(0xFFF5F5F5),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey, width: 2),
                  ),
                  shadowColor: Colors.black.withOpacity(0.2),
                  elevation: 6,
                  padding: EdgeInsets.symmetric(horizontal: 10),
                ),
                label: const Text("Выход"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),

            // O'ngdagi Joylashuvga yo'naltirish buttoni

          ],
        ),
      ),
    );
  }

}
