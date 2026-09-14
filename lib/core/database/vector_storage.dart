import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

abstract class VectorStorageServiceApi {
  Future<Database> get database;
  Future<void> upsertEmbeddings(String noteId, List<Uint8List> embeddings);
  Future<List<Map<String, dynamic>>> fetchAllEmbeddings({
    List<String>? noteIds,
  });
  Future<void> remove(String noteId);
  Future<void> removeBulk(Set<String> noteIds);
  Future<List<String>> getNoteIdsMissingEmbeddings(List<String> activeNoteIds);
  Future<Map<String, Uint8List>> fetchAllTaxonomyVectors();
  Future<void> saveTaxonomyVector(String topicTitle, Uint8List embedding);
  Future<void> close();
}

/// Manages persistent SQLite vector storage (`vectors.db`) for storing ONNX Float32 Uint8List embedding blobs and timestamps.
class VectorStorageService {
  static VectorStorageServiceApi to = _VectorStorageServiceImpl();

  static Future<Database> get database => to.database;

  static Future<void> upsertEmbeddings(
    String noteId,
    List<Uint8List> embeddings,
  ) => to.upsertEmbeddings(noteId, embeddings);

  static Future<List<Map<String, dynamic>>> fetchAllEmbeddings({
    List<String>? noteIds,
  }) => to.fetchAllEmbeddings(noteIds: noteIds);

  static Future<void> remove(String noteId) => to.remove(noteId);

  static Future<void> removeBulk(Set<String> noteIds) => to.removeBulk(noteIds);

  static Future<List<String>> getNoteIdsMissingEmbeddings(
    List<String> activeNoteIds,
  ) => to.getNoteIdsMissingEmbeddings(activeNoteIds);

  static Future<Map<String, Uint8List>> fetchAllTaxonomyVectors() =>
      to.fetchAllTaxonomyVectors();

  static Future<void> saveTaxonomyVector(
    String topicTitle,
    Uint8List embedding,
  ) => to.saveTaxonomyVector(topicTitle, embedding);

  static Future<void> close() => to.close();
}

class _VectorStorageServiceImpl implements VectorStorageServiceApi {
  static const String _dbName = 'vectors.db';
  static const String _embeddingTable = 'note_embeddings';
  static const String _taxonomyTable = 'taxonomy_vectors';

  Database? _db;
  final _dbVersion = 2;

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
        await _createTaxonomyTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < _dbVersion) {
          await db.execute('DROP TABLE IF EXISTS $_embeddingTable');
          await db.execute('DROP TABLE IF EXISTS $_taxonomyTable');
          await _createEmbeddingTable(db);
          await _createTaxonomyTable(db);
        }
      },
    );
  }

  Future<void> _createEmbeddingTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_embeddingTable (
        chunk_id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id TEXT NOT NULL,
        embedding BLOB NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_note_embeddings_note_id ON $_embeddingTable(note_id)',
    );
  }

  Future<void> _createTaxonomyTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_taxonomyTable (
        topic_title TEXT PRIMARY KEY,
        embedding BLOB NOT NULL
      )
    ''');
  }

  /// Atomically replaces all existing embedding chunks for [noteId] with fresh vectors and timestamp.
  @override
  Future<void> upsertEmbeddings(
    String noteId,
    List<Uint8List> embeddings,
  ) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete(
          _embeddingTable,
          where: 'note_id = ?',
          whereArgs: [noteId],
        );
        final batch = txn.batch();

        for (final embedding in embeddings) {
          batch.insert(_embeddingTable, {
            'note_id': noteId,
            'embedding': embedding,
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
    List<String>? noteIds,
  }) async {
    try {
      final db = await database;

      if (noteIds != null) {
        if (noteIds.isEmpty) return [];
        final placeholders = List.filled(noteIds.length, '?').join(',');
        return await db.query(
          _embeddingTable,
          columns: ['note_id', 'embedding'],
          where: 'note_id IN ($placeholders)',
          whereArgs: noteIds,
        );
      }

      return await db.query(_embeddingTable, columns: ['note_id', 'embedding']);
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
  Future<Map<String, Uint8List>> fetchAllTaxonomyVectors() async {
    try {
      final db = await database;
      final rows = await db.query(
        _taxonomyTable,
        columns: ['topic_title', 'embedding'],
      );
      return {
        for (final row in rows)
          row['topic_title'] as String: row['embedding'] as Uint8List,
      };
    } catch (e) {
      debugPrint('Taxonomy Vectors Fetch Error: $e');
      return {};
    }
  }

  @override
  Future<void> saveTaxonomyVector(
    String topicTitle,
    Uint8List embedding,
  ) async {
    try {
      final db = await database;
      await db.insert(_taxonomyTable, {
        'topic_title': topicTitle,
        'embedding': embedding,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Taxonomy Vector Insert Error: $e');
    }
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
