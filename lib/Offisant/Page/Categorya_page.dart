import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'dart:io';
import 'dart:async';
import '../../DB/Servis/category_local_service.dart';
import '../../DB/Servis/db_helper.dart';
import '../../DB/Servis/food_local_service.dart';
import '../../Global/Api_global.dart';
import '../../Global/Klavish.dart';
import '../Controller/TokenCOntroller.dart';
import '../Controller/usersCOntroller.dart';
import '../Model/Ovqat_model.dart';
import 'Ranglar.dart';

class Category {
  final String id;
  final String title;
  final String printerId;
  final String printerName;
  final String printerIp;
  final List<String> subcategories;

  Category({
    required this.id,
    required this.title,
    required this.printerId,
    required this.printerName,
    required this.printerIp,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final printer = json['printer_id'];

    String printerId = '';
    String printerName = '';
    String printerIp = '';

    if (printer != null && printer is Map<String, dynamic>) {
      printerId = printer['_id']?.toString() ?? '';
      printerName = printer['name']?.toString() ?? '';
      printerIp = printer['ip']?.toString() ?? '';
    } else {
      // 🔰 Local DB formatida printer alohida maydonlarda bo‘lishi mumkin
      printerId =
          json['printer_id']?.toString() ??
          (json['printerId']?.toString() ?? '');
      printerName =
          json['printer_name']?.toString() ??
          (json['printerName']?.toString() ?? '');
      printerIp =
          json['printer_ip']?.toString() ??
          (json['printerIp']?.toString() ?? '');
    }

    final rawSubs = json['subcategories'];
    List<String> subs = [];

    if (rawSubs is String) {
      try {
        final decoded = jsonDecode(rawSubs);
        if (decoded is List) {
          subs =
              decoded
                  .map(
                    (e) => (e is Map ? e['title']?.toString() : e.toString()),
                  )
                  .where((s) => s != null && s.isNotEmpty)
                  .cast<String>()
                  .toList();
        }
      } catch (e) {
        subs = [];
      }
    } else if (rawSubs is List) {
      if (rawSubs.isNotEmpty && rawSubs.first is Map<String, dynamic>) {
        subs =
            rawSubs
                .map((e) => (e['title']?.toString() ?? '').trim())
                .where((s) => s.isNotEmpty)
                .toList();
      } else {
        subs =
            rawSubs
                .map((e) => (e?.toString() ?? '').trim())
                .where((s) => s.isNotEmpty)
                .toList();
      }
    }

    return Category(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      printerId: printerId,
      printerName: printerName,
      printerIp: printerIp,
      subcategories: subs,
    );
  }
}

class OrderScreenContent extends StatefulWidget {
  final User user;
  final String? tableId;
  final VoidCallback? onOrderCreated;
  final String? tableName;
  final token;
  final bool isAddingToExistingOrder;
  final String? existingOrderId;
  final String formatted_order_number;

  const OrderScreenContent({
    super.key,
    required this.tableId, // ✅ majburiy
    this.tableName,
    required this.user,
    this.onOrderCreated,
    required this.token,
    this.isAddingToExistingOrder = false,
    this.existingOrderId,
    required this.formatted_order_number,
  });

  @override
  State<OrderScreenContent> createState() => _OrderScreenContentState();
}

class _OrderScreenContentState extends State<OrderScreenContent> {
  String? _selectedCategoryId;
  String _selectedCategoryName = '';
  String? _selectedSubcategory;
  List<Category> _categories = [];
  List<Ovqat> _allProducts = [];
  List<Ovqat> _filteredProducts = [];
  bool _isLoading = true;
  bool _categoriesLoaded = false; // Kategoriyalar alohida loading
  String? _token;
  bool _isSubmitting = false;
  String _searchQuery = '';

  final Map<String, Map<String, dynamic>> _cart = {};
  final NumberFormat _currencyFormatter = NumberFormat('#,##0', 'uz_UZ');

  // Yangi cache tizimi
  static Map<String, dynamic>? _memoryCache;
  static DateTime? _lastCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    // _initializeAppFast();
    _initializeToken().then((_) async {
      // 1️⃣ Avval localni tekshiramiz
      final cats = await CategoryLocalService.getCategories();
      final foods = await FoodLocalService.getAllFoods();

      if (cats.isEmpty || foods.isEmpty) {
        // ❌ Local bo‘sh → bir marta serverdan olib kelamiz
        await _syncAndSaveToLocal();
      }

      // 2️⃣ Har doim localdan yuklaymiz (UI uchun)
      await _loadCategoriesAndFoodsFromLocal();

      // 3️⃣ Har 1 soatda yangilab turish
      _startAutoSync();

      // 4️⃣ Offline zakazlarni sync qilish
      _startOrderSync();
    });
  }

  Future<void> _saveOrderToLocal() async {
    if (_cart.isEmpty) return;

    final orderId = DateTime.now().millisecondsSinceEpoch.toString();

    final orderData = {
      'id': orderId,
      'table_id': widget.tableId,
      'user_id': widget.user.id,
      'waiter_name': widget.user.firstName,
      'total_price': _calculateTotal(),
      'status': 'pending', // 🔴 hali serverga yuborilmagan
      'created_at': DateTime.now().toIso8601String(),
      'formatted_order_number': widget.formatted_order_number,
    };

    final items =
        _cart.entries
            .map((e) {
              final product = _findProductById(e.key);
              if (product == null) return null;

              return {
                'order_id': orderId,
                'food_id': e.key,
                'name': product.name,
                'quantity': e.value['quantity'],
                'price': product.price,
                'category_name': product.categoryName ?? '',
              };
            })
            .where((e) => e != null)
            .cast<Map<String, dynamic>>()
            .toList();

    await DBHelper.insertOrder(orderData, items);
  }

