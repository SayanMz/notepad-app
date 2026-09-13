import 'package:notepad/core/database/app_data.dart';

/// Seed data service providing initial onboarding notes, AI voice tutorials, smart search templates, and benchmark utilities.
class SeedDataService {
  SeedDataService._();

  static List<NotesSection> generateWelcomeNotes() {
    return [
      // --- NOTE 1: ENGAGING ONBOARDING ---
      NotesSection(
        title: '📝 Welcome to your new Notepad',
        content:
            'Welcome to a simpler, smarter space for your thoughts. Whether you are jotting down a quick grocery list, journaling your day, or planning your next big project, Notepad is designed to get out of your way and let your ideas flow.\n\n'
            '🔒 Total Privacy\n'
            'Your thoughts belong to you. Everything you write is safely locked right here on your phone. No snooping and no tracking—just a completely private space, with the option to securely back up to your personal Google Drive whenever you are ready.\n\n'
            '⚡ Lightning Fast\n'
            'Find exactly what you are looking for in milliseconds, even if you make a typo. And never worry about losing your work again—every single keystroke is automatically saved the moment you type it.\n\n'
            '🧠 A Little Magic\n'
            'Watch your notes organize themselves! Our smart topic discovery quietly groups related ideas together for you. Plus, you can use your voice to format text instantly—check out the next notes to see how the AI assistant works.',
        isPinned: true,
        cardColorValue: 0xFF14B8A6, // Teal Branding
      ),

      // --- NOTE 2: AI COMMANDS (BASICS & SELECTION) ---
      NotesSection(
        title: '🎙️ AI Voice Formatting: The Basics',
        content:
            'Execute hands-free commands and dictate thoughts via our hybrid local and Groq AI integration. Tap the floating circle icon to activate your Voice AI assistant.\n\n'
            'Try highlighting some text and using these selection commands:\n'
            '- "Strike through current selection"\n'
            '- "Link this to google.com"\n'
            '- "Decrease the size of this"\n\n'
            'You can also control the entire document at once:\n'
            '- "Make everything blue"\n'
            '- "Align the entire document to the center"\n'
            '- "Clear all formatting" (wipes all styles to reset your note)',
        cardColorValue: 0xFF6366F1, // Indigo AI Theme
      ),

      // --- NOTE 3: AI COMMANDS (ADVANCED TARGETING) ---
      NotesSection(
        title: '🪄 AI Voice Formatting: Advanced Targeting',
        content:
            'Your AI understands document structure natively, allowing you to format text flexibly without lifting a finger.\n\n'
            'Target specific lines and blocks naturally:\n'
            '- "Make the 3rd line magenta"\n'
            '- "Turn the final paragraph into an ordered list"\n'
            '- "Underline the second sentence"\n\n'
            'Target exact words and phrases with conversational freedom:\n'
            '- "Underline [word]"\n'
            '- "Make the 2nd [word] bold"\n'
            '- "Make the last occurrence of [word] blue"\n'
            '- "Direct [phrase] to google.com"',
        cardColorValue: 0xFF8B5CF6, // Purple AI Theme
      ),
    ];
  }

  /// Injected post-download to populate the Smart Search UI with distinct,
  /// useful templates that the user can either keep or delete.
  static List<NotesSection> generateSmartSearchTemplates() {
    return [
      // --- TOPIC: FOOD & COOKING ---
      NotesSection(
        title: 'Garlic Butter Pasta Prep',
        content:
            'A quick 15-minute dinner for busy weeknights.\n\n'
            'Ingredients:\n'
            '- 200g spaghetti or fettuccine\n'
            '- 4 cloves minced garlic\n'
            '- 3 tbsp unsalted butter\n'
            '- Olive oil, salt, red pepper flakes, and parmesan cheese.\n\n'
            'Boil the pasta until al dente. While it cooks, sauté the garlic in olive oil and butter on low heat. Toss the drained pasta directly into the pan with a splash of pasta water and stir until the sauce emulsifies.',
        cardColorValue: 0xFFF59E0B, // Amber
      ),

      // --- TOPIC: HEALTH & FITNESS ---
      NotesSection(
        title: 'Morning Dumbbell Routine',
        content:
            'Full body workout routine to run 3 days a week. Keep rest times under 60 seconds to maintain heart rate.\n\n'
            '- Warmup: 5 minutes of jumping jacks and dynamic stretching.\n'
            '- Goblet Squats: 3 sets of 12 reps\n'
            '- Dumbbell Romanian Deadlifts: 3 sets of 10 reps\n'
            '- Overhead Shoulder Press: 3 sets of 8 reps\n'
            '- Bent-over Rows: 3 sets of 10 reps\n\n'
            'Remember to drink at least a liter of water and stretch the hamstrings after finishing.',
        cardColorValue: 0xFFEC4899, // Pink
      ),

      // --- TOPIC: TRAVEL & TRANSPORT ---
      NotesSection(
        title: 'Weekend Cabin Trip Checklist',
        content:
            'Packing list for the mountain getaway next weekend:\n\n'
            '- Download offline maps for the mountain roads since cell service drops off near the highway exit.\n'
            '- Pack hiking boots, heavy wool socks, and a waterproof windbreaker.\n'
            '- Bring the portable tire inflator and jumper cables for the car trunk.\n'
            '- Confirm the Airbnb digital lock code and check-in time before we start the drive.',
        cardColorValue: 0xFF8B5CF6, // Purple
      ),

      // --- TOPIC: WORK & STUDY ---
      NotesSection(
        title: 'Q3 Product Strategy Sync',
        content:
            'Meeting notes from the afternoon planning session with the design team.\n\n'
            'Key Action Items:\n'
            '- Finalize the mobile wireframes before the sprint review on Thursday.\n'
            '- Follow up with the marketing team regarding the email campaign timeline.\n'
            '- Review the user retention metrics from the last quarter to see where onboarding drops off.\n\n'
            'I need to draft the project roadmap document and send it to the stakeholders by Friday morning.',
        cardColorValue: 0xFF3B82F6, // Blue
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
