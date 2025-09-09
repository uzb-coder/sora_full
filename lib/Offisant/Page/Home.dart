import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'dart:io';
import 'dart:async';
import '../../DB/Servis/category_local_service.dart';
import '../../DB/Servis/db_helper.dart';
import '../../DB/Servis/food_local_service.dart';
import '../../DB/Servis/hall_local_service.dart';
import '../../DB/Servis/table_local_service.dart';
import '../../Global/Api_global.dart';
import '../Controller/TokenCOntroller.dart';
import '../Controller/usersCOntroller.dart';
import '../Model/Ovqat_model.dart';
import 'Categorya_page.dart';
import 'Ranglar.dart';
import 'Yopilgan_zakaz_page.dart';

class Order {
  final String id;
  final String tableId;
  final String userId;
  final String firstName;
  final List<OrderItem> items;
  final num totalPrice;
  final String status;
  final String createdAt;
  final String formatted_order_number;
  final int isSynced; // 🔹 qo‘shildi
  bool isProcessing;

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
    this.isSynced = 0,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: (json['_id'] ?? json['id']).toString(),
      tableId: (json['table_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      firstName: (json['waiter_name'] ?? '').toString(),
      items: [],
      totalPrice: num.tryParse(json['total_price'].toString()) ?? 0,
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
      formatted_order_number: json['formatted_order_number'] ?? '',
      isSynced: json['is_synced'] ?? 0,
    );
  }
}

class OrderItem {
  final String foodId;
  final String? name;
  final num quantity;
  final num? price; // double/int ikkalasini qamrab oladi
  final String? categoryName;

