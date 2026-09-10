import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

abstract class VectorStorageServiceApi {
  Future<Database> get database;
  Future<void> upsertEmbeddings(
    String noteId,
    List<Uint8List> embeddings,
    DateTime updatedAt,
  );
  Future<List<Map<String, dynamic>>> fetchAllEmbeddings({
    DateTime? start,
    DateTime? end,
  });
  Future<void> remove(String noteId);
  Future<void> removeBulk(Set<String> noteIds);
  Future<List<String>> getNoteIdsMissingEmbeddings(List<String> activeNoteIds);
  Future<void> close();
}

/// Manages persistent SQLite vector storage (`vectors.db`) for storing ONNX Float32 Uint8List embedding blobs and timestamps.
class VectorStorageService {
  static VectorStorageServiceApi to = _VectorStorageServiceImpl();

  static Future<Database> get database => to.database;

  static Future<void> upsertEmbeddings(
    String noteId,
    List<Uint8List> embeddings,
    DateTime updatedAt,
  ) => to.upsertEmbeddings(noteId, embeddings, updatedAt);

  static Future<List<Map<String, dynamic>>> fetchAllEmbeddings({
    DateTime? start,
    DateTime? end,
  }) => to.fetchAllEmbeddings(start: start, end: end);

  static Future<void> remove(String noteId) => to.remove(noteId);

  static Future<void> removeBulk(Set<String> noteIds) => to.removeBulk(noteIds);

  static Future<List<String>> getNoteIdsMissingEmbeddings(
    List<String> activeNoteIds,
  ) => to.getNoteIdsMissingEmbeddings(activeNoteIds);

  static Future<void> close() => to.close();
}

class _VectorStorageServiceImpl implements VectorStorageServiceApi {
  static const String _dbName = 'vectors.db';
  static const String _embeddingTable = 'note_embeddings';

  Database? _db;
  final _dbVersion = 1;

  @override
  Future<Database> get database async {
    if (_db != null) return _db!;

    try {
      _db = await _initDb();
      return _db!;
    } catch (e) {
      // Auto-recovery mechanism: If DB fails or gets corrupted, delete and rebuild fresh database.
      debugPrint(
        'VectorStorageService: database init failed: $e. Rebuilding...',
      );
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, _dbName);
      await deleteDatabase(path);

      _db = await _initDb();
      return _db!;
    }
  }

  Future<Database> _initDb() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createEmbeddingTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < _dbVersion) {
          await db.execute('DROP TABLE IF EXISTS $_embeddingTable');
          await _createEmbeddingTable(db);
        }
      },
    );
  }

  Future<void> _createEmbeddingTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_embeddingTable (
        chunk_id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id TEXT NOT NULL,
        embedding BLOB NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_note_embeddings_note_id ON $_embeddingTable(note_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_note_embeddings_updated_at ON $_embeddingTable(updated_at)',
    );
  }

  /// Atomically replaces all existing embedding chunks for [noteId] with fresh vectors and timestamp.
  @override
  Future<void> upsertEmbeddings(
    String noteId,
    List<Uint8List> embeddings,
    DateTime updatedAt,
  ) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        // 1. Delete all existing chunks for this note to prevent stale or orphaned chunks when note length shrinks.
        await txn.delete(
          _embeddingTable,
          where: 'note_id = ?',
          whereArgs: [noteId],
        );
        // 2. Batch insert new Float32 Uint8List embedding chunks with epoch millisecond timestamps.
        final batch = txn.batch();
        final updatedAtMs = updatedAt.millisecondsSinceEpoch;

        for (final embedding in embeddings) {
          batch.insert(_embeddingTable, {
            'note_id': noteId,
            'embedding': embedding,
            'updated_at': updatedAtMs,
          });
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      debugPrint('Embedding Upsert Error: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllEmbeddings({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      final db = await database;
      String? where;
      List<dynamic>? whereArgs;

      // Construct conditional SQL WHERE clause based on optional start/end epoch millisecond timestamps.
      final startMs = start?.millisecondsSinceEpoch;
      final endMs = end?.millisecondsSinceEpoch;

      if (startMs != null && endMs != null) {
        where = 'updated_at BETWEEN ? AND ?';
        whereArgs = [startMs, endMs];
      } else if (startMs != null) {
        where = 'updated_at >= ?';
        whereArgs = [startMs];
      } else if (endMs != null) {
        where = 'updated_at <= ?';
        whereArgs = [endMs];
      }

      return await db.query(
        _embeddingTable,
        columns: ['note_id', 'embedding'],
        where: where,
        whereArgs: whereArgs,
      );
    } catch (e) {
      debugPrint('Embedding Fetch Error: $e');
      return [];
    }
  }

  @override
  Future<void> remove(String noteId) async {
    try {
      final db = await database;
      await db.delete(
        _embeddingTable,
        where: 'note_id = ?',
        whereArgs: [noteId],
      );
    } catch (e) {
      debugPrint('Embedding Delete Error: $e');
    }
  }

  @override
  Future<void> removeBulk(Set<String> noteIds) async {
    if (noteIds.isEmpty) return;
    try {
      final db = await database;
      // Generate parameterized SQL 'IN (?, ?, ...)' placeholders to execute bulk chunk deletion in a single query.
      final placeholders = List.filled(noteIds.length, '?').join(',');
      await db.delete(
        _embeddingTable,
        where: 'note_id IN ($placeholders)',
        whereArgs: noteIds.toList(),
      );
    } catch (e) {
      debugPrint('Embedding Bulk Delete Error: $e');
    }
  }

  /// Compares active note IDs against indexed vectors to return IDs needing embedding generation.
  @override
  Future<List<String>> getNoteIdsMissingEmbeddings(
    List<String> activeNoteIds,
  ) async {
    if (activeNoteIds.isEmpty) return [];

    try {
      final db = await database;
      // Query distinct indexed note IDs from SQLite and subtract them from active note IDs to find unindexed notes.
      final results = await db.rawQuery(
        'SELECT DISTINCT note_id FROM $_embeddingTable',
      );
      final embeddedIds = results
          .map((row) => row['note_id'] as String)
          .toSet();

      return activeNoteIds.where((id) => !embeddedIds.contains(id)).toList();
    } catch (e) {
      debugPrint('Missing Embedding Search Error: $e');
      return [];
    }
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
