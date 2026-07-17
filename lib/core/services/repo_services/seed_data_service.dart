// Seed data provides the initial notes and versioned startup content.
import 'package:notepad/core/database/app_data.dart';

class SeedDataService {
  static List<NotesSection> generateWelcomeNotes() {
    return [
      NotesSection(
        title: 'Welcome to Notepad',
        content:
            'Your new favorite workspace.\n\n'
            '- Use the toolbar 🪄 to manually apply styles like bold, italic, or new colors.\n'
            'Dive in and start typing, or check out the next note to see something cool!',
        isPinned: true,
        cardColorValue: 0xFF81A1C1,
      ),
      NotesSection(
        title: 'Meet your AI Assistant',
        content:
            'Why tap when you can talk?\n\n'
            'Tap the floating circle icon to activate your Voice AI. Just speak naturally to format your text.\n\n'
            'Quick commands to try right now:\n'
            '- Highlight this line and say: "Make this green"\n'
            '- Say: "Make everything bold"\n'
            '- Made a mess? Just say: "Clear all formatting" or "Nuke styles"',
        cardColorValue: 0xFFB48EAD,
      ),
      NotesSection(
        title: 'AI Playground',
        content:
            'Test out the engine\'s precision right here.\n\n'
            'The golden retriever is a very intelligent dog. Because it is loyal, the dog makes a great pet.\n\n'
            'Menu items:\n'
            'Pizza\n'
            'Burger\n\n'
            'Try saying these exact commands:\n'
            '- "Make the first line italic"\n'
            '- "Make golden retriever huge"\n'
            '- "Underline the second instance of dog"\n'
            '- "Center the last paragraph"',
        isPinned: true,
        cardColorValue: 0xFFEBCB8B,
      ),
      NotesSection(
        title: 'AI Playground',
        content:
            'List items: \n'
            'A\n'
            'B\n'
            'C\n'
            'D\n'
            '\n'
            'Now say: \n'
            'Make list items a list\n'
            'Make b brown\n'
            'Make the 2nd line blue\n'
            'Make the bottom line bold\n'
            'Make the starting line bold\n'
            'Shift the first line to middle\n'
            'Selection highlighter: \n'
            'Select any porion text and say:\n'
            'make these look gold\n'
            "select entire 'List items' and say 'make this sentence a list item'",
        cardColorValue: 0xFFEBCB8B,
      ),
    ];
  }

  static List<NotesSection> generateStressTestNotes(int count) {
    return List.generate(
      count,
      (index) => NotesSection(
        title: 'Stress Test Note #$index',
        content:
            'Automated performance benchmark tracking record index valuation data block generation sequence.',
      ),
    );
  }
}
