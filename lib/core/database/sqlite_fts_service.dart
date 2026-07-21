import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Mirrors active note content into SQLite FTS for fast text search.
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
      debugPrint('SqliteFtsService: database init failed: $e');
      rethrow;
    }
  }

  static Future<Database> _initDb() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, _dbName);

      return await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE VIRTUAL TABLE $_tableName USING fts5(
              id UNINDEXED,
              title,
              content,
              updated_at
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('DROP TABLE IF EXISTS $_tableName');
            await db.execute('''
        CREATE VIRTUAL TABLE $_tableName USING fts5(
          id UNINDEXED,
          title,
          content,
          updated_at
        )
      ''');
          }
        },
      );
    } catch (e) {
      debugPrint('SqliteFtsService: failed to open FTS database: $e');
      rethrow;
    }
  }

  static Future<void> insertOrUpdate(NotesSection note) async {
    if (note.id.trim().isEmpty) {
      debugPrint('SqliteFtsService: skipped insertOrUpdate for empty note id.');
      return;
    }

    try {
      final db = await database;
      await db.delete(_tableName, where: 'id = ?', whereArgs: [note.id]);
      await db.insert(_tableName, {
        'id': note.id,
        'title': note.title,
        'content': note.content,
        'updated_at': note.updatedAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('SqliteFtsService: insertOrUpdate failed for ${note.id}: $e');
    }
  }

  static Future<void> remove(String id) async {
    if (id.trim().isEmpty) {
      debugPrint('SqliteFtsService: skipped remove for empty id.');
      return;
    }

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
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return <String>{};

    final sanitizedQuery = normalizedQuery.replaceAll(RegExp(r'[^\w\s]'), '');
    if (sanitizedQuery.trim().isEmpty) return <String>{};

    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT id FROM $_tableName WHERE $_tableName MATCH ?',
        ['${sanitizedQuery.trim()}*'],
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
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const {};
    if (start.isAfter(end)) return const {};

    final sanitizedQuery = normalizedQuery.replaceAll(RegExp(r'[^\w\s]'), '');
    if (sanitizedQuery.trim().isEmpty) return const {};

    try {
      final db = await database;
      final results = await db.rawQuery(
        '''
      SELECT id FROM $_tableName
      WHERE $_tableName MATCH ?
      AND updated_at BETWEEN ? AND ?
      ''',
        [
          '${sanitizedQuery.trim()}*',
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
        });
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
