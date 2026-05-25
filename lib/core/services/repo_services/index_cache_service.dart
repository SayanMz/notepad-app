import 'package:flutter/foundation.dart';
import 'package:notepad/core/data/app_data.dart';

class IndexCacheService {
  /// Spawns an Isolate to build the dictionary without freezing the UI.
  /// Use this for bulk operations and background resets.
  static Future<Map<String, int>> buildCacheInBackground(
    List<NotesSection> notes,
  ) async {
    return compute(_syncBuildCache, notes);
  }

  /// Forces the cache to build immediately on the UI thread.
  /// ONLY use this inside getters where the UI needs data instantly.
  static Map<String, int> buildCacheOnMainThread(List<NotesSection> notes) {
    return _syncBuildCache(notes);
  }

  // The actual heavy-lifting loop (kept private)
  static Map<String, int> _syncBuildCache(List<NotesSection> notes) {
    return {for (int i = 0; i < notes.length; i++) notes[i].id: i};
  }

  static void removeEntry(Map<String, int> cache, String id) {
    cache.remove(id);
  }

  static void shiftIndicesFrom(
    Map<String, int> cache,
    List<NotesSection> list,
    int startIndex,
  ) {
    for (int i = startIndex; i < list.length; i++) {
      cache[list[i].id] = i;
    }
  }
}
