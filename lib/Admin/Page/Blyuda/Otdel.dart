import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sora/Global/Api_global.dart';
import 'Blyuda.dart';
import 'Printer.dart';
import 'kategorya.dart';
class MainScreen extends StatefulWidget {
  final String token;

  const MainScreen({super.key, required this.token});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _cachedPages;

  @override
  void initState() {
    super.initState();
    _cachedPages = [
      DepartmentsDataTable(token: widget.token),
      CategoryTablePage(token: widget.token),
      FoodsTablePage(token: widget.token),
      PrinterTablePage(token: widget.token),
      const SizedBox(), // Chiqish uchun bo‘sh joy
    ];
  }

  void _onTabTapped(int index) {
    if (index == 4) {
      Navigator.pop(context); // Chiqish
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> buttonTitles = [
      'Otdel',
      'Kategorya',
      'Blyuda',
      'Printer',
      'Выход',
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _cachedPages,
            ),
          ),
          const Divider(height: 1),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(buttonTitles.length, (index) {
                return ElevatedButton(
                  onPressed: () => _onTabTapped(index),
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
                  child: Text(
                    buttonTitles[index],
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}



class DepartmentsDataTable extends StatefulWidget {
  final String token;
  const DepartmentsDataTable({super.key, required this.token});

  @override
  State<DepartmentsDataTable> createState() => _DepartmentsDataTableState();
}

class _DepartmentsDataTableState extends State<DepartmentsDataTable> {
  List<dynamic> _departments = [];
  bool _isLoading = true; // Faqat sahifa birinchi yuklanayotganda
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}/departments/list');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _departments = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Xatolik: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Internet xatolik: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createDepartment(String title, String warehouse) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/departments/create');
    final body = json.encode({"title": title, "warehouse": warehouse});

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _fetchDepartments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xatolik: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Internet xatolik: $e")),
      );
    }
  }

  Future<void> _updateDepartment(String id, String title, String warehouse) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/departments/update/$id');
    final body = json.encode({"title": title, "warehouse": warehouse});

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        await _fetchDepartments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Yangilashda xatolik: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Internet xatolik: $e")),
      );
    }
  }

  Future<void> _deleteDepartment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("O‘chirishni tasdiqlang"),
        content: const Text("Haqiqatan ham ushbu bo‘limni o‘chirmoqchimisiz?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Yo‘q")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Ha"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final url = Uri.parse('${ApiConfig.baseUrl}/departments/delete/$id');

      try {
        final response = await http.delete(
          url,
          headers: {'Authorization': 'Bearer ${widget.token}'},
        );

        if (response.statusCode == 200) {
          await _fetchDepartments();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("O‘chirishda xatolik: ${response.statusCode}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Internet xatolik: $e")),
        );
      }
    }
  }

  void _showDepartmentDialog({bool isEdit = false, String? id, String? initialTitle, String? initialWarehouse}) {
    final titleController = TextEditingController(text: initialTitle ?? '');
    final warehouseController = TextEditingController(text: initialWarehouse ?? '');

    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;  // Dialog ichidagi loading flag

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> save() async {
              setStateDialog(() {
                isLoading = true;
              });

              try {
                if (isEdit && id != null) {
                  await _updateDepartment(id, titleController.text, warehouseController.text);
                } else {
                  await _createDepartment(titleController.text, warehouseController.text);
                }
                Navigator.of(context).pop();
              } finally {
                setStateDialog(() {
                  isLoading = false;
                });
              }
            }

            return AlertDialog(
              alignment: Alignment.center,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdit ? "Bo‘limni tahrirlash" : "Yangi bo‘lim qo‘shish",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: "Bo‘lim nomi",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: warehouseController,
                      decoration: InputDecoration(
                        labelText: "Ombor nomi",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      enabled: !isLoading,
                    ),
                    if (isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text("Bekor qilish"),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Saqlash",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) return Center(child: Text(_error!));

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: () => _showDepartmentDialog(),
            icon: const Icon(Icons.add),
            label: const Text("Bo'lim qo'shish"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
                        dataRowColor: MaterialStateProperty.all(Colors.grey[100]),
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        dataTextStyle: const TextStyle(color: Colors.black87),
                        columnSpacing: 32,
                        horizontalMargin: 16,
                        columns: const [
                          DataColumn(label: Text('Nomi')),
                          DataColumn(label: Text('Ombor')),
                          DataColumn(label: Text('Amallar')),
                        ],
                        rows: _departments.map((dep) {
                          return DataRow(
                            cells: [
                              DataCell(Text(dep['title'] ?? '')),
                              DataCell(Text(dep['warehouse'] ?? '')),
                              DataCell(Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      _showDepartmentDialog(
                                        isEdit: true,
                                        id: dep['_id'],
                                        initialTitle: dep['title'],
                                        initialWarehouse: dep['warehouse'],
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteDepartment(dep['_id']),
                                  ),
                                ],
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

