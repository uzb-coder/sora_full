import 'package:auto_size_text/auto_size_text.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../../Global/my_pkg.dart';

class AppColors {
  static const primary = Color(0xFF144D37);
  static const secondary = Color(0xFF144D37);
  static const accent = Color(0xFF144D37);
  static const surface = Color(0xFFF5F5F5); // Kulrang orqa fon
  static const white = Colors.white;
  static const grey = Color(0xFF6B7280);
  static const lightGrey = Color(0xFFE5E7EB); // Kulrang
  static const background = Color(0xFFE8E8E8); // Asosiy orqa fon
  static const cardBackground = Color(0xFFF9F9F9); // Kartalar uchun
  static const error = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);
  static const categoryActive = Color(0xFF059669); // Faol kategoriya
  static const categoryInactive = Color(0xFF9CA3AF); // Nofaol kategoriya
}

class Order {
  final String id;
  final String tableId;
  final String userId;
  final String firstName;
  final List<OrderItem> items;
  final num totalPrice;
  final String status;
  final String createdAt;
  bool isProcessing;
  final String formatted_order_number;

  Order({
    required this.id,
    required this.tableId,
    required this.userId,
    required this.firstName,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.formatted_order_number,
    this.isProcessing = false,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? '',
      tableId: json['table_id']?.toString() ?? '',
      formatted_order_number: json['formatted_order_number']?.toString() ?? '',
      userId: json['user_id'] ?? '',
      firstName: json['waiter_name'] ?? json['first_name'] ?? '',
      items:
          (json['items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class OrderItem {
  final String foodId;
  final String? name;
  final num quantity;
  final num? price; // int emas, double bo‘ldi
  final String? categoryName;

  OrderItem({
    required this.foodId,
    required this.quantity,
    this.name,
    this.price,
    this.categoryName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      foodId: json['food_id'] ?? '',
      quantity: json['quantity'] ?? 0,
      name: json['name'],
      price:
          json['price'] != null
              ? (json['price'] as num).toDouble()
              : null, // int/double ikkalasini qamrab oladi
      categoryName: json['category_name'],
    );
  }
}

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

class PosScreen extends StatefulWidget {
  final User user;
  final String token;
  const PosScreen({super.key, required this.user, required this.token});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  String? _selectedTableName;
  String? _selectedTableId;
  List<Order> _selectedTableOrders = [];
  bool _isLoadingOrders = false;
  String? _token;

  Timer? _realTimeTimer;
  List<StolModel> _tables = [];
  Map<String, bool> _tableOccupiedStatus = {};
  Map<String, String> _tableOwners = {};
  Map<String, List<Order>> _ordersCache = {}; // Zakazlar keshi
  bool _isLoadingTables = false;

  // Yangi o'zgaruvchilar qo'shildi
  List<Ovqat> _allProducts = [];
  List<Category> _categories = [];
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    _initializeToken();
    _startRealTimeUpdates();
    _loadProductsAndCategories(); // Yangi metod chaqiriladi
  }

  @override
  void dispose() {
    _realTimeTimer?.cancel();
    super.dispose();
  }

  Map<String, String> _authHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final t =
        _token ?? (widget as dynamic).token; // widget.token bo‘lsa fallback
    if (t != null && (t as String).isNotEmpty) {
      headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  Future<void> _fetchOrdersForTable(String tableId) async {
    if (_token == null) return;

    setState(() => _isLoadingOrders = true);

    try {
      final response = await http
          .get(
            Uri.parse("${ApiConfig.baseUrl}/orders/table/$tableId"),
            headers: _authHeaders(), // ✅ to‘g‘ri
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final orders =
            data
                .map((json) => Order.fromJson(json))
                .where((order) => order.status == 'pending')
                .toList();

        orders.sort((a, b) => a.id.compareTo(b.id));

        // Cache'ni yangilash
        _ordersCache[tableId] = orders;

        if (mounted && _selectedTableId == tableId) {
          setState(() {
            _selectedTableOrders = orders;
            _isLoadingOrders = false;
          });
        }
      } else {
        print("❌ Server xatosi: ${response.statusCode}");
        _ordersCache[tableId] = [];
        if (mounted && _selectedTableId == tableId) {
          setState(() {
            _selectedTableOrders = [];
            _isLoadingOrders = false;
          });
        }
      }
    } catch (e) {
      print("💥 Zakazlarni olishda xatolik: $e");
      if (mounted && _selectedTableId == tableId) {
        setState(() {
          _selectedTableOrders = [];
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _moveOrderToTable(String orderId, String newTableId) async {
    try {
      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/orders/move-table"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "orderId": orderId,
          "newTableId": newTableId,
          "force": false, // kerak bo‘lsa true qilib jo‘natasiz
        }),
      );

      if (response.statusCode == 200) {
        showCenterSnackBar(context, "Zakaz ko'chirildi", color: Colors.green);
        _clearCacheAndRefresh(); // yangilash
      } else {
        showCenterSnackBar(
          context,
          "Xatolik: ${response.statusCode}",
          color: Colors.red,
        );
      }
    } catch (e) {
      showCenterSnackBar(
        context,
        "Ko'chirishda xatolik: $e",
        color: Colors.red,
      );
    }
  }

  void _handleTableTap(String tableName, String tableId) {
    setState(() {
      _selectedTableName = tableName;
      _selectedTableId = tableId;

      _selectedTableOrders = _ordersCache[tableId] ?? [];
    });

    // Keyin fon rejimida API’dan yangisini olib kelamiz
    _fetchOrdersForTableSilently(tableId);
  }

  void _startRealTimeUpdates() {
    _realTimeTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      _checkTableStatusesRealTime();
      if (_selectedTableId != null) {
        _fetchOrdersForTableSilently(_selectedTableId!);
      }
    });
  }

  Future<void> _checkTableStatusesRealTime() async {
    try {
      Map<String, bool> newStatus = {};
      Map<String, String> newOwners = {};

      // Parallel requests bilan barcha stollarni tekshirish (tezroq)
      final futures = _tables.map((table) async {
        try {
          final response = await http
              .get(
                Uri.parse('${ApiConfig.baseUrl}/orders/table/${table.id}'),
                headers: {
                  'Authorization': 'Bearer ${widget.token}',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 2));

          if (response.statusCode == 200) {
            final List<dynamic> orders = jsonDecode(response.body);
            final pendingOrders =
                orders.where((o) => o['status'] == 'pending').toList();

            newStatus[table.id] = pendingOrders.isNotEmpty;
            if (pendingOrders.isNotEmpty) {
              newOwners[table.id] =
                  pendingOrders.first['user_id']?.toString() ?? '';
            } else {
              newOwners.remove(
                table.id,
              ); // Bo'sh stollar uchun owner ni olib tashlash
            }

            // Cache faqat tanlangan stol bo'lmasa yangilanadi
            if (_selectedTableId != table.id) {
              final orderObjects =
                  orders
                      .map((json) => Order.fromJson(json))
                      .where((order) => order.status == 'pending')
                      .toList();

              // Zakazlarni sort qilish
              orderObjects.sort((a, b) => a.id.compareTo(b.id));

              if (orderObjects.isNotEmpty ||
                  _ordersCache.containsKey(table.id)) {
                _ordersCache[table.id] = orderObjects;
              }
            }
          } else {
            newStatus[table.id] = false;
            newOwners.remove(table.id);
          }
        } catch (e) {
          // Real-time da xatolikni ignore qilamiz, eski holatni saqlaymiz
          newStatus[table.id] = _tableOccupiedStatus[table.id] ?? false;
          if (_tableOwners.containsKey(table.id)) {
            newOwners[table.id] = _tableOwners[table.id]!;
          }
        }
      });

      await Future.wait(futures);

      if (mounted) {
        // Faqat haqiqatdan ham o'zgarish bo'lsa UI ni yangilash
        bool statusChanged = !_mapsEqual(newStatus, _tableOccupiedStatus);
        bool ownerChanged = !_mapsEqualString(newOwners, _tableOwners);

        if (statusChanged || ownerChanged) {
          setState(() {
            _tableOccupiedStatus = newStatus;
            _tableOwners = newOwners;

            // Agar tanlangan stol bo'sh bo'lib qolgan bo'lsa, zakazlar ro'yxatini tozalash
            if (_selectedTableId != null && !newStatus[_selectedTableId!]!) {
              _selectedTableOrders = [];
            }
          });
        }
      }
    } catch (e) {
      // Real-time da umumiy xatolikni ham ignore qilamiz
    }
  }

  Future<void> _fetchOrdersForTableSilently(String tableId) async {
    if (_token == null) return;

    try {
      final response = await http
          .get(
            Uri.parse("${ApiConfig.baseUrl}/orders/table/$tableId"),
            headers: {
              'Authorization': 'Bearer ${widget.token}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final orders =
            data
                .map((json) => Order.fromJson(json))
                .where((order) => order.status == 'pending')
                .toList();

        orders.sort((a, b) => a.id.compareTo(b.id));

        _ordersCache[tableId] = orders;

        if (mounted && _selectedTableId == tableId) {
          setState(() {
            _selectedTableOrders = orders;
          });
        }
      }
    } catch (e) {
      print("❌ Silent fetch error: $e");
    }
  }

  void _clearCacheAndRefresh() {
    if (_selectedTableId != null) {
      _ordersCache.remove(_selectedTableId!);
    }

    // Darhol yangilash
    Future.microtask(() {
      if (_selectedTableId != null) {
        _fetchOrdersForTable(_selectedTableId!);
      }
      _checkTableStatusesRealTime();
    });
  }

  void _showOrderScreenDialog(String tableId) {
    bool isOccupied = _tableOccupiedStatus[tableId] ?? false;
    String? tableOwner = _tableOwners[tableId];

    if (isOccupied && tableOwner != null && tableOwner != widget.user.id) {
      showCenterSnackBar(
        context,
        'Bu stol boshqa ofitsiantga tegishli!',
        color: Colors.green,
      );
      return;
    }

    String? formattedOrderNumber =
        _selectedTableOrders.isNotEmpty
            ? _selectedTableOrders.first.formatted_order_number
            : '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          child: OrderScreenContent(
            formatted_order_number: formattedOrderNumber,
            tableId: tableId,
            tableName: _selectedTableName,
            user: widget.user,
            onOrderCreated: () async {
              _clearCacheAndRefresh();
            },
            token: widget.token,
          ),
        );
      },
    );
  }

  Future<void> _closeOrder(Order order) async {
    if (order.userId != widget.user.id) {
      showCenterSnackBar(
        context,
        'Faqat o\'zingiz yaratgan zakazni yopa olasiz!',
        color: Colors.green,
      );
      return;
    }

    try {
      setState(() => order.isProcessing = true);

      bool success = await closeOrder(order.id);

      if (success) {
        print("✅ Zakaz yopildi: ${order.id}");

        setState(() {
          _selectedTableOrders.removeWhere((o) => o.id == order.id);

          // Agar zakazlar qolmagan bo'lsa, stolni bo'sh qilib qo'yish
          if (_selectedTableOrders.isEmpty && _selectedTableId != null) {
            _tableOccupiedStatus[_selectedTableId!] = false;
            _tableOwners.remove(_selectedTableId!);
          }
        });

        // Cache ni tozalash
        if (_selectedTableId != null) {
          _ordersCache[_selectedTableId!] = _selectedTableOrders;
        }

        // Real-time statusni yangilash (background da)
        Future.microtask(() => _checkTableStatusesRealTime());

        showCenterSnackBar(context, 'Zakaz yopildi', color: Colors.green);
      } else {
        showCenterSnackBar(context, 'Xatolik yuz berdi');
      }
    } catch (e) {
      showCenterSnackBar(context, 'Xatolik: $e');
    } finally {
      if (mounted) setState(() => order.isProcessing = false);
    }
  }

  Future<void> _checkTableStatuses() async {
    try {
      Map<String, bool> newStatus = {};
      Map<String, String> newOwners = {};

      // Parallel requests bilan barcha stollarni tekshirish
      final futures = _tables.map((table) async {
        try {
          final response = await http
              .get(
                Uri.parse('${ApiConfig.baseUrl}/orders/table/${table.id}'),
                headers: {
                  'Authorization': 'Bearer ${widget.token}',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final List<dynamic> orders = jsonDecode(response.body);
            final pendingOrders =
                orders.where((o) => o['status'] == 'pending').toList();

            newStatus[table.id] = pendingOrders.isNotEmpty;
            if (pendingOrders.isNotEmpty) {
              newOwners[table.id] = pendingOrders.first['user_id'] ?? '';
            }

            // Cache yangilanishi faqat tanlangan stol bo'lmasa
            if (_selectedTableId != table.id) {
              final orderObjects =
                  orders
                      .map((json) => Order.fromJson(json))
                      .where((order) => order.status == 'pending')
                      .toList();

              // Sort qilish
              orderObjects.sort((a, b) => a.id.compareTo(b.id));

              _ordersCache[table.id] = orderObjects;
            }
          } else {
            newStatus[table.id] = false;
          }
        } catch (e) {
          print("Stol ${table.id} uchun xatolik: $e");
          newStatus[table.id] = _tableOccupiedStatus[table.id] ?? false;
        }
      });

      await Future.wait(futures);

      if (mounted) {
        bool statusChanged = !_mapsEqual(newStatus, _tableOccupiedStatus);
        bool ownerChanged = !_mapsEqualString(newOwners, _tableOwners);

        if (statusChanged || ownerChanged) {
          setState(() {
            _tableOccupiedStatus = newStatus;
            _tableOwners = newOwners;
          });
        }
      }
    } catch (e) {
      print("Status check error: $e");
    }
  }

  Future<void> _loadProductsAndCategories() async {
    setState(() => _isLoadingProducts = true);

    try {
      // ✅ Mahsulotlarni olish
      Future<List<Ovqat>> fetchProducts() async {
        final url = Uri.parse(
          "${ApiConfig.baseUrl}/foods/list",
        ); // <-- yo‘lni tekshiring

        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
        );

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          final data = decoded['foods'] ?? decoded['data'] ?? decoded;
          if (data is List) {
            return data.map((e) => Ovqat.fromJson(e)).toList();
          }
          throw Exception("API javobida mahsulotlar ro'yxati topilmadi");
        } else {
          throw Exception(
            "Mahsulotlar olishda xatolik: ${response.statusCode}",
          );
        }
      }

      Future<List<Category>> fetchCategories() async {
        final url = Uri.parse("${ApiConfig.baseUrl}/categories/list");

        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
        );

        if (response.statusCode == 200) {
          try {
            final decoded = json.decode(response.body);
            List<dynamic> categoriesList;
            if (decoded is List) {
              categoriesList = decoded;
            } else if (decoded is Map && decoded.containsKey('categories')) {
              categoriesList = decoded['categories'];
            } else {
              return [];
            }

            final categories =
                categoriesList.map((json) {
                  return Category.fromJson(json);
                }).toList();

            return categories;
          } catch (e) {
            return [];
          }
        } else {
          return [];
        }
      }

      final results = await Future.wait([fetchCategories(), fetchProducts()]);

      if (mounted) {
        setState(() {
          _categories = results[0] as List<Category>;
          _allProducts = results[1] as List<Ovqat>;
          _isLoadingProducts = false;
        });
      }

      for (var c in _categories) {}
    } catch (e) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _printToSocket(String ip, List<int> data) async {
    try {
      final socket = await Socket.connect(
        ip,
        9100,
        timeout: const Duration(seconds: 2),
      );
      socket.add(data);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 300));
      socket.destroy();
      debugPrint('$ip ga muvaffaqiyatli yuborildi');
    } catch (e) {
      debugPrint('$ip ga yuborishda xatolik: $e');
    }
  }

  List<int> _encodeText(String text) {
    return latin1.encode(text);
  }

  Future<void> _printCancelledItem(
    OrderItem item,
    int cancelQuantity,
    String reason,
    Order order,
  ) async {
    try {
      debugPrint('🖨️ Bekor qilingan mahsulot print qilinmoqda');
      debugPrint("🟢 Categories IDs: ${_categories.map((c) => c.id).toList()}");

      // Mahsulotning kategoriyasini topish
      final product = _allProducts.firstWhere(
        (p) => p.id == item.foodId,
        orElse:
            () => Ovqat(
              id: '',
              name: 'Noma\'lum',
              price: 0,
              categoryId: '',
              subcategory: null,
              categoryName: '',
              subcategories: [],
            ),
      );

      final category = _categories.firstWhere(
        (cat) => cat.id == product.categoryId,
        orElse:
            () => Category(
              id: '',
              title: '',
              printerId: '',
              printerName: '',
              printerIp: '',
              subcategories: [],
            ),
      );

      // Printer IP borligini tekshirish
      if (category.printerIp.isNotEmpty && category.printerIp != 'null') {
        final printData = {
          'orderNumber': order.formatted_order_number,
          'waiter_name': widget.user.firstName ?? 'Noma\'lum',
          'table_name': _selectedTableName ?? 'N/A',
          'item_name': item.name ?? 'Noma\'lum mahsulot',
          'cancel_quantity': cancelQuantity,
          'reason': reason,
          'time': DateTime.now().toString().substring(11, 16),
        };

        debugPrint("📡 ${category.title} => printerIp: ${category.printerIp}");

        final printBytes = _createCancelPrintData(printData);
        await _printToSocket(category.printerIp, printBytes);

        debugPrint(
          '✅ Bekor qilingan mahsulot ${category.printerIp} ga yuborildi',
        );
      } else {
        debugPrint("📡 ${category.title} => printerIp: ${category.printerIp}");
        debugPrint('⚠️ Kategoriya printeri topilmadi');
      }
    } catch (e) {
      debugPrint('❌ Cancel print error: $e');
    }
  }

  // Stol Controller
  static const String baseUrl = "${ApiConfig.baseUrl}";
  Future<List<StolModel>> fetchTables() async {
    final url = Uri.parse("$baseUrl/tables/list");
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}', // afitsant tokeni headerda
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> tablesJson = json.decode(response.body);
      return tablesJson.map((json) => StolModel.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception(
        "Token yaroqsiz yoki muddati o'tgan. Qayta login qiling.",
      );
    } else {
      throw Exception("Xatolik: ${response.statusCode}");
    }
  }

  bool _mapsEqual(Map<String, bool> map1, Map<String, bool> map2) {
    if (map1.length != map2.length) return false;
    for (var key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }

  bool _mapsEqualString(Map<String, String> map1, Map<String, String> map2) {
    if (map1.length != map2.length) return false;
    for (var key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }

  Future<void> _initializeToken() async {
    try {
      // 1) Avval konstruktor orqali kelgan tokenni oling
      _token = widget.token;

      // 2) Bo‘sh bo‘lsa localdan oling
      if (_token == null || _token!.isEmpty) {
        _token = await AuthService.getToken();
      }

      // 3) Hali ham bo‘sh bo‘lsa – login sahifasiga yo‘naltiring (yoki error ko‘rsating)
      if (_token == null || _token!.isEmpty) {
        // Bu yerda avtomatik login qila olmaysiz – foydalanuvchi credential kiritishi kerak
        showCenterSnackBar(
          context,
          "Iltimos, qayta tizimga kiring (token yo‘q).",
          color: Colors.red,
        );
        return;
      }

      // 4) Endi dastlabki yuklashlar
      _loadInitialTables();
    } catch (e) {
      print("Token error: $e");
    }
  }

  Future<void> _loadInitialTables() async {
    if (mounted) setState(() => _isLoadingTables = true);

    try {
      final tables = await fetchTables();

      if (mounted) {
        setState(() {
          _tables = tables;
          _isLoadingTables = false;
        });
        _checkTableStatuses();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTables = false);
      print("Tables loading error: $e");
    }
  }

  bool _ordersAreEqual(List<Order> orders1, List<Order> orders2) {
    if (orders1.length != orders2.length) return false;
    for (int i = 0; i < orders1.length; i++) {
      if (orders1[i].id != orders2[i].id) return false;
    }
    return true;
  }

  Future<bool> closeOrder(String orderId) async {
    const String apiUrl = "${ApiConfig.baseUrl}/orders/close/";
    try {
      final response = await http.put(
        Uri.parse("$apiUrl$orderId"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        print("Close order failed: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("Close order error: $e");
      return false;
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

  // Sabablar ro'yxati
  final List<String> reasons = [
    "Mijoz bekor qildi",
    "Klient shikoyat qildi",
    "Notogri tayyorlangan",
    "Mahsulot tugagan",
    "Xizmat sifati past",
    "Boshqa",
  ];

  Future<void> showCancelDialog(
    String orderId,
    String foodId,
    int itemIndex,
    Order order,
  ) async {
    String reason = reasons[0]; // Default sabab
    String notes = "ixtiyor"; // API uchun izoh
    int cancelQuantity = 1; // Default miqdor
    final item = order.items[itemIndex];
    final TextEditingController quantityController = TextEditingController(
      text: "1",
    );

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                "${item.name ?? 'Mahsulot'} ni bekor qilish",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Umumiy soni: ${item.quantity}"),
                  if (item.price != null)
                    Text(
                      "Narxi: ${NumberFormat('#,##0', 'uz').format(item.price! * item.quantity)} so'm",
                      style: TextStyle(color: Colors.green),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    "Bekor qilish sababi:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: reason,
                    items:
                        reasons.map((String r) {
                          return DropdownMenuItem<String>(
                            value: r,
                            child: Text(r),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          reason = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Bekor qilinadigan miqdor:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: "Miqdorni kiriting",
                    ),
                    onChanged: (value) {
                      setState(() {
                        cancelQuantity = int.tryParse(value) ?? 1;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "Bekor qilish",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (cancelQuantity <= 0 || cancelQuantity > item.quantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Noto'g'ri miqdor kiritildi!")),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    _deleteItem(
                      orderId,
                      foodId,
                      itemIndex,
                      reason,
                      notes,
                      cancelQuantity,
                      order,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Tasdiqlash",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // _deleteItem funksiyasini yangilash
  Future<void> _deleteItem(
    String orderId,
    String foodId,
    int itemIndex,
    String reason,
    String notes,
    int cancelQuantity,
    Order order,
  ) async {
    setState(() => order.isProcessing = true);

    final result = await cancelOrderItemFast(
      orderId: orderId,
      foodId: foodId,
      cancelQuantity: cancelQuantity,
      reason: reason,
      notes: notes,
    );

    setState(() {
      order.isProcessing = false;
      if (result['success'] == true) {
        final item = order.items[itemIndex];
        final currentQuantity = item.quantity;
        final newQuantity = currentQuantity - cancelQuantity;

        if (newQuantity <= 0) {
          order.items.removeAt(itemIndex);
        } else {
          order.items[itemIndex] = OrderItem(
            foodId: item.foodId,
            name: item.name,
            quantity: newQuantity,
            price: item.price,
            categoryName: item.categoryName,
          );
        }

        if (order.items.isEmpty) {
          _selectedTableOrders.removeWhere((o) => o.id == orderId);
          _ordersCache[_selectedTableId!]!.removeWhere((o) => o.id == orderId);
          if (_selectedTableOrders.isEmpty) {
            _tableOccupiedStatus[_selectedTableId!] = false;
            _tableOwners.remove(_selectedTableId!);
          }
        }

        // YANGI: Bekor qilingan mahsulotni printerga yuborish
        _printCancelledItem(item, cancelQuantity, reason, order);

        showCenterSnackBar(
          context,
          "✅ Mahsulot bekor qilindi!",
          color: Colors.green,
        );
        _fetchOrdersForTable(_selectedTableId!);
        _checkTableStatuses();
      } else {
        showCenterSnackBar(
          context,
          result['message']?.toString() ?? 'Mahsulotni bekor qilishda xatolik!',
          color: AppColors.error,
        );
      }
    });
  }

  // YANGI: Bekor qilingan mahsulot uchun print ma'lumotini yaratish
  List<int> _createCancelPrintData(Map<String, dynamic> data) {
    final bytes = <int>[];
    const printerWidth = 32;

    bytes.addAll([0x1B, 0x40]); // Reset
    bytes.addAll([0x1B, 0x74, 17]); // CP866

    // Markazlash
    bytes.addAll([0x1B, 0x61, 1]); // Center alignment

    // Sarlavha
    bytes.addAll(_encodeText('MAHSULOT BEKOR QILINDI\r\n'));
    bytes.addAll(_encodeText('=' * printerWidth + '\r\n'));

    // Asosiy ma'lumotlar
    bytes.addAll(_encodeText('Zakaz: ${data['orderNumber']}\r\n'));
    bytes.addAll(_encodeText('Ofitsiant: ${data['waiter_name']}\r\n'));
    bytes.addAll(_encodeText('Stol: ${data['table_name']}\r\n'));
    bytes.addAll(_encodeText('Vaqt: ${data['time']}\r\n'));
    bytes.addAll(_encodeText('-' * printerWidth + '\r\n'));

    // Bekor qilingan mahsulot ma'lumotlari
    bytes.addAll(_encodeText('MAHSULOT:\r\n'));
    bytes.addAll(_encodeText('${data['item_name']}\r\n'));
    bytes.addAll(_encodeText('MIQDOR: ${data['cancel_quantity']}\r\n'));
    bytes.addAll(_encodeText('-' * printerWidth + '\r\n'));

    // Sabab
    bytes.addAll(_encodeText('SABAB:\r\n'));
    bytes.addAll(_encodeText('${data['reason']}\r\n'));
    bytes.addAll(_encodeText('=' * printerWidth + '\r\n'));

    // Bo'sh joy qoldirish va kesish
    bytes.addAll(_encodeText('\r\n\r\n\r\n\r\n\r\n'));
    bytes.addAll([0x1D, 0x56, 0]); // Cut

    return bytes;
  }

  // API orqali taomni bekor qilish
  Future<Map<String, dynamic>> cancelOrderItemFast({
    required String orderId,
    required String foodId,
    required int cancelQuantity,
    required String reason,
    required String notes,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/orders/$orderId/cancel-item'),
            headers: {
              'Authorization': 'Bearer ${widget.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'food_id': foodId,
              'cancel_quantity': cancelQuantity,
              'reason': reason,
              'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _ordersCache.clear(); // Keshni tozalash
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Mahsulot bekor qilindi',
        };
      }

      return {
        'success': false,
        'message':
            data['message']?.toString() ?? 'Mahsulotni bekor qilishda xatolik',
      };
    } catch (e) {
      debugPrint('Mahsulotni bekor qilishda xatolik: $e');
      return {'success': false, 'message': 'Xatolik: $e'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth >= 600 && screenWidth <= 1200;

    return Scaffold(
      backgroundColor: Color(0xFFDFF3E3),
      appBar: _buildAppBar(),
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: _buildTablesGrid(isDesktop, isTablet),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: _buildOrderDetails(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFDFF3E3),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppColors.primary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.user.firstName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildHeaderButton(
                onPressed: () {
                  if (_selectedTableId != null) {
                    _showOrderScreenDialog(_selectedTableId!);
                  } else {
                    showCenterSnackBar(
                      context,
                      'Stolni tanlang!',
                      color: Colors.green,
                    );
                  }
                },
                icon: Icons.add_circle_outline,
                label:
                    _selectedTableName != null
                        ? "Yangi hisob: $_selectedTableName"
                        : "Yangi hisob",
                isPrimary: true,
              ),
              const SizedBox(width: 12),
              _buildHeaderButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => OrderTablePage(
                            waiterName: widget.user.firstName,
                            token: widget.token,
                          ),
                    ),
                  );
                },
                icon: Icons.check_circle_outline,
                label: "Yopilgan hisoblar",
                isPrimary: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : AppColors.secondary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: AppColors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildTablesGrid(bool isDesktop, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.table_restaurant, color: AppColors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Stollar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child:
                  _isLoadingTables
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      )
                      : _tables.isEmpty
                      ? const Center(
                        child: Text(
                          "Stollar topilmadi",
                          style: TextStyle(color: AppColors.grey),
                        ),
                      )
                      : GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent:
                              200, // element maksimal eni, xohlagancha sozlang
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: _tables.length,
                        itemBuilder: (_, index) {
                          final table = _tables[index];
                          final isSelected = _selectedTableId == table.id;
                          final isOccupied =
                              _tableOccupiedStatus[table.id] ?? false;
                          final isOwnTable =
                              _tableOwners[table.id] == widget.user.id;

                          return GestureDetector(
                            onTap: () {
                              if (_selectedTableId == table.id &&
                                  (!isOccupied || isOwnTable)) {
                                _showOrderScreenDialog(table.id);
                              } else {
                                _handleTableTap(table.name, table.id);
                              }
                            },
                            child: _buildTableCard(
                              table,
                              isSelected,
                              isOccupied,
                              isOwnTable,
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

  Widget _buildTableCard(
    StolModel table,
    bool isSelected,
    bool isOccupied,
    bool isOwnTable,
  ) {
    Color cardColor;
    Color textColor;
    String statusText;
    Color borderColor;

    if (isOccupied && !isOwnTable) {
      cardColor = AppColors.error.withOpacity(0.1);
      textColor = AppColors.error;
      statusText = "Boshqa ofitsiant";
      borderColor = AppColors.error;
    } else if (isOccupied && isOwnTable) {
      cardColor = AppColors.accent.withOpacity(0.1);
      textColor = AppColors.accent;
      statusText = "Mening stolim";
      borderColor = AppColors.accent;
    } else if (isSelected) {
      cardColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green;
      statusText = "Tanlangan";
      borderColor = Colors.green;
    } else {
      // 🟢 Bo'sh stol
      cardColor = Colors.green.withOpacity(0.05);
      textColor = Colors.green;
      statusText = "Bo'sh";
      borderColor = Colors.green; // 🔥 Bo'sh stol borderi ham yashil bo‘ladi
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: textColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.table_bar,
                size: 28,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "${table.name}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: textColor, width: 1),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔼 Tepada "Zakazlar" header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.receipt_long, color: AppColors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  "Zakazlar",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),

          // 🔽 Kontent qismi
          Expanded(
            child:
                _selectedTableId == null
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.point_of_sale,
                            size: 64,
                            color: AppColors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Stolni tanlang",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _selectedTableOrders.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 48,
                            color: AppColors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Zakazlar yo'q",
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _selectedTableOrders.length,
                      itemBuilder: (context, index) {
                        final order = _selectedTableOrders[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: _buildOrderCard(order, index),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, int index) {
    final isOwnOrder = order.userId == widget.user.id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${order.formatted_order_number}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Kutilmoqda',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (isOwnOrder) ...[
              const SizedBox(height: 8),
              Text(
                "Ofitsiant: ${order.firstName}",
                style: const TextStyle(fontSize: 13, color: AppColors.grey),
              ),
              Text(
                "Vaqt: ${_formatDateTime(order.createdAt)}",
                style: const TextStyle(fontSize: 13, color: AppColors.grey),
              ),
              const SizedBox(height: 12),
              const Text(
                "Mahsulotlar:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              ...order.items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${item.name ?? 'Mahsulot'} x${item.quantity}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (item.price != null)
                        Text(
                          "${NumberFormat('#,##0', 'uz').format(item.price! * item.quantity)} so'm",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: AppColors.error,
                          size: 20,
                        ),
                        onPressed:
                            isOwnOrder
                                ? () => showCancelDialog(
                                  order.id,
                                  item.foodId,
                                  order.items.indexOf(item),
                                  order,
                                )
                                : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payments, color: AppColors.accent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Jami:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "${NumberFormat('#,##0', 'uz').format(order.totalPrice)} so'm",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // YANGI: Mahsulot qo'shish va Zakazni yopish tugmalari
              Row(
                children: [
                  // Mahsulot qo'shish tugmasi
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child:
                          order.isProcessing
                              ? Container(
                                decoration: BoxDecoration(
                                  color: AppColors.lightGrey,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                              : ElevatedButton.icon(
                                onPressed: () => _showAddItemsDialog(order),
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  size: 18,
                                ),
                                label: const Text(
                                  "Qo'shish",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Zakazni yopish tugmasi
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child:
                          order.isProcessing
                              ? Container(
                                decoration: BoxDecoration(
                                  color: AppColors.lightGrey,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                              : ElevatedButton.icon(
                                onPressed: () => _closeOrder(order),
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text(
                                  "Yopish",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: AppColors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 🆕 Ko‘chirish tugmasi
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _showMoveTableDialog(order),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text("Ko'chirish"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, size: 20, color: AppColors.error),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Bu zakaz boshqa ofitsiantga tegishli",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveTableDialog(Order order) async {
    final emptyTables =
        _tables.where((t) => !(_tableOccupiedStatus[t.id] ?? false)).toList();

    if (emptyTables.isEmpty) {
      showCenterSnackBar(context, "Bo'sh stollar yo'q", color: Colors.red);
      return;
    }

    String? selectedTableId;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Zakazni boshqa stolga ko'chirish"),
          content: DropdownButtonFormField<String>(
            value: selectedTableId,
            items:
                emptyTables.map((table) {
                  return DropdownMenuItem(
                    value: table.id,
                    child: Text("Stol ${table.number}"),
                  );
                }).toList(),
            onChanged: (value) {
              selectedTableId = value;
            },
            decoration: const InputDecoration(
              labelText: "Stol tanlang",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Bekor qilish"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Ko'chirish"),
              onPressed: () async {
                if (selectedTableId != null) {
                  Navigator.pop(context);
                  await _moveOrderToTable(order.id, selectedTableId!);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Mahsulot qo'shish dialogini ko'rsatish metodi
  void _showAddItemsDialog(Order order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          child: OrderScreenContent(
            formatted_order_number:
                order.formatted_order_number, // YANGI qo'shildi
            tableId: order.tableId,
            tableName: _selectedTableName,
            user: widget.user,
            token: widget.token,
            isAddingToExistingOrder: true, // YANGI parametr
            existingOrderId: order.id, // YANGI parametr
            onOrderCreated: () async {
              _fetchOrdersForTable(_selectedTableId!);
              _checkTableStatuses();
            },
          ),
        );
      },
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }
}
