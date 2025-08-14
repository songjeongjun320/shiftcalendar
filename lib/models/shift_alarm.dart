import 'package:flutter/material.dart';
import 'shift_type.dart';

class ShiftAlarm {
  final String id;
  final String patternId;
  final Set<ShiftType> targetShiftTypes;
  final TimeOfDay time;
  final String title;
  final String message;
  final bool isActive;
  final AlarmSettings settings;
  final DateTime createdAt;
  
  const ShiftAlarm({
    required this.id,
    required this.patternId,
    required this.targetShiftTypes,
    required this.time,
    required this.title,
    required this.message,
    this.isActive = true,
    required this.settings,
    required this.createdAt,
  });
  
  String get targetShiftTypesDisplay {
    if (targetShiftTypes.length == ShiftType.values.length) {
      return 'All shifts';
    }
    return targetShiftTypes
        .map((type) => type.displayName)
        .join(', ');
  }
  
  ShiftAlarm copyWith({
    String? id,
    String? patternId,
    Set<ShiftType>? targetShiftTypes,
    TimeOfDay? time,
    String? title,
    String? message,
    bool? isActive,
    AlarmSettings? settings,
    DateTime? createdAt,
  }) {
    return ShiftAlarm(
      id: id ?? this.id,
      patternId: patternId ?? this.patternId,
      targetShiftTypes: targetShiftTypes ?? this.targetShiftTypes,
      time: time ?? this.time,
      title: title ?? this.title,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pattern_id': patternId,
      'target_shift_types': targetShiftTypes.map((e) => e.name).join(','),
      'time_hour': time.hour,
      'time_minute': time.minute,
      'title': title,
      'message': message,
      'is_active': isActive ? 1 : 0,
      'settings': settings.toMap(),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
  
  static ShiftAlarm fromMap(Map<String, dynamic> map) {
    return ShiftAlarm(
      id: map['id'],
      patternId: map['pattern_id'],
      targetShiftTypes: (map['target_shift_types'] as String)
          .split(',')
          .map((name) => ShiftType.values.firstWhere((e) => e.name == name))
          .toSet(),
      time: TimeOfDay(
        hour: map['time_hour'],
        minute: map['time_minute'],
      ),
      title: map['title'],
      message: map['message'],
      isActive: map['is_active'] == 1,
      settings: AlarmSettings.fromMap(
          map['settings'] is String 
              ? <String, dynamic>{} // Handle legacy data
              : map['settings'] as Map<String, dynamic>
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
  
  @override
  String toString() {
    return '$title at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} for $targetShiftTypesDisplay';
  }
}

class AlarmSettings {
  final bool vibration;
  final bool sound;
  final String soundPath;
  final bool snooze;
  final int snoozeDuration; // minutes
  final int maxSnoozeCount;
  
  const AlarmSettings({
    this.vibration = true,
    this.sound = true,
    this.soundPath = '',
    this.snooze = true,
    this.snoozeDuration = 10,
    this.maxSnoozeCount = 3,
  });
  
  AlarmSettings copyWith({
    bool? vibration,
    bool? sound,
    String? soundPath,
    bool? snooze,
    int? snoozeDuration,
    int? maxSnoozeCount,
  }) {
    return AlarmSettings(
      vibration: vibration ?? this.vibration,
      sound: sound ?? this.sound,
      soundPath: soundPath ?? this.soundPath,
      snooze: snooze ?? this.snooze,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'vibration': vibration,
      'sound': sound,
      'sound_path': soundPath,
      'snooze': snooze,
      'snooze_duration': snoozeDuration,
      'max_snooze_count': maxSnoozeCount,
    };
  }
  
  static AlarmSettings fromMap(Map<String, dynamic> map) {
    return AlarmSettings(
      vibration: map['vibration'] ?? true,
      sound: map['sound'] ?? true,
      soundPath: map['sound_path'] ?? '',
      snooze: map['snooze'] ?? true,
      snoozeDuration: map['snooze_duration'] ?? 10,
      maxSnoozeCount: map['max_snooze_count'] ?? 3,
    );
  }
}