import 'package:flutter/material.dart';
import '../../DB/Servis/db_helper.dart';
import 'dart:async';

// ====== MODELAR (oddiy entitylar) ======
class CategoryEntity {
  final String id;
  final String title;
  final String printerId;
  final String printerName;
  final String printerIp;

  CategoryEntity({
    required this.id,
    required this.title,
    required this.printerId,
    required this.printerName,
    required this.printerIp,
  });

  factory CategoryEntity.fromMap(Map<String, Object?> m) {
    return CategoryEntity(
      id: (m['id'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      printerId: (m['printer_id'] ?? '') as String,
      printerName: (m['printer_name'] ?? '') as String,
      printerIp: (m['printer_ip'] ?? '') as String,
    );
  }
}

class SubcategoryEntity {
  final String id;
  final String title;
  final String categoryId;

  SubcategoryEntity({
    required this.id,
    required this.title,
    required this.categoryId,
  });

  factory SubcategoryEntity.fromMap(Map<String, Object?> m) {
    return SubcategoryEntity(
      id: (m['id'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      categoryId: (m['category_id'] ?? '') as String,
    );
  }
}

class FoodEntity {
  final String id;
  final String name;
  final num price;
  final String unit;
  final String categoryId;
  final String? subcategory; // title bo‘lishi mumkin

  FoodEntity({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.categoryId,
    this.subcategory,
  });

  factory FoodEntity.fromMap(Map<String, Object?> m) {
    return FoodEntity(
      id: (m['id'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      price: (m['price'] ?? 0) as num,
      unit: (m['unit'] ?? '') as String,
      categoryId: (m['category_id'] ?? '') as String,
      subcategory: (m['subcategory'] as String?),
    );
  }
}

// ====== ASOSIY SAHIFA ======
class CategoryFoodPage extends StatefulWidget {
  const CategoryFoodPage({Key? key}) : super(key: key);

  @override
  State<CategoryFoodPage> createState() => _CategoryFoodPageState();
}

class _CategoryFoodPageState extends State<CategoryFoodPage> {
  // UI holati
  List<CategoryEntity> _categories = [];
  List<SubcategoryEntity> _subcategories = [];
  List<FoodEntity> _foods = [];
  String? _selectedCategoryId;
  String? _selectedSubcategoryTitle; // title bo‘yicha filter
  String _search = '';

  bool _isLoadingCats = true;
  bool _isLoadingSubs = false;
  bool _isLoadingFoods = false;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    await _loadCategories();
    if (_selectedCategoryId != null) {
      await _loadSubcategories(_selectedCategoryId!);
      await _loadFoods(categoryId: _selectedCategoryId!, subTitle: null);
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() => _isLoadingCats = true);
      final rows = await DBHelper.getCategories();
      final cats = rows.map((m) => CategoryEntity.fromMap(m)).toList();

      if (!mounted) return;
      setState(() {
        _categories = cats;
        _isLoadingCats = false;
        if (_categories.isNotEmpty) {
          _selectedCategoryId ??= _categories.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCats = false);
      _showSnack('Kategoriya yuklashda xatolik: $e');
    }
  }

  Future<void> _loadSubcategories(String categoryId) async {
    try {
      setState(() {
        _isLoadingSubs = true;
        _selectedSubcategoryTitle = null; // default: Barchasi
      });

      final db = await DBHelper.database;
      final rows = await db.query(
        'subcategories',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'title ASC',
      );
      final subs = rows.map((m) => SubcategoryEntity.fromMap(m)).toList();

      if (!mounted) return;
      setState(() {
        _subcategories = subs;
        _isLoadingSubs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSubs = false);
      _showSnack('Subkategoriya yuklashda xatolik: $e');
    }
  }

  Future<void> _loadFoods({
    required String categoryId,
    String? subTitle,
  }) async {
    try {
      setState(() => _isLoadingFoods = true);
      final db = await DBHelper.database;

      // where shartini dinamik tuzamiz
      String where = 'category_id = ?';
      final args = <Object?>[categoryId];

      if (subTitle != null && subTitle.isNotEmpty) {
        where += ' AND subcategory = ?';
        args.add(subTitle);
      }

      // Qidiruv (name LIKE)
      if (_search.isNotEmpty) {
        where += ' AND name LIKE ?';
        args.add('%$_search%');
      }

      final maps = await db.query(
        'foods',
        where: where,
        whereArgs: args,
        orderBy: 'name ASC',
      );

      final list = maps.map((m) => FoodEntity.fromMap(m)).toList();

      if (!mounted) return;
      setState(() {
        _foods = list;
        _isLoadingFoods = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingFoods = false);
      _showSnack('Mahsulot yuklashda xatolik: $e');
    }
  }

  void _onTapCategory(String catId) async {
    if (_selectedCategoryId == catId) return;
    setState(() {
      _selectedCategoryId = catId;
      _selectedSubcategoryTitle = null;
      _subcategories = [];
      _foods = [];
    });
    await _loadSubcategories(catId);
    await _loadFoods(categoryId: catId, subTitle: null);
  }

  void _onTapSubcategory(String? subTitle) async {
    setState(() {
      _selectedSubcategoryTitle = subTitle; // null => Barchasi
    });
    if (_selectedCategoryId != null) {
      await _loadFoods(
        categoryId: _selectedCategoryId!,
        subTitle: _selectedSubcategoryTitle,
      );
    }
  }

  void _onSearchChanged(String v) async {
    setState(() {
      _search = v.trim();
    });
    if (_selectedCategoryId != null) {
      await _loadFoods(
        categoryId: _selectedCategoryId!,
        subTitle: _selectedSubcategoryTitle,
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategoriyalar / Subkategoriyalar / Mahsulotlar'),
      ),
      body: Column(
        children: [
          // ====== QIDIRUV ======
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Qidirish (mahsulot nomi)...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),

          // ====== KATEGORIYALAR ======
          SizedBox(
            height: 56,
            child: _isLoadingCats
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final c = _categories[i];
                final selected = c.id == _selectedCategoryId;
                return ChoiceChip(
                  label: Text(c.title),
                  selected: selected,
                  onSelected: (_) => _onTapCategory(c.id),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _categories.length,
            ),
          ),

          // ====== SUBKATEGORIYALAR ======
          SizedBox(
            height: _subcategories.isEmpty && !_isLoadingSubs ? 0 : 56,
            child: _isLoadingSubs
                ? const Center(child: CircularProgressIndicator())
                : (_subcategories.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                // 0-chi chip: Barchasi
                if (i == 0) {
                  final bool selected =
                      _selectedSubcategoryTitle == null;
                  return ChoiceChip(
                    label: const Text('Barchasi'),
                    selected: selected,
                    onSelected: (_) => _onTapSubcategory(null),
                  );
                }
                final sub = _subcategories[i - 1];
                final bool selected =
                    _selectedSubcategoryTitle == sub.title;
                return ChoiceChip(
                  label: Text(sub.title),
                  selected: selected,
                  onSelected: (_) => _onTapSubcategory(sub.title),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _subcategories.length + 1,
            )),
          ),

          // ====== MAHSULOTLAR GRID ======
          Expanded(
            child: _isLoadingFoods
                ? const Center(child: CircularProgressIndicator())
                : _foods.isEmpty
                ? const Center(child: Text('Mahsulot topilmadi'))
                : LayoutBuilder(
              builder: (context, constraints) {
                // Ekran kengligiga qarab ustunlar soni
                final width = constraints.maxWidth;
                int cross = 2;
                if (width > 600) cross = 3;
                if (width > 900) cross = 4;
                if (width > 1200) cross = 5;

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                  itemCount: _foods.length,
                  itemBuilder: (_, i) {
                    final f = _foods[i];
                    return Card(
                      elevation: 2,
                      child: InkWell(
                        onTap: () {
                          // TODO: bu yerda mahsulotni tanlash / savatga qo‘shish mumkin
                          _showSnack('${f.name} tanlandi');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "${f.price} ${f.unit}",
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(
                                    color: theme
                                        .colorScheme.primary),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  const Icon(Icons.category, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      f.subcategory ?? '—',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                      theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
