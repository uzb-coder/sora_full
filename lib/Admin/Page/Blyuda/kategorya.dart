import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../Global/Api_global.dart';

class Printer {
  final String id;
  final String name;
  final String ip;

  Printer({required this.id, required this.name, required this.ip});

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      ip: json['ip'] ?? '',
    );
  }
}

class Subcategory {
  final String title;

  Subcategory({required this.title});

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(title: json['title'] ?? '');
  }
}

class Category {
  final String id;
  final String title;
  final Printer printer;
  final List<Subcategory> subcategories;

  Category({
    required this.id,
    required this.title,
    required this.printer,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final subcategoriesJson = json['subcategories'];
    List<Subcategory> subcategoriesList = [];

    if (subcategoriesJson != null && subcategoriesJson is List) {
      subcategoriesList = subcategoriesJson
          .where((e) => e != null)
          .map((e) => Subcategory.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Category(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      printer: Printer.fromJson(json['printer_id'] ?? {}),
      subcategories: subcategoriesList,
    );
  }
}

Future<List<Category>> fetchCategories(String token) async {
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/categories/list'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final List categoriesJson = data['categories'] ?? [];
    return categoriesJson
        .map((categoryJson) =>
        Category.fromJson(categoryJson as Map<String, dynamic>))
        .toList();
  } else {
    throw Exception('Категория юклаб бўлмади');
  }
}

Future<List<Printer>> fetchPrinters(String token) async {
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/printers'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final List<dynamic> printersJson = data['printers'] ?? [];
    return printersJson
        .map((e) => Printer.fromJson(e as Map<String, dynamic>))
        .toList();
  } else {
    throw Exception("Принтерлар олинмади");
  }
}

class CategoryTablePage extends StatefulWidget {
  final String token;
  const CategoryTablePage({super.key, required this.token});

  @override
  State<CategoryTablePage> createState() => _CategoryTablePageState();
}

class _CategoryTablePageState extends State<CategoryTablePage> {
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = fetchCategories(widget.token);
  }

  void _refresh() {
    setState(() {
      _categoriesFuture = fetchCategories(widget.token);
    });
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Категорияни ўчириш",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Ростдан ҳам ўчирмоқчимисиз?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Йўқ"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Ҳа", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/categories/delete/$id'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (res.statusCode == 200) _refresh();
  }

