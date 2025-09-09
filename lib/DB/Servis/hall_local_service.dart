import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class HallLocalService {
  static Future<void> upsertHalls(List<Map<String, dynamic>> halls) async {
    final db = await DBHelper.database;
    final batch = db.batch();
    for (final h in halls) {
      batch.insert('halls', h, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getHalls() async {
    final db = await DBHelper.database;
    return db.query('halls');
  }

  static Future<void> clearHalls() async {
    final db = await DBHelper.database;
    await db.delete('halls');
  }
}