  void _startOrderSync() {
    Timer.periodic(const Duration(hours: 1), (timer) async {
      print("🔄 Offline zakazlarni sync qilish boshlandi...");
      final unsyncedOrders = await DBHelper.getUnsyncedOrders();

      for (final order in unsyncedOrders) {
        final orderId = order['id'];

        // Order items olish
        final db = await DBHelper.database;
        final items = await db.query(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [orderId],
        );

        final orderData = {
          'table_id': order['table_id'],
          'user_id': order['user_id'],
          'first_name': order['waiter_name'],
          'items':
              items
                  .map(
                    (e) => {'food_id': e['food_id'], 'quantity': e['quantity']},
                  )
                  .toList(),
          'total_price': order['total_price'],
          'kassir_workflow': true,
          'table_number': widget.tableName ?? 'N/A',
        };

        try {
          final response = await http.post(
            Uri.parse("${ApiConfig.baseUrl}/orders/create"),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode(orderData),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            await DBHelper.markOrderAsSynced(orderId);
            print(
              "✅ Zakaz serverga yuborildi va synced qilindi (id: $orderId)",
            );
          } else {
            print("⚠️ Server xatosi: ${response.body}");
          }
        } catch (e) {
          print("❌ Sync error: $e");
        }
      }
      print("🔄 Offline sync tugadi");
    });
  }

  Future<void> _loadCategoriesAndFoodsFromLocal() async {
    try {
      print("📦 Local DB dan kategoriyalar olinmoqda...");
      final cats = await CategoryLocalService.getCategories();

      print("📦 Local DB dan mahsulotlar olinmoqda...");
      final foods = await FoodLocalService.getAllFoods();

      setState(() {
        _categories = cats.map((e) => Category.fromJson(e)).toList();
        _allProducts = foods.map((e) => Ovqat.fromJson(e)).toList();
        _filteredProducts = _allProducts;
        _isLoading = false;
        _categoriesLoaded = true;
      });

      print(
        "✅ Localdan yuklash tugadi. Kategoriya: ${_categories.length}, Mahsulot: ${_allProducts.length}",
      );
    } catch (e) {
      print("❌ Local yuklashda xato: $e");
    }
  }

  /// 🔹 Har 1 soatda sync qilish
  void _startAutoSync() {
    Timer.periodic(Duration(hours: 1), (timer) async {
      print("🔄 Avto-sync boshlandi...");
      await _syncAndSaveToLocal();
      print("🔄 Avto-sync tugadi");
    });
  }

  /// 🔹 Serverdan olib local DB ga yozish
  Future<void> _syncAndSaveToLocal() async {
    try {
      if (_token == null) {
        print("❌ Token topilmadi, sync bekor qilindi");
        return;
      }

      print("🌍 Serverdan kategoriyalar yuklanmoqda...");
      final catRes = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/categories/list"),
        headers: {"Authorization": "Bearer $_token"},
      );

      if (catRes.statusCode == 200) {
        final data = jsonDecode(catRes.body);
        final List cats = data['categories'] ?? [];
        await DBHelper.clearCategories();
        await DBHelper.upsertCategories(cats.cast<Map<String, dynamic>>());
        print("✅ ${cats.length} ta kategoriya localga saqlandi");
      }

      print("🌍 Serverdan mahsulotlar yuklanmoqda...");
      final foodRes = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/foods/list"),
        headers: {"Authorization": "Bearer $_token"},
      );

