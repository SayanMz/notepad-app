import 'dart:math';
import 'package:notepad/core/database/app_data.dart';

/// In-memory fuzzy search engine implementing multi-term AND matching and Restricted Damerau-Levenshtein distance calculation.
class FuzzySearchService {
  // Inverted index mapping vocabulary terms (length >= 3) to sets of note IDs containing them.
  static final Map<String, Set<String>> _wordIndex = {};

  // Reverse index mapping note IDs to their indexed words for O(1) removals when notes are modified or deleted.
  static final Map<String, Set<String>> _noteToWords = {};

  static Future<void> rebuildIndex(List<NotesSection> notes) async {
    _wordIndex.clear();
    _noteToWords.clear();
    notes.forEach(indexNote);
  }

  /// Indexes a single note by tokenizing its text and inserting terms into the inverted index.
  static void indexNote(NotesSection note) {
    // Evict any existing index entries for this note ID prior to re-indexing.
    removeNote(note.id);
    if (note.isDeleted) return;

    // Extract lowercase alphanumeric terms (>= 3 chars) from combined title and content.
    final words = _extractWords(
      '${note.title} ${note.content}',
    ).where((w) => w.length >= 3).toSet();

    if (words.isEmpty) return;

    _noteToWords[note.id] = words;
    for (final word in words) {
      _wordIndex.putIfAbsent(word, () => <String>{}).add(note.id);
    }
  }

  static void indexNotesBulk(Iterable<NotesSection> notes) =>
      notes.forEach(indexNote);

  static void removeNote(String noteId) {
    final words = _noteToWords.remove(noteId);
    if (words == null) return;

    // Reverse lookup cleanup: Remove note ID from each word's bucket, deleting empty buckets.
    for (final word in words) {
      if (_wordIndex[word] case final ids?) {
        ids.remove(noteId);
        if (ids.isEmpty) _wordIndex.remove(word);
      }
    }
  }

  static void removeNotesBulk(Set<String> noteIds) =>
      noteIds.forEach(removeNote);

  /// Searches vocabulary terms using Damerau-Levenshtein distance.
  /// Applies multi-term intersection (AND matching) so all query words must match a note.
  static Set<String> findMatches(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.length < 2) return {};

    // Split query into terms of 3+ characters; return empty if query is too short.
    final queryTerms = cleanQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .toList();

    if (queryTerms.isEmpty) return {};

    Set<String>? finalMatchingIds;

    for (final term in queryTerms) {
      // Dynamic edit-distance threshold: allow 1 typo for terms length <= 5, and 2 typos for terms length > 5.
      final termThreshold = term.length > 5 ? 2 : 1;
      final termMatches = <String>{};

      for (final MapEntry(key: vocabWord, value: noteIds)
          in _wordIndex.entries) {
        // Length pre-filtering: skip vocabulary terms whose length difference exceeds the threshold.
        if ((vocabWord.length - term.length).abs() > termThreshold) continue;

        // Compare term distance against edit threshold.
        if (_damerauLevenshteinDistance(term, vocabWord) <= termThreshold) {
          termMatches.addAll(noteIds);
        }
      }

      // Intersection AND matching: combine matching note IDs across terms so all query words must match.
      if (finalMatchingIds == null) {
        finalMatchingIds = termMatches;
      } else {
        finalMatchingIds = finalMatchingIds.intersection(termMatches);
      }

      // Short-circuit optimization: exit immediately if running set intersection becomes empty.
      if (finalMatchingIds.isEmpty) return {};
    }

    return finalMatchingIds ?? {};
  }

  /// Helper to tokenize raw string into lowercase alphanumeric words.
  static Set<String> _extractWords(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toSet();
  }

  /// Optimal String Alignment / Restricted Damerau-Levenshtein Distance.
  /// Calculates edit distance accounting for insertions, deletions, substitutions, and adjacent transpositions (e.g. 'teh' -> 'the').
  /// Uses 3 rotating 1D array buffers (h0, h1, h2) to achieve O(M) space complexity instead of O(N*M).
  static int _damerauLevenshteinDistance(String s, String t) {
    // Fast-path equality and empty string checks.
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final n = s.length;
    final m = t.length;

    // Rotating 1D buffer allocation:
    var h0 = List<int>.filled(m + 1, 0); // Row i - 2
    var h1 = List<int>.generate(m + 1, (j) => j); // Row i - 1
    var h2 = List<int>.filled(m + 1, 0); // Row i

    for (int i = 1; i <= n; i++) {
      h2[0] = i;
      final sChar = s[i - 1];

      for (int j = 1; j <= m; j++) {
        final tChar = t[j - 1];
        // Substitution cost: 0 if characters match, 1 otherwise.
        final cost = (sChar == tChar) ? 0 : 1;

        // Standard Levenshtein calculation: min(insertion, deletion, substitution).
        var currentCost = min(min(h2[j - 1] + 1, h1[j] + 1), h1[j - 1] + cost);

        // Damerau Transposition check: handles adjacent character swaps (e.g., 'teh' -> 'the').
        if (i > 1 && j > 1 && sChar == t[j - 2] && s[i - 2] == tChar) {
          currentCost = min(currentCost, h0[j - 2] + 1);
        }

        h2[j] = currentCost;
      }

      // Rotate row buffer references for next iteration without new list allocations.
      final temp = h0;
      h0 = h1;
      h1 = h2;
      h2 = temp;
    }

    return h1[m];
  }
}
