import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sora/Offisant/Page/Home.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'dart:io';
import 'dart:async';
import '../../Admin/Page/Stollarni_joylashuv.dart';
import '../../Global/Api_global.dart';
import '../Controller/TokenCOntroller.dart';
import '../Controller/usersCOntroller.dart';
import '../Model/Ovqat_model.dart';
import 'Yopilgan_zakaz_page.dart';
import 'package:flutter/material.dart';

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

    // Debug uchun
    print('Debug - Category: ${json['title']}, printer_id: $printer');

    String printerId = '';
    String printerName = '';
    String printerIp = '';

    if (printer != null && printer is Map<String, dynamic>) {
      printerId = printer['_id']?.toString() ?? '';
      printerName = printer['name']?.toString() ?? '';
      printerIp = printer['ip']?.toString() ?? '';
    }

    return Category(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      printerId: printerId,
      printerName: printerName,
      printerIp: printerIp,
      subcategories:
          (json['subcategories'] is List)
              ? (json['subcategories'] as List)
                  .map((e) => e['title']?.toString() ?? '')
                  .toList()
              : [],
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
    this.tableId,
    required this.user,
    this.onOrderCreated,
    this.tableName,
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
    _initializeAppFast();
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
        return;
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
          .timeout(Duration(seconds: 2)); // Qisqa timeout
      print(response.body);
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);

        List<Category> categories = [];
        if (decoded is Map<String, dynamic>) {
          final data = decoded['categories'] ?? decoded['data'] ?? decoded;
          if (data is List) {
            categories = data.map((e) => Category.fromJson(e)).toList();
          }
        } else if (decoded is List) {
          categories = decoded.map((e) => Category.fromJson(e)).toList();
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
      final q = _searchQuery.toLowerCase();
      filtered =
          _allProducts.where((product) {
            final n = product.name.toLowerCase();
            final s = (product.subcategory ?? '').toLowerCase();
            return n.contains(q) || s.contains(q);
          }).toList();

      if (filtered.isNotEmpty && _selectedCategoryId == null) {
        final firstProduct = filtered.first;

        // Avval ID bo‘yicha, topilmasa title bo‘yicha qidiring
        Category? matchedCategory = _categories.firstWhere(
          (cat) => cat.id == firstProduct.categoryId,
          orElse:
              () => Category(
                id: '',
                title: '',
                subcategories: const [],
                printerName: '',
                printerIp: '',
                printerId: '',
              ),
        );
        if (matchedCategory.id.isEmpty) {
          matchedCategory = _categories.firstWhere(
            (cat) => (cat.title) == (firstProduct.categoryName),
            orElse:
                () => Category(
                  id: '',
                  title: '',
                  subcategories: const [],
                  printerName: '',
                  printerIp: '',
                  printerId: '',
                ),
          );
        }

        if (matchedCategory.id.isNotEmpty) {
          _selectedCategoryId = matchedCategory.id;
          _selectedCategoryName = matchedCategory.title;

          if ((firstProduct.subcategory ?? '').isNotEmpty) {
            _selectedSubcategory = firstProduct.subcategory;
          }
        }
      }
    } else if (_selectedCategoryId != null ||
        _selectedCategoryName.isNotEmpty) {
      // Kategoriya tanlangan bo‘lsa — ID yoki title bo‘yicha mos keltiramiz
      filtered =
          _allProducts.where((product) {
            final sameId =
                (product.categoryId?.toString() ?? '') ==
                (_selectedCategoryId ?? '');
            final sameName = (product.categoryName) == (_selectedCategoryName);
            if (!(sameId || sameName)) return false;

            if ((_selectedSubcategory ?? '').isNotEmpty) {
              return (product.subcategory) == (_selectedSubcategory);
            }
            return true;
          }).toList();
    } else {
      filtered = _allProducts;
    }

    setState(() {
      _filteredProducts = filtered;
    });
  }

  // <-- _OrderScreenContentState ichiga joylang (istalgan joyga, masalan _filterProductsByCategory() dan oldin)
  String _n(String? s) => (s ?? '').trim().toLowerCase();

  List<String> _visibleSubsFor(Category selectedCategory) {
    // 1) Kategoriya JSON’dan kelsa — o‘shani ishlatamiz
    if (selectedCategory.subcategories.isNotEmpty) {
      final list =
          selectedCategory.subcategories
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return list;
    }

    // 2) Aks holda mahsulotlardan yig‘amiz (ID yoki nom bo‘yicha mos kelsa)
    final set = <String>{};
    for (final p in _allProducts) {
      final sameId = (p.categoryId?.toString() ?? '') == selectedCategory.id;
      final sameName = _n(p.categoryName) == _n(selectedCategory.title);
      if ((sameId || sameName) && (p.subcategory?.trim().isNotEmpty ?? false)) {
        set.add(p.subcategory!.trim());
      }
    }

    final list =
        set.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
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
      final result = await _sendOrderInBackground();

      if (result['success'] == true) {
        if (mounted) {
          _showSuccess(result['message'] ?? 'Zakaz muvaffaqiyatli yuborildi!');
          widget.onOrderCreated?.call();
          Navigator.of(context).pop(); // ✅ darhol yopiladi
        }
      } else {
        if (mounted) {
          _showError(result['message'] ?? 'Zakaz yuborishda xatolik');
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // 🔹 Zakazni serverga yuborish
  Future<Map<String, dynamic>> _sendOrderInBackground() async {
    try {
      if (_cart.isEmpty) {
        return {'success': false, 'message': 'Savat bo‘sh'};
      }
      if (_token == null) {
        return {'success': false, 'message': 'Token topilmadi'};
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
        'user_id': widget.user.id,
        'first_name': widget.user.firstName ?? 'Noma\'lum',
        'items': orderItems,
        'total_price': _calculateTotal(),
        'kassir_workflow': true,
        'table_number': widget.tableName ?? 'N/A',
      };

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
        // ✅ Printerni backgroundda yuboramiz
        Future.microtask(() => _printOrderAsync(data));
        return {'success': true, 'message': 'Zakaz muvaffaqiyatli yuborildi!'};
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

      final data = jsonDecode(response.body);

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

    final header = 'Nomi'.padRight(20) + 'Soni';
    bytes.addAll([0x1B, 0x61, 1]); // Markaz
    bytes.addAll(_encodeText(header + '\r\n'));
    bytes.addAll(_encodeText('-' * 32 + '\r\n'));

    for (final item in data['items']) {
      final name = item['name'].toString();
      final qty = item['qty'].toString();
      final line = name.padRight(20) + qty;

      bytes.addAll([0x1B, 0x61, 0]); // Chapga
      bytes.addAll(_encodeText(line + '\r\n'));

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
    // Local helper: normalize
    String n(String? s) => (s ?? '').trim().toLowerCase();

    // 1) Subkategoriya ro‘yxatini tayyorlab olish:
    //    - Agar Category.subcategories bo‘lsa — o‘shani ishlatamiz
    //    - Aks holda mahsulotlardan (ID yoki nom bo‘yicha) yig‘amiz
    List<String> subs;
    if (selectedCategory.subcategories.isNotEmpty) {
      subs =
          selectedCategory.subcategories
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      final set = <String>{};
      for (final p in _allProducts) {
        final sameId = (p.categoryId?.toString() ?? '') == selectedCategory.id;
        final sameName = n(p.categoryName) == n(selectedCategory.title);
        if ((sameId || sameName) &&
            (p.subcategory?.trim().isNotEmpty ?? false)) {
          set.add(p.subcategory!.trim());
        }
      }
      subs =
          set.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

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
          // Header
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

          if (subs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildSubcategoryChip(null, 'Barchasi'),
                    const SizedBox(width: 8),
                    ...subs.map(
                      (sub) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildSubcategoryChip(sub, sub),
                      ),
                    ),
                  ],
                ),
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
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 5 : (isTablet ? 2 : 3),
                          childAspectRatio: 1.1,
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
    final hasCategory =
        _selectedCategoryId != null && _selectedCategoryName != null;

    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        // Avval kategoriya tanlanganmi — tekshiramiz
        if (!hasCategory) {
          // Agar xabar ko'rsatmoqchi bo'lsangiz, quyidagisini uncomment qiling:
          // showTopSnackBar(context, CustomSnackBar.error(message: "Avval kategoriya tanlang"));
          return;
        }

        final catId = _selectedCategoryId!; // bu yerda endi xavfsiz
        final catName = _selectedCategoryName!;

        // UI holatini yangilab qo'yamiz
        setState(() {
          _selectedSubcategory = selected ? subcategory : null;
        });

        _selectCategory(
          catId,
          catName,
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
    final double totalPrice =
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
                          width: 28,
                          height: 28,
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
                          width: 28,
                          height: 28,
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
                          width: 28,
                          height: 28,
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
                          width: 28,
                          height: 28,
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
                        onTap: () {
                          if (product.unit == 'kg') {
                            _showKgInputModal(context, product);
                          } else {
                            _updateCart(product.id, 1);
                          }
                        },
                        child: Container(
                          width: 28,
                          height: 28,
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
                      SizedBox(width: 15),
                      GestureDetector(
                        onTap: () => _showNoteInputModal(context, product),
                        child: Container(
                          width: 28,
                          height: 28,
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
            onTap: () {},
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
            constraints: BoxConstraints(maxWidth: isDesktop ? 200 : 150),
            child: OutlinedButton.icon(
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text(
                'Bekor qilish',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
            constraints: BoxConstraints(maxWidth: isDesktop ? 300 : 250),
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
                  fontSize: 14,
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
    bytes.addAll(_encodeText(tableLine + '\r\n'));

    bytes.addAll(_encodeText('=' * printerWidth + '\r\n'));

    for (final item in data['items']) {
      final name = item['name'].toString();
      final qty = item['qty'].toString();
      final line = name.padRight(20) + qty;

      bytes.addAll([0x1B, 0x61, 0]); // Left
      bytes.addAll(_encodeText(line + '\r\n'));

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
