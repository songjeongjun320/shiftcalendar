import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
import '../models/shift_type.dart';
import 'package:timezone/timezone.dart' as tz;

class ScheduledNotification {
  final int id;
  final String alarmId;
  final DateTime scheduledTime;
  final String title;
  final String message;
  final ShiftType shiftType;
  
  const ScheduledNotification({
    required this.id,
    required this.alarmId,
    required this.scheduledTime,
    required this.title,
    required this.message,
    required this.shiftType,
  });
}

class ShiftSchedulingService {
  static const int _schedulingHorizonDays = 30; // Schedule 30 days ahead
  static const int _maxNotificationsPerAlarm = 64; // Platform limit consideration
  
  /// Calculate notification schedule for a shift alarm based on its pattern
  Future<List<ScheduledNotification>> calculateAlarmSchedule(
    ShiftAlarm alarm, 
    ShiftPattern pattern,
  ) async {
    final notifications = <ScheduledNotification>[];
    final now = tz.TZDateTime.now(tz.local);
    final horizon = now.add(Duration(days: _schedulingHorizonDays));
    
    int notificationCount = 0;
    
    for (var date = _normalizeDate(now); 
         date.isBefore(horizon) && notificationCount < _maxNotificationsPerAlarm; 
         date = date.add(Duration(days: 1))) {
      
      final shiftType = pattern.getShiftForDate(date.toLocal());
      
      if (alarm.targetShiftTypes.contains(shiftType)) {
        // Create timezone-aware scheduled time
        final scheduledDateTime = tz.TZDateTime(
          tz.local,
          date.year, 
          date.month, 
          date.day,
          alarm.time.hour,
          alarm.time.minute,
        );
        
        // Only schedule if in the future
        if (scheduledDateTime.isAfter(now)) {
          notifications.add(ScheduledNotification(
            id: _generateNotificationId(alarm.id, date.toLocal()),
            alarmId: alarm.id,
            scheduledTime: scheduledDateTime.toLocal(), // Convert back to DateTime for compatibility
            title: alarm.title,
            message: _formatMessage(alarm.message, shiftType),
            shiftType: shiftType,
          ));
          notificationCount++;
        }
      }
    }
    
    return notifications;
  }
  
  /// Get the next scheduled alarm for a pattern
  Future<DateTime?> getNextAlarmTime(
    List<ShiftAlarm> alarms, 
    ShiftPattern pattern,
  ) async {
    DateTime? nextAlarm;
    
    for (final alarm in alarms.where((a) => a.isActive)) {
      final schedule = await calculateAlarmSchedule(alarm, pattern);
      if (schedule.isNotEmpty) {
        final alarmTime = schedule.first.scheduledTime;
        if (nextAlarm == null || alarmTime.isBefore(nextAlarm)) {
          nextAlarm = alarmTime;
        }
      }
    }
    
    return nextAlarm;
  }
  
  /// Get current shift status for a pattern
  ShiftType getCurrentShift(ShiftPattern pattern) {
    return pattern.getShiftForDate(tz.TZDateTime.now(tz.local).toLocal());
  }
  
  /// Get upcoming shifts within the scheduling horizon
  List<ShiftSchedulePreview> getUpcomingShifts(
    ShiftPattern pattern,
    {int daysAhead = 7}
  ) {
    final previews = <ShiftSchedulePreview>[];
    final today = DateTime.now();
    
    for (int i = 0; i < daysAhead; i++) {
      final date = DateTime(
        today.year,
        today.month,
        today.day + i,
      );
      
      final shift = pattern.getShiftForDate(date);
      previews.add(ShiftSchedulePreview(
        date: date,
        shiftType: shift,
        isToday: i == 0,
      ));
    }
    
    return previews;
  }
  
  /// Calculate total scheduled notifications across all patterns and alarms
  Future<int> getTotalScheduledNotifications(
    List<ShiftAlarm> allAlarms,
    List<ShiftPattern> allPatterns,
  ) async {
    int total = 0;
    
    for (final pattern in allPatterns.where((p) => p.isActive)) {
      final patternAlarms = allAlarms.where((a) => 
          a.patternId == pattern.id && a.isActive).toList();
      
      for (final alarm in patternAlarms) {
        final schedule = await calculateAlarmSchedule(alarm, pattern);
        total += schedule.length;
      }
    }
    
    return total;
  }
  
  /// Format alarm message with shift context
  String _formatMessage(String template, ShiftType shift) {
    return template
        .replaceAll('{shift}', shift.displayName)
        .replaceAll('{shift_code}', shift.shortCode)
        .replaceAll('{shift_desc}', shift.description);
  }
  
  /// Generate unique but deterministic notification ID
  int _generateNotificationId(String alarmId, DateTime date) {
    // Use a more unique combination to reduce collisions
    final timestamp = date.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24); // Days since epoch
    final alarmHash = alarmId.hashCode.abs();
    final combined = (alarmHash + timestamp) % 2147483647;
    print('Generated notification ID: $combined for alarm $alarmId on ${date.toString().substring(0, 10)}');
    return combined;
  }
  
  /// Normalize date to start of day
  tz.TZDateTime _normalizeDate(tz.TZDateTime date) {
    return tz.TZDateTime(tz.local, date.year, date.month, date.day);
  }
  
  /// Validate if a pattern has valid alarm setup
  bool validatePatternAlarms(ShiftPattern pattern, List<ShiftAlarm> alarms) {
    final patternAlarms = alarms.where((a) => a.patternId == pattern.id);
    
    // Check if pattern has at least one active alarm
    if (!patternAlarms.any((a) => a.isActive)) {
      return false;
    }
    
    // Check for conflicting alarms (same time, same shift types)
    for (final alarm1 in patternAlarms) {
      for (final alarm2 in patternAlarms) {
        if (alarm1.id != alarm2.id &&
            alarm1.time == alarm2.time &&
            alarm1.targetShiftTypes.intersection(alarm2.targetShiftTypes).isNotEmpty) {
          return false; // Conflicting alarms found
        }
      }
    }
    
    return true;
  }
}

class ShiftSchedulePreview {
  final DateTime date;
  final ShiftType shiftType;
  final bool isToday;
  
  const ShiftSchedulePreview({
    required this.date,
    required this.shiftType,
    required this.isToday,
  });
  
  String get weekdayName {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }
  
  String get dateDisplay {
    return '${date.month}/${date.day}';
  }
}