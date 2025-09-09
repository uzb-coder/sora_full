import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class FoodLocalService {
  /// 📥 Mahsulotlarni saqlash
  static Future<void> saveFoods(List<Map<String, dynamic>> foods) async {
    final db = await DBHelper.database;
    final batch = db.batch();

    for (var food in foods) {
      batch.insert(
        'foods',
        food,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint("📦 ${foods.length} ta mahsulot DB ga yozildi");
  }

  /// 📦 Hamma mahsulotlarni olish
  static Future<List<Map<String, dynamic>>> getAllFoods() async {
    final db = await DBHelper.database;
    final result = await db.query('foods');
    debugPrint("📦 Local DB dan ${result.length} ta mahsulot olindi");
    return result;
  }

  /// 🔍 Bitta mahsulotni ID orqali olish
  static Future<Map<String, dynamic>?> getFoodById(String id) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'foods',
      where: '_id = ? OR id = ? OR food_id = ?',
      whereArgs: [id, id, id],
      limit: 1,
    );
    if (result.isNotEmpty) {
      debugPrint("✅ Local DB’dan mahsulot topildi: ${result.first}");
      return result.first;
    }
    debugPrint("⚠️ Local DB’da mahsulot topilmadi: $id");
    return null;
  }

  /// 🗑️ Tozalash
  static Future<void> clearFoods() async {
    final db = await DBHelper.database;
    await db.delete('foods');
    debugPrint("🗑️ Mahsulotlar tozalandi");
  }
}
