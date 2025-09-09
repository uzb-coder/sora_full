import 'package:sqflite/sqflite.dart';
import '../../Offisant/Controller/usersCOntroller.dart';
import 'db_helper.dart';

class UserLocalService {
  static Future<void> clearUsers() async {
    final db = await DBHelper.database;
    await db.delete('users');
  }

  static Future<void> insertUsers(List<User> users) async {
    final db = await DBHelper.database;
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
    final db = await DBHelper.database;
    final maps = await db.query('users');
    return maps.map((e) => User.fromMap(e)).toList();
  }

  static Future<User?> getUserByCode(String userCode) async {
    final db = await DBHelper.database;
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

  static Future<int> updateUserWithPin(String id, String pin) async {
    final db = await DBHelper.database;
    return await db.update(
      'users',
      {'password': pin},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
