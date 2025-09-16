import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../../Global/Api_global.dart';


class Food {
  final String id;
  final String name;
  final int price;
  final String warehouse;
  final String unit;
  final int soni;
  final String subcategory;
  final String categoryId;
  final String departmentId;
  final String? expiration;

  Food({
    required this.id,
    required this.name,
    required this.price,
    required this.warehouse,
    required this.unit,
    required this.soni,
    required this.subcategory,
    required this.categoryId,
    required this.departmentId,
    this.expiration,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: _parseToInt(json['price']),
      warehouse: json['warehouse']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      soni: _parseToInt(json['soni']),
      subcategory: json['subcategory']?.toString() ?? '',
      categoryId:
      json['category'] is Map
          ? json['category']['_id']?.toString() ?? ''
          : json['category']?.toString() ?? '',
      departmentId:
      json['department_id'] is Map
          ? json['department_id']['_id']?.toString() ?? ''
          : json['department_id']?.toString() ?? '',
      expiration: json['expiration']?.toString(),
    );
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed?.toInt() ?? 0;
    }
    return 0;
  }
}

class Category {
  final String id;
  final String title;
  final List<String> subcategories;

  Category({
    required this.id,
    required this.title,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subcategories:
      (json['subcategories'] as List<dynamic>?)
          ?.map(
            (s) =>
        s is Map
            ? s['title']?.toString() ?? ''
            : s?.toString() ?? '',
      )
          .toList() ??
          [],
    );
  }
}

class Department {
  final String id;
  final String title;
  final String warehouse;

  Department({required this.id, required this.title, required this.warehouse});

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      warehouse: json['warehouse']?.toString() ?? '',
    );
  }
}

class FoodsTablePage extends StatefulWidget {
  final String token;
  const FoodsTablePage({super.key, required this.token});

  @override
  State<FoodsTablePage> createState() => _FoodsTablePageState();
}

