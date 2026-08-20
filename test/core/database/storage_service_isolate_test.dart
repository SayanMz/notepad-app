import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/storage_service.dart';

NotesSection _note(int index) {
  return NotesSection(
    id: 'note-$index',
    title: 'Note $index',
    content: 'Content $index',
    updatedAt: DateTime.utc(2024, 1, 1).add(Duration(days: index)),
  );
}

void main() {
  test('exportNotesToJSON and importNotesFromJSON work on the isolate path',
      () async {
    final notes = List.generate(250, _note);

    final encoded = await StorageService.exportNotesToJSON(notes);
    final decodedJson = jsonDecode(encoded) as List<dynamic>;
    final restored = await StorageService.importNotesFromJSON(encoded);

    expect(decodedJson, hasLength(250));
    expect(restored, hasLength(250));
    expect(restored.first.id, 'note-0');
    expect(restored.last.id, 'note-249');
  });

  test('importNotesFromJSON throws a FormatException for malformed JSON', () async {
    // Silence expected FormatException logs
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};

    try {
      await expectLater(
        () => StorageService.importNotesFromJSON('{"broken": true'),
        throwsFormatException,
      );
    } finally {
      debugPrint = originalDebugPrint;
    }
  });
}
