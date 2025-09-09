import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../Kassir/Model/KassirModel.dart';
import '../../Offisant/Controller/usersCOntroller.dart';

class DBHelper {
  static Database? _database;

  static Future<Database> get database async => _db();

  static Future<Database> _db() async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');

    _database = await openDatabase(
      path,
      version: 15, // versiyani oshirdingiz
      onCreate: (db, version) async {
        // USERS
        await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id TEXT PRIMARY KEY,
        first_name TEXT,
        last_name TEXT,
        role TEXT,
        user_code TEXT,
        password TEXT,
        is_active INTEGER,
        permissions TEXT,
        percent INTEGER
      )
      ''');

        // ORDERS
        await db.execute('''
      CREATE TABLE IF NOT EXISTS orders(
        id TEXT PRIMARY KEY,
        server_id TEXT,
        table_id TEXT,
        user_id TEXT,
        waiter_name TEXT,
        total_price REAL,
        status TEXT,
        created_at TEXT,
        formatted_order_number TEXT,
        is_synced INTEGER DEFAULT 0,
        payment_method TEXT,
        payment_amount REAL DEFAULT 0,
        updated_at TEXT,
        closed_at TEXT,
        is_synced_close INTEGER DEFAULT 0,
        is_synced_payment INTEGER DEFAULT 0
      )
      ''');

        // HALLS
        await db.execute('''
      CREATE TABLE IF NOT EXISTS halls(
        id TEXT PRIMARY KEY,
        name TEXT
      )
      ''');

        // TABLES
        await db.execute('''
      CREATE TABLE IF NOT EXISTS tables(
        id TEXT PRIMARY KEY,
        hall_id TEXT,
        name TEXT,
        status TEXT,
        guest_count INTEGER,
        capacity INTEGER,
        is_active INTEGER,
        created_at TEXT,
        updated_at TEXT,
        number TEXT,
        v INTEGER,
        display_name TEXT
      )
      ''');

        // CATEGORIES
        await db.execute('''
      CREATE TABLE IF NOT EXISTS categories(
        id TEXT PRIMARY KEY,
        title TEXT,
        printer_id TEXT,
        printer_name TEXT,
        printer_ip TEXT,
        subcategories TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        __v INTEGER
      )
      ''');

        // SUBCATEGORIES
        await db.execute('''
      CREATE TABLE IF NOT EXISTS subcategories(
        id TEXT PRIMARY KEY,
        title TEXT,
        category_id TEXT
      )
      ''');

        // FOODS
        await db.execute('''
      CREATE TABLE IF NOT EXISTS foods(
        _id TEXT PRIMARY KEY,
        name TEXT,
        price REAL,
        category_id TEXT,
        category_name TEXT,
        subcategory TEXT,
        description TEXT,
        image TEXT,
        unit TEXT,
        department_id TEXT,
        warehouse TEXT,
        soni INTEGER,
        expiration TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        __v INTEGER
      )
      ''');

        // ORDER_ITEMS
        await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT,
        food_id TEXT,
        name TEXT,
        quantity REAL,
        price REAL,
        category_name TEXT,
        is_synced INTEGER DEFAULT 0
      )
      ''');