  OrderItem({
    required this.foodId,
    required this.quantity,
    this.name,
    this.price,
    this.categoryName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // ⚙️ Serverdan turli nomlarda kelishi mumkin, bularni qamrab olamiz:
    final foodObj =
        json['food'] is Map<String, dynamic>
            ? (json['food'] as Map<String, dynamic>)
            : null;

    final String id =
        (json['food_id'] ??
                json['foodId'] ??
                foodObj?['_id'] ??
                foodObj?['id'] ??
                '')
            .toString();

    final String? itemName =
        (json['name'] ??
                json['food_name'] ??
                json['title'] ??
                foodObj?['name'] ??
                foodObj?['title'])
            ?.toString();

    // quantity ham har xil nomda kelishi mumkin
    final num qty =
        (json['quantity'] ?? json['qty'] ?? json['amount'] ?? 0) is num
            ? (json['quantity'] ?? json['qty'] ?? json['amount'] ?? 0) as num
            : num.tryParse(
                  (json['quantity'] ?? json['qty'] ?? json['amount'] ?? '0')
                      .toString(),
                ) ??
                0;

    // narx uchun ehtimoliy maydonlar
    final dynamic p =
        json['price'] ??
        json['unit_price'] ??
        json['unitPrice'] ??
        json['selling_price'] ??
        json['sell_price'] ??
        json['price_per_unit'];

    final num? parsedPrice =
        p == null ? null : (p is num ? p : num.tryParse(p.toString()));

    final String? catName =
        (json['category_name'] ??
                json['categoryName'] ??
                foodObj?['category_name'] ??
                foodObj?['category'] ??
                json['category'] ??
                json['cat'])
            ?.toString();

    return OrderItem(
      foodId: id,
      name: itemName,
      quantity: qty,
      price: parsedPrice,
      categoryName: catName,
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

class TableModel {
  final String id;
  final String name;
  final String status;
  final int guestCount;
  final int capacity;

  TableModel({
    required this.id,
    required this.name,
    required this.status,
    required this.guestCount,
    required this.capacity,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      guestCount: json['guest_count'] ?? 0,
      capacity: json['capacity'] ?? 0,
    );
  }
}

class HallModel {
  final String id;
  final String name;
  final List<TableModel> tables;

  HallModel({required this.id, required this.name, required this.tables});

  factory HallModel.fromJson(Map<String, dynamic> json) {
    return HallModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      tables:
          (json['tables'] as List? ?? [])
              .map((t) => TableModel.fromJson(t))
              .toList(),
    );
  }
}

class HallController {
  static const String baseUrl = ApiConfig.baseUrl;
  static Timer? _syncTimer;

  /// 🔑 Sozlamalar uchun kalitlar
  static const _kLastSyncKey = 'halls_last_sync';

  /// 🧠 Localdan qaytaradi, serverga umuman chiqmaydi
  static Future<List<HallModel>> getHalls(String token) async {
    final localHalls = await HallLocalService.getHalls();
    final localTables = await TableLocalService.getTables();

    if (localHalls.isNotEmpty) {
      print("📦 Localdan ${localHalls.length} hall olindi");
    } else {
      print("📦 Local bo'sh: 0 hall");
    }

    final hallsFromLocal =
        localHalls.map((h) {
          final tables =
              localTables
                  .where((t) => t['hall_id'] == h['id'])
                  .map(
                    (t) => TableModel(
                      id: t['id'] as String,
                      name: t['name'] as String,
                      status: t['status'] as String,
                      guestCount: (t['guest_count'] ?? 0) as int,
                      capacity: (t['capacity'] ?? 0) as int,
                    ),
                  )
                  .toList();

          return HallModel(
            id: h['id'] as String,
            name: h['name'] as String,
            tables: tables,
          );
        }).toList();

    // ❌ Serverga chiqish bu yerda yo‘q
    return hallsFromLocal;
  }

  /// ⏱ Har 1 soatda sync — dastur ochilganda darhol so‘rov yubormaydi.
  /// ⚠️ Agar local bo‘sh bo‘lsa, bir marta sync qilib beradi (birinchi ishga tushirishda).
  static Future<void> startAutoSync(String token) async {
    _syncTimer?.cancel();

    // 1) Birinchi marotaba ishga tushishda local bo‘sh bo‘lsa — bir marta sync
    final localHalls = await HallLocalService.getHalls();
    if (localHalls.isEmpty) {
      print(
        "🚀 Birinchi ishga tushirish: local bo‘sh, bir marta SYNC qilinadi",
      );
      await _syncFromServer(token);
    } else {
      print(
        "⏳ Dastur ochildi: darhol so‘rov yuborilmaydi, 1 soatdan keyin SYNC boshlanadi",
      );
    }

    // 2) Keyingi synclar: har 1 soatda
    _syncTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      await _syncFromServer(token);
      print("🔄 Avtomatik hall/stol SYNC bajarildi");
    });
  }

  /// ⛔ Sync timer tozalash
  static void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// 🔄 Serverdan olib localni yangilash (ichki funksya)
  static Future<void> _syncFromServer(String token) async {
    print("🌍 [SYNC] Serverdan halls/list so‘rov yuborildi...");
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/halls/list"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("🌍 [SYNC] Javob status: ${response.statusCode}");

      if (response.statusCode == 200) {
        print("🌍 [SYNC] JSON decode boshlanmoqda...");
        final List<dynamic> jsonList = json.decode(response.body);
        print("🌍 [SYNC] ${jsonList.length} ta hall serverdan olindi");

        final hallsForLocal = <Map<String, dynamic>>[];
        final tablesForLocal = <Map<String, dynamic>>[];

        for (var hall in jsonList) {
          hallsForLocal.add({
            'id': hall['_id'] ?? '',
            'name': hall['name'] ?? '',
          });

          final hallTables = hall['tables'] as List? ?? [];
          print("➡️ Hall: ${hall['name']} → ${hallTables.length} stol");

          for (var t in hallTables) {
            tablesForLocal.add({
              'id': t['_id'] ?? '',
              'hall_id': hall['_id'] ?? '',
              'name': t['name'] ?? '',
              'status': t['status'] ?? '',
              'guest_count': t['guest_count'] ?? 0,
              'capacity': t['capacity'] ?? 0,
              'is_active': t['is_active'] == true ? 1 : 0,
              'created_at': t['createdAt'] ?? '',
              'updated_at': t['updatedAt'] ?? '',
              'number': t['number'] ?? '',
              'v': t['__v'] ?? 0,
              'display_name': t['display_name'] ?? '',
            });
          }
        }

        print("💾 Localni tozalash...");
        await HallLocalService.clearHalls();
        await TableLocalService.clearTables();

        print("💾 Localga halls yozilmoqda: ${hallsForLocal.length}");
        await HallLocalService.upsertHalls(hallsForLocal);

        print("💾 Localga tables yozilmoqda: ${tablesForLocal.length}");
        await TableLocalService.upsertTables(tablesForLocal);

        // 🕒 Oxirgi sync vaqtini saqlash
        await _setLastSync(DateTime.now());

        print(
          "✅ [SYNC] ${hallsForLocal.length} hall va ${tablesForLocal.length} stol localga saqlandi",
        );
      } else {
        print(
          "⚠️ [SYNC] Server xatolik: ${response.statusCode}, body: ${response.body}",
        );
      }
    } catch (e) {
      print("⚠️ [SYNC] Xatolik: $e");
    }
  }

  /// 📌 Qo‘lda sync qilish uchun (masalan: “Yangilash” tugmasi)
  static Future<void> forceSync(String token) async {
    await _syncFromServer(token);
  }

