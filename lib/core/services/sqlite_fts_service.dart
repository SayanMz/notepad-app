import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class SqliteFtsService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'notes_search.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 🌟 Initialize FTS5 Virtual Table for near O(1) text indexing matching
        await db.execute('''
          CREATE VIRTUAL TABLE notes_fts USING fts5(
            id UNINDEXED,
            title,
            content
          )
        ''');
      },
    );
  }

  static Future<void> insertOrUpdate(
    String id,
    String title,
    String content,
  ) async {
    final db = await database;
    // FTS5 requires a clean drop-and-replace sweep to safely avoid duplication records
    await db.delete('notes_fts', where: 'id = ?', whereArgs: [id]);
    await db.insert('notes_fts', {
      'id': id,
      'title': title,
      'content': content,
    });
  }

  static Future<void> remove(String id) async {
    final db = await database;
    await db.delete('notes_fts', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> removeBulk(List<String> ids) async {
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete('notes_fts', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> clear() async {
    final db = await database;
    await db.delete('notes_fts');
  }

  static Future<List<String>> searchIds(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await database;

    // Sanitize punctuation inputs to safely protect the internal query evaluator from crashing
    final sanitizedQuery = '${query.replaceAll(RegExp(r'[^\w\s]'), '')}*';

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT id FROM notes_fts WHERE notes_fts MATCH ?',
      [sanitizedQuery],
    );
    return List.generate(maps.length, (i) => maps[i]['id'] as String);
  }
}
