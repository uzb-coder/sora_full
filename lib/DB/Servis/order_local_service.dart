import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';

class OrderLocalService
{
  static Future<void> insertOrder(Map<String, dynamic> order, List<Map<String, dynamic>> items) async {
    final db = await DBHelper.database;
    await db.insert('orders', order, conflictAlgorithm: ConflictAlgorithm.replace);

    for (var item in items) {
      await db.insert('order_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    final db = await DBHelper.database;
    return await db.query('orders', where: 'is_synced = 0');
  }

  static Future<void> markOrderAsSynced(String orderId) async {
    final db = await DBHelper.database;
    await db.update(
      'orders',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  static Future<void> markOrderAsCancelled(String orderId) async {
    final db = await DBHelper.database;
    await db.update(
      'orders',
      {'status': 'cancelled'},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}