      if (foodRes.statusCode == 200) {
        final data = jsonDecode(foodRes.body);
        final List foods = data['foods'] ?? [];
        await DBHelper.clearFoods();
        await DBHelper.upsertFoods(foods.cast<Map<String, dynamic>>());
        print("✅ ${foods.length} ta mahsulot localga saqlandi");
      }
    } catch (e) {
      print("❌ Sync xatolik: $e");
    }
  }

  Future<void> syncCategoriesAndFoods(String token) async {
    try {
      final catRes = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/categories/list"),
        headers: {"Authorization": "Bearer $token"},
      );

      debugPrint("🌍 Kategoriya status: ${catRes.statusCode}");
      if (catRes.statusCode == 200) {
        final data = jsonDecode(catRes.body);
        final List cats = data['categories'] ?? [];
        await CategoryLocalService.clearCategories();
        await CategoryLocalService.saveCategories(
          cats.cast<Map<String, dynamic>>(),
        );
      }

      final foodRes = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/foods/list"),
        headers: {"Authorization": "Bearer $token"},
      );

      debugPrint("🌍 Food status: ${foodRes.statusCode}");
      if (foodRes.statusCode == 200) {
        final data = jsonDecode(foodRes.body);
        final List foods = data['foods'] ?? [];
        await FoodLocalService.clearFoods();
        await FoodLocalService.saveFoods(foods.cast<Map<String, dynamic>>());
      }

      debugPrint("✅ Sync tugadi");
    } catch (e) {
      debugPrint("❌ Sync error: $e");
    }
  }

  void _updateCart(String productId, int change, {double? kg}) {
    setState(() {
      final product = _findProductById(productId);
      if (product == null) {
        debugPrint('Xatolik: Mahsulot topilmadi, ID: $productId');
        return;
      }

      final currentEntry = _cart[productId] ?? {'quantity': 0.0, 'kg': 1.0};

      if (product.unit == 'kg') {
        final newKg = kg ?? currentEntry['kg'];
        if (change > 0 && newKg > 0) {
          _cart[productId] = {'quantity': newKg, 'kg': newKg};
          debugPrint('Kg mahsulot qo‘shildi: ${product.name}, kg: $newKg');
        } else {
          _cart.remove(productId);
          debugPrint('Mahsulot o‘chirildi: ${product.name}');
        }
      } else {
        // Oddiy mahsulotlar uchun
        final newQty = currentEntry['quantity'] + change;
        if (newQty <= 0) {
          _cart.remove(productId);
          debugPrint('Mahsulot o‘chirildi: ${product.name}');
        } else {
          _cart[productId] = {
            'quantity': newQty,
            'kg': currentEntry['kg'],
            'note': currentEntry['note'] ?? '', // ✏️ izohni saqlash
          };
          debugPrint(
            'Oddiy mahsulot qo‘shildi: ${product.name}, soni: $newQty',
          );
        }
      }
    });
  }

  Future<void> _initializeAppFast() async {
    // Token va kategoriyalarni parallel yuklash
    await Future.wait([_initializeToken(), _loadCategoriesFast()]);

    // Mahsulotlarni background da yuklash
    _loadProductsInBackground();
  }

  Future<void> _initializeToken() async {
    try {
      _token = widget.token ?? await AuthService.getToken();
      if (_token == null) {
        await AuthService.loginAndPrintToken();
        _token = await AuthService.getToken();
      }
    } catch (e) {
      debugPrint("Token error: $e");
    }
  }

  bool _isCacheValid() {
    return _memoryCache != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheExpiry;
  }

  // Kategoriyalarni tezkor yuklash
  Future<void> _loadCategoriesFast() async {
    try {
      // Cache dan kategoriyalarni olish
      if (_isCacheValid() && _memoryCache!['categories'] != null) {
        _categories = List<Category>.from(_memoryCache!['categories']);
        setState(() {
          _categoriesLoaded = true;
        });
        return; // ✅ agar memory cache ishlasa, qaytib ketadi
      }

      // API dan kategoriyalarni olish
      final url = Uri.parse("${ApiConfig.baseUrl}/categories/list");

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_token ?? widget.token}',
            },
          )
          .timeout(const Duration(seconds: 2)); // Qisqa timeout
      print(response.body);

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);

        List<Category> categories = [];
        List<Map<String, dynamic>> categoryMaps = [];

        if (decoded is Map<String, dynamic>) {
          final data = decoded['categories'] ?? decoded['data'] ?? decoded;
          if (data is List) {
            categories = data.map((e) => Category.fromJson(e)).toList();
            categoryMaps = List<Map<String, dynamic>>.from(data);
            // ✅ SQLlite ga yozib qo‘yish
            if (categoryMaps.isNotEmpty) {
              await CategoryLocalService.saveCategories(categoryMaps);
            }
          }
        } else if (decoded is List) {
          categories = decoded.map((e) => Category.fromJson(e)).toList();
          categoryMaps = List<Map<String, dynamic>>.from(decoded);
        }

        // Cache ga saqlash
        _memoryCache ??= {};
        _memoryCache!['categories'] = categories;
        _lastCacheTime = DateTime.now();

        if (mounted) {
          setState(() {
            _categories = categories;
            _categoriesLoaded = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Kategoriyalar yuklashda xatolik: $e");
      if (mounted) {
        setState(() => _categoriesLoaded = true);
      }
    }
  }

  // Mahsulotlarni background da yuklash
  void _loadProductsInBackground() async {
    try {
      // Cache dan mahsulotlarni olish
      if (_isCacheValid() && _memoryCache!['products'] != null) {
        _allProducts = List<Ovqat>.from(_memoryCache!['products']);
        setState(() {
          _isLoading = false;
        });
        _filterProductsByCategory();
        return;
      }

      // API dan mahsulotlarni olish
      final url = Uri.parse("${ApiConfig.baseUrl}/foods/list");

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_token ?? widget.token}',
            },
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);

        List<Ovqat> products = [];
        if (decoded is Map<String, dynamic>) {
          final data =
              decoded['foods'] ??
              decoded['data'] ??
              decoded['products'] ??
              decoded;
          if (data is List) {
            products = data.map((e) => Ovqat.fromJson(e)).toList();
          }
        } else if (decoded is List) {
          products = decoded.map((e) => Ovqat.fromJson(e)).toList();
        }

        // Cache ga saqlash
        _memoryCache ??= {};
        _memoryCache!['products'] = products;
        _lastCacheTime = DateTime.now();

        if (mounted) {
          setState(() {
            _allProducts = products;
            _isLoading = false;
          });
          _filterProductsByCategory();
        }
      }
    } catch (e) {
      debugPrint("Mahsulotlar yuklashda xatolik: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterProductsByCategory() {
    List<Ovqat> filtered = _allProducts;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered =
          _allProducts.where((product) {
            final productName = product.name.toLowerCase();
            final productSub = product.subcategory?.toLowerCase() ?? '';

            // Mahsulot nomi yoki subkategoriya nomi bilan mos kelishi
            return productName.contains(query) || productSub.contains(query);
          }).toList();

      if (filtered.isNotEmpty && _selectedCategoryId == null) {
        final firstProduct = filtered.first;
        final matchedCategory = _categories.firstWhere(
          (cat) => cat.id == firstProduct.categoryId,
          orElse:
              () => Category(
                id: '',
                title: '',
                subcategories: [],
                printerName: '',
                printerIp: '',
                printerId: '',
              ),
        );

        if (matchedCategory.id.isNotEmpty) {
          _selectedCategoryId = matchedCategory.id;
          _selectedCategoryName = matchedCategory.title;

          // Agar mahsulotda subkategoriya bo'lsa, uni ham tanlash
          if (firstProduct.subcategory != null &&
              firstProduct.subcategory!.isNotEmpty) {
            _selectedSubcategory = firstProduct.subcategory;
          }
        }
      }
    }
    // Qidiruv bo'sh bo'lsa, kategoriya tanlangan bo'lsa
    else if (_selectedCategoryId != null) {
      // Faqat kategoriya tanlangan - kategoriya bo'yicha filterlash
      filtered =
          _allProducts.where((product) {
            if (product.categoryId != _selectedCategoryId) return false;

            // Agar subkategoriya tanlangan bo'lsa
            if (_selectedSubcategory != null &&
                _selectedSubcategory!.isNotEmpty) {
              return product.subcategory?.toLowerCase() ==
                  _selectedSubcategory!.toLowerCase();
            }

            return true;
          }).toList();
    }
    // Hech narsa tanlangmagan va qidiruv bo'sh - barcha mahsulotlar
    else {
      filtered = _allProducts;
    }

    // Natijani yangilash
    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _selectCategory(
    String categoryId,
    String categoryTitle, {
    String? subcategory,
  }) {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedCategoryName = categoryTitle;
      _selectedSubcategory = subcategory;
    });
    _filterProductsByCategory();
  }

  double _calculateTotal() {
    if (_cart.isEmpty) {
      return 0.0;
    }
    if (_allProducts.isEmpty) {
      return 0.0;
    }

    double total = 0;
    for (final entry in _cart.entries) {
      final product = _findProductById(entry.key);
      if (product != null) {
        if (product.unit == 'kg') {
          final itemPrice = product.price * entry.value['quantity'];
          total += itemPrice;
        } else {
          final itemPrice = product.price * entry.value['quantity'];
          total += itemPrice;
        }
      } else {
        debugPrint('Xatolik: Mahsulot topilmadi, food_id: ${entry.key}');
      }
    }
    return total;
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'ichimliklar':
        return Icons.local_bar;
      case 'shirinliklar':
        return Icons.bakery_dining;
      case 'taomlar':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }

  Future<void> _createOrderUltraFast() async {
    if (_isSubmitting || _cart.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      // 1️⃣ Localga saqlash
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      final order = {
        'id': orderId,
        'table_id': widget.tableId,
        'user_id': widget.user.id,
        'waiter_name': widget.user.firstName,
        'total_price': _calculateTotal(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'formatted_order_number': widget.formatted_order_number,
      };

      final items =
          _cart.entries.map((e) {
            final product = _findProductById(e.key);
            return {
              'order_id': orderId,
              'food_id': product?.id ?? '',
              'name': product?.name ?? '',
              'quantity': e.value['quantity'],
              'price': product?.price,
              'category_name': product?.categoryName ?? '',
            };
          }).toList();

      await DBHelper.insertOrder(order, items);

      // ✅ Printerga yuborish
      _printOrderOffline({
        'orderNumber': widget.formatted_order_number,
        'waiter_name': widget.user.firstName,
        'table_name': widget.tableName,
        'items': items,
      });

      // ✅ UI yangilanishi uchun localdan qayta yuklash
      final updatedOrders = await DBHelper.getOrdersByTable(widget.tableId!);
      print(
        "📦 Local DB dan ${updatedOrders.length} ta zakaz olindi va UI yangilandi",
      );

      widget.onOrderCreated?.call(); // PosScreen ham qayta chaqiradi

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _printOrderOffline(Map<String, dynamic> data) async {
    try {
      final Map<String, List<Map<String, dynamic>>> printerGroups = {};

      for (final entry in _cart.entries) {
        final product = _findProductById(entry.key);
        if (product != null) {
          final category = _categories.firstWhere(
            (cat) => cat.id == product.categoryId,
            orElse:
                () => Category(
                  id: '',
                  title: '',
                  subcategories: [],
                  printerName: '',
                  printerIp: '',
                  printerId: '',
                ),
          );
          if (category.printerIp.isNotEmpty && category.printerIp != 'null') {
            printerGroups.putIfAbsent(category.printerIp, () => []);
            printerGroups[category.printerIp]!.add({
              'name': product.name,
              'qty': entry.value['quantity'],
              'kg': product.unit == 'kg' ? entry.value['kg'] : null,
            });
          }
        }
      }

      printerGroups.forEach((ip, items) {
        final printData = {
          'orderNumber': data['orderNumber'],
          'waiter_name': data['waiter_name'],
          'table_name': data['table_name'],
          'items': items,
        };
        final bytes = _createPrintData(printData);
        _printToSocket(ip, bytes).catchError((e) {
          debugPrint("⚠️ Offline print xato ($ip): $e");
        });
      });
    } catch (e) {
      debugPrint("❌ Offline print error: $e");
    }
  }

  // 🔹 Zakazni serverga yuborish
  Future<Map<String, dynamic>> _sendOrderInBackground() async {
    try {
      if (_cart.isEmpty) {
        return {'success': false, 'message': 'Savat bo‘sh'};
      }
      if (_token == null) {
        await _initializeToken(); // Tokenni qayta olish
        if (_token == null) {
          return {'success': false, 'message': 'Token topilmadi'};
        }
      }
      if (widget.user.id == null || widget.user.id.isEmpty) {
        return {'success': false, 'message': 'Afitsant ID topilmadi'};
      }

      final orderItems =
          _cart.entries
              .map((e) {
                final product = _findProductById(e.key);
                if (product == null) return null;

                final quantity =
                    product.unit == 'kg'
                        ? e.value['quantity']
                        : (e.value['quantity'] as num).toInt();

                if (quantity <= 0) return null;
                return {'food_id': e.key, 'quantity': quantity};
              })
              .where((item) => item != null)
              .toList();

      final orderData = {
        'table_id': widget.tableId,
        'user_id': widget.user.id, // Afitsant ID
        'first_name': widget.user.firstName ?? 'Noma\'lum',
        'items': orderItems,
        'total_price': _calculateTotal(),
        'kassir_workflow': true,
        'table_number': widget.tableName ?? 'N/A',
      };

      // So‘rovni yuborishdan oldin orderData ni chop etish
      debugPrint('Order Data: ${jsonEncode(orderData)}');

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/orders/create"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(orderData),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Printerni backgroundda yuborish
        Future.microtask(() => _printOrderAsync(data));
        return {'success': true, 'message': 'Zakaz muvaffaqiyatli yuborildi!'};
      } else {
        debugPrint('Server xatosi: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'message': data['message'] ?? 'Server xatosi',
        };
      }
    } catch (e) {
      debugPrint('Xatolik: $e');
      // Offline rejimda localga saqlash
      await _saveOrderToLocal();
      return {
        'success': false,
        'message': 'Internet aloqasi yo‘q, zakaz localga saqlandi: $e',
      };
    }
  }

  void showCenterSnackBar(
    BuildContext context,
    String message, {
    Color color = Colors.green,
  }) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              minWidth: 100,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      animationDuration: const Duration(milliseconds: 50),
      reverseAnimationDuration: const Duration(milliseconds: 50),
    );
  }

  Future<Map<String, dynamic>> _sendAddItemsInBackground() async {
    try {
      final orderItems =
          _cart.entries
              .map((e) {
                final product = _findProductById(e.key);
                if (product == null) return null;

                final quantity =
                    product.unit == 'kg'
                        ? e.value['quantity']
                        : (e.value['quantity'] as num).toInt();

                if (quantity <= 0) return null;
                return {'food_id': e.key, 'quantity': quantity};
              })
              .where((item) => item != null)
              .toList();

      final response = await http.post(
        Uri.parse(
          "${ApiConfig.baseUrl}/orders/${widget.existingOrderId}/add-items",
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'items': orderItems}),
      );
      print("${ApiConfig.baseUrl}/orders/${widget.existingOrderId}/add-items");
      print("${widget.token}");
      print(orderItems.toString());
      final data = jsonDecode(response.body);
      print(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        Future.microtask(() => _printAddedItemsOptimized(data));
        return {'success': true, 'message': 'Mahsulotlar qo‘shildi!'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Server xatosi',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Xatolik: $e'};
    }
  }

  Future<void> _printOrderAsync(Map<String, dynamic> responseData) async {
    try {
      final Map<String, List<Map<String, dynamic>>> printerGroups = {};
      for (final entry in _cart.entries) {
        final product = _findProductById(entry.key);
        if (product != null) {
          final category = _categories.firstWhere(
            (cat) => cat.id == product.categoryId,
            orElse:
                () => Category(
                  id: '',
                  title: '',
                  subcategories: [],
                  printerName: '',
                  printerIp: '',
                  printerId: '',
                ),
          );
          if (category.printerIp.isNotEmpty && category.printerIp != 'null') {
            printerGroups.putIfAbsent(category.printerIp, () => []);
            printerGroups[category.printerIp]!.add({
              'name': product.name,
              'qty': entry.value['quantity'],
              'kg': product.unit == 'kg' ? entry.value['kg'] : null,
            });
          }
        }
      }

      // Fire-and-forget → kutilmaydi
      printerGroups.forEach((ip, items) {
        final printData = {
          'orderNumber':
              responseData['order']?['orderNumber']?.toString() ?? '',
          'waiter_name': widget.user.firstName ?? 'Noma\'lum',
          'table_name': widget.tableName ?? 'N/A',
          'items': items,
        };
        final bytes = _createPrintData(printData);
        _printToSocket(ip, bytes).catchError((e) {
          debugPrint("⚠️ Printer $ip ga yuborishda xato: $e");
        });
      });
    } catch (e) {
      debugPrint("❌ Print error: $e");
    }
  }

  Future<void> _printAddedItemsOptimized(
    Map<String, dynamic> responseData,
  ) async {
    try {
      final Map<String, List<Map<String, dynamic>>> printerGroups = {};
      for (final entry in _cart.entries) {
        final product = _findProductById(entry.key);
        if (product != null) {
          final category = _categories.firstWhere(
            (cat) => cat.id == product.categoryId,
            orElse:
                () => Category(
                  id: '',
                  title: '',
                  subcategories: [],
                  printerName: '',
                  printerIp: '',
                  printerId: '',
                ),
          );
          if (category.printerIp.isNotEmpty && category.printerIp != 'null') {
            printerGroups.putIfAbsent(category.printerIp, () => []);
            printerGroups[category.printerIp]!.add({
              'name': product.name,
              'qty': entry.value['quantity'],
              'kg': product.unit == 'kg' ? entry.value['kg'] : null,
            });
          }
        }
      }

      printerGroups.forEach((ip, items) {
        final printData = {
          'orderNumber': widget.existingOrderId?.substring(0, 8) ?? '',
          'waiter_name': widget.user.firstName ?? 'Noma\'lum',
          'table_name': widget.tableName ?? 'N/A',
          'items': items,
          'isAddition': true,
        };
        final bytes = _createPrintDataForAddition(printData);
        _printToSocket(ip, bytes).catchError((e) {
          debugPrint("⚠️ Qo‘shimcha $ip ga yuborishda xato: $e");
        });
      });
    } catch (e) {
      debugPrint("❌ Print error: $e");
    }
  }

  // Muvaffaqiyat xabarini ko‘rsatish uchun yangi metod
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Ovqat? _findProductById(String id) {
    for (final product in _allProducts) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<void> _printToSocket(String ip, List<int> data) async {
    try {
      print('Printerga ulanmoqda: $ip:9100');

      final socket = await Socket.connect(
        ip,
        9100,
        timeout: Duration(milliseconds: 500),
      );
      socket.add(data);
      await socket.flush();

      socket.destroy();

      print('$ip ga muvaffaqiyatli yuborildi');
    } catch (e) {
      print('$ip ga yuborishda xatolik: $e');
    }
  }

  List<int> _createPrintData(Map<String, dynamic> data) {
    final bytes = <int>[];

    bytes.addAll([0x1B, 0x40]); // Reset
    bytes.addAll([0x1B, 0x74, 17]); // CP866 kodirovka

    bytes.addAll([0x1B, 0x61, 1]); // Markaz
    final waiter = data['waiter_name'];
    final table = data['table_name'];

    bytes.addAll(_encodeText('ZAKAZ : ${widget.formatted_order_number}\r\n'));
    bytes.addAll(_encodeText('Ofitsiant: $waiter\r\n'));
    bytes.addAll(_encodeText('Stol: $table\r\n'));
    bytes.addAll(
      _encodeText('${DateTime.now().toString().substring(11, 16)}\r\n'),
    );
    bytes.addAll(_encodeText('=' * 32 + '\r\n'));

    final header = '${'Nomi'.padRight(20)}Soni';
    bytes.addAll([0x1B, 0x61, 1]); // Markaz
    bytes.addAll(_encodeText('$header\r\n'));
    bytes.addAll(_encodeText('-' * 32 + '\r\n'));

    for (final item in data['items']) {
      final name = item['name'].toString();
      final qty = item['qty'].toString();
      final line = name.padRight(20) + qty;

      bytes.addAll([0x1B, 0x61, 0]); // Chapga
      bytes.addAll(_encodeText('$line\r\n'));

      // ✏️ Agar izoh mavjud bo‘lsa, uni chiqaramiz
      final note = _cart[item['id']]?['note'] ?? '';
      if (note.isNotEmpty) {
        bytes.addAll([0x1B, 0x61, 0]); // Chapga
        bytes.addAll(_encodeText('  -> $note\r\n'));
      }
    }

    bytes.addAll(_encodeText('=' * 32 + '\r\n\r\n\r\n\r\n\r\n'));
    bytes.addAll([0x1D, 0x56, 0]); // Kesish

    return bytes;
  }

  List<int> _encodeText(String text) {
    return latin1.encode(text);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth >= 600 && screenWidth <= 1200;

    final selectedCategory =
        _categories.cast<Category?>().firstWhere(
          (cat) => cat?.id == _selectedCategoryId,
          orElse: () => null,
        ) ??
        Category(
          id: '',
          title: 'Kategoriyani tanlang',
          subcategories: [],
          printerName: '',
          printerIp: '',
          printerId: '',
        );

    return Scaffold(
      backgroundColor: Color(0xFFDFF3E3),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(isDesktop),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: isDesktop ? 280 : (isTablet ? 250 : 200),
                    child: _buildCategoriesSection(isDesktop),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildProductsSection(
                      isDesktop,
                      isTablet,
                      selectedCategory,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildBottomActions(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 10 : 8,
        horizontal: isDesktop ? 16 : 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  widget.isAddingToExistingOrder
                      ? Icons.add_shopping_cart
                      : Icons.shopping_cart,
                  color: AppColors.white,
                  size: isDesktop ? 24 : 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isAddingToExistingOrder
                            ? "Mahsulot qo'shish"
                            : "Yangi hisob",
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.isAddingToExistingOrder
                            ? "Zakaz: ${widget.existingOrderId?.substring(0, 8) ?? ''}"
                            : "Hodim: ${widget.user.firstName}",
                        style: TextStyle(
                          fontSize: isDesktop ? 12 : 10,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: isDesktop ? 200 : 150),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Qidirish...',
                    hintStyle: TextStyle(
                      color: Colors.white70,
                      fontSize: isDesktop ? 12 : 10,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.white,
                      size: isDesktop ? 18 : 16,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isDesktop ? 8 : 6,
                      horizontal: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: isDesktop ? 12 : 10,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _filterProductsByCategory();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: AppColors.white,
                  size: isDesktop ? 24 : 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: Color(0xFFDFF3E3),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.category, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Kategoriyalar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return Card(
                          color: Color(0xFF144D37),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color:
                                  _selectedCategoryId == category.id
                                      ? AppColors.primary
                                      : AppColors.lightGrey,
                              width: _selectedCategoryId == category.id ? 2 : 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              _getCategoryIcon(category.title),
                              size: 18,
                              color: Colors.white,
                            ),
                            title: Text(
                              category.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap:
                                () => _selectCategory(
                                  category.id,
                                  category.title,
                                ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(
    bool isDesktop,
    bool isTablet,
    Category selectedCategory,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white60,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant_menu,
                  color: AppColors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedCategoryName.isNotEmpty
                      ? '$_selectedCategoryName${_selectedSubcategory != null ? " ($_selectedSubcategory)" : ""}'
                      : 'Mahsulotlar',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          if (selectedCategory.subcategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildSubcategoryChip(null, 'Barchasi'),
                        const SizedBox(width: 8),
                        ...selectedCategory.subcategories.map(
                          (sub) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildSubcategoryChip(sub, sub),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                      : _filteredProducts.isEmpty
                      ? Center(
                        child: Text(
                          _selectedCategoryId == null && _searchQuery.isEmpty
                              ? 'Kategoriyani tanlang'
                              : 'Mahsulot topilmadi',
                          style: const TextStyle(color: AppColors.grey),
                        ),
                      )
                      : GridView.builder(
                        physics: AlwaysScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 5 : (isTablet ? 4 : 3),
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return _buildProductCard(product, isDesktop);
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryChip(String? subcategory, String label) {
    final isActive = _selectedSubcategory == subcategory;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        _selectCategory(
          _selectedCategoryId!,
          _selectedCategoryName,
          subcategory: selected ? subcategory : null,
        );
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isActive ? AppColors.primary : AppColors.lightGrey,
        ),
      ),
    );
  }

  Widget _buildProductCard(Ovqat product, bool isDesktop) {
    final cartEntry = _cart[product.id];
    final int quantityInCart = cartEntry?['quantity']?.toInt() ?? 0;
    final double kgInCart =
        product.unit == 'kg'
            ? (cartEntry?['quantity']?.toDouble() ?? 1.0)
            : 1.0;
    final num totalPrice =
        product.unit == 'kg'
            ? product.price * kgInCart
            : product.price * quantityInCart;

    return LayoutBuilder(
      builder: (context, constraints) {
        double maxCardWidth = isDesktop ? 220 : constraints.maxWidth * 0.5;

        return GestureDetector(
          onTap: () {
            if (product.unit == 'kg') {
              _showKgInputModal(context, product);
            } else {
              _updateCart(product.id, 1);
            }
          },
          child: Container(
            constraints: BoxConstraints(maxWidth: maxCardWidth, maxHeight: 180),
            decoration: BoxDecoration(
              color: const Color(0xFF144D37),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    quantityInCart > 0 || kgInCart > 0
                        ? Colors.white
                        : Colors.grey[400]!,
                width: quantityInCart > 0 || kgInCart > 0 ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  offset: const Offset(0, 4),
                  blurRadius: 6,
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    product.unit == 'kg'
                        ? '${_currencyFormatter.format(product.price)} so\'m/kg'
                        : '${_currencyFormatter.format(product.price)} ${product.unit} so\'m',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: AutoSizeText(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 3,
                      minFontSize: 8,
                      maxFontSize: 15,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (product.unit == 'kg' && kgInCart > 0) ...[
                      GestureDetector(
                        onTap: () => _updateCart(product.id, -1),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.remove,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (product.unit == 'kg') {
                            _showKgInputModal(context, product);
                          } else {
                            _updateCart(product.id, 1);
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 18,
                            color: const Color(0xFF144D37),
                          ),
                        ),
                      ),
                    ] else if (product.unit != 'kg' && quantityInCart > 0) ...[
                      GestureDetector(
                        onTap: () => _updateCart(product.id, -1),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.remove,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$quantityInCart',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          if (product.unit == 'kg') {
                            _showKgInputModal(context, product);
                          } else {
                            _updateCart(product.id, 1);
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 18,
                            color: const Color(0xFF144D37),
                          ),
                        ),
                      ),
                    ] else ...[
                      GestureDetector(
                        onTap: () => _showNoteInputModal(context, product),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 15),
                      GestureDetector(
                        onTap: () {
                          if (product.unit == 'kg') {
                            _showKgInputModal(context, product);
                          } else {
                            _updateCart(product.id, 1);
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 18,
                            color: const Color(0xFF144D37),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if ((product.unit == 'kg' && kgInCart > 0) ||
                    (product.unit != 'kg' && quantityInCart > 0))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Jami: ${_currencyFormatter.format(totalPrice)} so\'m',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoteInputModal(BuildContext context, Ovqat product) {
    final currentNote = _cart[product.id]?['note'] ?? '';
    final TextEditingController noteController = TextEditingController(
      text: currentNote,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Izoh qo‘shish - ${product.name}"),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Izoh qo‘shish ...",
              border: OutlineInputBorder(),
            ),
            onTap: () {
              KeyboardManager.showKeyboard(context, noteController);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Bekor qilish"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (_cart.containsKey(product.id)) {
                    _cart[product.id]!['note'] = noteController.text;
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text("Saqlash"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomActions(bool isDesktop) {
    final double total = _calculateTotal();
    final bool isCartEmpty = _cart.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFDFF3E3),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 250 : 200),
            child: OutlinedButton.icon(
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text(
                'Bekor qilish',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                side: const BorderSide(color: AppColors.grey),
                foregroundColor: AppColors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 500 : 300),
            child: ElevatedButton.icon(
              onPressed:
                  (isCartEmpty || _isSubmitting)
                      ? null
                      : (widget.isAddingToExistingOrder
                          ? _addItemsToExistingOrder
                          : _createOrderUltraFast),
              icon:
                  _isSubmitting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : Icon(
                        widget.isAddingToExistingOrder
                            ? Icons.add_shopping_cart
                            : Icons.restaurant_menu,
                        size: 18,
                      ),
              label: Text(
                _isSubmitting
                    ? (widget.isAddingToExistingOrder
                        ? 'Qo\'shilmoqda...'
                        : 'Yuborilmoqda...')
                    : (widget.isAddingToExistingOrder
                        ? 'Mahsulot qo\'shish (${_currencyFormatter.format(total)} so\'m)'
                        : 'Zakaz berish (${_currencyFormatter.format(total)} so\'m)'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    (isCartEmpty || _isSubmitting)
                        ? AppColors.grey
                        : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showKgInputModal(BuildContext context, Ovqat product) {
    double kg = _cart[product.id]?['quantity']?.toDouble() ?? 1.0;
    double price = product.price * kg;
    TextEditingController kgController = TextEditingController(
      text: kg.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), ''),
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(6), // Yanada kichik padding
              titlePadding: const EdgeInsets.only(top: 6, left: 6, right: 6),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6), // Kichikroq
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.scale,
                          color: Colors.white,
                          size: 14,
                        ), // Kichik ikonka
                        const SizedBox(width: 4),
                        const Text(
                          'AFITSANT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12, // Kichik font
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                    ), // Kichik font
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Narxi: ${_currencyFormatter.format(product.price)} so\'m/kg',
                    style: const TextStyle(
                      fontSize: 14, // Kichik font
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: 220, // Yanada kichik kenglik
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ), // Kichik
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        kgController.text.isEmpty
                            ? '0 kg'
                            : '${kgController.text} kg',
                        style: const TextStyle(
                          fontSize: 14, // Kichik font
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      childAspectRatio: 1.4, // Kichikroq tugmalar
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                      children: [
                        for (int i = 1; i <= 9; i++)
                          _buildNumberButton(i.toString(), () {
                            setState(() {
                              kgController.text += i.toString();
                              kg = double.tryParse(kgController.text) ?? 0.0;
                              price = product.price * kg;
                            });
                          }),
                        _buildNumberButton('0', () {
                          setState(() {
                            kgController.text += '0';
                            kg = double.tryParse(kgController.text) ?? 0.0;
                            price = product.price * kg;
                          });
                        }),
                        _buildNumberButton('.', () {
                          setState(() {
                            if (!kgController.text.contains('.')) {
                              kgController.text += '.';
                            }
                          });
                        }),
                        _buildNumberButton('←', () {
                          // Backspace
                          setState(() {
                            if (kgController.text.isNotEmpty) {
                              kgController.text = kgController.text.substring(
                                0,
                                kgController.text.length - 1,
                              );
                              kg = double.tryParse(kgController.text) ?? 0.0;
                              price = product.price * kg;
                            }
                          });
                        }, isSpecial: true),
                        _buildNumberButton('C', () {
                          // Clear
                          setState(() {
                            kgController.text = '';
                            kg = 0.0;
                            price = 0.0;
                          });
                        }, isSpecial: true),
                      ],
                    ),

                    const SizedBox(height: 6),
                    // Tan narxi va yangi narxi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Yangi narxi: ${_currencyFormatter.format(price)} so\'m',
                          style: const TextStyle(
                            fontSize: 11, // Kichik font
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                            ), // Kichik
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            side: BorderSide(color: Colors.grey[400]!),
                          ),
                          child: const Text(
                            'Qaytish',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ), // Kichik font
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              kg > 0
                                  ? () {
                                    _updateCart(product.id, 1, kg: kg);
                                    Navigator.of(context).pop();
                                  }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                            ), // Kichik
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: Colors.grey[400]!),
                            ),
                          ),
                          child: const Text(
                            'Saqlash',
                            style: TextStyle(
                              fontSize: 10, // Kichik font
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Tugma funksiyasi (eski _buildNumberButton ni almashtiring)
  Widget _buildNumberButton(
    String text,
    VoidCallback onTap, {
    bool isSelected = false,
    bool isSpecial = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSpecial ? 12 : 14, // Kichikroq font
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addItemsToExistingOrder() async {
    if (_isSubmitting || _cart.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      showCenterSnackBar(
        context,
        'Mahsulotlar qo\'shilmoqda...',
        color: Colors.blue,
      );

      _sendAddItemsInBackground();

      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          showCenterSnackBar(
            context,
            'Mahsulotlar qo\'shildi!',
            color: Colors.green,
          );
          widget.onOrderCreated?.call();
          Navigator.of(context).pop();
        }
      });
    } finally {
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) setState(() => _isSubmitting = false);
      });
    }
  }

  List<int> _createPrintDataForAddition(Map<String, dynamic> data) {
    final bytes = <int>[];
    const printerWidth = 32;

    bytes.addAll([0x1B, 0x40]); // Reset
    bytes.addAll([0x1B, 0x74, 17]); // CP866

    bytes.addAll([0x1B, 0x61, 1]); // Center
    bytes.addAll(_encodeText('QO\'SHIMCHA MAHSULOT\r\n'));
    bytes.addAll(_encodeText('Zakaz : ${widget.formatted_order_number}\r\n'));
    bytes.addAll(_encodeText('Ofitsiant: ${data['waiter_name']}\r\n'));

    final tableLine =
        '${data['table_name']}'.padRight(15) +
        DateTime.now().toString().substring(11, 16);
    bytes.addAll(_encodeText('$tableLine\r\n'));

    bytes.addAll(_encodeText('=' * printerWidth + '\r\n'));

    for (final item in data['items']) {
      final name = item['name'].toString();
      final qty = item['qty'].toString();
      final line = name.padRight(20) + qty;

      bytes.addAll([0x1B, 0x61, 0]); // Left
      bytes.addAll(_encodeText('$line\r\n'));

      // ✏️ Qo‘shimcha izohni chiqarish
      final note = _cart[item['id']]?['note'] ?? '';
      if (note.isNotEmpty) {
        bytes.addAll(_encodeText('  -> $note\r\n'));
      }
    }

    bytes.addAll(_encodeText('=' * printerWidth + '\r\n'));
    bytes.addAll(_encodeText('\r\n\r\n\r\n\r\n\r\n'));
    bytes.addAll([0x1D, 0x56, 0]); // Cut

    return bytes;
  }
}
