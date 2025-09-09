import 'package:sqflite/sqflite.dart';

import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';

class TableLocalService {
  static Future<void> upsertTables(List<Map<String, dynamic>> tables) async {
    final db = await DBHelper.database;
    final batch = db.batch();
    for (final t in tables) {
      batch.insert('tables', t, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getTables() async {
    final db = await DBHelper.database;
    return db.query('tables');
  }

  static Future<void> clearTables() async {
    final db = await DBHelper.database;
    await db.delete('tables');
  }
}
