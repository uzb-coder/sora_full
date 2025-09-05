import 'package:sqflite/sqflite.dart';
import 'dart:convert'; // <-- JSON uchun kerak
import 'db_helper.dart';

// lib/DB/Servis/category_local_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../Global/Api_global.dart'; // baseUrl va token oladigan joyingiz

import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class CategoryLocalService {
  static Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    final db = await DBHelper.database;
    final batch = db.batch();

    for (var cat in categories) {
      final subs = (cat['subcategories'] is List)
          ? jsonEncode(cat['subcategories']) // JSON qilib saqlaymiz
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

      batch.insert(
        'categories',
        {
          '_id': cat['_id']?.toString(),
          'title': cat['title']?.toString(),
          'printer_id': printerId,
          'printer_name': printerName,
          'printer_ip': printerIp,
          'subcategories': subs,
          'createdAt': cat['createdAt']?.toString(),
          'updatedAt': cat['updatedAt']?.toString(),
          '__v': cat['__v'] ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await DBHelper.database;
    final result = await db.query('categories');
    print("📦 Local DB categories: $result");
    return result;
  }


  static Future<void> clearCategories() async {
    final db = await DBHelper.database;
    await db.delete('categories');
    print("🗑️ Kategoriyalar tozalandi");
  }

}
