import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class FoodLocalService {
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

  static Future<List<Map<String, dynamic>>> getAllFoods() async {
    final db = await DBHelper.database;
    final result = await db.query('foods');
    debugPrint("📦 Local DB dan ${result.length} ta mahsulot olindi");
    return result;
  }

  static Future<void> clearFoods() async {
    final db = await DBHelper.database;
    await db.delete('foods');
    debugPrint("🗑️ Mahsulotlar tozalandi");
  }
}
