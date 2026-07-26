import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Mirrors active note content into SQLite for fast text search using standard SQL.
class SqliteFtsService {
  static const String _dbName = 'notes_search.db';
  static const String _tableName = 'notes_fts';

  static Database? _db;

  static Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

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
      version: 3,
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

  static Future<void> insertOrUpdate(NotesSection note) async {
    if (note.id.trim().isEmpty) return;

    try {
      final db = await database;
      await db.insert(_tableName, {
        'id': note.id,
        'title': note.title,
        'content': note.content,
        'updated_at': note.updatedAt.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('SqliteFtsService: insertOrUpdate failed for ${note.id}: $e');
    }
  }

  static Future<void> remove(String id) async {
    if (id.trim().isEmpty) return;

    try {
      final db = await database;
      await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('SqliteFtsService: remove failed for $id: $e');
    }
  }

  static Future<void> removeBulk(List<String> ids) async {
    if (ids.isEmpty) return;

    final uniqueIds = ids.where((id) => id.trim().isNotEmpty).toSet();
    if (uniqueIds.isEmpty) return;

    try {
      final db = await database;
      final batch = db.batch();

      for (final id in uniqueIds) {
        batch.delete(_tableName, where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('SqliteFtsService: bulk remove failed: $e');
    }
  }

  static Future<void> clear() async {
    try {
      final db = await database;
      await db.delete(_tableName);
    } catch (e) {
      debugPrint('SqliteFtsService: clear failed: $e');
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
          .map((row) => row['id'])
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('SqliteFtsService: search failed: $e');
      return <String>{};
    }
  }

  static Future<Set<String>> searchIdsWithDateRange(
    String query,
    DateTime start,
    DateTime end,
  ) async {
    if (start.isAfter(end)) return const {};

    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const {};

    try {
      final db = await database;
      final results = await db.query(
        _tableName,
        columns: ['id'],
        where:
            '(title LIKE ? OR content LIKE ?) AND updated_at BETWEEN ? AND ?',
        whereArgs: [
          '%$cleanQuery%',
          '%$cleanQuery%',
          start.toIso8601String(),
          end.toIso8601String(),
        ],
      );

      return results
          .map((row) => row['id'])
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('SqliteFtsService: date range search failed: $e');
      return const {};
    }
  }

  static Future<void> reindexAllNotes(List<NotesSection> allNotes) async {
    try {
      await clear();
      final db = await database;
      final batch = db.batch();

      for (final note in allNotes) {
        batch.insert(_tableName, {
          'id': note.id,
          'title': note.title,
          'content': note.content,
          'updated_at': note.updatedAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);
      debugPrint(
        'SqliteFtsService: Successfully reindexed ${allNotes.length} notes.',
      );
    } catch (e) {
      debugPrint('SqliteFtsService: Reindexing failed: $e');
    }
  }
}
