import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
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
      version: 8, // yangi versiya
      onCreate: (db, version) async {
        // USERS jadvali
        await db.execute('''
          CREATE TABLE users(
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

        // TABLES jadvali
        await db.execute('''
          CREATE TABLE tables(
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

        // HALLS jadvali
        await db.execute('''
          CREATE TABLE halls(
            id TEXT PRIMARY KEY,
            name TEXT
          )
        ''');

        // ORDERS jadvali
        await db.execute('''
          CREATE TABLE orders(
            id TEXT PRIMARY KEY,
            table_id TEXT,
            user_id TEXT,
            waiter_name TEXT,
            total_price REAL,
            status TEXT,
            created_at TEXT,
            formatted_order_number TEXT
          )
        ''');

        // ORDER_ITEMS jadvali
        await db.execute('''
          CREATE TABLE order_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id TEXT,
            food_id TEXT,
            name TEXT,
            quantity REAL,
            price REAL,
            category_name TEXT
          )
        ''');

// CATEGORY jadvali
        await db.execute('''
 CREATE TABLE categories(
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

        // SUBCATEGORY
        await db.execute('''
  CREATE TABLE subcategories(
    id TEXT PRIMARY KEY,
    title TEXT,
    category_id TEXT
  )
''');

// === FOODS jadvali ===
        await db.execute('''
CREATE TABLE foods (
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 10) {
          // Eski foods jadvalini alter qilamiz
          await db.execute("ALTER TABLE foods ADD COLUMN category_name TEXT");
          await db.execute("ALTER TABLE foods ADD COLUMN description TEXT");
          await db.execute("ALTER TABLE foods ADD COLUMN image TEXT");
        }
      },
    );
    return _database!;
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
        'price': (f['price'] is num) ? f['price'] : double.tryParse(f['price']?.toString() ?? '0'),
        'category_id': f['category'] is Map ? f['category']['_id']?.toString() : f['category_id']?.toString(),
        'category_name': f['category'] is Map ? f['category']['title']?.toString() : f['category_name']?.toString(),
        'subcategory': f['subcategory']?.toString() ?? '',
        'description': f['description']?.toString() ?? '',
        'image': f['image']?.toString() ?? '',
        'unit': f['unit']?.toString() ?? '',
        'department_id': f['department_id'] is Map ? f['department_id']['_id']?.toString() : f['department_id']?.toString(),
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
// lib/DB/Servis/db_helper.dart ichida, class DBHelper { ... } ichiga qo'ying
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
        final String printerId = (printer is Map)
            ? (printer['_id']?.toString() ?? '')
            : (r['printer_id']?.toString() ?? '');
        final String printerName = (printer is Map)
            ? (printer['name']?.toString() ?? '')
            : (r['printer_name']?.toString() ?? '');
        final String printerIp = (printer is Map)
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
        print("   ➕ Save Category => id:$id, title:$title, printer:$printerName($printerIp)");

        batch.insert(
          'categories',
          {
            'id': id,                         // ⚠️ Jadval ustuni 'id' bo'lishi shart
            'title': title,
            'printer_id': printerId,
            'printer_name': printerName,
            'printer_ip': printerIp,
            'subcategories': subcategoriesJson, // TEXT sifatida
            'createdAt': createdAt,
            'updatedAt': updatedAt,
            '__v': v,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        print("   ❌ upsertCategories row error: $e | row: $r");
      }
    }

    await batch.commit(noResult: true);

    // Tekshiruv: nechta yozildi?
    final check = await db.query('categories');
    print("✅ upsertCategories commit: ${check.length} ta kategoriya bazada bor");
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