class _FoodsTablePageState extends State<FoodsTablePage> {
  late Future<List<Food>> _futureFoods;
  late Future<List<Category>> _futureCategories;
  late Future<List<Department>> _futureDepartments;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _futureFoods = fetchFoods(widget.token);
    _futureCategories = fetchCategories(widget.token);
    _futureDepartments = fetchDepartments(widget.token);
  }


  // 🔎 qidiruv
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // 📜 scroll saqlash
  final ScrollController _scrollController = ScrollController();
  double _savedScrollOffset = 0.0;

  @override

  void _refresh() {
    setState(() {
      _savedScrollOffset = _scrollController.offset;
      _loadData();
    });
  }

  Future<void> _showCreateFoodDialog() async => _showFoodDialog(null);

  Future<void> _showEditFoodDialog(Food food) async => _showFoodDialog(food);

  Future<void> _showFoodDialog(Food? food) async {
    final nameController = TextEditingController(text: food?.name ?? '');
    final priceController = TextEditingController(
      text: food?.price.toString() ?? '',
    );
    final quantityController = TextEditingController(
      text: food?.soni.toString() ?? '',
    );
    final dateController = TextEditingController(text: food?.expiration ?? '');

    String? selectedUnit = food?.unit;
    String? selectedSubcategory =
    food?.subcategory.isNotEmpty == true ? food?.subcategory : null;
    Category? selectedCategory =
    food != null ? await _getCategoryById(food.categoryId) : null;
    Department? selectedDepartment =
    food != null ? await _getDepartmentById(food.departmentId) : null;

    const units = ['dona', 'kg', 'litr', 'sm', 'gramm', 'metr', 'bek'];
    final isEditing = food != null;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true, // Dialog tashqarisiga bosib yopish imkoniyati
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return FutureBuilder(
              future: Future.wait([_futureCategories, _futureDepartments]),
              builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AlertDialog(
                    content: SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return AlertDialog(
                    title: const Text('Xatolik'),
                    content: Text(
                      'Ma\'lumotlarni yuklashda xatolik: ${snapshot.error ?? 'Noma\'lum xatolik'}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                }

                final categories = snapshot.data![0] as List<Category>;
                final departments = snapshot.data![1] as List<Department>;
                List<String> subcategories = selectedCategory?.subcategories ?? [];

                return Dialog(
                  // AlertDialog o'rniga Dialog ishlatamiz - ko'proq nazorat beradi
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 500, // Maksimal kenglik
                      maxHeight: 600, // Maksimal balandlik
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dialog header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isEditing ? Icons.edit : Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isEditing
                                      ? 'Mahsulotni tahrirlash'
                                      : 'Yangi mahsulot qo\'shish',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 30,
                                  minHeight: 30,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Dialog body - scrollable content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Taom nomi
                                  TextField(
                                    controller: nameController,
                                    autofocus: true, // Avtomatik focus
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Taom nomi *',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Narxi va Birligi - bir qatorda
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: priceController,
                                          keyboardType: TextInputType.number,
                                          textInputAction: TextInputAction.next,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          decoration: const InputDecoration(
                                            labelText: 'Narxi *',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.attach_money),
                                            suffixText: "so'm",
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          decoration: const InputDecoration(
                                            labelText: 'Birligi *',
                                            border: OutlineInputBorder(),
                                          ),
                                          value: selectedUnit,
                                          items: units
                                              .map(
                                                (u) => DropdownMenuItem(
                                              value: u,
                                              child: Text(u),
                                            ),
                                          )
                                              .toList(),
                                          onChanged: (v) =>
                                              setDialogState(() => selectedUnit = v),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Soni
                                  TextField(
                                    controller: quantityController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Soni (ombordagi) *',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Yaroqlilik muddati
                                  TextField(
                                    controller: dateController,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Yaroqlilik muddati (ixtiyoriy)',
                                      border: OutlineInputBorder(),
                                      suffixIcon: Icon(Icons.date_range),
                                    ),
                                    onTap: () async {
                                      DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) {
                                        dateController.text = DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(picked);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Kategoriya
                                  DropdownButtonFormField<Category>(
                                    decoration: const InputDecoration(
                                      labelText: 'Kategoriya *',
                                      border: OutlineInputBorder(),
                                    ),
                                    value: selectedCategory,
                                    items: categories
                                        .map(
                                          (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c.title),
                                      ),
                                    )
                                        .toList(),
                                    onChanged: (val) => setDialogState(() {
                                      selectedCategory = val;
                                      selectedSubcategory = null;
                                      subcategories = val?.subcategories ?? [];
                                    }),
                                  ),

                                  // Subkategoriya (conditional)
                                  if (subcategories.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'Subkategoriya (ixtiyoriy)',
                                        border: OutlineInputBorder(),
                                      ),
                                      value: selectedSubcategory,
                                      items: [
                                        // Bo'sh variant qo'shamiz
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('Tanlanmagan',
                                              style: TextStyle(color: Colors.grey)),
                                        ),
                                        ...subcategories.map(
                                              (sub) => DropdownMenuItem(
                                            value: sub,
                                            child: Text(sub),
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) => setDialogState(
                                            () => selectedSubcategory = val,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),

                                  // Bo'lim
                                  DropdownButtonFormField<Department>(
                                    decoration: const InputDecoration(
                                      labelText: 'Bo\'lim (otdel) *',
                                      border: OutlineInputBorder(),
                                    ),
                                    value: selectedDepartment,
                                    items: departments
                                        .map(
                                          (d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(
                                          '${d.title} (${d.warehouse})',
                                        ),
                                      ),
                                    )
                                        .toList(),
                                    onChanged: (val) => setDialogState(
                                          () => selectedDepartment = val,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Dialog footer
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Bekor qilish'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  // Validatsiya
                                  if (nameController.text.trim().isEmpty) {
                                    return _showErrorSnackBar(
                                      context,
                                      'Taom nomini kiriting!',
                                    );
                                  }
                                  final priceText = priceController.text.trim();
                                  if (priceText.isEmpty) {
                                    return _showErrorSnackBar(
                                      context,
                                      'Narxni kiriting!',
                                    );
                                  }
                                  final price = int.tryParse(priceText);
                                  if (price == null || price <= 0) {
                                    return _showErrorSnackBar(
                                      context,
                                      'To\'g\'ri narx kiriting!',
                                    );
                                  }
                                  if (selectedUnit == null) {
                                    return _showErrorSnackBar(
                                      context,
                                      'Birlikni tanlang!',
                                    );
                                  }
                                  final quantityText = quantityController.text.trim();
                                  if (quantityText.isEmpty) {
                                    return _showErrorSnackBar(context, 'Sonni kiriting!');
                                  }
                                  final quantity = int.tryParse(quantityText);
                                  if (quantity == null || quantity < 0) {
                                    return _showErrorSnackBar(
                                      context,
                                      'To\'g\'ri sonni kiriting!',
                                    );
                                  }
                                  if (selectedCategory == null) {
                                    return _showErrorSnackBar(
                                      context,
                                      'Kategoriyani tanlang!',
                                    );
                                  }
                                  if (selectedDepartment == null) {
                                    return _showErrorSnackBar(
                                      context,
                                      'Bo\'limni tanlang!',
                                    );
                                  }

                                  try {
                                    // Loading dialog
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => AlertDialog(
                                        content: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const CircularProgressIndicator(),
                                            const SizedBox(width: 20),
                                            Flexible(
                                              child: Text(
                                                isEditing
                                                    ? 'Mahsulot yangilanmoqda...'
                                                    : 'Mahsulot qo\'shilmoqda...',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    if (isEditing) {
                                      await updateFood(
                                        widget.token,
                                        food!.id,
                                        nameController.text.trim(),
                                        price,
                                        selectedCategory!.id,
                                        selectedSubcategory ?? '',
                                        selectedDepartment!.id,
                                        selectedDepartment!.warehouse,
                                        selectedUnit!,
                                        quantity,
                                        dateController.text.isEmpty
                                            ? null
                                            : dateController.text,
                                      );
                                    } else {
                                      await createFood(
                                        widget.token,
                                        nameController.text.trim(),
                                        price,
                                        selectedCategory!.id,
                                        selectedSubcategory ?? '',
                                        selectedDepartment!.id,
                                        selectedDepartment!.warehouse,
                                        selectedUnit!,
                                        quantity,
                                        dateController.text.isEmpty
                                            ? null
                                            : dateController.text,
                                      );
                                    }

                                    if (!mounted) return;
                                    Navigator.pop(context); // Loading dialog yopish
                                    Navigator.pop(context); // Main dialog yopish
                                    setState(_loadData);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isEditing
                                              ? 'Mahsulot muvaffaqiyatli yangilandi!'
                                              : 'Mahsulot muvaffaqiyatli qo\'shildi!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    Navigator.pop(context); // Loading dialog yopish
                                    _showErrorSnackBar(context, 'Xatolik: $e');
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isEditing ? Icons.update : Icons.add,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(isEditing ? 'Yangilash' : 'Qo\'shish'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  Future<Category?> _getCategoryById(String id) async {
    try {
      final categories = await _futureCategories;
      return categories.firstWhereOrNull((c) => c.id == id);
    } catch (e) {
      debugPrint('Category topishda xato: $e');
      return null;
    }
  }

  Future<Department?> _getDepartmentById(String id) async {
    try {
      final departments = await _futureDepartments;
      return departments.firstWhereOrNull((d) => d.id == id);
    } catch (e) {
      debugPrint('Department topishda xato: $e');
      return null;
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      height: 50,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {bool isTitle = false}) {
    return Container(
      height: 60,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isTitle ? FontWeight.w500 : FontWeight.normal,
          color: Colors.black87,
        ),
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
            // Chap tomonda: Mahsulot yaratish
            ElevatedButton.icon(
              onPressed: _showCreateFoodDialog,
              icon: const Icon(Icons.add, color: Colors.white, size: 16),
              label: const Text(
                "Mahsulot yaratish",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),

            const Spacer(), // 🔑 chap va o‘ngni ajratadi

            // O‘ng tomonda: Search + Yangilash yonma-yon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔎 Search
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 250,),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Qidirish...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // 🔄 Yangilash tugmasi
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, color: Colors.grey),
                  tooltip: 'Yangilash',
                ),
              ],
            ),
          ],

        ),
      ),
      body: Container(
        color: Colors.grey[100],
        child: FutureBuilder(
          future: Future.wait([_futureFoods, _futureCategories]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text("Xatolik: ${snapshot.error}"),
              );
            }

            final foods = snapshot.data![0] as List<Food>? ?? [];
            final categories = snapshot.data![1] as List<Category>? ?? [];
            final categoryMap = {for (var c in categories) c.id: c.title};

            // 🔎 filter
            final filteredFoods = foods.where((f) {
              final q = _searchQuery;
              if (q.isEmpty) return true;
              return f.name.toLowerCase().contains(q) ||
                  f.price.toString().contains(q) ||
                  f.unit.toLowerCase().contains(q) ||
                  f.soni.toString().contains(q) ||
                  (f.expiration ?? "").toLowerCase().contains(q) ||
                  (categoryMap[f.categoryId] ?? "").toLowerCase().contains(q) ||
                  f.subcategory.toLowerCase().contains(q);
            }).toList();

            // 📜 scroll pozitsiyani qaytarish
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_savedScrollOffset > 0 &&
                  _scrollController.hasClients &&
                  _scrollController.offset == 0) {
                _scrollController.jumpTo(_savedScrollOffset);
                _savedScrollOffset = 0.0;
              }
            });

            if (filteredFoods.isEmpty) {
              return const Center(child: Text("Mos mahsulot topilmadi"));
            }

            return Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  // header
                  Container(
                    height: 50,
                    color: Colors.grey[200],
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: _buildHeaderCell("Nomi")),
                        Expanded(flex: 1, child: _buildHeaderCell("Narxi")),
                        Expanded(flex: 1, child: _buildHeaderCell("Birligi")),
                        Expanded(flex: 1, child: _buildHeaderCell("Soni")),
                        Expanded(flex: 1, child: _buildHeaderCell("Yaroqlilik")),
                        Expanded(flex: 2, child: _buildHeaderCell("Kategoriya")),
                        Expanded(flex: 2, child: _buildHeaderCell("Subkategoriya")),
                        Expanded(flex: 1, child: _buildHeaderCell("Amallar")),
                      ],
                    ),
                  ),
                  // body
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: filteredFoods.length,
                      itemBuilder: (context, index) {
                        final food = filteredFoods[index];
                        final categoryTitle =
                            categoryMap[food.categoryId] ?? 'Noma\'lum';
                        return Container(
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!),
                            ),
                            color: index % 2 == 0
                                ? Colors.white
                                : Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: _buildDataCell(food.name, isTitle: true)),
                              Expanded(flex: 1, child: _buildDataCell("${food.price} so'm")),
                              Expanded(flex: 1, child: _buildDataCell(food.unit)),
                              Expanded(flex: 1, child: _buildDataCell(food.soni.toString())),
                              Expanded(flex: 1, child: _buildDataCell(food.expiration?.substring(0, 10) ?? '')),
                              Expanded(flex: 2, child: _buildDataCell(categoryTitle)),
                              Expanded(flex: 2, child: _buildDataCell(food.subcategory.isNotEmpty ? food.subcategory : '-')),
                              Expanded(
                                flex: 1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                                      onPressed: () => _showEditFoodDialog(food),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                      onPressed: () => _confirmDelete(food),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  Future<void> _confirmDelete(Food food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
        title: const Text("Tasdiqlash"),
        content: Text("\"${food.name}\" mahsulotini o'chirmoqchimisiz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Yo'q"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ha", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('O\'chirilmoqda...'),
              ],
            ),
          ),
        );
        await deleteFood(widget.token, food.id);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mahsulot o'chirildi"),
            backgroundColor: Colors.green,
          ),
        );
        setState(_loadData);
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> deleteFood(String token, String foodId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/foods/delete/$foodId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      final errorBody =
      response.body.isNotEmpty
          ? jsonDecode(response.body)['message'] ?? response.body
          : 'Noma\'lum xatolik';
      throw Exception('Mahsulotni o\'chirishda xatolik: $errorBody');
    }
  }

  Future<List<Food>> fetchFoods(String token) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/foods/list'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data is List ? data : data['foods'] as List? ?? [];
      return list.map((f) => Food.fromJson(f)).toList();
    } else {
      throw Exception("Mahsulotlarni yuklashda xatolik: ${res.statusCode}");
    }
  }

  Future<List<Category>> fetchCategories(String token) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/categories/list'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data is List ? data : data['categories'] as List? ?? [];
      final categories = list.map((c) => Category.fromJson(c)).toList();
      for (var category in categories) {
        debugPrint('Kategoriya ID: ${category.id}, Title: ${category.title}, Subkategoriyalar: ${category.subcategories}');
      }
      return categories;
    } else {
      throw Exception("Kategoriyalarni yuklashda xatolik: ${res.statusCode}");
    }
  }

  Future<List<Department>> fetchDepartments(String token) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/departments/list'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data is List ? data : data['departments'] as List? ?? [];
      final departments = list.map((d) => Department.fromJson(d)).toList();
      for (var department in departments) {
        debugPrint('Department ID: ${department.id}, Title: ${department.title}, Warehouse: ${department.warehouse}');
      }
      return departments;
    } else {
      throw Exception("Bo'limlarni yuklashda xatolik: ${res.statusCode}");
    }
  }

  Future<void> createFood(
      String token,
      String name,
      int price,
      String categoryId,
      String subcategory,
      String departmentId,
      String warehouse,
      String unit,
      int soni,
      String? expiration,
      ) async {
    // Expiration ni to'g'ri formatda tayyorlaymiz
    String? formattedExpiration;
    if (expiration != null && expiration.isNotEmpty) {
      // Agar sana ISO format bo'lsa (2025-08-12), uni to'g'ri formatga o'tkazamiz
      try {
        DateTime date = DateTime.parse(expiration);
        formattedExpiration = date.toIso8601String();
      } catch (e) {
        // Agar parse qila olmasa, asl formatni saqlaymiz
        formattedExpiration = expiration;
      }
    }

    final Map<String, dynamic> foodData = {
      'name': name,
      'price': price,
      'category': categoryId,
      'department_id': departmentId,
      'warehouse': warehouse,
      'unit': unit,
      'soni': soni,
    };

    // Subcategory ni qo'shamiz (agar bo'sh bo'lsa ham)
    if (subcategory.isNotEmpty) {
      foodData['subcategory'] = subcategory;
    }

    // Expiration ni qo'shamiz (agar mavjud bo'lsa)
    if (formattedExpiration != null) {
      foodData['expiration'] = formattedExpiration;
    }

    debugPrint('API ga yuborilayotgan ma\'lumotlar: ${jsonEncode(foodData)}');

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/foods/create'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(foodData),
    );

    debugPrint('API javobi status: ${response.statusCode}');
    debugPrint('API javobi body: ${response.body}');

    if (response.statusCode != 201) {
      final errorMessage = response.body.isNotEmpty
          ? jsonDecode(response.body)['message'] ?? 'Noma\'lum xatolik'
          : 'Noma\'lum xatolik';
      throw Exception("Mahsulot qo'shishda xatolik: $errorMessage");
    }
  }

  Future<void> updateFood(
      String token,
      String foodId,
      String name,
      int price,
      String categoryId,
      String subcategory,
      String departmentId,
      String warehouse,
      String unit,
      int soni,
      String? expiration,
      ) async {
    // Expiration ni to'g'ri formatda tayyorlaymiz
    String? formattedExpiration;
    if (expiration != null && expiration.isNotEmpty) {
      try {
        DateTime date = DateTime.parse(expiration);
        formattedExpiration = date.toIso8601String();
      } catch (e) {
        formattedExpiration = expiration;
      }
    }

    final foodData = {
      'name': name,
      'price': price,
      'category': categoryId,
      'department_id': departmentId,
      'warehouse': warehouse,
      'unit': unit,
      'soni': soni,
    };

    if (subcategory.isNotEmpty) {
      foodData['subcategory'] = subcategory;
    }

    if (formattedExpiration != null) {
      foodData['expiration'] = formattedExpiration;
    }

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/foods/update/$foodId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(foodData),
    );

    if (response.statusCode != 200) {
      final errorMessage =
      response.body.isNotEmpty
          ? jsonDecode(response.body)['message'] ?? 'Noma\'lum xatolik'
          : 'Noma\'lum xatolik';
      throw Exception("Mahsulotni yangilashda xatolik: $errorMessage");
    }
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
