# Project Feature Snapshot

This file provides a static reference of the current Notepad feature set.

## Core Editor
- Rich text editing powered by `flutter_quill`.
- Inline formatting for bold, italic, underline, strikethrough, font size, text color, alignment, lists, checklists, and hyperlinks.
- Responsive toolbar controls with centralized selection-state handling.
- Note preview rendering for list views.
- PDF and HTML export support.

## Voice and AI
- Voice-assisted note editing.
- Speech recognition for command capture.
- AI-driven command parsing and formatting execution.
- Spoken feedback for voice command outcomes.

## Home Experience
- Notes list with pinning, sorting, and bulk actions.
- Selection overlay and selection-aware actions.
- Swipe interactions for note management.
- Custom splash experience with Lottie animation.
- Draggable custom color picker for color categorisation of notes.

## Search and Filter
- Search across notes with keywords for title and content.
- Filter support with date and time-based selection.
- Responsive search results with scrollable content with each note card.

## Trash Management
- Dedicated trash / recycle views.
- Swipe-to-restore behavior.
- Empty-state handling for deleted notes.
- Auto-purge notes after 30days.

## Sync and Storage
- Local-first persistence using SQLite.
- Hive-based storage support.
- Secure storage for protected values.
- Google Drive sign-in and backup/sync integration.

## App Infrastructure
- App-wide theming and dark mode support.
- Reusable constants and UI utilities.
- Bootstrap and startup orchestration.
- Cross-platform support for Android, Windows, and desktop workflows.

For cross platform support paste this code on terminal: 
flutter create --platforms=ios,macos,web,linux