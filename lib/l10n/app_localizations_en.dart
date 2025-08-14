// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Shift Calendar';

  @override
  String get welcomeTitle => 'Welcome to Shift Calendar';

  @override
  String get welcomeDescription =>
      'Create shift patterns that automatically schedule alarms based on your work cycle, not fixed weekdays.';

  @override
  String get createPattern => 'Create Pattern';

  @override
  String get useSamplePattern => 'Use Sample Pattern';

  @override
  String get samplePatternDescription =>
      'Create your own pattern or use the sample Day-Day-Night-Night-Off-Off pattern.';

  @override
  String get currentPattern => 'Current Pattern';

  @override
  String get todayShift => 'Today\'s Shift';

  @override
  String get alarms => 'Alarms';

  @override
  String get basicAlarms => 'Basic Alarms';

  @override
  String get upcomingShifts => 'Upcoming Shifts';

  @override
  String get actions => 'Actions';

  @override
  String get dayShift => 'Day Shift';

  @override
  String get nightShift => 'Night Shift';

  @override
  String get offShift => 'Off';

  @override
  String get day => 'Day';

  @override
  String get night => 'Night';

  @override
  String get off => 'Off';

  @override
  String get add => 'Add';

  @override
  String get addAlarm => 'Add Alarm';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get newAlarm => 'New Alarm';

  @override
  String get editAlarm => 'Edit Alarm';

  @override
  String get label => 'Label';

  @override
  String get time => 'Time';

  @override
  String get repeat => 'Repeat';

  @override
  String get alarmTone => 'Alarm tone';

  @override
  String get active => 'Active';

  @override
  String get enableThisAlarm => 'Enable this alarm';

  @override
  String get once => 'Once';

  @override
  String get daily => 'Daily';

  @override
  String get weekdays => 'Weekdays';

  @override
  String get weekends => 'Weekends';

  @override
  String get everyDay => 'Every day';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get mon => 'Mon';

  @override
  String get tue => 'Tue';

  @override
  String get wed => 'Wed';

  @override
  String get thu => 'Thu';

  @override
  String get fri => 'Fri';

  @override
  String get sat => 'Sat';

  @override
  String get sun => 'Sun';

  @override
  String get bell => 'Bell';

  @override
  String get chime => 'Chime';

  @override
  String get classic => 'Classic';

  @override
  String get gentle => 'Gentle';

  @override
  String get radar => 'Radar';

  @override
  String get deleteAlarm => 'Delete Alarm';

  @override
  String get deleteAlarmConfirm => 'Are you sure you want to delete';

  @override
  String get alarmDeleted => 'Alarm deleted';

  @override
  String get alarmTimeUpdated => 'Alarm time updated to';

  @override
  String get alarmSavedAndScheduled => 'Alarm saved and scheduled';

  @override
  String get alarmSavedInactive => 'Alarm saved (inactive)';

  @override
  String get clearAllData => 'Clear All Data';

  @override
  String scheduledNotifications(Object count) {
    return 'Scheduled notifications: $count';
  }

  @override
  String dayShiftAlarms(Object count) {
    return 'Day shift alarms: $count';
  }

  @override
  String nightShiftAlarms(Object count) {
    return 'Night shift alarms: $count';
  }

  @override
  String get noAlarmsConfigured => 'No alarms configured';

  @override
  String get noBasicAlarmsConfigured => 'No basic alarms configured';

  @override
  String get patternCreationTitle => 'Create Shift Pattern';

  @override
  String get choosePresetPattern => 'Choose a preset pattern:';

  @override
  String get createCustomPattern => 'Create Custom Pattern';

  @override
  String get customPattern => 'Custom Pattern';

  @override
  String get patternName => 'Pattern Name';

  @override
  String get buildYourCycle => 'Build your cycle:';

  @override
  String currentCycle(Object count) {
    return 'Current cycle ($count days):';
  }

  @override
  String get clearAll => 'Clear All';

  @override
  String get patternNameHint => 'e.g., My Custom Pattern';

  @override
  String currentCycleDays(Object count) {
    return 'Current cycle ($count days):';
  }

  @override
  String get createShiftPattern => 'Create Shift Pattern';

  @override
  String get selectAlarmTime => 'Select alarm time';

  @override
  String get selectAlarmTone => 'Select alarm tone';

  @override
  String editAlarmTimeFor(Object title) {
    return 'Select alarm time for $title';
  }

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get close => 'Close';

  @override
  String get english => 'English';

  @override
  String get korean => '한국어';

  @override
  String get editAlarmTime => 'Edit alarm time';
}
