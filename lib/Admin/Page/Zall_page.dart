import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sora/Global/Api_global.dart';

// ===== MODEL =====
class TableModel {
  final String id;
  final String name;
  final String status;
  final int guestCount;
  final int capacity;

  TableModel({
    required this.id,
    required this.name,
    required this.status,
    required this.guestCount,
    required this.capacity,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      guestCount: json['guest_count'] ?? 0,
      capacity: json['capacity'] ?? 0,
    );
  }
}

class HallModel {
  final String id;
  final String name;
  final List<TableModel> tables;

  HallModel({
    required this.id,
    required this.name,
    required this.tables,
  });

  factory HallModel.fromJson(Map<String, dynamic> json) {
    return HallModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      tables: (json['tables'] as List<dynamic>? ?? [])
          .map((t) => TableModel.fromJson(t))
          .toList(),
    );
  }
}

// ===== CONTROLLER =====
class HallController {
  static const String baseUrl = "${ApiConfig.baseUrl}";

  // Hamma hallarni olish
  static Future<List<HallModel>> getHalls(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/halls/list"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print(response.body);
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((e) => HallModel.fromJson(e)).toList();
    } else {
      throw Exception("Hallarni olishda xatolik: ${response.statusCode}");
    }
  }

  // Hall qo'shish
  static Future<void> createHall(String token, String name) async {
    final response = await http.post(
      Uri.parse("$baseUrl/halls/create"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({"name": name, "is_active": true}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("✅ Yangi hall qo'shildi");
    } else {
      throw Exception("Hall qo'shishda xatolik: ${response.body}");
    }
  }

  // Hallni yangilash
  static Future<void> updateHall(String token, String hallId, String newName) async {
    final response = await http.put(
      Uri.parse("$baseUrl/halls/update/$hallId"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({"name": newName}),
    );

    if (response.statusCode == 200) {
      print("✅ Hall yangilandi");
    } else {
      throw Exception("Hall yangilashda xatolik: ${response.body}");
    }
  }

  // Hallni o'chirish
  static Future<void> deleteHall(String token, String hallId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/halls/delete/$hallId"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      print("✅ Hall o'chirildi");
    } else {
      throw Exception("Hall o'chirishda xatolik: ${response.body}");
    }
  }

  // Stol qo'shish
  static Future<void> addTableToHall(
      String token, String hallId, String name, int capacity) async {
    final response = await http.post(
      Uri.parse("$baseUrl/tables/create"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        "hall": hallId,
        "name": name,
        "capacity": capacity,
        "is_active": true,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("✅ Stol qo'shildi");
    } else {
      throw Exception("Stol qo'shishda xatolik: ${response.body}");
    }
  }

  // Stol yangilash
  static Future<void> updateTable(
      String token, String tableId, String newName, int newCapacity) async {
    final response = await http.put(
      Uri.parse("$baseUrl/tables/update/$tableId"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        "name": newName,
        "capacity": newCapacity,
      }),
    );

    if (response.statusCode == 200) {
      print("✅ Stol yangilandi");
    } else {
      throw Exception("Stol yangilashda xatolik: ${response.body}");
    }
  }

  // Stolni o'chirish
  static Future<void> deleteTable(String token, String tableId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/tables/delete/$tableId"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      print("✅ Stol o'chirildi");
    } else {
      throw Exception("Stol o'chirishda xatolik: ${response.body}");
    }
  }
}

// ===== MODERN UI WIDGET =====
class HallsPage extends StatefulWidget {
  final String token;
  const HallsPage({super.key, required this.token});

  @override
  State<HallsPage> createState() => _HallsPageState();
}

