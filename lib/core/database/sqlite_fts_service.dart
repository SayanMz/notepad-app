import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Manages a high-performance SQLite search index using atomic batch transactions to
// enable ultra-fast text matching and date filtering.
class SqliteFtsService {
  static const String _dbName = 'notes_search.db';
  static const String _tableName = 'notes_fts';

  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;

    try {
      _db = await _initDb();
      return _db!;
    } catch (e) {
      debugPrint('SqliteFtsService: database init failed: $e. Rebuilding...');
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, _dbName);
      await deleteDatabase(path);

      _db = await _initDb();
      return _db!;
    }
  }

  static Future<Database> _initDb() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, _dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Standard table (no virtual tables or FTS extensions needed)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableName (
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            updated_at TEXT
          )
        ''');
      },
    );
  }

  /// Maps a [NotesSection] object to a raw SQL data map.
  static Map<String, dynamic> _noteToMap(NotesSection note) => {
    'id': note.id,
    'title': note.title,
    'content': note.content,
    'updated_at': note.updatedAt.toIso8601String(),
  };

  static Future<void> insertOrUpdate(NotesSection note) async {
    if (note.id.trim().isEmpty) return;

    try {
      final db = await database;
      await db.insert(
        _tableName,
        _noteToMap(note),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('SqliteFtsService Error (insertOrUpdate): ${note.id}. $e');
    }
  }

  static Future<void> insertOrUpdateBulk(List<NotesSection> notes) async {
    if (notes.isEmpty) return;

    try {
      final db = await database;
      final batch = db.batch();

      for (final note in notes) {
        batch.insert(
          _tableName,
          _noteToMap(note),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('SqliteFtsService Error (insertOrUpdateBulk): $e');
    }
  }

  static Future<void> remove(String id) async {
    if (id.trim().isEmpty) return;

    try {
      final db = await database;
      await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('SqliteFtsService Error (remove): $id. $e');
    }
  }

  static Future<void> removeBulk(Set<String> ids) async {
    final cleanIds = ids.where((id) => id.trim().isNotEmpty).toList();
    if (cleanIds.isEmpty) return;

    try {
      final db = await database;

      // SQL Parameter limit is usually 999.
      if (cleanIds.length > 990) {
        debugPrint(
          'SqliteFtsService Warning: bulk removal exceeds parameter limits. '
              'Atomicity not guaranteed for total set.',
        );
      }

      final placeholders = List.filled(cleanIds.length, '?').join(',');

      await db.delete(
        _tableName,
        where: 'id IN ($placeholders)',
        whereArgs: cleanIds,
      );
    } catch (e) {
      debugPrint('SqliteFtsService Error (removeBulk): $e');
    }
  }

  static Future<void> reindexAllNotes(List<NotesSection> allNotes) async {
    try {
      final db = await database;
      final batch = db.batch();

      // Wipe the table and re-populate inside a single atomic transaction.
      batch.delete(_tableName);

      for (final note in allNotes) {
        batch.insert(_tableName, _noteToMap(note));
      }

      await batch.commit(noResult: true);
      debugPrint(
        'SqliteFtsService: Successfully reindexed ${allNotes.length} notes.',
      );
    } catch (e) {
      debugPrint('SqliteFtsService Error (reindexAllNotes): $e');
    }
  }

  static Future<Set<String>> searchIds(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return <String>{};

    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        columns: ['id'],
        where: 'title LIKE ? OR content LIKE ?',
        whereArgs: ['%$cleanQuery%', '%$cleanQuery%'],
      );

      return maps
          .map((row) => row['id']) // Extract only the ID from the database row
          .whereType<String>()     // Ensure it's a valid string
          .where((id) => id.trim().isNotEmpty) // Skip any empty IDs
          .toSet(); // Return as a Set for O(1) lookups
    } catch (e) {
      debugPrint('SqliteFtsService Error (searchIds): $e');
      return <String>{};
    }
  }

  static Future<Set<String>> searchIdsWithDateRange(
    String query,
    DateTime start,
    DateTime end,
  ) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || start.isAfter(end)) return const {};

    try {
      final db = await database;

      final textTerm = '%$cleanQuery%';
      final isoStart = start.toIso8601String();
      final isoEnd = end.toIso8601String();

      final results = await db.query(
        _tableName,
        columns: ['id'],
        where:
            '(title LIKE ? OR content LIKE ?) AND updated_at BETWEEN ? AND ?',
        whereArgs: [
          textTerm, // Matches title LIKE ?
          textTerm, // Matches content LIKE ?
          isoStart, // Matches BETWEEN ?
          isoEnd,   // Matches AND ?
        ],
      );

      return results
          .map((row) => row['id'])
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('SqliteFtsService Error (searchIdsWithDateRange): $e');
      return const {};
    }
  }
}
