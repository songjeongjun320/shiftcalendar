import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class BasicAlarm {
  final String id;
  final String label;
  final TimeOfDay time;
  final Set<int> repeatDays; // 1=Monday, 2=Tuesday, ..., 7=Sunday
  final bool isActive;
  final AlarmTone tone;
  final double volume; // 0.0 to 1.0
  final DateTime createdAt;

  const BasicAlarm({
    required this.id,
    required this.label,
    required this.time,
    required this.repeatDays,
    this.isActive = true,
    required this.tone,
    this.volume = 0.8,
    required this.createdAt,
  });

  bool get isOneTime => repeatDays.isEmpty;
  
  String get repeatDaysDisplay {
    if (repeatDays.isEmpty) return 'Once';
    if (repeatDays.length == 7) return 'Every day';
    
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selectedDays = repeatDays.toList()..sort();
    
    // Check for weekdays (Mon-Fri)
    if (selectedDays.length == 5 && 
        selectedDays.every((day) => day >= 1 && day <= 5)) {
      return 'Weekdays';
    }
    
    // Check for weekends
    if (selectedDays.length == 2 && 
        selectedDays.contains(6) && selectedDays.contains(7)) {
      return 'Weekends';
    }
    
    return selectedDays.map((day) => weekdays[day - 1]).join(', ');
  }
  
  String getLocalizedRepeatDaysDisplay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (repeatDays.isEmpty) return l10n.once;
    if (repeatDays.length == 7) return l10n.everyDay;
    
    final weekdays = [l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri, l10n.sat, l10n.sun];
    final selectedDays = repeatDays.toList()..sort();
    
    // Check for weekdays (Mon-Fri)
    if (selectedDays.length == 5 && 
        selectedDays.every((day) => day >= 1 && day <= 5)) {
      return l10n.weekdays;
    }
    
    // Check for weekends
    if (selectedDays.length == 2 && 
        selectedDays.contains(6) && selectedDays.contains(7)) {
      return l10n.weekends;
    }
    
    return selectedDays.map((day) => weekdays[day - 1]).join(', ');
  }

  BasicAlarm copyWith({
    String? id,
    String? label,
    TimeOfDay? time,
    Set<int>? repeatDays,
    bool? isActive,
    AlarmTone? tone,
    double? volume,
    DateTime? createdAt,
  }) {
    return BasicAlarm(
      id: id ?? this.id,
      label: label ?? this.label,
      time: time ?? this.time,
      repeatDays: repeatDays ?? this.repeatDays,
      isActive: isActive ?? this.isActive,
      tone: tone ?? this.tone,
      volume: volume ?? this.volume,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'time_hour': time.hour,
      'time_minute': time.minute,
      'repeat_days': repeatDays.join(','),
      'is_active': isActive ? 1 : 0,
      'tone': tone.name,
      'volume': volume,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  static BasicAlarm fromMap(Map<String, dynamic> map) {
    final repeatDaysString = map['repeat_days'] as String? ?? '';
    final repeatDays = repeatDaysString.isEmpty 
        ? <int>{}
        : repeatDaysString.split(',').map(int.parse).toSet();
        
    return BasicAlarm(
      id: map['id'],
      label: map['label'] ?? 'Alarm',
      time: TimeOfDay(
        hour: map['time_hour'],
        minute: map['time_minute'],
      ),
      repeatDays: repeatDays,
      isActive: map['is_active'] == 1,
      tone: AlarmTone.values.firstWhere(
        (tone) => tone.name == (map['tone'] ?? 'bell'),
        orElse: () => AlarmTone.bell,
      ),
      volume: map['volume']?.toDouble() ?? 0.8,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  @override
  String toString() {
    return '$label at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - $repeatDaysDisplay';
  }
}

enum AlarmTone {
  bell('Bell', 'assets/sounds/bell.mp3'),
  chime('Chime', 'assets/sounds/chime.mp3'),
  classic('Classic', 'assets/sounds/classic.mp3'),
  gentle('Gentle', 'assets/sounds/gentle.mp3'),
  radar('Radar', 'assets/sounds/radar.mp3');

  const AlarmTone(this.displayName, this.soundPath);

  final String displayName;
  final String soundPath;
}

extension AlarmToneLocalization on AlarmTone {
  String localizedDisplayName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case AlarmTone.bell:
        return l10n.bell;
      case AlarmTone.chime:
        return l10n.chime;
      case AlarmTone.classic:
        return l10n.classic;
      case AlarmTone.gentle:
        return l10n.gentle;
      case AlarmTone.radar:
        return l10n.radar;
    }
  }
}