class _HallsPageState extends State<HallsPage> {
  late Future<List<HallModel>> hallsFuture;
  HallModel? selectedHall;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    hallsFuture = HallController.getHalls(widget.token);
  }

  void _refreshData() {
    setState(() {
      hallsFuture = HallController.getHalls(widget.token);
    });
  }

  void _showLoader() {
    setState(() => isLoading = true);
  }

  void _hideLoader() {
    setState(() => isLoading = false);
  }

  void _showAddHallDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.home_work, color: Colors.blue[600], size: 20),
            ),
            const SizedBox(width: 12),
            const Text("Yangi zal qo'shish", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: "Zal nomi",
              prefixIcon: const Icon(Icons.edit),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                _showLoader();
                try {
                  await HallController.createHall(widget.token, nameController.text);
                  _refreshData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("✅ Zal muvaffaqiyatli qo'shildi"),
                        backgroundColor: Colors.green[600],
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("❌ Xatolik: $e"),
                        backgroundColor: Colors.red[600],
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } finally {
                  _hideLoader();
                }
              }
            },
            child: const Text("Qo'shish"),
          ),
        ],
      ),
    );
  }

  void _showUpdateHallDialog(String hallId, String oldName) {
    final nameController = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit, color: Colors.orange[600], size: 20),
            ),
            const SizedBox(width: 12),
            const Text("Zalni o'zgartirish", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: "Yangi nom",
              prefixIcon: const Icon(Icons.edit),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                _showLoader();
                try {
                  await HallController.updateHall(widget.token, hallId, nameController.text);
                  _refreshData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("✅ Zal muvaffaqiyatli yangilandi"),
                        backgroundColor: Colors.green[600],
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("❌ Xatolik: $e"),
                        backgroundColor: Colors.red[600],
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } finally {
                  _hideLoader();
                }
              }
            },
            child: const Text("Yangilash"),
          ),
        ],
      ),
    );
  }

  void _showDeleteHallConfirmation(String hallId, String hallName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning, color: Colors.red[600], size: 20),
            ),
            const SizedBox(width: 12),
            const Text("O'chirishni tasdiqlang"),
          ],
        ),
        content: Text("'$hallName' zalini o'chirishni xohlaysizmi?\nBu amalni bekor qilib bo'lmaydi."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Yo'q"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              _showLoader();
              try {
                await HallController.deleteHall(widget.token, hallId);
                if (selectedHall?.id == hallId) {
                  setState(() => selectedHall = null);
                }
                _refreshData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("✅ Zal muvaffaqiyatli o'chirildi"),
                      backgroundColor: Colors.green[600],
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("❌ Xatolik: $e"),
                      backgroundColor: Colors.red[600],
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } finally {
                _hideLoader();
              }
            },
            child: const Text("Ha, o'chirish"),
          ),
        ],
      ),
    );
  }

  void _showAddTableDialog() {
    if (selectedHall == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Avval zalni tanlang")),
      );
      return;
    }

    final nameController = TextEditingController();
    final capacityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.table_restaurant, color: Colors.green[600], size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text("${selectedHall!.name} zaliga stol qo'shish")),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Stol nomi",
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "O'rindiqlar soni",
                  prefixIcon: const Icon(Icons.people),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameController.text.isNotEmpty && capacityController.text.isNotEmpty) {
                Navigator.pop(context);
                _showLoader();
                try {
                  await HallController.addTableToHall(
                    widget.token,
                    selectedHall!.id,
                    nameController.text,
                    int.parse(capacityController.text),
                  );
                  _refreshData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("✅ Stol muvaffaqiyatli qo'shildi"),
                        backgroundColor: Colors.green[600],
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("❌ Xatolik: $e"),
                        backgroundColor: Colors.red[600],
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } finally {
                  _hideLoader();
                }
              }
            },
            child: const Text("Qo'shish"),
          ),
        ],
      ),
    );
  }

  void _showUpdateTableDialog(String tableId, String oldName, int oldCapacity) {
    final nameController = TextEditingController(text: oldName);
    final capacityController = TextEditingController(text: oldCapacity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit, color: Colors.blue[600], size: 20),
            ),
            const SizedBox(width: 12),
            const Text("Stolni o'zgartirish"),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Yangi nom",
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Yangi sig'imi",
                  prefixIcon: const Icon(Icons.people),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameController.text.isNotEmpty && capacityController.text.isNotEmpty) {
                Navigator.pop(context);
                _showLoader();
                try {
                  await HallController.updateTable(
                    widget.token,
                    tableId,
                    nameController.text,
                    int.parse(capacityController.text),
                  );
                  _refreshData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("✅ Stol muvaffaqiyatli yangilandi"),
                        backgroundColor: Colors.green[600],
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("❌ Xatolik: $e"),
                        backgroundColor: Colors.red[600],
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } finally {
                  _hideLoader();
                }
              }
            },
            child: const Text("Yangilash"),
          ),
        ],
      ),
    );
  }

  void _showDeleteTableConfirmation(String tableId, String tableName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning, color: Colors.red[600], size: 20),
            ),
            const SizedBox(width: 12),
            const Text("Stolni o'chirishni tasdiqlang"),
          ],
        ),
        content: Text("'$tableName' stolini o'chirishni xohlaysizmi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Yo'q"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              _showLoader();
              try {
                await HallController.deleteTable(widget.token, tableId);
                _refreshData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("✅ Stol muvaffaqiyatli o'chirildi"),
                      backgroundColor: Colors.green[600],
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("❌ Xatolik: $e"),
                      backgroundColor: Colors.red[600],
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } finally {
                _hideLoader();
              }
            },
            child: const Text("Ha, o'chirish"),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available': case 'bo\'sh': return Colors.green;
      case 'occupied': case 'band': return Colors.red;
      case 'reserved': case 'bron': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'available': return 'Bo\'sh';
      case 'occupied': return 'Band';
      case 'reserved': return 'Bron';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false, // o'zimiz control qilamiz
        title: const Text(
          "Zallar boshqaruvi",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,

        // ✅ Chap tomonda — Orqaga qaytish tugmasi + Zal qo‘shish
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () {
                Navigator.pop(context); // orqaga qaytish
              },
            ),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showAddHallDialog,
                icon: const Icon(Icons.add_home, size: 18),
                label: const Text("Zal"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        leadingWidth: 160, // kengroq qilamiz

        // ✅ O‘ng tomonda — Stol qo‘shish
        actions: [
          Container(
            margin: const EdgeInsets.all(6),
            child: ElevatedButton.icon(
              onPressed: _showAddTableDialog,
              icon: const Icon(Icons.add_circle, size: 18),
              label: const Text("Stol"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<List<HallModel>>(
            future: hallsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Ma'lumotlar yuklanmoqda...",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text("Xatolik yuz berdi",
                          style: TextStyle(fontSize: 18, color: Colors.red[600])),
                      const SizedBox(height: 8),
                      Text("${snapshot.error}", style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshData,
                        child: const Text("Qayta urinish"),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home_work_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("Hali zallar qo'shilmagan",
                          style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showAddHallDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text("Birinchi zalni qo'shish"),
                      ),
                    ],
                  ),
                );
              }

              final halls = snapshot.data!;
              return Row(
                children: [
                  // Sol panel - Zallar
                  Container(
                    width: 280,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(2, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[600]!, Colors.blue[400]!],
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.home_work, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                "Zallar ro'yxati",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: halls.length,
                            itemBuilder: (context, index) {
                              final hall = halls[index];
                              final isSelected = selectedHall?.id == hall.id;

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blue[50] : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(color: Colors.blue[300]!, width: 2)
                                      : null,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setState(() {
                                        selectedHall = hall;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.blue[600] : Colors.grey[200],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.home_work,
                                              color: isSelected ? Colors.white : Colors.grey[600],
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  hall.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                    color: isSelected ? Colors.blue[800] : Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "${hall.tables.length} ta stol",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isSelected ? Colors.blue[600] : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton(
                                            icon: Icon(
                                              Icons.more_vert,
                                              size: 20,
                                              color: Colors.grey[600],
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit, size: 18, color: Colors.blue[600]),
                                                    const SizedBox(width: 8),
                                                    const Text("O'zgartirish"),
                                                  ],
                                                ),
                                                onTap: () {
                                                  Future.delayed(Duration.zero, () {
                                                    _showUpdateHallDialog(hall.id, hall.name);
                                                  });
                                                },
                                              ),
                                              PopupMenuItem(
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete, size: 18, color: Colors.red[600]),
                                                    const SizedBox(width: 8),
                                                    const Text("O'chirish"),
                                                  ],
                                                ),
                                                onTap: () {
                                                  Future.delayed(Duration.zero, () {
                                                    _showDeleteHallConfirmation(hall.id, hall.name);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // O'ng panel - Stollar
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: selectedHall == null
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_restaurant_outlined,
                                size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              "Stollarni ko'rish uchun zalni tanlang",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                          : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green[600]!, Colors.green[400]!],
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.table_restaurant, color: Colors.white),
                                const SizedBox(width: 12),
                                Text(
                                  "${selectedHall!.name} - Stollar",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    "${selectedHall!.tables.length} ta stol",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: selectedHall!.tables.isEmpty
                                ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.table_restaurant_outlined,
                                      size: 80, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Bu zalda hali stollar yo'q",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _showAddTableDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text("Birinchi stolni qo'shish"),
                                  ),
                                ],
                              ),
                            )
                                : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: MediaQuery.of(context).size.width - 296, // 280 + 16 padding
                                      ),
                                      child: DataTable(
                                        columnSpacing: 20,
                                        headingRowHeight: 60,
                                        dataRowHeight: 70,
                                        headingRowColor: WidgetStateProperty.all(
                                          Colors.grey[100],
                                        ),
                                        columns: const [
                                          DataColumn(
                                            label: Expanded(
                                              child: Text(
                                                "Stol nomi",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Expanded(
                                              child: Text(
                                                "O'rindiqlar",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Expanded(
                                              child: Text(
                                                "Holati",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Expanded(
                                              child: Text(
                                                "Mehmonlar",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Expanded(
                                              child: Text(
                                                "Amallar",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        rows: selectedHall!.tables
                                            .map((table) => DataRow(
                                          cells: [
                                            DataCell(
                                              Container(
                                                width: 150,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue[100],
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(
                                                        Icons.table_restaurant,
                                                        size: 18,
                                                        color: Colors.blue[600],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        table.name,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 15,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                width: 80,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Text(
                                                      "${table.capacity}",
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                width: 100,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(table.status).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: _getStatusColor(table.status),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      _getStatusText(table.status),
                                                      style: TextStyle(
                                                        color: _getStatusColor(table.status),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                width: 80,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange[100],
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Text(
                                                      "${table.guestCount}",
                                                      style: TextStyle(
                                                        color: Colors.orange[800],
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                width: 100,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      margin: const EdgeInsets.only(right: 6),
                                                      child: Material(
                                                        color: Colors.blue[50],
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: InkWell(
                                                          borderRadius: BorderRadius.circular(8),
                                                          onTap: () => _showUpdateTableDialog(
                                                            table.id,
                                                            table.name,
                                                            table.capacity,
                                                          ),
                                                          child: Icon(
                                                            Icons.edit,
                                                            size: 18,
                                                            color: Colors.blue[600],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      child: Material(
                                                        color: Colors.red[50],
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: InkWell(
                                                          borderRadius: BorderRadius.circular(8),
                                                          onTap: () => _showDeleteTableConfirmation(
                                                            table.id,
                                                            table.name,
                                                          ),
                                                          child: Icon(
                                                            Icons.delete,
                                                            size: 18,
                                                            color: Colors.red[600],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Loading overlay
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Yuklanmoqda...",
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}