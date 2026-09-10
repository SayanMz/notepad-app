import 'package:notepad/core/database/app_data.dart';

/// Seed data provides the initial onboarding notes for fresh installations.
class SeedDataService {
  SeedDataService._();

  /// Generates a curated set of 6 notes: 2 onboarding feature guides
  /// and 4 distinct, orthogonal semantic notes for smart search topic discovery.
  static List<NotesSection> generateWelcomeNotes() {
    return [
      // --- NOTE 1: THE FOUNDATION FEATURES ---
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

      // --- NOTE 2: AI ASSISTANT & COMMAND MASTERCLASS ---
      NotesSection(
        title: '🎙️ Smart Voice AI & Formatting Commands',
        content:
            'Capture ideas faster than you can type. Tap the floating circle icon to activate your Voice AI assistant.\n\n'
            'Speak naturally to transform text and structure your thoughts instantly:\n'
            '- "Make the first line green" or "Underline the last line"\n'
            '- "Make this bold" or "Link this to google.com"\n'
            '- "Turn this paragraph into a checklist"\n'
            '- "Align the starting line to the center"\n'
            '- "Clear all formatting" if you want to start fresh.\n\n'
            'The AI understands context and respects your document structure without tap-fatigue.',
        isPinned: true,
        cardColorValue: 0xFF6366F1, // Indigo AI Theme
      ),

      // --- NOTE 3: FITNESS & WORKOUT ---
      NotesSection(
        title: 'Strength & Conditioning Regimen',
        content:
            'Weekly Training Split:\n'
            '- Monday: Heavy bench press, overhead dumbbell press, and tricep pushdowns.\n'
            '- Wednesday: Deadlifts, pull-ups, and seated cable rows.\n'
            '- Friday: Barbell squats, Bulgarian split squats, and calf raises.\n\n'
            'Goal: Aim for progressive overload on compound lifts while keeping rest intervals strictly under 90 seconds.',
        cardColorValue: 0xFFEC4899, // Pink
      ),

      // --- NOTE 4: PERSONAL FINANCE & BILLS ---
      NotesSection(
        title: 'Monthly Budget & Savings Plan',
        content:
            'Fixed Obligations:\n'
            '- Electricity, water, and broadband subscriptions cleared on the 1st.\n'
            '- Apartment rent dispatched via standing instruction.\n\n'
            'Investment Allocations:\n'
            '- Transfer 30% of net income into broad-market index mutual funds.\n'
            '- Deposit surplus liquidity into high-yield emergency liquid savings.',
        cardColorValue: 0xFF14B8A6, // Teal
      ),

      // --- NOTE 5: FOOD & COOKING ---
      NotesSection(
        title: 'Artisan Sourdough Bread Recipe & Baking Guide',
        content:
            'Home Cooking & Baking Instructions:\n'
            '- 500g unbleached bread flour\n'
            '- 350ml lukewarm water (70% hydration)\n'
            '- 100g active sourdough starter\n'
            '- 10g fine sea salt\n\n'
            'Culinary Method:\n'
            'Mix flour and water for a 45-minute autolyse. Fold in the starter and salt, '
            'perform stretch-and-folds every 30 minutes, and bake your meal in a preheated Dutch oven kitchen pot at 230°C.',
        cardColorValue: 0xFFF59E0B, // Amber
      ),

      // --- NOTE 6: SOFTWARE & TECH ---
      NotesSection(
        title: 'Software Engineering & App Code Optimization',
        content:
            'Computer Science & Programming Roadmap:\n'
            '- Isolate database queries off the main thread to prevent frame drops in the app.\n'
            '- Introduce secondary indexes on foreign key columns in SQLite.\n'
            '- Profile raster thread compile times and eliminate layout reflows during scroll transitions.\n'
            '- Implement caching algorithms and coding routines for high-frequency model inference outputs.',
        cardColorValue: 0xFF6366F1, // Indigo
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