        // CANCEL QUEUE
        await db.execute('''
      CREATE TABLE IF NOT EXISTS order_cancel_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_local_id TEXT NOT NULL,
        order_server_id TEXT,
        food_id TEXT NOT NULL,
        cancel_quantity INTEGER NOT NULL,
        reason TEXT,
        notes TEXT,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0
      )
      ''');
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 12) {
          await _addColumnIfNotExists(db, 'foods', 'category_name', 'TEXT');
          await _addColumnIfNotExists(db, 'foods', 'description', 'TEXT');
          await _addColumnIfNotExists(db, 'foods', 'image', 'TEXT');
        }
        if (oldVersion < 13) {
          await _addColumnIfNotExists(db, 'orders', 'payment_method', 'TEXT');
          await _addColumnIfNotExists(
            db,
            'orders',
            'payment_amount',
            'REAL DEFAULT 0',
          );
          await _addColumnIfNotExists(db, 'orders', 'updated_at', 'TEXT');
        }
        if (oldVersion < 14) {
          await _addColumnIfNotExists(
            db,
            'orders',
            'is_synced_close',
            'INTEGER DEFAULT 0',
          );
          await _addColumnIfNotExists(
            db,
            'orders',
            'is_synced_payment',
            'INTEGER DEFAULT 0',
          );
          await _addColumnIfNotExists(db, 'orders', 'closed_at', 'TEXT');
        }
        if (oldVersion < 15) {
          await _addColumnIfNotExists(db, 'orders', 'closed_at', 'TEXT');
          await _addColumnIfNotExists(
            db,
            'orders',
            'is_synced_close',
            'INTEGER DEFAULT 0',
          );
          await _addColumnIfNotExists(
            db,
            'orders',
            'is_synced_payment',
            'INTEGER DEFAULT 0',
          );
        }
      },
    );

    return _database!;
  }

  /// Helper function to add column only if it doesn't exist
  static Future<void> _addColumnIfNotExists(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    final exists = result.any((row) => row['name'] == column);

    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
      print("✅ Column '$column' added to $table");
    }
  }

  static Future<List<Map<String, dynamic>>> getOpenOrders() async {
    final db = await database;

    final orders = await db.query(
      'orders',
      where: "(status IS NULL) OR (status NOT IN ('closed','paid'))",
      orderBy: 'created_at DESC',
    );

    final result = <Map<String, dynamic>>[];

    for (final order in orders) {
      final items = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [order['id']],
      );
      result.add({...order, 'items': items});
    }

    return result;
  }

  static Future<void> upsertOrderFromPendingJson(Map<String, dynamic> o) async {
    final db = await database;
    await db.insert('orders', {
      'id': (o['id'] ?? o['_id'])?.toString(),
      'server_id': (o['server_id'] ?? o['_id'])?.toString(),
      'table_id': o['table_id']?.toString(),
      'user_id': o['user_id']?.toString(),
      'waiter_name':
          o['waiterName']?.toString() ?? o['waiter_name']?.toString(),
      'total_price': (o['totalPrice'] ?? o['finalTotal'] ?? 0) * 1.0,
      'status': (o['status'] ?? 'pending').toString(),
      'created_at':
          o['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      'formatted_order_number':
          o['formattedOrderNumber']?.toString() ??
          o['formatted_order_number']?.toString(),
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Agar items bo'lsa – saqlab qo'yamiz
    final items = (o['items'] is List) ? (o['items'] as List) : const [];
    for (final it in items) {
      await insertOrUpdateOrderItem((o['id'] ?? o['_id']).toString(), {
        'food_id': it['food_id'] ?? it['_id'],
        'name': it['name'],
        'quantity': it['quantity'] ?? 0,
        'price': it['price'] ?? 0,
        'category_name': it['category_name'] ?? '',
      });
    }
  }

  // 🔓 Ochiq zakazlarni olish
  static Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final db = await database;

    final orders = await db.query(
      'orders',
      where: 'status = ?',
      whereArgs: ['pending'], // faqat ochiq zakazlar
      orderBy: 'created_at DESC',
    );

    final result = <Map<String, dynamic>>[];

    for (final order in orders) {
      final items = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [order['id']],
      );

      result.add({...order, 'items': items});
    }

    return result;
  }

  static Future<Map<String, dynamic>> getTableStatus(
    String tableId,
    String currentUserId,
  ) async {
    final db = await database;

    final orders = await db.query(
      'orders',
      where: 'table_id = ? AND status = ?',
      whereArgs: [tableId, 'pending'],
    );

    if (orders.isEmpty) {
      return {'isOccupied': false, 'isOwnTable': false, 'ownerId': null};
    }

    final ownerId = orders.first['user_id']?.toString() ?? '';
    return {
      'isOccupied': true,
      'isOwnTable': ownerId == currentUserId,
      'ownerId': ownerId,
    };
  }

  // 🔒 Yopiq zakazlarni olish (mavjud metodni nomini to‘g‘rilab qo‘ydim)
  static Future<List<Map<String, dynamic>>> getClosedOrders() async {
    final db = await database;

    final orders = await db.query(
      'orders',
      where: 'status = ?',
      whereArgs: ['closed'],
      orderBy: 'created_at DESC',
    );

    final result = <Map<String, dynamic>>[];

    for (final order in orders) {
      final items = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [order['id']],
      );

      result.add({...order, 'items': items});
    }

    return result;
  }

  // DBHelper ichiga qo‘shish (ixtiyoriy, tezlik uchun):
  static Future<Map<String, Map<String, String>>> getPendingStateByTables(
    List<String> tableIds,
  ) async {
    final db = await database;
    final placeholders = List.filled(tableIds.length, '?').join(',');
    final rows = await db.rawQuery('''
    SELECT table_id, MIN(user_id) as user_id, COUNT(*) as cnt
    FROM orders
    WHERE status = 'pending' AND table_id IN ($placeholders)
    GROUP BY table_id
  ''', tableIds);
    final occupied = <String, String>{}; // 'true'/'false' yozib beramiz
    final owners = <String, String>{};
    for (final r in rows) {
      final tid = r['table_id']?.toString() ?? '';
      final cnt = int.tryParse((r['cnt'] ?? '0').toString()) ?? 0;
      if (tid.isNotEmpty && cnt > 0) {
        occupied[tid] = 'true';
        owners[tid] = (r['user_id'] ?? '').toString();
      }
    }
    return {'occupied': occupied, 'owners': owners};
  }

  static Future<void> moveOrderLocal(String orderId, String newTableId) async {
    final db = await _db();
    await db.update(
      'orders',
      {
        'table_id': newTableId,
        'is_synced': 0, // sync qilinmagan
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
    print("✅ Local DB: Zakaz $orderId yangi stolga ko‘chirildi ($newTableId)");
  }

  // 🔎 Bitta orderni olish
  static Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    final db = await database;
    final rows = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> cancelOrderItemLocal({
    required String orderId,
    required String foodId,
    required int cancelQuantity,
    String? reason,
    String? notes,
  }) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        print(
          "🛑 cancelOrderItemLocal START: orderId=$orderId, foodId=$foodId, qty=$cancelQuantity",
        );

        // 1️⃣ Orderni olish
        final orders = await txn.query(
          'orders',
          where: 'id = ?',
          whereArgs: [orderId.toString()],
          limit: 1,
        );
        if (orders.isEmpty) {
          print("❌ Order topilmadi (id=$orderId)");
          throw Exception('Order topilmadi (id=$orderId)');
        }
        final orderRow = orders.first;

        // 2️⃣ order_items dan itemni olish
        final items = await txn.query(
          'order_items',
          where: 'order_id = ? AND food_id = ?',
          whereArgs: [orderId.toString(), foodId.toString()],
        );

        if (items.isEmpty) {
          print("❌ Mahsulot topilmadi (orderId=$orderId, foodId=$foodId)");
          throw Exception('Mahsulot topilmadi (food_id=$foodId)');
        }

        final item = items.first;
        final currQty =
            (item['quantity'] is num)
                ? item['quantity'] as num
                : num.tryParse(item['quantity'].toString()) ?? 0;
        final newQty = currQty - cancelQuantity;

        print(
          "📦 Oldingi qty=$currQty, Bekor qilinmoqda=$cancelQuantity, Yangi qty=$newQty",
        );

        if (newQty <= 0) {
          await txn.delete(
            'order_items',
            where: 'order_id = ? AND food_id = ?',
            whereArgs: [orderId.toString(), foodId.toString()],
          );
          print("🗑 order_items dan o‘chirildi (foodId=$foodId)");
        } else {
          await txn.update(
            'order_items',
            {'quantity': newQty, 'is_synced': 0},
            where: 'order_id = ? AND food_id = ?',
            whereArgs: [orderId.toString(), foodId.toString()],
          );
          print("🔄 order_items yangilandi: foodId=$foodId → qty=$newQty");
        }

        // 3️⃣ Total price qayta hisoblash
        final allItems = await txn.query(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [orderId.toString()],
        );

        num total = 0;
        for (final x in allItems) {
          final q =
              (x['quantity'] is num)
                  ? x['quantity'] as num
                  : num.tryParse(x['quantity'].toString()) ?? 0;
          final p =
              (x['price'] is num)
                  ? x['price'] as num
                  : num.tryParse((x['price'] ?? '0').toString()) ?? 0;
          total += q * p;
        }

        await txn.update(
          'orders',
          {'total_price': total, 'is_synced': 0},
          where: 'id = ?',
          whereArgs: [orderId.toString()],
        );
        print("💰 Order total_price yangilandi: $total (orderId=$orderId)");

        // 4️⃣ Queue ga yozib qo‘yish
        await txn.insert('order_cancel_queue', {
          'order_local_id': orderId,
          'order_server_id': orderRow['server_id'],
          'food_id': foodId.toString(),
          'cancel_quantity': cancelQuantity,
          'reason': reason ?? '',
          'notes': notes ?? '',
          'created_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        });
        print(
          "📥 Cancel queue ga qo‘shildi (foodId=$foodId, qty=$cancelQuantity)",
        );
      });

      print("✅ cancelOrderItemLocal SUCCESS: orderId=$orderId, foodId=$foodId");
    } catch (e, stack) {
      print("❌ cancelOrderItemLocal ERROR: $e");
      print("🔍 Stack: $stack");
      rethrow;
    }
  }

  // 📥 Queue dagi unsynced yozuvlar
  static Future<List<Map<String, dynamic>>> getUnsyncedCancelLogs() async {
    final db = await database;
    return db.query(
      'order_cancel_queue',
      where: 'is_synced = 0',
      orderBy: 'id ASC',
    );
  }

  // ✅ Queue yozuvini synced qilib belgilash
  static Future<void> markCancelLogSynced(int id) async {
    final db = await database;
    await db.update(
      'order_cancel_queue',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> updateOrderServerId(
    String localId,
    String serverId,
  ) async {
    final db = await _db();
    await db.update(
      'orders',
      {'server_id': serverId, 'is_synced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
    print("🔄 Local DB: Order $localId uchun server_id yangilandi → $serverId");
  }

  // DBHelper ichida
  static Future<void> insertOrderItems(
    String orderId,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;
    for (final item in items) {
      await db.insert('order_items', {
        'order_id': orderId,
        'food_id': item['food_id'],
        'name': item['name'],
        'quantity': item['quantity'],
        'price': item['price'],
        'category_name': item['category_name'],
        'is_synced': 0, // 🔴 yangi qo‘shilgan – serverga yuborilmagan
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> markOrderItemsAsSynced(String orderId) async {
    final db = await database;
    await db.update(
      'order_items',
      {'is_synced': 1},
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  static Future<void> insertOrder(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await _db();
    final batch = db.batch();

    final orderData = Map<String, dynamic>.from(order);

    // 🔑 is_synced va status majburiy yozamiz
    orderData['is_synced'] = order['is_synced'] ?? 0;
    orderData['status'] = order['status'] ?? 'pending';

    batch.insert(
      'orders',
      orderData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (final item in items) {
      final itemData = Map<String, dynamic>.from(item);
      itemData['order_id'] = order['id'];
      batch.insert(
        'order_items',
        itemData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print(
      "✅ Local DB: Zakaz va ${items.length} ta mahsulot saqlandi (order_id: ${order['id']})",
    );
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    final db = await _db();
    final res = await db.query('orders', where: 'is_synced = 0');
    print("📦 Unsynced orders count: ${res.length}");
    return res;
  }

  static Future<List<Map<String, dynamic>>> getOrdersByTable(
    String tableId,
  ) async {
    final db = await database;

    // Faqat ochiq zakazlarni olish
    final orders = await db.query(
      'orders',
      where: 'table_id = ? AND status = ?',
      whereArgs: [tableId, 'pending'],
      orderBy: 'created_at ASC',
    );

    final result = <Map<String, dynamic>>[];

    for (final order in orders) {
      final items = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [order['id']],
      );

      // ✅ items ni ham qo‘shib yuboramiz
      result.add({...order, 'items': items});
    }

    return result;
  }

  // Zakazni sync qilingan deb belgilash
  static Future<void> markOrderAsSynced(String orderId) async {
    final db = await _db();
    await db.update(
      'orders',
      {'is_synced': 1}, // ✅ endi qayta sync bo‘lmaydi
      where: 'id = ?',
      whereArgs: [orderId],
    );
    print("✅ Zakaz $orderId sync qilindi");
  }

  // Zakazni localda yopish
  static Future<void> closeOrderLocal(String orderId) async {
    final time = DateTime.now().toIso8601String();
    final db = await _db();
    await db.update(
      'orders',
      {
        'status': 'closed',
        'closed_at': time,
        'is_synced_close': 0, // 🔴 yopish hali serverga yuborilmagan
        'updated_at': time,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
    print("✅ Local DB: Zakaz yopildi (order_id: $orderId)");
  }

  static Future<bool> markOrderPaidLocal({
    required String orderId,
    required String paymentMethod,
    required double paymentAmount,
  }) async {
    try {
      final db = await DBHelper.database;
      await db.update(
        'orders',
        {
          'status': 'paid',
          'payment_method': paymentMethod,
          'payment_amount': paymentAmount,
          'is_synced': 0, // umumiy flag
          'is_synced_payment': 0, // 🔴 to'lov hali yuborilmagan
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      print(
        "💰 To‘lov localda yozildi: $orderId, $paymentMethod, $paymentAmount",
      );
      return true;
    } catch (e, st) {
      print("❌ markOrderPaidLocal xato: $e\n$st");
      return false;
    }
  }

  // 🔎 Yopilgan, lekin serverga yuborilmaganlar
  static Future<List<Map<String, dynamic>>> getUnsyncedClosedOrders() async {
    final db = await database;
    return db.query(
      'orders',
      where:
          "status = 'closed' AND (is_synced_close = 0 OR is_synced_close IS NULL)",
      orderBy: 'datetime(closed_at) ASC',
    );
  }

  // 🔎 To'langan, lekin serverga yuborilmaganlar
  static Future<List<Map<String, dynamic>>> getUnsyncedPaidOrders() async {
    final db = await database;
    return db.query(
      'orders',
      where:
          "status = 'paid' AND (is_synced_payment = 0 OR is_synced_payment IS NULL)",
      orderBy: 'datetime(updated_at) ASC',
    );
  }

  // ✅ Yopish sync bo'ldi deb belgilash
  static Future<void> markOrderCloseSynced(String orderId) async {
    final db = await database;
    await db.update(
      'orders',
      {'is_synced_close': 1},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // ✅ To'lov sync bo'ldi deb belgilash
  static Future<void> markOrderPaymentSynced(String orderId) async {
    final db = await database;
    await db.update(
      'orders',
      {'is_synced_payment': 1},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<bool> processPaymentLocal(
    PendingOrder order,
    String paymentMethod,
    double paymentAmount,
  ) async {
    try {
      final db = await DBHelper.database;
      await db.update(
        'orders',
        {
          'status': 'paid',
          'payment_method': paymentMethod,
          'payment_amount': paymentAmount,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );
      debugPrint(
        "💰 To‘lov localda yozildi: ${order.id}, $paymentMethod, $paymentAmount",
      );
      return true;
    } catch (e, st) {
      debugPrint("❌ processPaymentLocal xato: $e\n$st");
      return false;
    }
  }

  static Future<void> insertOrUpdateOrderItem(
    String orderId,
    Map<String, dynamic> item,
  ) async {
    final db = await database;
    final orderKey = orderId.toString();
    final foodId = (item['food_id'] ?? item['id'] ?? '').toString();

    if (foodId.isEmpty) {
      print("⚠️ food_id bo‘sh: $item");
      return;
    }

    final qty =
        (item['quantity'] is num
            ? item['quantity']
            : num.tryParse(item['quantity']?.toString() ?? '0')) ??
        0;
    final price =
        (item['price'] is num
            ? item['price']
            : num.tryParse(item['price']?.toString() ?? '0')) ??
        0;

    try {
      await db.transaction((txn) async {
        final existing = await txn.query(
          'order_items',
          where: 'order_id = ? AND food_id = ?',
          whereArgs: [orderKey, foodId],
        );
        if (existing.isNotEmpty) {
          final newQty = ((existing.first['quantity'] as num?) ?? 0) + qty;
          await txn.update(
            'order_items',
            {
              'quantity': newQty,
              'price': price,
              'name': item['name'] ?? '',
              'category_name': item['category_name'] ?? '',
              'is_synced': 1, // Local rejim
            },
            where: 'order_id = ? AND food_id = ?',
            whereArgs: [orderKey, foodId],
          );
          print("🔄 Yangilandi: ${item['name']} x$newQty");
        } else {
          await txn.insert('order_items', {
            'order_id': orderKey,
            'food_id': foodId,
            'name': item['name'] ?? '',
            'quantity': qty,
            'price': price,
            'category_name': item['category_name'] ?? '',
            'is_synced': 1, // Local rejim
          });
          print("➕ Qo‘shildi: ${item['name']} x$qty");
        }

        final totalRows = await txn.rawQuery(
          'SELECT SUM(quantity * price) AS total FROM order_items WHERE order_id = ?',
          [orderKey],
        );
        final total = (totalRows.first['total'] as num?) ?? 0;

        await txn.update(
          'orders',
          {'total_price': total, 'is_synced': 1},
          where: 'id = ?',
          whereArgs: [orderKey],
        );
        print("💰 Order $orderKey: total=$total");
      });
    } catch (e, stack) {
      print("❌ Xatolik: $e\n🔍 Stack: $stack");
      rethrow;
    }
  }

  // ---------- USERS ----------
  static Future<void> clearUsers() async {
    final db = await _db();
    await db.delete('users');
  }

  static Future<void> insertUsers(List<User> users) async {
    final db = await _db();
    final batch = db.batch();
    for (var user in users) {
      batch.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<User>> getUsers() async {
    final db = await _db();
    final maps = await db.query('users');
    return maps.map((e) => User.fromMap(e)).toList();
  }

  static Future<User?> getUserByCode(String userCode) async {
    final db = await _db();
    final maps = await db.query(
      'users',
      where: 'user_code = ?',
      whereArgs: [userCode],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  static Future<void> upsertFoods(List<Map<String, dynamic>> foods) async {
    final db = await _db();
    final batch = db.batch();

    for (final f in foods) {
      batch.insert('foods', {
        '_id': f['_id']?.toString(),
        'name': f['name']?.toString() ?? '',
        'price':
            (f['price'] is num)
                ? f['price']
                : double.tryParse(f['price']?.toString() ?? '0'),
        'category_id':
            f['category'] is Map
                ? f['category']['_id']?.toString()
                : f['category_id']?.toString(),
        'category_name':
            f['category'] is Map
                ? f['category']['title']?.toString()
                : f['category_name']?.toString(),
        'subcategory': f['subcategory']?.toString() ?? '',
        'description': f['description']?.toString() ?? '',
        'image': f['image']?.toString() ?? '',
        'unit': f['unit']?.toString() ?? '',
        'department_id':
            f['department_id'] is Map
                ? f['department_id']['_id']?.toString()
                : f['department_id']?.toString(),
        'warehouse': f['warehouse']?.toString() ?? '',
        'soni': f['soni'] ?? 0,
        'expiration': f['expiration']?.toString(),
        'createdAt': f['createdAt']?.toString(),
        'updatedAt': f['updatedAt']?.toString(),
        '__v': f['__v'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  static Future<int> updateUserWithPin(String id, String pin) async {
    final db = await _db();
    return await db.update(
      'users',
      {'password': pin},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> upsertCategories(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();

    print("🧾 upsertCategories: ${rows.length} ta kategoriya kelgan");

    for (final r in rows) {
      try {
        final String id = (r['_id']?.toString() ?? r['id']?.toString() ?? '');
        final String title = r['title']?.toString() ?? '';

        // printer_id Map yoki String bo'lishi mumkin
        final printer = r['printer_id'];
        final String printerId =
            (printer is Map)
                ? (printer['_id']?.toString() ?? '')
                : (r['printer_id']?.toString() ?? '');
        final String printerName =
            (printer is Map)
                ? (printer['name']?.toString() ?? '')
                : (r['printer_name']?.toString() ?? '');
        final String printerIp =
            (printer is Map)
                ? (printer['ip']?.toString() ?? '')
                : (r['printer_ip']?.toString() ?? '');

        // subcategories ni TEXT (JSON) sifatida saqlaymiz
        String subcategoriesJson;
        if (r['subcategories'] is String) {
          subcategoriesJson = r['subcategories'];
        } else {
          subcategoriesJson = jsonEncode(r['subcategories'] ?? []);
        }

        final createdAt = r['createdAt']?.toString();
        final updatedAt = r['updatedAt']?.toString();
        final v = r['__v'] ?? 0;

        // Debug
        print(
          "   ➕ Save Category => id:$id, title:$title, printer:$printerName($printerIp)",
        );

        batch.insert('categories', {
          'id': id, // ⚠️ Jadval ustuni 'id' bo'lishi shart
          'title': title,
          'printer_id': printerId,
          'printer_name': printerName,
          'printer_ip': printerIp,
          'subcategories': subcategoriesJson, // TEXT sifatida
          'createdAt': createdAt,
          'updatedAt': updatedAt,
          '__v': v,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        print("   ❌ upsertCategories row error: $e | row: $r");
      }
    }

    await batch.commit(noResult: true);

    // Tekshiruv: nechta yozildi?
    final check = await db.query('categories');
    print(
      "✅ upsertCategories commit: ${check.length} ta kategoriya bazada bor",
    );
  }

  // ---------- TABLES ----------
  static Future<void> upsertTables(List<Map<String, dynamic>> tables) async {
    final db = await _db();
    final batch = db.batch();
    for (final t in tables) {
      batch.insert('tables', t, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getTables() async {
    final db = await _db();
    return db.query('tables', orderBy: 'number ASC');
  }

  static Future<void> clearTables() async {
    final db = await _db();
    await db.delete('tables');
  }

  static Future<List<Map<String, dynamic>>> getFoods() async {
    final db = await _db();
    return db.query('foods');
  }

  static Future<void> clearFoods() async {
    final db = await _db();
    await db.delete('foods');
  }

  static Future<List<Map<String, dynamic>>> getOrderItems(
    String orderId,
  ) async {
    final db = await database;
    return await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  // ---------- CATEGORIES ----------

  static Future<List<Map<String, Object?>>> getCategories() async {
    final db = await database;
    return db.query('categories', orderBy: 'title ASC');
  }

  static Future<void> clearCategories() async {
    final db = await _db();
    await db.delete('categories');
  }
}
