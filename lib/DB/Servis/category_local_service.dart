import 'package:sqflite/sqflite.dart';
import 'dart:convert'; // <-- JSON uchun kerak
import 'db_helper.dart';

// lib/DB/Servis/category_local_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../Global/Api_global.dart'; // baseUrl va token oladigan joyingiz

import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class CategoryLocalService {
  /// 📥 Kategoriyalarni saqlash
  static Future<void> saveCategories(
    List<Map<String, dynamic>> categories,
  ) async {
    CategoryLocalService.clearCategories();
    final db = await DBHelper.database;
    final batch = db.batch();

    for (var cat in categories) {
      final subs =
          (cat['subcategories'] is List)
              ? jsonEncode(cat['subcategories'])
              : '[]';

      final printer = cat['printer_id'];
      String printerId = '';
      String printerName = '';
      String printerIp = '';
      if (printer is Map<String, dynamic>) {
        printerId = printer['_id']?.toString() ?? '';
        printerName = printer['name']?.toString() ?? '';
        printerIp = printer['ip']?.toString() ?? '';
      }

      batch.insert('categories', {
        '_id': cat['_id']?.toString(),
        'title': cat['title']?.toString(),
        'printer_id': printerId,
        'printer_name': printerName,
        'printer_ip': printerIp,
        'subcategories': subs,
        'createdAt': cat['createdAt']?.toString(),
        'updatedAt': cat['updatedAt']?.toString(),
        '__v': cat['__v'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// 📦 Hamma kategoriyalarni olish
  static Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await DBHelper.database;
    final result = await db.query('categories');
    print("📦 Local DB categories: $result");
    return result;
  }

  /// 🔍 Bitta kategoriya ID orqali olish
  static Future<Map<String, dynamic>?> getCategoryById(String id) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'categories',
      where: '_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isNotEmpty) {
      print("✅ Local DB’dan kategoriya topildi: ${result.first}");
      return result.first;
    }
    print("⚠️ Local DB’da kategoriya topilmadi: $id");
    return null;
  }

  /// 🗑️ Tozalash
  static Future<void> clearCategories() async {
    final db = await DBHelper.database;
    await db.delete('categories');
    print("🗑️ Kategoriyalar tozalandi");
  }
}
