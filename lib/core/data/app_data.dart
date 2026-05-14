import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/services/note_preview_util.dart';
import 'package:uuid/uuid.dart';

part 'app_data.g.dart';

final _uuid = Uuid();

/// Generates a unique ID for each note.
String generateNoteId() => 'note_${_uuid.v4()}';

/// Holds the full note state: text, metadata, and UI flags.
@HiveType(typeId: 0)
class NotesSection {
  /// Creates a note and fills in safe defaults when fields are omitted.
  NotesSection({
    String? id,
    required this.title,
    this.content = '',
    this.richContent = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.isSelected = false,
    this.isPinned = false,
    this.cardColorValue = 0xFFFFFFFF, // Default to white (int)
  }) : id = id ?? generateNoteId(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  String get displayTitle => title.trim().isEmpty ? 'Untitled Note' : title;

  @HiveField(2)
  String content;

  @HiveField(3)
  String richContent;

  // --- MEMOIZATION CACHE ---
  // This lives in RAM for instant access during scrolling.
  List<String>? _cachedPreview;
  String? _lastProcessedContent;

  // Inside NotesSection class in app_data.dart

  List<String> getPreview(int maxLines) {
    final String sourceData = richContent.isNotEmpty ? richContent : content;

    if (_cachedPreview != null && _lastProcessedContent == sourceData) {
      return _cachedPreview!.take(maxLines).toList();
    }

    _lastProcessedContent = sourceData;
    // Pass the raw JSON to extractor
    _cachedPreview = extractPreviewLines(sourceData, maxLines: 12);

    return _cachedPreview!.take(maxLines).toList();
  }

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  bool isDeleted;

  @HiveField(7)
  bool isPinned;

  @HiveField(8)
  int cardColorValue;

  // Helper getter/setter to work with Color objects in UI, but it doesn't handle the "Save" or "Notify"
  Color get cardColor => Color(cardColorValue);
  set cardColor(Color color) => cardColorValue = color.toARGB32();

  /// UI-only selection state used by bulk actions.
  bool isSelected;

  ///For Cloud Sync and JSON Export
  /// Serializes the note for local storage and export flows.

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'richContent': richContent,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
    'isPinned': isPinned,
    'cardColorValue': cardColorValue,
  };

  // Rebuilds a note from stored JSON and keeps older data compatible.

  factory NotesSection.fromJson(Map<String, dynamic> json) => NotesSection(
    id: json['id'] as String?,
    title: (json['title'] ?? '') as String,
    content: (json['content'] ?? '') as String,
    richContent: (json['richContent'] ?? '') as String,
    createdAt: _parseDateTime(json['createdAt']),
    updatedAt:
        _parseDateTime(json['updatedAt']) ?? _parseDateTime(json['createdAt']),
    isDeleted: json['isDeleted'] ?? false,
    isPinned: json['isPinned'] ?? false,
    cardColorValue: json['cardColorValue'] as int? ?? 0xFFFFFFFF,
  );
}

// Converts a stored date string into `DateTime?`.
DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    debugPrint('Invalid date value in stored note data: $value');
  }
  return parsed;
}

/// Stores app-level preferences such as theme mode.
/// More settings values will be stored here in future as the app grows
@HiveType(typeId: 1)
class AppSettings {
  @HiveField(0)
  final bool isDarkMode;

  @HiveField(1)
  final String? userName; // Cache the name[cite: 6]

  @HiveField(2)
  final String? userEmail; // Cache the email[cite: 6]

  @HiveField(3)
  final String? userAvatarUrl; // Cache the profile pic URL[cite: 6]

  @HiveField(4)
  final List<int> recentColorValues;

  /// Creates settings with a light-theme default.
  const AppSettings({
    this.isDarkMode = false,
    this.userName,
    this.userEmail,
    this.userAvatarUrl,
    this.recentColorValues = const [
      0xFFFFF59D, // Pastel Yellow
      0xFFFFCC80, // Soft Peach
      0xFFEF9A9A, // Light Coral Red
      0xFFCE93D8, // Muted Lilac
      0xFF90CAF9, // Light Sky Blue
      0xFFA5D6A7, // Mint Green
      0xFFE0E0E0, // Neutral Light Gray
    ],
  });

  /// Returns a new settings object with only the requested values changed.
  AppSettings copyWith({
    bool? isDarkMode,
    String? userName,
    String? userEmail,
    String? userAvatarUrl,
    List<int>? recentColorValues,
    bool clearUser = false, // Helper to wipe data on logout
  }) {
    return AppSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      userName: clearUser ? null : (userName ?? this.userName),
      userEmail: clearUser ? null : (userEmail ?? this.userEmail),
      userAvatarUrl: clearUser ? null : (userAvatarUrl ?? this.userAvatarUrl),
      recentColorValues: recentColorValues ?? this.recentColorValues,
    );
  }
}
