import 'package:notepad/core/data/app_data.dart';

/// Centralizes all hardcoded starter data and testing generation
/// so the main repository doesn't have to compile strings.
class SeedDataService {
  /// Generates the initial tutorial notes for first-time users.
  static List<NotesSection> generateWelcomeNotes() {
    return [
      NotesSection(
        title: 'Welcome to Notepad',
        content:
            'Your new favorite workspace.\n\n'
            '- Use the toolbar below to manually apply styles like bold, italic, or new colors.\n'
            '- Highlight text to add links or change font sizes.\n'
            '- Long-press a note on the home screen to delete it.\n\n'
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
            '- "Make golden retriever huge,"\n'
            '- "Make the word bold look large"\n'
            '- "Underline the second instance of dog"\n'
            '- "Make menu items a checklist"\n'
            '- "Center the last paragraph"',
        cardColorValue: 0xFFEBCB8B,
      ),
      NotesSection(
        title: 'AI tested/working Commands by me',
        content:
            "List items: \n"
            "A\n"
            "B\n"
            "C\n"
            "D\n"
            "\n"
            "Now say: \n"
            "Make list items a list\n"
            "Make b brown\n"
            "Make the 2nd line blue\n"
            "Make the bottom line bold\n"
            "Make the starting line bold\n"
            "Shift the first line to middle\n"
            "Selection highlighter: \n"
            "Select any porion text and say:\n"
            "make these look gold\n"
            "select entire list items and say 'make this sentence a list item'"
            "only keep the list item section for this test to work properly, remove everything else",
      ),
    ];
  }

  /// Generates thousands of dummy notes to verify O(1) map lookups and scrolling performance.
  static List<NotesSection> generateStressTestNotes(int count) {
    return List.generate(
      count,
      (i) => NotesSection(
        title: 'Stress Test Note #$i',
        content:
            'This is a test note to check if the O(1) Map lookup remains fast.',
      ),
    );
  }
}
