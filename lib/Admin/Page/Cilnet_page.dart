import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sora/Global/Api_global.dart';

// Umumiy ranglar
const Color primaryColor = Color(0xFF2196F3);
const Color backgroundColor = Color(0xFFF5F5F5);
const Color errorColor = Colors.redAccent;
const Color tableHeaderColor = Color(0xFFE3F2FD);

void showCustomSnackBar(BuildContext context, String message, {bool error = false}) {
  final snackBar = SnackBar(
    content: Text(message),
    backgroundColor: error ? Colors.red.shade600 : primaryColor,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    duration: const Duration(seconds: 2),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

class ClientPage extends StatefulWidget {
  final String token;
  const ClientPage({super.key, required this.token});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  List<dynamic> _clients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/clients/list"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _clients = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Сервер хато: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Тармоқда хато юз берди: $e";
        _isLoading = false;
      });
    }
  }

  Future<bool> _createClient({
    required String name,
    required String phone,
    required int discount,
    required String cardNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/clients/create"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "name": name,
          "phone": phone,
          "discount": discount,
          "card_number": cardNumber,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        final body = response.body;
        print("Хато: ${response.statusCode} - $body");
        return false;
      }
    } catch (e) {
      print("Хато: $e");
      return false;
    }
  }

  Future<bool> _updateClient({
    required String id,
    required String name,
    required String phone,
    required int discount,
    required String cardNumber,
  }) async {
    print("Янгилаш client id: $id");
    try {
      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/clients/update/$id"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "name": name,
          "phone": phone,
          "discount": discount,
          "card_number": cardNumber,
        }),
      );

      print("Янгилаш статус: ${response.statusCode}");
      print("Янгилаш жавоби: ${response.body}");

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Янгилаш хато: $e");
      return false;
    }
  }

  Future<bool> _deleteClient(String id) async {
    print("Ўчириш client id: $id");
    try {
      final response = await http.delete(
        Uri.parse("${ApiConfig.baseUrl}/clients/delete/$id"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
      );

      print("Ўчириш статус: ${response.statusCode}");
      print("Ўчириш жавоби: ${response.body}");

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Ўчириш хато: $e");
      return false;
    }
  }

  Future<void> _showAddClientModal() async {
    final _formKey = GlobalKey<FormState>();

    String name = '';
    String phone = '';
    String discount = '';
    String cardNumber = '';

    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titleTextStyle: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              title: const Text("Янги мижоз қўшиш"),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(labelText: "Исм"),
                        onChanged: (val) => name = val,
                        validator: (val) => val == null || val.isEmpty ? "Исм киритинг" : null,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(labelText: "Телефон"),
                        keyboardType: TextInputType.phone,
                        onChanged: (val) => phone = val,
                        validator: (val) => val == null || val.isEmpty ? "Телефон киритинг" : null,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Чегирма (%)",
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => discount = val,
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Чегирма киритинг";
                          final number = int.tryParse(val);
                          if (number == null) return "Фақат рақам киритинг";
                          if (number < 0 || number > 100) return "0 дан 100 гача рақам киритинг";
                          return null;
                        },
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Карта рақами",
                        ),
                        onChanged: (val) => cardNumber = val,
                        validator: (val) => val == null || val.isEmpty ? "Карта рақами киритинг" : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Бекор қилиш"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        setStateModal(() {
                          isLoading = true;
                        });
                        final success = await _createClient(
                          name: name,
                          phone: phone,
                          discount: int.parse(discount),
                          cardNumber: cardNumber,
                        );
                        setStateModal(() {
                          isLoading = false;
                        });
                        if (success) {
                          Navigator.of(context).pop();
                          _fetchClients();
                          showCustomSnackBar(context, "Мижоз муваффақиятли қўшилди");
                        } else {
                          showCustomSnackBar(context, "Хато юз берди", error: true);
                        }
                      }
                    },
                    child: const Text("Яратиш"),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditClientModal(Map<String, dynamic> client) async {
    final _formKey = GlobalKey<FormState>();

    String name = client['name'] ?? '';
    String phone = client['phone'] ?? '';
    String discount = (client['discount']?.toString() ?? '0');
    String cardNumber = client['card_number'] ?? '';

    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titleTextStyle: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              title: const Text("Мижозни таҳрирлаш"),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: name,
                        decoration: const InputDecoration(labelText: "Исм"),
                        onChanged: (val) => name = val,
                        validator: (val) => val == null || val.isEmpty ? "Исм киритинг" : null,
                      ),
                      TextFormField(
                        initialValue: phone,
                        decoration: const InputDecoration(labelText: "Телефон"),
                        keyboardType: TextInputType.phone,
                        onChanged: (val) => phone = val,
                        validator: (val) => val == null || val.isEmpty ? "Телефон киритинг" : null,
                      ),
                      TextFormField(
                        initialValue: discount,
                        decoration: const InputDecoration(
                          labelText: "Чегирма (%)",
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => discount = val,
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Чегирма киритинг";
                          final number = int.tryParse(val);
                          if (number == null) return "Фақат рақам киритинг";
                          if (number < 0 || number > 100) return "0 дан 100 гача рақам киритинг";
                          return null;
                        },
                      ),
                      TextFormField(
                        initialValue: cardNumber,
                        decoration: const InputDecoration(
                          labelText: "Карта рақами",
                        ),
                        onChanged: (val) => cardNumber = val,
                        validator: (val) => val == null || val.isEmpty ? "Карта рақами киритинг" : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Бекор қилиш"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        setStateModal(() {
                          isLoading = true;
                        });

                        final success = await _updateClient(
                          id: client['_id'],
                          name: name,
                          phone: phone,
                          discount: int.parse(discount),
                          cardNumber: cardNumber,
                        );

                        setStateModal(() {
                          isLoading = false;
                        });

                        if (success) {
                          Navigator.of(context).pop();
                          _fetchClients();
                          showCustomSnackBar(context, "Мижоз муваффақиятли янгиланди");
                        } else {
                          showCustomSnackBar(context, "Янгилашда хато юз берди", error: true);
                        }
                      }
                    },
                    child: const Text("Сақлаш"),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        title: const Text("Ўчиришни тасдиқланг"),
        content: const Text("Мижозни ўчирмоқчимисиз?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Бекор қилиш"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Ўчириш"),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
          ),
        ],
      ),
    );

    if (result == true) {
      final success = await _deleteClient(id);
      if (success) {
        _fetchClients();
        showCustomSnackBar(context, "Мижоз ўчирилди");
      } else {
        showCustomSnackBar(context, "Ўчиришда хато юз берди", error: true);
      }
    }
  }

  DataTable _buildDataTable() {
    return DataTable(
      columnSpacing: 24,
      headingRowColor: MaterialStateProperty.all(tableHeaderColor),
      headingTextStyle: const TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.bold,
      ),
      columns: const [
        DataColumn(label: Text("Исм")),
        DataColumn(label: Text("Телефон")),
        DataColumn(label: Text("Чегирма")),
        DataColumn(label: Text("Карта рақами")),
        DataColumn(label: Text("Ҳarakatлар")),
      ],
      rows: _clients.map((client) {
        return DataRow(
          cells: [
            DataCell(Text(client['name']?.toString() ?? '')),
            DataCell(Text(client['phone']?.toString() ?? '')),
            DataCell(Text("${client['discount']?.toString() ?? '0'}%")),
            DataCell(Text(client['card_number']?.toString() ?? '')),
            DataCell(
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: primaryColor),
                    tooltip: 'Таҳрирлаш',
                    onPressed: () {
                      _showEditClientModal(client);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: errorColor),
                    tooltip: 'Ўчириш',
                    onPressed: () {
                      _confirmDelete(client['_id']);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _showAddClientModal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Фойдаланувчи яратиш",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: _buildDataTable(),
              ),
            ),
          );
        },
      ),
      floatingActionButton: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
        },
        label: const Text("Чиқиш"),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 70),
          backgroundColor: backgroundColor,
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
