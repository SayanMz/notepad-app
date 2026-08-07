// Defines the core Hive data models for note persistence and global application configuration.
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/services/note_preview_util.dart';
import 'package:ulid/ulid.dart';

part 'app_data.g.dart';

String generateNoteId() => 'note_${Ulid().toString().toLowerCase()}';

@HiveType(typeId: 0)
class NotesSection {
  NotesSection({
    String? id,
    required this.title,
    this.positionIndex = 0,
    DateTime? updatedAt,
    this.content = '',
    this.richContent = '',
    this.isDeleted = false,
    this.isPinned = false,
    this.cardColorValue = 0xFFFFFFFF,
  }) : id = id ?? generateNoteId(),
       updatedAt = updatedAt ?? DateTime.now();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  String get displayTitle => title.trim().isEmpty ? 'Untitled Note' : title;

  @HiveField(2)
  String content;

  @HiveField(3)
  String richContent;

  List<PreviewLine>? _cachedPreview;
  String? _lastProcessedContent;

  List<PreviewLine> getPreview(int maxLines, {String? normalizedContent}) {
    final String sourcedData =
        normalizedContent ?? (richContent.isNotEmpty ? richContent : content);

    if (_cachedPreview != null && _lastProcessedContent == sourcedData) {
      return _cachedPreview!.take(maxLines).toList();
    }

    _lastProcessedContent = sourcedData;
    _cachedPreview = extractPreviewLines(sourcedData, maxLines: maxLines);

    return _cachedPreview!.take(maxLines).toList();
  }

  @HiveField(4)
  DateTime updatedAt;

  int get daysLeft => 30 - DateTime.now().difference(updatedAt).inDays;
  bool get isExpired => DateTime.now().difference(updatedAt).inDays >= 30;

  @HiveField(5)
  bool isDeleted;

  @HiveField(6)
  bool isPinned;

  @HiveField(7)
  int cardColorValue;

  Color get cardColor => Color(cardColorValue);
  set cardColor(Color color) => cardColorValue = color.toARGB32();

  @HiveField(8)
  int positionIndex;

  @HiveField(9)
  double scrollOffset = 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'richContent': richContent,
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
    'isPinned': isPinned,
    'cardColorValue': cardColorValue,
  };

  factory NotesSection.fromJson(Map<String, dynamic> json) => NotesSection(
    id: json['id'] as String?,
    title: (json['title'] ?? '') as String,
    content: (json['content'] ?? '') as String,
    richContent: (json['richContent'] ?? '') as String,
    updatedAt: _parseDateTime(json['updatedAt']),
    isDeleted: json['isDeleted'] ?? false,
    isPinned: json['isPinned'] ?? false,
    cardColorValue: json['cardColorValue'] as int? ?? 0xFFFFFFFF,
  );
}

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

@HiveType(typeId: 1)
class AppSettings {
  @HiveField(0)
  final bool isDarkMode;

  @HiveField(1)
  final String? userName;

  @HiveField(2)
  final String? userEmail;

  @HiveField(3)
  final List<int> recentColorValues;

  @HiveField(4)
  final int seedVersion;

  @HiveField(5)
  final DateTime? lastMaintenanceDate;

  const AppSettings({
    this.isDarkMode = false,
    this.userName,
    this.userEmail,
    this.seedVersion = 0,
    this.lastMaintenanceDate,
    this.recentColorValues = const [
      0xFFFFF59D,
      0xFFFFCC80,
      0xFFEF9A9A,
      0xFFCE93D8,
      0xFF90CAF9,
      0xFFA5D6A7,
      0xFFE0E0E0,
    ],
  });

  AppSettings copyWith({
    bool? isDarkMode,
    String? userName,
    String? userEmail,
    String? userAvatarUrl,
    List<int>? recentColorValues,
    bool clearUser = false,
    int? seedVersion,
    DateTime? lastMaintenanceDate,
  }) {
    return AppSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      userName: clearUser ? null : (userName ?? this.userName),
      userEmail: clearUser ? null : (userEmail ?? this.userEmail),
      recentColorValues: recentColorValues ?? this.recentColorValues,
      seedVersion: seedVersion ?? this.seedVersion,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
    );
  }
}
