import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/services/note_preview_util.dart';
import 'package:uuid/uuid.dart';

part 'app_data.g.dart';

final _uuid = Uuid();

String generateNoteId() => 'note_${_uuid.v4()}';

@HiveType(typeId: 0)
// Hive models and adapters for note and app settings data live here.
class NotesSection {
  NotesSection({
    String? id,
    this.positionIndex = 0,
    required this.title,
    this.content = '',
    this.richContent = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.isPinned = false,
    this.cardColorValue = 0xFFFFFFFF,
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
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  int get daysLeft => 30 - DateTime.now().difference(updatedAt).inDays;
  bool get isExpired => DateTime.now().difference(updatedAt).inDays >= 30;

  @HiveField(6)
  bool isDeleted;

  @HiveField(7)
  bool isPinned;

  @HiveField(8)
  int cardColorValue;

  Color get cardColor => Color(cardColorValue);
  set cardColor(Color color) => cardColorValue = color.toARGB32();

  @HiveField(9, defaultValue: 0)
  int positionIndex;

  @HiveField(10, defaultValue: 0.0)
  double scrollOffset = 0.0;

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
  final String? userAvatarUrl;

  @HiveField(4)
  final List<int> recentColorValues;

  @HiveField(5, defaultValue: -1)
  final int seedVersion;

  @HiveField(6)
  final DateTime? lastMaintenanceDate;

  const AppSettings({
    this.isDarkMode = false,
    this.userName,
    this.userEmail,
    this.userAvatarUrl,
    this.seedVersion = -1,
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
      userAvatarUrl: clearUser ? null : (userAvatarUrl ?? this.userAvatarUrl),
      recentColorValues: recentColorValues ?? this.recentColorValues,
      seedVersion: seedVersion ?? this.seedVersion,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
    );
  }
}
