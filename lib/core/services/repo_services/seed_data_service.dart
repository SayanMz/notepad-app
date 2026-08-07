import 'package:notepad/core/database/app_data.dart';

/// Seed data provides the initial onboarding notes for fresh installations.
class SeedDataService {
  SeedDataService._();

  /// Generates a minimalist set of 3 welcome notes that guide the user 
  /// through both manual and AI-powered features.
  static List<NotesSection> generateWelcomeNotes() {
    return [
      // --- NOTE 1: THE FOUNDATION ---
      NotesSection(
        title: '📝 Welcome to Notepad',
        content:
            'Your new favorite workspace for capturing thoughts and organizing your life.\n\n'
            'Privacy is built-in: Everything you write is secured with local encryption and stays private on your device.\n\n'
            '✨ Quick Tips:\n'
            '- Tap a note to edit.\n'
            '- Use the toolbar 🪄 below to apply styles like bold, italic, or custom colors.\n'
            '- Swipe any note in the list to move it to the Recycle Bin.',
        isPinned: true,
        cardColorValue: 0xFF14B8A6, // Teal Branding
      ),

      // --- NOTE 2: THE AI ASSISTANT ---
      NotesSection(
        title: '🎙️ Your Smart AI Assistant',
        content:
            'Capture ideas faster than you can type. Tap the floating circle icon to activate your Voice AI.\n\n'
            'Try these commands to see the magic:\n'
            '- Say "Make the first line green" to style text instantly.\n'
            '- Highlight any text and say "Make this bold" or "Link this to google.com".\n'
            '- Say "Clear all formatting" if you want to start fresh.\n\n'
            'It understands context—just speak naturally to transform your thoughts.',
        cardColorValue: 0xFF6366F1, // Indigo AI Theme
      ),

      // --- NOTE 3: THE MASTERCLASS ---
      NotesSection(
        title: '🪄 Advanced AI Masterclass',
        content:
            'Ready to see the engine\'s precision? This note is a playground for advanced positional commands.\n\n'
            'Test these logic paths:\n'
            '- "Make the first sentence italic"\n'
            '- "Underline the last line of this note"\n'
            '- "Turn this paragraph into a checklist"\n'
            '- "Align the starting line to the center"\n\n'
            'The AI respects the structure of your document, allowing for surgical precision without the tap-fatigue.',
        cardColorValue: 0xFFF59E0B, // Amber Warmth
      ),
    ];
  }

  /// Utility for generating dummy data during performance or stress testing.
  static List<NotesSection> generateStressTestNotes(int count) {
    return List.generate(
      count,
      (index) => NotesSection(
        title: 'Performance Benchmark #$index',
        content:
            'Automated stress test entry for evaluating database indexing and scroll physics.',
      ),
    );
  }
}
