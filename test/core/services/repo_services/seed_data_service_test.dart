import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/services/repo_services/seed_data_service.dart';

void main() {
  test('generateWelcomeNotes returns the expected seeded notes', () {
    final notes = SeedDataService.generateWelcomeNotes();

    expect(notes, hasLength(4));
    expect(notes.first.title, 'Welcome to Notepad');
    expect(notes.first.isPinned, isTrue);
    expect(notes[1].title, 'Meet your AI Assistant');
    expect(notes[2].title, 'AI Playground');
    expect(notes[3].title, 'AI Playground');
  });

  test('generateStressTestNotes creates unique test entries', () {
    final notes = SeedDataService.generateStressTestNotes(3);

    expect(notes.map((note) => note.title), [
      'Stress Test Note #0',
      'Stress Test Note #1',
      'Stress Test Note #2',
    ]);
    expect(notes.every((note) => note.content.isNotEmpty), isTrue);
    expect(notes.every((note) => note.isPinned == false), isTrue);
  });
}
