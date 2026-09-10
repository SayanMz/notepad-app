import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:sqflite/sqflite.dart';

abstract class SqliteFtsServiceApi {
  Future<Database> get database;
  Future<void> insertOrUpdate(NotesSection note);
  Future<void> insertOrUpdateBulk(List<NotesSection> notes);
  Future<void> remove(String id);
  Future<void> removeBulk(Set<String> ids);
  Future<void> reindexAllNotes(List<NotesSection> allNotes);

  /// Searches for note IDs using FTS5 MATCH with BM25 ranking.
  /// Returns a List to preserve relevance ordering.
  Future<List<String>> searchIds(String query);
  Future<List<String>> searchIdsWithDateRange(
    String query,
    DateTime start,
    DateTime end,
  );
  Future<List<String>> searchIdsByDateRange(DateTime start, DateTime end);

  Future<void> close();
}

/// Manages a high-performance SQLite search index in volatile RAM.
/// Uses FTS5 with Porter Stemming for fast text matching without disk leakage.
class SqliteFtsService {
  static SqliteFtsServiceApi to = _SqliteFtsServiceImpl();

  static Future<Database> get database => to.database;
  static Future<void> insertOrUpdate(NotesSection note) =>
      to.insertOrUpdate(note);
  static Future<void> insertOrUpdateBulk(List<NotesSection> notes) =>
      to.insertOrUpdateBulk(notes);
  static Future<void> remove(String id) => to.remove(id);
  static Future<void> removeBulk(Set<String> ids) => to.removeBulk(ids);
  static Future<void> reindexAllNotes(List<NotesSection> allNotes) =>
      to.reindexAllNotes(allNotes);
  static Future<List<String>> searchIds(String query) => to.searchIds(query);
  static Future<List<String>> searchIdsWithDateRange(
    String query,
    DateTime start,
    DateTime end,
  ) => to.searchIdsWithDateRange(query, start, end);
  static Future<List<String>> searchIdsByDateRange(
    DateTime start,
    DateTime end,
  ) => to.searchIdsByDateRange(start, end);
  static Future<void> close() => to.close();
}

class _SqliteFtsServiceImpl implements SqliteFtsServiceApi {
  static const String _tableName = 'notes_fts';

  Database? _db;

  @override
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    return await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await _createFtsTable(db);
      },
    );
  }

  Future<void> _createFtsTable(Database db) async {
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $_tableName USING fts5(
        id UNINDEXED,
        title,
        content,
        updated_at UNINDEXED,
        tokenize = "unicode61 remove_diacritics 1 tokenchars '-'"
      )
    ''');
  }

  String _sanitizeFtsQuery(String input) {
    // Replace all non-alphanumeric characters with spaces to prevent
    // phrase/wildcard conflicts (fixes hyphens, dots, and symbols in search).
    final clean = input.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').trim();
    if (clean.isEmpty) return '';

    // Convert "AES-256" -> '"AES"* "256"*' for high-performance wildcard matching
    return clean.split(RegExp(r'\s+')).map((term) => '"$term"*').join(' ');
  }

  @override
  Future<List<String>> searchIds(String query) async {
    final ftsQuery = _sanitizeFtsQuery(query);
    if (ftsQuery.isEmpty) return [];

    try {
      final db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _tableName,
        columns: ['id'],
        where: '$_tableName MATCH ?',
        whereArgs: [ftsQuery],
        // Notes with roughly equal relevance fall back to most recently updated.
        orderBy:
            'ROUND(bm25($_tableName, 0.0, 5.0, 1.0, 0.0), 1) ASC, updated_at DESC',
      );

      return results.map((row) => row['id'] as String).toList();
    } catch (e) {
      debugPrint('FTS Search Error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> searchIdsWithDateRange(
    String query,
    DateTime start,
    DateTime end,
  ) async {
    final ftsQuery = _sanitizeFtsQuery(query);
    if (ftsQuery.isEmpty) return [];

    try {
      final db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _tableName,
        columns: ['id'],
        where: '$_tableName MATCH ? AND updated_at BETWEEN ? AND ?',
        whereArgs: [ftsQuery, start.toIso8601String(), end.toIso8601String()],
        orderBy: 'bm25($_tableName, 0.0, 5.0, 1.0, 0.0) ASC',
      );

      return results.map((row) => row['id'] as String).toList();
    } catch (e) {
      debugPrint('FTS Range Search Error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> searchIdsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _tableName,
        columns: ['id'],
        where: 'updated_at BETWEEN ? AND ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'updated_at DESC',
      );
      return results.map((row) => row['id'] as String).toList();
    } catch (e) {
      debugPrint('FTS Date-Only Search Error: $e');
      return [];
    }
  }

  Map<String, dynamic> _noteToMap(NotesSection note) => {
    'id': note.id,
    'title': note.title,
    'content': note.content,
    'updated_at': note.updatedAt.toIso8601String(),
  };

  @override
  Future<void> insertOrUpdate(NotesSection note) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete(_tableName, where: 'id = ?', whereArgs: [note.id]);
        await txn.insert(_tableName, _noteToMap(note));
      });
    } catch (e) {
      debugPrint('FTS Insert Error: $e');
    }
  }

  @override
  Future<void> insertOrUpdateBulk(List<NotesSection> notes) async {
    if (notes.isEmpty) return;
    try {
      final db = await database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final note in notes) {
          batch.delete(_tableName, where: 'id = ?', whereArgs: [note.id]);
          batch.insert(_tableName, _noteToMap(note));
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      debugPrint('FTS Bulk Insert Error: $e');
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      final db = await database;
      await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('FTS Delete Error: $e');
    }
  }

  @override
  Future<void> removeBulk(Set<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await database;
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete(
        _tableName,
        where: 'id IN ($placeholders)',
        whereArgs: ids.toList(),
      );
    } catch (e) {
      debugPrint('FTS Bulk Delete Error: $e');
    }
  }

  @override
  Future<void> reindexAllNotes(List<NotesSection> allNotes) async {
    try {
      final db = await database;
      final batch = db.batch();
      batch.delete(_tableName);
      for (final note in allNotes) {
        batch.insert(_tableName, _noteToMap(note));
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('FTS Reindex Error: $e');
    }
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
