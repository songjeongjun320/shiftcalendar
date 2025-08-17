import 'package:flutter/material.dart';
import 'shift_type.dart';
import 'alarm_enums.dart';

class ShiftAlarm {
  final String id;
  final String patternId;
  final AlarmType alarmType;
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
    required this.alarmType,
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
  
  String getLocalizedTargetShiftTypesDisplay(BuildContext context) {
    if (targetShiftTypes.length == ShiftType.values.length) {
      return 'All shifts'; // Can be localized if needed
    }
    return targetShiftTypes
        .map((type) => type.localizedDisplayName(context))
        .join(', ');
  }
  
  ShiftAlarm copyWith({
    String? id,
    String? patternId,
    AlarmType? alarmType,
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
      alarmType: alarmType ?? this.alarmType,
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
      'alarm_type': alarmType.name,
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
    final targetShiftTypesSet = (map['target_shift_types'] as String)
        .split(',')
        .map((name) => ShiftType.values.firstWhere((e) => e.name == name, orElse: () => ShiftType.day))
        .toSet();

    AlarmType type;
    if (map['alarm_type'] != null) {
      type = AlarmType.values.byName(map['alarm_type']);
    } else {
      // Legacy data migration: Infer type from target shifts or title
      final title = map['title'] as String? ?? '';
      if (targetShiftTypesSet.contains(ShiftType.night) || title.toLowerCase().contains('night')) {
        type = AlarmType.night;
      } else if (targetShiftTypesSet.contains(ShiftType.day) || title.toLowerCase().contains('day')) {
        type = AlarmType.day;
      } else if (targetShiftTypesSet.contains(ShiftType.off)) {
        type = AlarmType.off;
      } else {
        type = AlarmType.day; // Fallback
      }
    }

    return ShiftAlarm(
      id: map['id'],
      patternId: map['pattern_id'],
      alarmType: type,
      targetShiftTypes: targetShiftTypesSet,
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
  final AlarmTone tone;
  final double volume; // 0.0 to 1.0
  final bool snooze;
  final int snoozeDuration; // minutes
  final int maxSnoozeCount;
  
  const AlarmSettings({
    this.vibration = true,
    this.sound = true,
    this.tone = AlarmTone.wakeupcall,
    this.volume = 0.8,
    this.snooze = true,
    this.snoozeDuration = 10,
    this.maxSnoozeCount = 3,
  });
  
  AlarmSettings copyWith({
    bool? vibration,
    bool? sound,
    AlarmTone? tone,
    double? volume,
    bool? snooze,
    int? snoozeDuration,
    int? maxSnoozeCount,
  }) {
    return AlarmSettings(
      vibration: vibration ?? this.vibration,
      sound: sound ?? this.sound,
      tone: tone ?? this.tone,
      volume: volume ?? this.volume,
      snooze: snooze ?? this.snooze,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'vibration': vibration,
      'sound': sound,
      'tone': tone.name,
      'volume': volume,
      'snooze': snooze,
      'snooze_duration': snoozeDuration,
      'max_snooze_count': maxSnoozeCount,
    };
  }
  
  static AlarmSettings fromMap(Map<String, dynamic> map) {
    return AlarmSettings(
      vibration: map['vibration'] ?? true,
      sound: map['sound'] ?? true,
      tone: AlarmTone.values.firstWhere(
        (e) => e.name == map['tone'],
        orElse: () => AlarmTone.wakeupcall
      ),
      volume: map['volume']?.toDouble() ?? 0.8,
      snooze: map['snooze'] ?? true,
      snoozeDuration: map['snooze_duration'] ?? 10,
      maxSnoozeCount: map['max_snooze_count'] ?? 3,
    );
  }
}