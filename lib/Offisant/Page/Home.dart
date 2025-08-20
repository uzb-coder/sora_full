import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'dart:io';
import 'dart:async';
import '../../Admin/Page/Blyuda/Blyuda.dart';
import '../../Admin/Page/Stollarni_joylashuv.dart';
import '../../Global/Api_global.dart';
import '../Controller/TokenCOntroller.dart';
import '../Controller/usersCOntroller.dart';
import '../Model/Ovqat_model.dart';
import 'Yopilgan_zakaz_page.dart';

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
  final double totalPrice;
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
  final int quantity;
  final int? price;
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
      price: json['price'],
      categoryName: json['category_name'],
    );
  }
}

class Category {
  final String id;
  final String title;
  final String printerName;
  final String printerIp;
  final List<String> subcategories;

  Category({
    required this.id,
    required this.title,
    required this.printerName,
    required this.printerIp,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id'],
      title: json['title'] ?? '',
      printerName: json['printer_id']?['name'] ?? '',
      printerIp: json['printer_id']?['ip'] ?? '',
      subcategories: json['subcategories'] != null
          ? List<String>.from(json['subcategories'].map((e) => e['title']))
          : [],
    );
  }
}

class PosScreen extends StatefulWidget {
  final User user;
  final token;
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

  // Mahsulotlar va kategoriyalarni yuklash
  Future<void> _loadProductsAndCategories() async {
    setState(() => _isLoadingProducts = true);
    try {
      String baseUrl = "${ApiConfig.baseUrl}/";

      // Mahsulotlarni yuklash
      Future<List<Ovqat>> fetchProducts() async {
        final url = Uri.parse("$baseUrl/foods/list");
        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
        );

        if (response.statusCode == 200) {
          final dynamic decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            final data = decoded['foods'] ?? decoded['data'] ?? decoded;
            if (data is List) {
              return data.map((e) => Ovqat.fromJson(e)).toList();
            }
          } else if (decoded is List) {
            return decoded.map((e) => Ovqat.fromJson(e)).toList();
          }
          throw Exception("API javobida mahsulotlar ro'yxati topilmadi");
        } else {
          throw Exception("Mahsulotlar olishda xatolik: ${response.statusCode}");
        }
      }

      // Kategoriyalarni yuklash
      Future<List<Category>> fetchCategories() async {
        final url = Uri.parse("$baseUrl/categories/list");
        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
        );