  void _openAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (_) => AddCategoryDialog(token: widget.token, onRefresh: _refresh),
    );
  }

  void _openEditCategoryDialog(Category category) {
    showDialog(
      context: context,
      builder: (_) => EditCategoryDialog(
        token: widget.token,
        category: category,
        onRefresh: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _openAddCategoryDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Категория яратиш",
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
      body: Container(
        color: const Color(0xFFF5F5F5),
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        height: double.infinity,
        child: FutureBuilder<List<Category>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Хатолик: ${snapshot.error}"));
            }

            final categories = snapshot.data ?? [];

            return LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor: MaterialStateColor.resolveWith(
                                  (states) => Colors.grey[200]!),
                          dataRowColor: MaterialStateColor.resolveWith(
                                  (states) => Colors.white),
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(
                              label: Text(
                                "Категория",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(label: Text("Принтер")),
                            DataColumn(label: Text("IP")),
                            DataColumn(label: Text("Субкатегориялар")),
                            DataColumn(label: Text("Амал")),
                          ],
                          rows: categories.map((cat) {
                            return DataRow(
                              cells: [
                                DataCell(Text(cat.title)),
                                DataCell(Text(cat.printer.name)),
                                DataCell(Text(cat.printer.ip)),
                                DataCell(
                                  Wrap(
                                    spacing: 8, // elementlar orasidagi bo‘shliq
                                    runSpacing: 4, // joy yetmasa yangi qatorga tushish
                                    children: cat.subcategories
                                        .map((sub) => Text("|  ${sub.title} | "))
                                        .toList(),
                                  ),
                                ),

                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () =>
                                            _openEditCategoryDialog(cat),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _confirmDelete(cat.id),
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
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AddCategoryDialog extends StatefulWidget {
  final String token;
  final VoidCallback onRefresh;
  const AddCategoryDialog({super.key, required this.token, required this.onRefresh});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _categoryNameController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final List<String> _subcategories = [];
  List<Printer> _printers = [];
  Printer? _selectedPrinter;

  @override
  void initState() {
    super.initState();
    fetchPrinters(widget.token).then((list) {
      setState(() {
        _printers = list;
        if (_printers.isNotEmpty) _selectedPrinter = _printers[0];
      });
    });
  }

  void _addSubcategory() {
    final name = _subcategoryController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _subcategories.add(name);
        _subcategoryController.clear();
      });
    }
  }

  void _createCategory() async {
    final body = {
      "title": _categoryNameController.text.trim(),
      "printer_id": _selectedPrinter?.id,
      "subcategories": _subcategories.map((e) => {"title": e}).toList(),
    };

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/categories/create'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      Navigator.pop(context);
      widget.onRefresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Хатолик: ${response.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      alignment: Alignment.center,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        "Янги категория қўшиш",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _categoryNameController,
              decoration: InputDecoration(
                labelText: "Категория номи",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Printer>(
              decoration: InputDecoration(
                labelText: "Принтер танланг",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _printers.map((printer) {
                return DropdownMenuItem(
                  value: printer,
                  child: Text(printer.name),
                );
              }).toList(),
              value: _selectedPrinter,
              onChanged: (value) => setState(() => _selectedPrinter = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subcategoryController,
                    decoration: InputDecoration(
                      labelText: "Субкатегория номи",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                IconButton(onPressed: _addSubcategory, icon: const Icon(Icons.add)),
              ],
            ),
            if (_subcategories.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _subcategories.map((e) => Text("• $e")).toList(),
              ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Бекор қилиш"),
        ),
        ElevatedButton(
          onPressed: _createCategory,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlue,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("Сақлаш", style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}

class EditCategoryDialog extends StatefulWidget {
  final String token;
  final Category category;
  final VoidCallback onRefresh;
  const EditCategoryDialog({super.key, required this.token, required this.category, required this.onRefresh});

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late TextEditingController _titleController;
  late TextEditingController _subcategoryController;
  List<String> _subcategories = [];
  List<Printer> _printers = [];
  Printer? _selectedPrinter;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.category.title);
    _subcategoryController = TextEditingController();
    _subcategories = widget.category.subcategories.map((e) => e.title).toList();
    fetchPrinters(widget.token).then((list) {
      setState(() {
        _printers = list;
        _selectedPrinter = list.firstWhere(
              (printer) => printer.id == widget.category.printer.id,
          orElse: () => list.first,
        );
      });
    });
  }

  void _addSubcategory() {
    final name = _subcategoryController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _subcategories.add(name);
        _subcategoryController.clear();
      });
    }
  }

  void _removeSubcategory(String name) {
    setState(() {
      _subcategories.remove(name);
    });
  }

  void _updateCategory() async {
    final body = {
      "title": _titleController.text.trim(),
      "printer_id": _selectedPrinter?.id,
      "subcategories": _subcategories.map((e) => {"title": e}).toList(),
    };

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/categories/update/${widget.category.id}'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context);
      widget.onRefresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Хатолик: ${response.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      alignment: Alignment.center,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        "Категорияни таҳрирлаш",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Категория номи",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Printer>(
              decoration: InputDecoration(
                labelText: "Принтер танланг",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _printers.map((printer) {
                return DropdownMenuItem(
                  value: printer,
                  child: Text(printer.name),
                );
              }).toList(),
              value: _selectedPrinter,
              onChanged: (value) => setState(() => _selectedPrinter = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subcategoryController,
                    decoration: InputDecoration(
                      labelText: "Субкатегория қўшиш",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                IconButton(onPressed: _addSubcategory, icon: const Icon(Icons.add)),
              ],
            ),
            Wrap(
              spacing: 6,
              children: _subcategories.map((sub) {
                return Chip(
                  label: Text(sub),
                  onDeleted: () => _removeSubcategory(sub),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Бекор қилиш"),
        ),
        ElevatedButton(
          onPressed: _updateCategory,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlue,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("Сақлаш", style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
