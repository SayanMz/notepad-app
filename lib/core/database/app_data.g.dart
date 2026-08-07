// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotesSectionAdapter extends TypeAdapter<NotesSection> {
  @override
  final int typeId = 0;

  @override
  NotesSection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotesSection(
      id: fields[0] as String?,
      title: fields[1] as String,
      positionIndex: fields[8] as int,
      updatedAt: fields[4] as DateTime?,
      content: fields[2] as String,
      richContent: fields[3] as String,
      isDeleted: fields[5] as bool,
      isPinned: fields[6] as bool,
      cardColorValue: fields[7] as int,
    )..scrollOffset = fields[9] as double;
  }

  @override
  void write(BinaryWriter writer, NotesSection obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.richContent)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.isDeleted)
      ..writeByte(6)
      ..write(obj.isPinned)
      ..writeByte(7)
      ..write(obj.cardColorValue)
      ..writeByte(8)
      ..write(obj.positionIndex)
      ..writeByte(9)
      ..write(obj.scrollOffset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotesSectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 1;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      isDarkMode: fields[0] as bool,
      userName: fields[1] as String?,
      userEmail: fields[2] as String?,
      seedVersion: fields[4] as int,
      lastMaintenanceDate: fields[5] as DateTime?,
      recentColorValues: (fields[3] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.isDarkMode)
      ..writeByte(1)
      ..write(obj.userName)
      ..writeByte(2)
      ..write(obj.userEmail)
      ..writeByte(3)
      ..write(obj.recentColorValues)
      ..writeByte(4)
      ..write(obj.seedVersion)
      ..writeByte(5)
      ..write(obj.lastMaintenanceDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
