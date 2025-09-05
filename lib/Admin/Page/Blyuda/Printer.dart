import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../Global/Api_global.dart';

class Printer {
  final String id;
  final String name;
  final String ip;
  final String status;
  final String lastChecked;

  Printer({
    required this.id,
    required this.name,
    required this.ip,
    required this.status,
    required this.lastChecked,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['_id'],
      name: json['name'],
      ip: json['ip'],
      status: json['status'],
      lastChecked: json['lastChecked'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'ip': ip,
    'status': status,
    'lastChecked': lastChecked,
  };
}

class PrinterTablePage extends StatefulWidget {
  final String token;
  const PrinterTablePage({super.key, required this.token});

  @override
  State<PrinterTablePage> createState() => _PrinterTablePageState();
}

class _PrinterTablePageState extends State<PrinterTablePage> {
  List<Printer> printers = [];
  bool isLoading = true;
  bool isCrudLoading = false;
  WebSocketChannel? _channel;
  Timer? _statusCheckTimer;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCacheAndFetch();
    connectToSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  // 📡 WebSocket ulanishi (saqlab qoldim, lekin client-side check qo'shdim)
  void connectToSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://sora-b.vercel.app/printer-status'),
    );
    print("Token : ${widget.token}");

    // Agar server token talab qilsa, uni yuborishga urinib ko'ring (taxminiy fix)
    _channel!.sink.add(jsonEncode({'token': widget.token}));

    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      setState(() {
        final index = printers.indexWhere((p) => p.id == data['id']);
        if (index != -1) {
          printers[index] = Printer(
            id: printers[index].id,
            name: printers[index].name,
            ip: printers[index].ip,
            status: data['status'],
            lastChecked: data['lastChecked'] ?? printers[index].lastChecked,
          );
        }
      });
    });
  }

  // 🏓 Printer online/offline ni tekshirish (client-side ping orqali)
  Future<String> checkPrinterStatus(String ip) async {
    try {
      // Printerlar ko'pincha 80-portda HTTP server yoki 9100-da raw printing ishlatadi.
      // Bu yerda 80-portni sinab ko'ramiz, agar kerak bo'lsa 9100 ga o'zgartiring.
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 1));
      socket.destroy();
      return 'online';
    } catch (e) {
      return 'offline';
    }
  }

  // 🔄 Har 2 sekundda statuslarni yangilash (judda tez real-time uchun)
  void startStatusChecks() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (printers.isEmpty) return;

      List<Future> futures = [];
      for (var printer in List.from(printers)) { // Kopiyasini ishlatish uchun
        futures.add(
          checkPrinterStatus(printer.ip).then((status) {
            final index = printers.indexWhere((p) => p.id == printer.id);
            if (index != -1) {
              printers[index] = Printer(
                id: printers[index].id,
                name: printers[index].name,
                ip: printers[index].ip,
                status: status,
                lastChecked: DateTime.now().toIso8601String(),
              );
            }
          }),
        );
      }
      await Future.wait(futures);
      setState(() {});
      savePrintersToCache(printers);
    });
  }

  // 📂 Local cache dan yuklash
  Future<void> loadCacheAndFetch() async {
    await loadCachedPrinters();
    await fetchPrinters();
    startStatusChecks(); // Fetchdan keyin status checklarni boshlash
  }

  Future<void> loadCachedPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('cached_printers');
    if (jsonString != null) {
      final List list = jsonDecode(jsonString);
      setState(() {
        printers = list.map((e) => Printer.fromJson(e)).toList();
        isLoading = false;
      });
    }
  }

  Future<void> savePrintersToCache(List<Printer> printers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(printers.map((p) => p.toJson()).toList());
    await prefs.setString('cached_printers', jsonString);
  }

  // 🌐 Serverdan printerni olish
  Future<void> fetchPrinters() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/printers');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['printers'];
      print("Token : ${widget.token}");

      setState(() {
        printers = list.map((json) => Printer.fromJson(json)).toList();
        isLoading = false;
      });

      savePrintersToCache(printers);
    } else {
      setState(() => isLoading = false);
    }
  }

  // ➕ Printer yaratish
  Future<void> createPrinter() async {
    setState(() => isCrudLoading = true);

    final name = _nameController.text.trim();
    final ip = _ipController.text.trim();

    if (name.isEmpty || ip.isEmpty) {
      setState(() => isCrudLoading = false);
      return;
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/printers');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name, 'ip': ip}),
    );
    print("📡 createPrinter Status: ${response.statusCode}");
    print("📦 Response Body: ${response.body}");
    print("Token : ${widget.token}");

    setState(() => isCrudLoading = false);

    if (response.statusCode == 200 || response.statusCode == 201) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // ✅ Faqat dialog yopiladi
      _nameController.clear();
      _ipController.clear();
      await fetchPrinters();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Printer yaratishda xatolik yuz berdi")),
      );
    }
  }

  // ✏️ Printer tahrirlash
  Future<void> updatePrinter(String id) async {
    setState(() => isCrudLoading = true);

    final name = _nameController.text.trim();
    final ip = _ipController.text.trim();

    if (name.isEmpty || ip.isEmpty) {
      setState(() => isCrudLoading = false);
      return;
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/printers/$id');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name, 'ip': ip}),
    );
    print("Token : ${widget.token}");
    setState(() => isCrudLoading = false);
    print("📡 updatePrinter Status: ${response.statusCode}");
    print("📦 Response Body: ${response.body}");
    if (response.statusCode == 200) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // ✅ Faqat dialog yopiladi
      _nameController.clear();
      _ipController.clear();
      await fetchPrinters();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Printer yangilanishida xatolik yuz berdi"),
        ),
      );
    }
  }

  // ❌ Printer o‘chirish
  Future<void> deletePrinter(String id) async {
    setState(() => isCrudLoading = true);

    final url = Uri.parse('${ApiConfig.baseUrl}/printers/$id');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    setState(() => isCrudLoading = false);

    if (response.statusCode == 200) {
      printers.removeWhere((p) => p.id == id);
      setState(() {});
      savePrintersToCache(printers);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Printerni o'chirishda xatolik yuz berdi"),
        ),
      );
    }
  }

  // 📋 Dialog
  void showPrinterDialog({String? id, String? initialName, String? initialIp}) {
    _nameController.text = initialName ?? '';
    _ipController.text = initialIp ?? '';

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
        alignment: Alignment.center,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          id == null ? "Yangi Printer qo'shish" : "Printerni tahrirlash",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Printer nomi",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: "IP manzili",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: isCrudLoading
                ? null
                : () => id == null ? createPrinter() : updatePrinter(id),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: isCrudLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text(
              "Saqlash",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void confirmDelete(String id) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
        title: const Text("O'chirishni tasdiqlaysizmi?"),
        content: const Text("Bu printerni butunlay o'chirasiz."),
        actions: [
          TextButton(
            onPressed:
                () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(
                context,
                rootNavigator: true,
              ).pop(); // ✅ Faqat dialog yopiladi
              deletePrinter(id);
            },
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => showPrinterDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Printer yaratish",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : printers.isEmpty
                      ? const Center(child: Text("Printerlar topilmadi"))
                      : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: DataTable2(
                      columnSpacing: 12,
                      headingRowColor: MaterialStateProperty.all(
                        const Color(0xFFE0E0E0),
                      ),
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      columns: const [
                        DataColumn(label: Text("Nomi")),
                        DataColumn(label: Text("IP manzili")),
                        DataColumn(label: Text("Holati")),
                        DataColumn(label: Text("Amallar")),
                      ],
                      rows:
                      printers.map((printer) {
                        return DataRow(
                          cells: [
                            DataCell(Text(printer.name)),
                            DataCell(Text(printer.ip)),
                            DataCell(
                              Text(
                                printer.status.toUpperCase(),
                                style: TextStyle(
                                  color:
                                  printer.status
                                      .toLowerCase() ==
                                      'online'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Color(0xFF2196F3),
                                    ),
                                    onPressed:
                                        () => showPrinterDialog(
                                      id: printer.id,
                                      initialName: printer.name,
                                      initialIp: printer.ip,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed:
                                        () => confirmDelete(
                                      printer.id,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isCrudLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}