  static Future<void> _setLastSync(DateTime dt) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLastSyncKey, dt.toIso8601String());
  }

  static Future<DateTime?> getLastSync() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kLastSyncKey);
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
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
  Map<String, bool> _tableOccupiedStatus = {};
  Map<String, String> _tableOwners = {};
  Map<String, List<Order>> _ordersCache = {}; // Zakazlar keshi
  bool _isLoadingTables = false;
  List<HallModel> _halls = [];
  String? _selectedHallId;

  // Yangi o'zgaruvchilar qo'shildi
  List<Ovqat> _allProducts = [];
  List<Category> _categories = [];
  bool _isLoadingProducts = false;
  Timer? _syncTimer; // 🔹 qo‘shib qo‘ying

  @override
  void initState() {
    super.initState();
    _initializeToken();
    _startRealTimeUpdates();
    _loadProductsAndCategories();

    // 1️⃣ Halls’ni darhol yuklash
    _loadHalls();

    // 2️⃣ Har 1 soatda serverdan sync qilish
    HallController.startAutoSync(widget.token);
    // 🔄 Har daqiqada stol ko‘chirish sync
    Timer.periodic(const Duration(minutes: 1), (_) {
      if (_token != null) {
        syncMovedOrders(_token!);
      }
    });

    // 🔄 Har 30 sekundda yopilgan orderlarni sync qilish
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_token != null) {
        _syncClosedOrders(_token!);
      }
    });
  }

  Future<void> _loadHalls() async {
    final halls = await HallController.getHalls(widget.token);
    if (!mounted) return; // 🔑 qo‘shing
    setState(() {
      _halls = halls;
    });
  }

  @override
  void dispose() {
    HallController.stopAutoSync();
    _realTimeTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialHalls() async {
    if (mounted) setState(() => _isLoadingTables = true);

    try {
      final halls = await fetchHalls();
      if (mounted) {
        setState(() {
          _halls = halls;
          _isLoadingTables = false;
        });
        _checkTableStatuses();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTables = false);
      print("Halls loading error: $e");
    }
  }

  Future<List<HallModel>> fetchHalls() async {
    final url = Uri.parse("${ApiConfig.baseUrl}/halls/list");
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> hallsJson = json.decode(response.body);
      return hallsJson.map((json) => HallModel.fromJson(json)).toList();
    } else {
      throw Exception("Hallarni olishda xatolik: ${response.statusCode}");
    }
  }

  List<TableModel> _getSelectedHallTables() {
    if (_selectedHallId == null) return [];
    final selectedHall = _halls.firstWhere(
      (hall) => hall.id == _selectedHallId,
      orElse: () => HallModel(id: '', name: '', tables: []),
    );
    return selectedHall.tables;
  }

  Future<void> _fetchOrdersForTable(String tableId) async {
    try {
      final rows = await DBHelper.getOrdersByTable(tableId);

      final orders =
          rows.map((e) {
              // 🟢 itemsni xavfsiz parse qilish
              final List<dynamic> itemsRaw = (e['items'] as List?) ?? [];

              final items =
                  itemsRaw.map((raw) {
                    final map =
                        (raw is Map<String, dynamic>)
                            ? raw
                            : Map<String, dynamic>.from(raw as Map);

                    return OrderItem(
                      foodId: map['food_id']?.toString() ?? '',
                      name: map['name']?.toString(),
                      quantity:
                          (map['quantity'] is num
                              ? map['quantity']
                              : num.tryParse(
                                map['quantity']?.toString() ?? '0',
                              )) ??
                          0,
                      price:
                          (map['price'] is num
                              ? map['price']
                              : num.tryParse(
                                map['price']?.toString() ?? '0',
                              )) ??
                          0,
                      categoryName: map['category_name']?.toString(),
                    );
                  }).toList();

              // 🧮 Jami hisoblash
              final num calcTotal = items.fold<num>(
                0,
                (sum, it) => sum + (it.quantity * (it.price ?? 0)),
              );

              final num dbTotal =
                  (e['total_price'] is num)
                      ? e['total_price'] as num
                      : num.tryParse(e['total_price']?.toString() ?? '0') ?? 0;

              final num displayTotal = (dbTotal > 0) ? dbTotal : calcTotal;

              return Order(
                id: e['id'].toString(),
                tableId: e['table_id']?.toString() ?? '',
                userId: e['user_id']?.toString() ?? '',
                firstName: e['waiter_name']?.toString() ?? '',
                items: items,
                totalPrice: displayTotal,
                status: (e['status'] ?? 'pending').toString(),
                createdAt: e['created_at']?.toString() ?? '',
                formatted_order_number:
                    e['formatted_order_number']?.toString() ?? '',
                isSynced: e['is_synced'] as int? ?? 0,
              );
            }).toList()
            ..removeWhere((o) => o.status != 'pending'); // faqat ochiq orderlar

      if (mounted) {
        setState(() {
          _selectedTableOrders = List.from(orders); // 🔑 majburiy refresh
          _isLoadingOrders = false;
        });

        print(
          "✅ UI yangilandi: ${orders.length} ta order, items: ${orders.map((o) => o.items.map((i) => "${i.name} x${i.quantity}").join(", ")).join("; ")}",
        );
      }

      // Local statuslarni yangilash
      await _updateLocalTableStatuses();
    } catch (e, stack) {
      print("❌ Order olish xatoligi: $e\n🔍 Stack: $stack");
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _moveOrderToTable(String orderId, String newTableId) async {
    print("➡️ [START] _moveOrderToTable chaqirildi");
    print("   orderId: $orderId");
    print("   newTableId: $newTableId");

    try {
      // 🔹 Avval local DB yangilaymiz
      print("💾 Local DB da orderni yangilashga urinyapman...");
      await DBHelper.moveOrderLocal(orderId, newTableId);
      print(
        "✅ Local DB: Zakaz $orderId yangi stolga ko‘chirildi ($newTableId)",
      );

      // 🔄 UI yangilash
      _ordersCache.remove(orderId);
      await _fetchOrdersForTable(newTableId);
      await _checkTableStatusesRealTime();
      await _updateLocalTableStatuses();

      // 🔍 Orderni olish
      final orderRows = await DBHelper.getOrdersByTable(newTableId);
      final order = orderRows.firstWhere(
        (o) => o['id'].toString() == orderId,
        orElse: () => {},
      );

      final serverId = order['server_id'];

      if (serverId == null || serverId.toString().isEmpty) {
        print(
          "⏸ Serverga yuborilmadi: order hali sync qilinmagan (faqat localda ko‘chirildi).",
        );
        return;
      }

      // 🔑 Active tokenni olish
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("active_token");
      print("🟢 Active token: $token");

      if (token == null || token.isEmpty) {
        print("❌ Active token mavjud emas, serverga yuborilmadi");
        return;
      }

      if (JwtDecoder.isExpired(token)) {
        print("⚠️ Token eskirgan, foydalanuvchi qayta login qilishi kerak");
        return;
      }

      // 🌍 Serverga PUT yuborish
      print("🌍 Serverga PUT so‘rov yuborilmoqda...");
      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/orders/move-table"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "orderId": serverId, // 🔑 faqat serverId yuboriladi
          "newTableId": newTableId,
          "force": false,
        }),
      );

      print("🌍 Server javob status: ${response.statusCode}");
      print("🌍 Server javob body: ${response.body}");

      if (response.statusCode == 200) {
        print("✅ Zakaz $serverId serverga muvaffaqiyatli ko‘chirildi");
        await DBHelper.markOrderAsSynced(orderId); // Localni ham sync qilamiz
      } else if (response.statusCode == 401) {
        print(
          "❌ Token yaroqsiz yoki muddati o‘tgan. Foydalanuvchini qayta login qilish kerak.",
        );
      } else {
        print("⚠️ Server xatolik: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      print("❌ _moveOrderToTable error: $e");
    }
  }

  Future<void> syncMovedOrders(String s) async {
    try {
      final db = await DBHelper.database;

      // faqat stol ko‘chirilgan, hali sync qilinmagan orderlarni olish
      final unsyncedOrders = await db.query('orders', where: 'is_synced = 0');

      print("🔄 SyncMovedOrders: ${unsyncedOrders.length} ta order topildi");

      // 🔑 Active token olish
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("active_token");

      if (token == null || token.isEmpty) {
        print("❌ Active token mavjud emas, sync to‘xtatildi");
        return;
      }

      if (JwtDecoder.isExpired(token)) {
        print("⚠️ Token eskirgan, foydalanuvchi qayta login qilishi kerak");
        return;
      }

      for (final order in unsyncedOrders) {
        final localId = order['id'].toString();
        final newTableId = order['table_id'].toString();
        final serverId = order['server_id']; // 🔑 bu sync bo‘lganda keladi

        if (serverId == null || serverId.toString().isEmpty) {
          print("⏸ Order $localId hali serverda yaratilmagan, skip qilindi");
          continue;
        }

        print(
          "➡️ Serverga move-table yuborilmoqda: orderId=$serverId → $newTableId",
        );

        final response = await http.put(
          Uri.parse("${ApiConfig.baseUrl}/orders/move-table"),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "orderId": serverId, // 🔑 faqat serverId yuboriladi
            "newTableId": newTableId,
            "force": false,
          }),
        );

        print("🌍 Javob: ${response.statusCode} ${response.body}");

        if (response.statusCode == 200) {
          // agar muvaffaqiyatli bo‘lsa sync qilindi deb belgilaymiz
          await db.update(
            'orders',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [localId],
          );
          print("✅ Order $localId sync qilindi (serverId=$serverId)");
        } else if (response.statusCode == 401) {
          print("❌ Token yaroqsiz. Foydalanuvchini qayta login qilish kerak.");
          break;
        } else {
          print("⚠️ Order $localId sync qilinmadi, server xatolik");
        }
      }

      // Syncdan keyin local statuslarni yangilash
      await _updateLocalTableStatuses();
    } catch (e) {
      print("❌ syncMovedOrders xatolik: $e");
    }
  }

  _handleTableTap(String tableName, String tableId) {
    print("🖱️ Stol tanlandi: $tableName (ID: $tableId)");

    setState(() {
      _selectedTableName = tableName;
      _selectedTableId = tableId;
    });

    // 🔥 Endi localdan olish
    _fetchOrdersForTable(tableId);
  }

  void _startRealTimeUpdates() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      // Avval stol statuslarini tekshirish
      await _checkTableStatusesRealTime();

      // Local statuslarni yangilash
      await _updateLocalTableStatuses();

      // Agar stol tanlangan bo'lsa, orderlarni yangilash
      if (_selectedTableId != null) {
        await _fetchOrdersForTableSilently(_selectedTableId!);
      }
    });
  }

  Future<void> _updateLocalTableStatuses() async {
    try {
      final tableIds = _getSelectedHallTables().map((t) => t.id).toList();
      if (tableIds.isEmpty) return;

      final state = await DBHelper.getPendingStateByTables(tableIds);

      final occupiedMap = state['occupied'] as Map<String, String>? ?? {};
      final ownersMap = state['owners'] as Map<String, String>? ?? {};

      final newOccupied = <String, bool>{};
      for (final entry in occupiedMap.entries) {
        newOccupied[entry.key] = entry.value == 'true';
      }

      if (mounted) {
        bool statusChanged = !_mapsEqual(newOccupied, _tableOccupiedStatus);
        bool ownerChanged = !_mapsEqualString(ownersMap, _tableOwners);

        if (statusChanged || ownerChanged) {
          setState(() {
            _tableOccupiedStatus = newOccupied;
            _tableOwners = ownersMap;
          });
        }
      }
    } catch (e) {
      print("❌ Local table statuses update error: $e");
    }
  }

  Future<void> _checkTableStatusesRealTime() async {
    try {
      Map<String, bool> newStatus = {};
      Map<String, String> newOwners = {};

      // Parallel requests bilan barcha stollarni tekshirish (tezroq)
      final futures = _getSelectedHallTables().map((table) async {
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
    try {
      final rows = await DBHelper.getOrdersByTable(tableId);

      List<Order> localOrders =
          rows.map((e) {
            final List<Map<String, dynamic>> itemsRaw =
                (e['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

            final parsedItems =
                itemsRaw.map((i) {
                  return OrderItem(
                    foodId: i['food_id']?.toString() ?? '',
                    name: i['name']?.toString(),
                    quantity:
                        (i['quantity'] is num)
                            ? i['quantity'] as num
                            : num.tryParse(i['quantity']!.toString()) ?? 0,
                    price:
                        (i['price'] is num)
                            ? i['price'] as num
                            : num.tryParse(i['price']!.toString()),
                    categoryName: i['category_name']?.toString(),
                  );
                }).toList();

            // Jami hisoblab chiqish
            final num calcTotal = parsedItems.fold<num>(
              0,
              (s, it) => s + (it.quantity * (it.price ?? 0)),
            );

            final num dbTotal =
                (e['total_price'] is num)
                    ? e['total_price'] as num
                    : num.tryParse(e['total_price']!.toString()) ?? 0;

            final num displayTotal = (dbTotal > 0) ? dbTotal : calcTotal;

            return Order(
              id: e['id'].toString(),
              tableId: e['table_id']?.toString() ?? '',
              userId: e['user_id']?.toString() ?? '',
              firstName: e['waiter_name']?.toString() ?? '',
              items: parsedItems,
              totalPrice: displayTotal,
              status: (e['status'] ?? 'pending').toString(),
              createdAt: e['created_at']?.toString() ?? '',
              formatted_order_number:
                  e['formatted_order_number']?.toString() ?? '',
              isSynced: e['is_synced'] as int? ?? 0,
            );
          }).toList();

      localOrders = localOrders.where((o) => o.status == "pending").toList();

      // MAJBURIY yangilash
      if (mounted && _selectedTableId == tableId) {
        setState(() {
          _selectedTableOrders = localOrders;
        });
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

  _showOrderScreenDialog(String tableId) {
    showDialog(
      context: context,
      builder:
          (_) => OrderScreenContent(
            tableId: tableId,
            tableName: _selectedTableName,
            user: widget.user,
            formatted_order_number:
                "ORD-${DateTime.now().millisecondsSinceEpoch}",
            token: widget.token,
            onOrderCreated: () async {
              print("🔄 Yangi order yaratildi, UI yangilanmoqda...");

              // Cache'ni tozalash
              _ordersCache.clear();

              // Orderlarni qayta yuklash
              await _fetchOrdersForTable(tableId);

              // Stol statuslarini yangilash
              await _checkTableStatusesRealTime();
              await _updateLocalTableStatuses();

              // UI'ni majburiy yangilash
              if (mounted) setState(() {});

              print("✅ UI muvaffaqiyatli yangilandi");
            },
          ),
    );
  }

  Future<void> _closeOrder(Order order) async {
    setState(() => order.isProcessing = true);

    try {
      // Localda yopamiz
      await DBHelper.closeOrderLocal(order.id);

      // UI dan darhol olib tashlaymiz
      if (mounted) {
        setState(() {
          _selectedTableOrders.removeWhere((o) => o.id == order.id);

          // Agar tanlangan stolda boshqa pending order qolmagan bo‘lsa
          if (_selectedTableOrders.isEmpty) {
            _tableOccupiedStatus[_selectedTableId!] = false;
            _tableOwners.remove(_selectedTableId!);
          }
        });
      }

      // Local statuslarni yangilash
      await _updateLocalTableStatuses();

      showCenterSnackBar(context, "Zakaz yopildi", color: Colors.green);
    } catch (e) {
      print(e);
      showCenterSnackBar(context, "Xatolik: $e", color: Colors.red);
    } finally {
      if (mounted) setState(() => order.isProcessing = false);
    }
  }

  Future<void> _syncClosedOrders(String token) async {
    try {
      final unsynced = await DBHelper.getUnsyncedClosedOrders();
      if (unsynced.isEmpty) return;

      for (final o in unsynced) {
        final localId = o['id'].toString();
        final serverId = o['server_id']?.toString();

        if (serverId == null || serverId.isEmpty) continue;

        // Assume server endpoint for closing order
        final resp = await http.put(
          Uri.parse("${ApiConfig.baseUrl}/orders/$serverId/close"),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({}), // If needed, add body
        );

        if (resp.statusCode == 200) {
          await DBHelper.markOrderCloseSynced(localId);
          print("✅ Closed order $localId synced (serverId=$serverId)");
        } else {
          print("⚠️ Closed order $localId sync failed: ${resp.statusCode}");
        }
      }

      // Syncdan keyin local statuslarni yangilash
      await _updateLocalTableStatuses();
    } catch (e) {
      print("❌ _syncClosedOrders error: $e");
    }
  }

  Future<void> _checkTableStatuses() async {
    try {
      Map<String, bool> newStatus = {};
      Map<String, String> newOwners = {};

      // Parallel requests bilan barcha stollarni tekshirish
      final futures = _getSelectedHallTables().map((table) async {
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

            // API javobini to'g'ri parse qilish
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
    return latin1.encode(text); // CP866 yoki UTF-8 kodlash
  }

  Future<void> _printCancelledItem(
    OrderItem item,
    int cancelQuantity,
    String reason,
    Order order,
  ) async {
    try {
      debugPrint('🖨️ Bekor qilingan mahsulot print qilinmoqda');

      // 1️⃣ Avval productni _allProducts dan izlaymiz
      Ovqat? product;
      try {
        product = _allProducts.firstWhere(
          (p) => p.id == item.foodId,
          orElse:
              () => Ovqat(
                id: '',
                name: item.name ?? 'Nomaʼlum',
                price: item.price ?? 0,
                categoryId: '',
                categoryName: item.categoryName ?? '',
                subcategory: null,
                subcategories: [],
              ),
        );
      } catch (_) {}

      // 2️⃣ Agar product topilmasa, local DB dan olish
      if (product == null || product.id.isEmpty) {
        final rows = await FoodLocalService.getFoodById(item.foodId);
        if (rows != null) {
          product = Ovqat.fromJson(rows);
        }
      }

      // 3️⃣ Kategoriyani _categories dan izlash
      Category? category;
      try {
        category = _categories.firstWhere(
          (cat) => cat.id == product?.categoryId,
          orElse:
              () => Category(
                id: '',
                title: product?.categoryName ?? '',
                printerId: '',
                printerName: '',
                printerIp: '',
                subcategories: [],
              ),
        );
      } catch (_) {}

      // 4️⃣ Agar kategoriya topilmasa, local DB dan olish
      if (category == null || category.id.isEmpty) {
        final rows = await CategoryLocalService.getCategoryById(
          product?.categoryId ?? '',
        );
        if (rows != null) {
          category = Category.fromJson(rows);
        }
      }

      // 5️⃣ Endi printerga yuborish
      if (category != null && category.printerIp.isNotEmpty) {
        final printData = {
          'orderNumber': order.formatted_order_number,
          'waiter_name': widget.user.firstName,
          'table_name': _selectedTableName ?? 'N/A',
          'item_name': product?.name ?? item.name ?? 'Nomaʼlum',
          'cancel_quantity': cancelQuantity,
          'reason': reason,
          'time': DateTime.now().toString().substring(11, 16),
        };

        final printBytes = _createCancelPrintData(printData);
        await _printToSocket(category.printerIp, printBytes);

        debugPrint(
          '✅ Bekor qilingan mahsulot ${category.printerIp} ga yuborildi',
        );
      } else {
        debugPrint('⚠️ Kategoriya printeri topilmadi (local + server)');
      }
    } catch (e) {
      debugPrint('❌ Cancel print error: $e');
    }
  }

  static const String baseUrl = "${ApiConfig.baseUrl}";

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
        _loadInitialHalls();
      }
    } catch (e) {
      print("Token error: $e");
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
    try {
      // 🔹 Endi faqat localda yopamiz
      await DBHelper.closeOrderLocal(orderId);
      print("✅ Zakaz localda yopildi (order_id: $orderId)");
      return true;
    } catch (e) {
      print("❌ Zakaz yopishda xatolik (local): $e");
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

    try {
      // 1️⃣ LOCAL'da o‘chirib qo‘yamiz (miqdor kamayadi yoki item o‘chadi, total qayta hisoblanadi)
      await DBHelper.cancelOrderItemLocal(
        orderId: orderId,
        foodId: foodId,
        cancelQuantity: cancelQuantity,
        reason: reason,
        notes: notes,
      );

      // 2️⃣ UI ni yangilash (localdan qayta yuklab olamiz)
      await _fetchOrdersForTable(_selectedTableId!);
      await _checkTableStatuses();
      await _updateLocalTableStatuses();

      // 3️⃣ Printerga xabar yuborish (o‘zgarmaydi)
      final item = order.items[itemIndex];
      _printCancelledItem(item, cancelQuantity, reason, order);

      // 4️⃣ Sync queue ni ishga tushirib yuborish (agar token bo‘lsa)
      _trySyncCancelQueue();

      showCenterSnackBar(
        context,
        "✅ Mahsulot bekor qilindi (LOCAL)!",
        color: Colors.green,
      );
    } catch (e) {
      showCenterSnackBar(context, "Xatolik: $e", color: AppColors.error);
    } finally {
      if (mounted) setState(() => order.isProcessing = false);
    }
  }

  Future<void> _trySyncCancelQueue() async {
    try {
      // 🔑 Active token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("active_token");
      if (token == null || token.isEmpty) return;
      if (JwtDecoder.isExpired(token)) return;

      final logs = await DBHelper.getUnsyncedCancelLogs();
      if (logs.isEmpty) return;

      for (final log in logs) {
        final int logId = log['id'] as int;
        final String orderLocalId = (log['order_local_id'] ?? '').toString();
        String? orderServerId =
            (log['order_server_id']?.toString().isNotEmpty ?? false)
                ? log['order_server_id'].toString()
                : null;

        // Agar server_id yo‘q bo‘lsa – orderdan olib ko‘ramiz
        if (orderServerId == null || orderServerId.isEmpty) {
          final orderRow = await DBHelper.getOrderById(orderLocalId);
          if (orderRow != null &&
              (orderRow['server_id']?.toString().isNotEmpty ?? false)) {
            orderServerId = orderRow['server_id'].toString();
          }
        }

        // Hali ham yo‘q bo‘lsa – keyinroq yuboramiz
        if (orderServerId == null || orderServerId.isEmpty) {
          continue;
        }

        // Serverga yuborish
        final resp = await http
            .post(
              Uri.parse('$baseUrl/orders/$orderServerId/cancel-item'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'food_id': log['food_id'],
                'cancel_quantity': log['cancel_quantity'],
                'reason': log['reason'] ?? '',
                'notes': log['notes'] ?? '',
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          // muvaffaqiyatli bo‘lsa queue-ni closed qilamiz
          await DBHelper.markCancelLogSynced(logId);
        } else if (resp.statusCode == 401) {
          // token muammo – to‘xtaymiz
          break;
        } else {
          // boshqa xatolar – keyinga qoldiramiz
        }
      }
    } catch (_) {
      // Offline yoki boshqa xatolar – keyingi syncda urinadi
    }
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
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await HallController.forceSync(_token ?? "");
                  setState(() {});
                },
              ),
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
          // 🔼 Tepada header
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
                  'Zallar va Stollar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),

          // 🔹 Hall tanlash uchun tugmalar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children:
                    _halls.map((hall) {
                      final isSelected = _selectedHallId == hall.id;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedHallId = hall.id;
                              _selectedTableId = null;
                              _selectedTableName = null;
                              _selectedTableOrders = [];
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isSelected ? AppColors.primary : AppColors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(hall.name),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),

          // 🔽 Pastda tanlangan zalning stollari chiqadi
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
                      : _halls.isEmpty
                      ? const Center(
                        child: Text(
                          "Zallar topilmadi",
                          style: TextStyle(color: AppColors.grey),
                        ),
                      )
                      : _selectedHallId == null
                      ? const Center(
                        child: Text(
                          "Iltimos, zalni tanlang",
                          style: TextStyle(color: AppColors.grey),
                        ),
                      )
                      : _getSelectedHallTables().isEmpty
                      ? const Center(
                        child: Text(
                          "Bu zalda stollar yo'q",
                          style: TextStyle(color: AppColors.grey),
                        ),
                      )
                      : GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: _getSelectedHallTables().length,
                        itemBuilder: (_, index) {
                          final table = _getSelectedHallTables()[index];
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
                              table, // ✅ TableModel sifatida uzatiladi
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
    TableModel table,
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
      cardColor = Colors.green.withOpacity(0.05);
      textColor = Colors.green;
      statusText = "Bo'sh";
      borderColor = Colors.green;
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
              table.name,
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
    // Debug log qo'shish
    print(
      "🎨 _buildOrderCard chaqirildi: order.id=${order.id}, items.length=${order.items.length}",
    );
    for (int i = 0; i < order.items.length; i++) {
      print("   Item $i: ${order.items[i].name} x${order.items[i].quantity}");
    }

    final isOwnOrder = order.userId == widget.user.id;
    final canEdit = isOwnOrder;

    // Fallback: agar DB total 0 bo'lsa, itemlardan hisoblab ko'rsatamiz
    final num computedTotal = order.items.fold<num>(
      0,
      (s, it) => s + (it.quantity * (it.price ?? 0)),
    );
    final num displayTotal =
        (order.totalPrice != 0) ? order.totalPrice : computedTotal;

    return Container(
      // MUHIM: Unique key qo'shish
      key: ValueKey("order_${order.id}_${order.items.length}_${displayTotal}"),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ma'lumotlari
            Row(
              children: [
                Icon(Icons.receipt, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  "Zakaz #${order.formatted_order_number}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
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

            // ITEMLAR - har biri uchun unique key
            ...order.items.asMap().entries.map((entry) {
              int itemIndex = entry.key;
              OrderItem item = entry.value;

              return Container(
                key: ValueKey(
                  "item_${order.id}_${item.foodId}_${itemIndex}_${item.quantity}",
                ),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${item.name ?? 'Mahsulot'} x${item.quantity}",
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
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
                          canEdit
                              ? () => showCancelDialog(
                                order.id,
                                item.foodId,
                                itemIndex,
                                order,
                              )
                              : null,
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            // JAMI SUMMA
            Container(
              key: ValueKey("total_${order.id}_${displayTotal}"),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.payments,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Jami:",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${NumberFormat('#,##0', 'uz').format(displayTotal)} so'm",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                // Qo'shish
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed:
                          canEdit
                              ? () {
                                print(
                                  "🛒 Qo'shish tugmasi bosildi: order.id=${order.id}",
                                );
                                _showAddItemsDialog(order);
                              }
                              : null,
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text("Qo'shish"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.lightGrey,
                        disabledForegroundColor: AppColors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Yopish
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: canEdit ? () => _closeOrder(order) : null,
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text("Yopish"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.lightGrey,
                        disabledForegroundColor: AppColors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Ko'chirish
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed:
                          canEdit ? () => _showMoveTableDialog(order) : null,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text("Ko'chirish"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.lightGrey,
                        disabledForegroundColor: AppColors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (!canEdit) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Bu zakaz boshqa ofitsiantga tegishli – tahrirlab bo'lmaydi",
                        style: TextStyle(fontSize: 12, color: AppColors.error),
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
    // Faqat tanlangan zalning stollari ichidan bo'shlarini olish
    final emptyTables =
        _getSelectedHallTables()
            .where((t) => !(_tableOccupiedStatus[t.id] ?? false))
            .toList();

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
                    child: Text(
                      "Stol ${table.name}",
                    ), // 🔹 TableModel.name ishlatildi
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

  void _showAddItemsDialog(Order order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          child: OrderScreenContent(
            formatted_order_number: order.formatted_order_number,
            tableId: order.tableId,
            tableName: _selectedTableName,
            user: widget.user,
            token: widget.token,
            isAddingToExistingOrder: true,
            existingOrderId: order.id,
            onOrderCreated: () async {
              print("🔄 onOrderCreated callback ishga tushdi");

              // MUHIM: UI'ni darhol yangilash
              if (mounted) {
                // 1. Cache'ni tozalash
                _ordersCache.clear();

                // 2. Tanlangan stolning orderlarini qayta yuklash
                await _fetchOrdersForTable(_selectedTableId!);

                // 3. Stol statuslarini yangilash
                await _checkTableStatusesRealTime();
                await _updateLocalTableStatuses();

                // 4. UI'ni majburiy yangilash
                setState(() {});

                print("✅ UI muvaffaqiyatli yangilandi");
              }
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
