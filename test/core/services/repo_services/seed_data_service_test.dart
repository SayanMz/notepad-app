import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/services/repo_services/seed_data.dart';

void main() {
  test('generateWelcomeNotes returns the expected onboarding welcome notes', () {
    final notes = SeedDataService.generateWelcomeNotes();

    expect(notes, hasLength(3));
    expect(notes.first.title, '📝 Welcome to your new Notepad');
    expect(notes.first.isPinned, isTrue);
    expect(notes[1].title, '🎙️ AI Voice Formatting: The Basics');
    expect(notes[1].isPinned, isTrue);
    expect(notes[2].title, '🪄 AI Voice Formatting: Advanced Targeting');
    expect(notes[2].isPinned, isTrue);
  });

  test('generateSmartSearchTemplates returns the expected template notes', () {
    final templates = SeedDataService.generateSmartSearchTemplates();

    expect(templates, hasLength(4));
    expect(templates[0].title, 'Garlic Butter Pasta Prep');
    expect(templates[1].title, 'Morning Dumbbell Routine');
    expect(templates[2].title, 'Weekend Cabin Trip Checklist');
    expect(templates[3].title, 'Q3 Product Strategy Sync');
  });

  test('generateStressTestNotes creates unique test entries', () {
    final notes = SeedDataService.generateStressTestNotes(3);

    expect(notes.map((note) => note.title), [
      'Performance Benchmark #0',
      'Performance Benchmark #1',
      'Performance Benchmark #2',
    ]);
    expect(notes.every((note) => note.content.isNotEmpty), isTrue);
    expect(notes.every((note) => note.isPinned == false), isTrue);
  });
}