        if (response.statusCode == 200) {
          final dynamic decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            final data = decoded['categories'] ?? decoded['data'] ?? decoded;
            if (data is List) {
              return data.map((e) => Category.fromJson(e)).toList();
            }
          } else if (decoded is List) {
            return decoded.map((e) => Category.fromJson(e)).toList();
          }
          throw Exception("API javobida kategoriyalar ro'yxati topilmadi");
        } else {
          throw Exception("Kategoriya olishda xatolik: ${response.statusCode}");
        }
      }

      final futures = await Future.wait([
        fetchCategories(),
        fetchProducts(),
      ]);

      if (mounted) {
        setState(() {
          _categories = futures[0] as List<Category>;
          _allProducts = futures[1] as List<Ovqat>;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      debugPrint("Mahsulotlar va kategoriyalarni yuklashda xato: $e");
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  // Printer metodlari qo'shildi
  Future<void> _printToSocket(String ip, List<int> data) async {
    try {
      debugPrint('Printerga ulanmoqda: $ip:9100');
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
    return latin1.encode(text); // CP866 yoki UTF-8 kodlash
  }

  // Bekor qilingan mahsulotni printerga yuborish
  Future<void> _printCancelledItem(
      OrderItem item, int cancelQuantity, String reason, Order order) async {
    try {
      debugPrint('🖨️ Bekor qilingan mahsulot print qilinmoqda');

      // Mahsulotning kategoriyasini topish
      final product = _allProducts.firstWhere(
            (p) => p.id == item.foodId,
        orElse: () => Ovqat(
          id: '',
          name: 'Noma\'lum',
          price: 0,
          categoryId: '',
          subcategory: null, categoryName: '', subcategories: [],
        ),
      );

      final category = _categories.firstWhere(
            (cat) => cat.id == product.categoryId,
        orElse: () => Category(
          id: '',
          title: '',
          subcategories: [],
          printerName: '',
          printerIp: '',
        ),
      );

      // Printer IP borligini tekshirish
      if (category.printerIp.isNotEmpty && category.printerIp != 'null') {
        final printData = {
          'orderNumber': order.formatted_order_number,
          'waiter_name': widget.user.firstName ?? 'Nomaplan, orElse: () => null',
          'table_name' : _selectedTableName ?? 'N/A',
          'item_name': item.name ?? 'Noma\'lum mahsulot',
          'cancel_quantity': cancelQuantity,
          'reason': reason,
          'time': DateTime.now().toString().substring(11, 16),
        };

        final printBytes = _createCancelPrintData(printData);
        await _printToSocket(category.printerIp, printBytes);
        debugPrint('✅ Bekor qilingan mahsulot ${category.printerIp} ga yuborildi');
      } else {
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

  void _startRealTimeUpdates() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkTableStatuses();
      // Tanlangan stol uchun zakazlarni background'da yangilash
      if (_selectedTableId != null) {
        _fetchOrdersForTableSilently(_selectedTableId!);
      }
    });
  }

  Future<void> _checkTableStatuses() async {
    try {
      Map<String, bool> newStatus = {};
      Map<String, String> newOwners = {};

      // Parallel requests bilan barcha stollarni bir vaqtda tekshirish
      final futures = _tables.map((table) async {
        try {
          final response = await http
              .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/orders/table/${table.id}',
            ),
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
              newOwners[table.id] = pendingOrders.first['user_id'] ?? '';
            }
            // Zakazlar cache'ini ham yangilash
            final orderObjects =
            orders
                .map((json) => Order.fromJson(json))
                .where((order) => order.status == 'pending')
                .toList();

            if (orderObjects.isNotEmpty || _ordersCache.containsKey(table.id)) {
              _ordersCache[table.id] = orderObjects;
            }
          } else {
            newStatus[table.id] = false;
          }
        } catch (e) {
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

            // Tanlangan stol uchun zakazlarni yangilash
            if (_selectedTableId != null &&
                _ordersCache.containsKey(_selectedTableId!)) {
              final newOrders = _ordersCache[_selectedTableId!]!;
              if (!_ordersAreEqual(_selectedTableOrders, newOrders)) {
                _selectedTableOrders = newOrders;
              }
            }
          });
        }
      }
    } catch (e) {
      print("Status check error: $e");
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
      _token = await AuthService.getToken();
      if (_token == null) {
        await AuthService.loginAndPrintToken();
        _token = await AuthService.getToken();
      }
      if (_token != null) {
        _loadInitialTables();
      }
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

  void _handleTableTap(String tableName, String tableId) {
    setState(() {
      _selectedTableName = tableName;
      _selectedTableId = tableId;
      // Cache'dan darhol ko'rsatish
      if (_ordersCache.containsKey(tableId)) {
        _selectedTableOrders = _ordersCache[tableId]!;
        _isLoadingOrders = false;
      } else {
        _isLoadingOrders = true;
      }
    });

    // Background'da yangi ma'lumotlarni olish
    _fetchOrdersForTable(tableId);
  }

  Future<void> _fetchOrdersForTable(String tableId) async {
    if (_token == null) return;

    if (!_ordersCache.containsKey(tableId)) {
      setState(() => _isLoadingOrders = true);
    }

    try {
      final response = await http
          .get(
        Uri.parse("${ApiConfig.baseUrl}/orders/table/$tableId"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      )
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final orders =
        data
            .map((json) => Order.fromJson(json))
            .where((order) => order.status == 'pending')
            .toList();

        // Cache'ga saqlash
        _ordersCache[tableId] = orders;

        if (mounted && _selectedTableId == tableId) {
          setState(() {
            _selectedTableOrders = orders;
            _isLoadingOrders = false;
          });
        }
      } else {
        _ordersCache[tableId] = [];
        if (mounted && _selectedTableId == tableId) {
          setState(() {
            _selectedTableOrders = [];
            _isLoadingOrders = false;
          });
        }
      }
    } catch (e) {
      if (mounted &&
          _selectedTableId == tableId &&
          !_ordersCache.containsKey(tableId)) {
        setState(() {
          _selectedTableOrders = [];
          _isLoadingOrders = false;
        });
      }
      print("Orders loading error: $e");
    }
  }

  // Background'da loading ko'rsatmasdan yangilash - tezroq
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
          .timeout(const Duration(seconds: 1));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final orders =
        data
            .map((json) => Order.fromJson(json))
            .where((order) => order.status == 'pending')
            .toList();

        _ordersCache[tableId] = orders;

        // Faqat tanlangan stol bo'lsa va o'zgarish bo'lsa yangilash
        if (mounted && _selectedTableId == tableId) {
          bool hasChanged =
              _selectedTableOrders.length != orders.length ||
                  !_ordersAreEqual(_selectedTableOrders, orders);

          if (hasChanged) {
            setState(() {
              _selectedTableOrders = orders;
            });
          }
        }
      }
    } catch (e) {
      // Xatolikni ignore qilish - background jarayon
    }
  }

  bool _ordersAreEqual(List<Order> orders1, List<Order> orders2) {
    if (orders1.length != orders2.length) return false;
    for (int i = 0; i < orders1.length; i++) {
      if (orders1[i].id != orders2[i].id) return false;
    }
    return true;
  }

  void _showOrderScreenDialog(String tableId) {
    // Faqat o'z ofitsiantining stollarida yangi hisob ochishga ruxsat
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
// Mavjud buyurtmadan formatted_order_number ni olish
    String? formattedOrderNumber = _selectedTableOrders.isNotEmpty
        ? _selectedTableOrders.first.formatted_order_number
        : '';

    print("Formatted order number: $formattedOrderNumber"); // Debugging uchun

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          child: OrderScreenContent(
            formatted_order_number: formattedOrderNumber, // YANGI qo'shildi
            tableId: tableId,
            tableName: _selectedTableName,
            user: widget.user,
            onOrderCreated: () {
              _fetchOrdersForTable(tableId);
              _checkTableStatuses();
            },
            token: widget.token,
          ),
        );
      },
    );
  }
  // Zakaz controller

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

  Future<void>  _closeOrder(Order order) async {
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
        // Cache'dan ham olib tashlash
        if (_ordersCache.containsKey(_selectedTableId!)) {
          _ordersCache[_selectedTableId!]!.removeWhere((o) => o.id == order.id);
        }

        setState(() {
          _selectedTableOrders.removeWhere((o) => o.id == order.id);
        });

        // Darhol status yangilash
        Future.microtask(() => _checkTableStatuses());

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
    "Noto‘g‘ri tayyorlangan",
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
    String reason = reasons[0];  // Default sabab
    String notes = "ixtiyor";    // API uchun izoh
    int cancelQuantity = 1;      // Default miqdor
    final item = order.items[itemIndex];
    final TextEditingController quantityController = TextEditingController(text: "1");

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
                    items: reasons.map((String r) {
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
                          (context) =>
                          OrderTablePage(waiterName: widget.user.firstName, token: widget.token,),
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
      height: 44,
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

    if (isOccupied && !isOwnTable) {
      cardColor = AppColors.error.withOpacity(0.1);
      textColor = AppColors.error;
      statusText = "Boshqa ofitsiant";
    } else if (isOccupied && isOwnTable) {
      cardColor = AppColors.accent.withOpacity(0.1);
      textColor = AppColors.accent;
      statusText = "Mening stolim";
    } else if (isSelected) {
      cardColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green;
      statusText = "Tanlangan";
    } else {
      cardColor = AppColors.lightGrey;
      textColor = AppColors.grey;
      statusText = "Bo'sh";
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
          isOccupied && !isOwnTable
              ? AppColors.error
              : isOccupied && isOwnTable
              ? AppColors.accent
              : isSelected
              ? Colors.green
              : AppColors.lightGrey,
          width: 2,
        ),
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
              "${table.number}",
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
      child:
      _selectedTableId == null
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale, size: 64, color: AppColors.grey),
            SizedBox(height: 16),
            Text(
              "Stolni tanlang",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.grey),
            ),
          ],
        ),
      )
          : Column(
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
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: AppColors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "$_selectedTableName",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                    (_tableOwners[_selectedTableId] ==
                        widget.user.id)
                        ? AppColors.accent
                        : AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (_tableOwners[_selectedTableId] == widget.user.id)
                        ? 'Mening'
                        : 'Boshqa',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:
              _isLoadingOrders
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
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
                Text("${order.formatted_order_number}", style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                ),),
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

  // Mahsulot qo'shish dialogini ko'rsatish metodi
  void _showAddItemsDialog(Order order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          child: OrderScreenContent(
            formatted_order_number: order.formatted_order_number, // YANGI qo'shildi
            tableId: order.tableId,
            tableName: _selectedTableName,
            user: widget.user,
            token: widget.token,
            isAddingToExistingOrder: true, // YANGI parametr
            existingOrderId: order.id, // YANGI parametr
            onOrderCreated: () {
              // Zakazlar ro'yxatini yangilash
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

class OrderScreenContent extends StatefulWidget {
  final User user;
  final String? tableId;
  final VoidCallback? onOrderCreated;
  final String? tableName;
  final token;
  final bool isAddingToExistingOrder; // YANGI
  final String? existingOrderId; // YANGI
  final String formatted_order_number;

  const OrderScreenContent({
    super.key,
    this.tableId,
    required this.user,
    this.onOrderCreated,
    this.tableName,
    required this.token,
    this.isAddingToExistingOrder = false, // YANGI
    this.existingOrderId, // YANGI
    required this.formatted_order_number, // YANGI
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
  String? _token;
  bool _isSubmitting = false;
  String _searchQuery = ''; // Qidirish so'rovi uchun o'zgaruvchi

  final Map<String, int> _cart = {};
  final NumberFormat _currencyFormatter = NumberFormat('#,##0', 'uz_UZ');

  static List<Category>? _cachedCategories;
  static List<Ovqat>? _cachedProducts;
  static DateTime? _lastCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _initializeTokenAsync();
    await _loadDataFast();
  }

  void _initializeTokenAsync() async {
    try {
      _token = await AuthService.getToken();
      if (_token == null) {
        await AuthService.loginAndPrintToken();
        _token = await AuthService.getToken();
      }
    } catch (e) {
      debugPrint("Token error: $e");
    }
  }

  bool _isCacheValid() {
    return _cachedCategories != null &&
        _cachedProducts != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheExpiry;
  }

  Future<void> _loadDataFast() async {
    try {
      setState(() => _isLoading = true);

      if (_isCacheValid()) {
        _categories = _cachedCategories!;
        _allProducts = _cachedProducts!;
        setState(() => _isLoading = false);
        return;
      }

      String baseUrl = "${ApiConfig.baseUrl}";

      Future<List<Ovqat>> fetchProducts() async {
        final url = Uri.parse("$baseUrl/foods/list");

        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
        );

        if (response.statusCode == 200) {
          final dynamic decoded = json.decode(response.body);
          print("🔍 Mahsulotlar decoded turi: ${decoded.runtimeType}");

          if (decoded is Map<String, dynamic>) {
            final data =
                decoded['foods'] ??
                    decoded['data'] ??
                    decoded['products'] ??
                    decoded;
            if (data is List) {
              return data.map((e) => Ovqat.fromJson(e)).toList();
            } else {
              throw Exception("API javobida mahsulotlar ro'yxati topilmadi");
            }
          } else if (decoded is List) {
            return decoded.map((e) => Ovqat.fromJson(e)).toList();
          } else {
            throw Exception("API javobi noto'g'ri formatda");
          }
        } else {
          throw Exception(
            "Mahsulotlar olishda xatolik: ${response.statusCode}",
          );
        }
      }

      Future<List<Category>> fetchCategories() async {
        final url = Uri.parse("$baseUrl/categories/list");

        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
        );

        if (response.statusCode == 200) {
          final dynamic decoded = json.decode(response.body);
          print("🔍 decoded turi: ${decoded.runtimeType}");

          if (decoded is Map<String, dynamic>) {
            final data = decoded['categories'] ?? decoded['data'] ?? decoded;
            if (data is List) {
              return data.map((e) => Category.fromJson(e)).toList();
            } else {
              throw Exception("API javobida kategoriyalar ro'yxati topilmadi");
            }
          } else if (decoded is List) {
            return decoded.map((e) => Category.fromJson(e)).toList();
          } else {
            throw Exception("API javobi noto'g'ri formatda");
          }
        } else {
          throw Exception("Kategoriya olishda xatolik: ${response.statusCode}");
        }
      }

      final futures = await Future.wait([
        fetchCategories().timeout(Duration(seconds: 3)),
        fetchProducts().timeout(Duration(seconds: 3)),
      ]).timeout(Duration(seconds: 5));

      _cachedCategories = futures[0] as List<Category>;
      _cachedProducts = futures[1] as List<Ovqat>;
      _lastCacheTime = DateTime.now();

      if (mounted) {
        setState(() {
          _categories = _cachedCategories!;
          _allProducts = _cachedProducts!;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterProductsByCategory() {
    List<Ovqat> filtered = _allProducts;

    // Agar qidiruv so'rovi bo'sh bo'lsa
    if (_searchQuery.isEmpty) {
      if (_selectedCategoryId == null) {
        // Hech narsa tanlanmagan - barcha mahsulotlar
        setState(() {
          _filteredProducts = _allProducts;
        });
        return;
      } else {
        // Faqat kategoriya tanlangan
        filtered = _allProducts.where((product) {
          if (product.categoryId != _selectedCategoryId) return false;

          // Agar subkategoriya tanlangan bo'lsa
          if (_selectedSubcategory != null && _selectedSubcategory!.isNotEmpty) {
            return product.subcategory?.toLowerCase() == _selectedSubcategory!.toLowerCase();
          }

          return true;
        }).toList();
      }
    } else {
      // Qidiruv so'rovi mavjud
      final query = _searchQuery.toLowerCase();

      // 1️⃣ Avval kategoriya/subkategoriya avtomatik tanlash
      if (_selectedCategoryId == null) {
        Category? matchedCategory;
        String? matchedSubcategory;

        // Subkategoriya nomi bo'yicha qidirish
        for (final category in _categories) {
          for (final sub in category.subcategories) {
            if (sub.toLowerCase().contains(query)) {
              matchedCategory = category;
              matchedSubcategory = sub;
              break;
            }
          }
          if (matchedCategory != null) break;
        }

        // Agar subkategoriya topilmasa, kategoriya nomi bo'yicha qidirish
        if (matchedCategory == null) {
          for (final category in _categories) {
            if (category.title.toLowerCase().contains(query)) {
              matchedCategory = category;
              break;
            }
          }
        }

        // Topilgan kategoriyani tanlash
        if (matchedCategory != null) {
          _selectedCategoryId = matchedCategory.id;
          _selectedCategoryName = matchedCategory.title;
          _selectedSubcategory = matchedSubcategory;
        }
      }

      // 2️⃣ Kategoriya bo'yicha filterlash
      if (_selectedCategoryId != null) {
        filtered = filtered.where((product) {
          return product.categoryId == _selectedCategoryId;
        }).toList();
      }

      // 3️⃣ Subkategoriya bo'yicha filterlash
      if (_selectedSubcategory != null && _selectedSubcategory!.isNotEmpty) {
        filtered = filtered.where((product) {
          final productSub = product.subcategory?.toLowerCase() ?? '';
          final selectedSub = _selectedSubcategory!.toLowerCase();

          // To'liq mos kelishi yoki qidiruv so'rovi bilan mos kelishi
          return productSub == selectedSub ||
              productSub.contains(query) ||
              product.name.toLowerCase().contains(selectedSub);
        }).toList();
      }

      // 4️⃣ Mahsulot nomi bo'yicha qo'shimcha filterlash
      filtered = filtered.where((product) {
        final productName = product.name.toLowerCase();
        final productSub = product.subcategory?.toLowerCase() ?? '';

        return productName.contains(query) || productSub.contains(query);
      }).toList();
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

  void _updateCart(String productId, int change) {
    setState(() {
      final currentQty = _cart[productId] ?? 0;
      final newQty = currentQty + change;

      if (newQty <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = newQty;
      }
    });
  }

  double _calculateTotal() {
    double total = 0;
    for (final entry in _cart.entries) {
      final product = _allProducts.cast<Ovqat?>().firstWhere(
            (p) => p?.id == entry.key,
        orElse: () => null,
      );
      if (product != null) {
        total += product.price * entry.value;
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
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          _sendOrderInBackground();
          showCenterSnackBar(
            context,
            'Zakaz qabul qilindi!',
            color: Colors.green,
          );
          widget.onOrderCreated?.call();
          Navigator.of(context).pop();
        }
      });
    } finally {
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      });
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

  Future<void> _sendOrderInBackground() async {
    try {
      if (_token == null) {
        _token = await AuthService.getToken();
        if (_token == null) {
          await AuthService.loginAndPrintToken();
          _token = await AuthService.getToken();
        }
      }

      final orderItems =
      _cart.entries
          .map((e) => {'food_id': e.key, 'quantity': e.value})
          .toList();

      final orderData = {
        'table_id': widget.tableId,
        'user_id': widget.user.id,
        'first_name': widget.user.firstName ?? 'Noma\'lum',
        'items': orderItems,
        'total_price': _calculateTotal(),
      };

      debugPrint('Zakaz yuborilmoqda: $orderData');

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/orders/create"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(orderData),
      );
      print('Server body: ${response.body}');

      Map<String, dynamic> responseData;

      try {
        responseData = jsonDecode(response.body);
      } catch (_) {
        print("❗ JSON emas, fallback ma'lumot ishlatilyapti.");
        responseData = {
          'order': {
            'order_number': DateTime.now().millisecondsSinceEpoch
                .toString()
                .substring(8),
          },
          'printing': {
            'results': [],
          },
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Zakaz muvaffaqiyatli yaratildi');
      } else {
        print('Zakaz yaratishda xatolik: ${response.statusCode}');
      }

      await _printOrderAsync(responseData);
    } catch (e) {
      print('Background order failed: $e');
    }
  }

  Future<void> _printOrderAsync(Map<String, dynamic> responseData) async {
    try {
      debugPrint('🖨️ Print jarayoni boshlandi');

      final Map<String, List<Map<String, dynamic>>> printerGroups = {};

      for (final entry in _cart.entries) {
        final product = _findProductById(entry.key);
        if (product != null) {
          final category = _categories.firstWhere(
                (cat) => cat.id == product.categoryId,
            orElse: () => Category(
              id: '',
              title: '',
              subcategories: [],
              printerName: '',
              printerIp: '',
            ),
          );

          print(
            '📦 Mahsulot: ${product.name} -> Kategoriya: ${category.title} -> Printer IP: ${category.printerIp}',
          );

          if (category.printerIp.isNotEmpty && category.printerIp != 'null') {
            if (!printerGroups.containsKey(category.printerIp)) {
              printerGroups[category.printerIp] = [];
            }

            printerGroups[category.printerIp]!.add({
              'name': product.name,
              'qty': entry.value,
              'category': category.title,
            });
          }
        }
      }

      print('🖨️ Printer guruhlari: ${printerGroups.keys.toList()}');

      if (printerGroups.isEmpty) {
        print(
          '⚠️ Kategoriya printerlari topilmadi, server printerlarini tekshiryapman...',
        );

        final printers = responseData['printing']?['results'] as List?;
        if (printers != null && printers.isNotEmpty) {
          final serverPrinterIp =
          printers.first['printer_ip']?.toString()?.trim();
          if (serverPrinterIp != null &&
              serverPrinterIp.isNotEmpty &&
              serverPrinterIp != 'null') {
            printerGroups[serverPrinterIp] =
                _cart.entries.map((e) {
                  final product = _findProductById(e.key);
                  return {
                    'name': product?.name ?? 'Unknown',
                    'qty': e.value,
                    'category': 'Umumiy',
                  };
                }).toList();
          }
        }
      }

      if (printerGroups.isEmpty) {
        debugPrint('❌ Hech qanday printer topilmadi');
        return;
      }

      final printFutures =
      printerGroups.entries.map((group) {
        final printerIp = group.key;
        final items = group.value;

        final printData = {
          'orderNumber':
          responseData['order']?['orderNumber']?.toString() ?? '',
          'waiter_name': widget.user.firstName ?? 'Noma\'lum',
          'table_name': widget.tableName ?? 'N/A',
          'items': items,
        };

        final printBytes = _createPrintData(printData);
        return _printToSocket(printerIp, printBytes);
      }).toList();

      await Future.wait(printFutures, eagerError: false);

      debugPrint('✅ ${printerGroups.length} ta printerga yuborildi');
    } catch (e) {
      print('❌ Print error: $e');
    }
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

      final socket = await Socket.connect(ip, 9100);

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
    final orderNum = data['order_number'];
    final waiter = data['waiter_name'];
    final table = data['table_name'];

    bytes.addAll(_encodeText('ZAKAZ : ${widget.formatted_order_number} \r\n'));
    bytes.addAll(_encodeText('Ofitsiant: $waiter\r\n'));
    bytes.addAll(_encodeText('Stol: $table\r\n'));
    bytes.addAll(
      _encodeText('${DateTime.now().toString().substring(11, 16)}\r\n'),
    );
    bytes.addAll(_encodeText('=' * 25 + '\r\n'));

    final header = 'Nomi'.padRight(20) + 'Soni';
    bytes.addAll([0x1B, 0x61, 1]); // Markaz
    bytes.addAll(_encodeText(header + '\r\n'));
    bytes.addAll(_encodeText('-' * 25 + '\r\n'));

    for (final item in data['items']) {
      final name = item['name'].toString();
      final qty = item['qty'].toString();
      final line = name.padRight(20) + qty;
      bytes.addAll([0x1B, 0x61, 1]); // Markaz
      bytes.addAll(_encodeText(line + '\r\n'));
    }

    bytes.addAll(_encodeText('=' * 25 + '\r\n\r\n\r\n\r\n\r\n'));
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

  Widget _buildAppBar(bool isDesktop)   {
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
            child: _isLoading
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
                      color: _selectedCategoryId == category.id
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
                    onTap: () => _selectCategory(
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
          if (selectedCategory.subcategories != null &&
              selectedCategory.subcategories.isNotEmpty)
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
                        ...selectedCategory.subcategories
                            .map(
                              (sub) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildSubcategoryChip(sub, sub),
                          ),
                        )
                            .toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoading
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
    final int quantityInCart = _cart[product.id] ?? 0;
    final double totalPrice = product.price * quantityInCart;

    return LayoutBuilder(
      builder: (context, constraints) {
        double maxCardWidth = isDesktop ? 220 : constraints.maxWidth * 0.5;

        return GestureDetector(
          onTap: () => _updateCart(product.id, 1),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxCardWidth,
              maxHeight: 180,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF144D37),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: quantityInCart > 0 ? Colors.white : Colors.grey[400]!,
                width: quantityInCart > 0 ? 2 : 1,
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
                    '${_currencyFormatter.format(product.price)} so\'m',
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
                    if (quantityInCart > 0) ...[
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
                    ],
                    GestureDetector(
                      onTap: () => _updateCart(product.id, 1),
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
                  ],
                ),
                if (quantityInCart > 0)
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
              icon: _isSubmitting
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

  Future<void> _sendAddItemsInBackground() async {
    try {
      final orderItems =
      _cart.entries
          .map((e) => {'food_id': e.key, 'quantity': e.value})
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        await _printAddedItemsOptimized(responseData);
      }
    } catch (e) {
      print('Background add items error: $e');
    }
  }

  Future<void> _printAddedItemsOptimized(
      Map<String, dynamic> responseData,
      ) async {
    try {
      debugPrint('🖨️ Optimallashtirilgan print jarayoni');

      final Map<String, List<Map<String, dynamic>>> printerGroups = {};

      for (final entry in _cart.entries) {
        final product = _findProductById(entry.key);
        if (product != null) {
          final category = _categories.firstWhere(
                (cat) => cat.id == product.categoryId,
            orElse: () => Category(
              id: '',
              title: '',
              subcategories: [],
              printerName: '',
              printerIp: '',
            ),
          );

          if (category.printerIp.isNotEmpty && category.printerIp != 'null') {
            if (!printerGroups.containsKey(category.printerIp)) {
              printerGroups[category.printerIp] = [];
            }

            printerGroups[category.printerIp]!.add({
              'name': product.name,
              'qty': entry.value,
              'category': category.title,
            });
          }
        }
      }

      debugPrint('🎯 Faqat ${printerGroups.length} ta printerga yuboriladi');

      final printFutures =
      printerGroups.entries.map((group) {
        final printData = {
          'orderNumber': widget.existingOrderId?.substring(0, 8) ?? '',
          'waiter_name': widget.user.firstName ?? 'Noma\'lum',
          'table_name': widget.tableName ?? 'N/A',
          'items': group.value,
          'isAddition': true,
        };

        final printBytes = _createPrintDataForAddition(printData);
        return _printToSocket(group.key, printBytes).timeout(
          Duration(seconds: 2),
          onTimeout: () {
            debugPrint('⚠️ Printer timeout: ${group.key}');
          },
        );
      }).toList();

      await Future.wait(printFutures, eagerError: false);
    } catch (e) {
      print('❌ Optimized print error: $e');
    }
  }

  List<int> _createPrintDataForAddition(Map<String, dynamic> data) {
    final bytes = <int>[];
    const printerWidth = 32;

    bytes.addAll([0x1B, 0x40]); // Reset
    bytes.addAll([0x1B, 0x74, 17]); // CP866

    bytes.addAll([0x1B, 0x61, 1]); // Center alignment
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
      final line = '$name $qty';

      final lineBytes = _encodeText(line);
      final padding = (printerWidth - lineBytes.length) ~/ 2;
      if (padding > 0) {
        bytes.addAll(_encodeText(' ' * padding + line + '\r\n'));
      } else {
        final nameBytes = _encodeText(name);
        final qtyBytes = _encodeText(qty);
        final maxNameBytes = printerWidth - qtyBytes.length - 1;

        if (nameBytes.length <= maxNameBytes) {
          bytes.addAll(
            _encodeText(name.padRight(maxNameBytes) + ' ' + qty + '\r\n'),
          );
        } else {
          int start = 0;
          while (start < nameBytes.length) {
            final end = (start + printerWidth > nameBytes.length)
                ? nameBytes.length
                : start + printerWidth;
            final chunk = nameBytes.sublist(start, end);
            final chunkPadding = (printerWidth - chunk.length) ~/ 2;
            if (chunkPadding > 0) {
              bytes.addAll(_encodeText(' ' * chunkPadding));
            }
            bytes.addAll(chunk);
            bytes.addAll(_encodeText('\r\n'));
            start = end;
          }
          final qtyPadding = (printerWidth - qtyBytes.length) ~/ 2;
          if (qtyPadding > 0) {
            bytes.addAll(_encodeText(' ' * qtyPadding + qty + '\r\n'));
          } else {
            bytes.addAll(_encodeText(qty + '\r\n'));
          }
        }
      }
    }

    bytes.addAll(_encodeText('=' * printerWidth + '\r\n'));
    bytes.addAll(_encodeText('\r\n\r\n\r\n\r\n\r\n'));
    bytes.addAll([0x1D, 0x56, 0]); // Cut

    return bytes;
  }

  static void clearCache() {
    _cachedCategories = null;
    _cachedProducts = null;
    _lastCacheTime = null;
  }
}
