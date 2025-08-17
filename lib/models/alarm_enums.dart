import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

enum AlarmType {
  day('day', 'Day Shift'),
  night('night', 'Night Shift'),
  off('off', 'Day Off'),
  basic('basic', 'Basic Alarm');

  const AlarmType(this.value, this.displayName);
  final String value;
  final String displayName;
}

enum AlarmTone {
  anoyingalarm('Annoying Alarm', 'anoyingalarm'),
  cinematicEpicTrailer('Cinematic Epic Trailer', 'cinematic_epic_trailer'),
  emergencyAlarm('Emergency Alarm', 'emergency_alarm'),
  firefighterAlarm('Firefighter Alarm', 'firefighteralarm'),
  funnyAlarm('Funny Alarm', 'funny_alarm'),
  gentleAcoustic('Gentle Acoustic', 'gentle_acoustic'),
  wakeupcall('Wake Up Call', 'wakeupcall');

  const AlarmTone(this.displayName, this.soundPath);

  final String displayName;
  final String soundPath;
}

extension AlarmToneLocalization on AlarmTone {
  String localizedDisplayName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case AlarmTone.anoyingalarm:
        return l10n.annoyingAlarm;
      case AlarmTone.cinematicEpicTrailer:
        return l10n.cinematicEpicTrailer;
      case AlarmTone.emergencyAlarm:
        return l10n.emergencyAlarm;
      case AlarmTone.firefighterAlarm:
        return l10n.firefighterAlarm;
      case AlarmTone.funnyAlarm:
        return l10n.funnyAlarm;
      case AlarmTone.gentleAcoustic:
        return l10n.gentleAcoustic;
      case AlarmTone.wakeupcall:
        return l10n.wakeupCall;
    }
  }
}
