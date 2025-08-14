import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/basic_alarm.dart';

class BasicAlarmService {
  final FlutterLocalNotificationsPlugin _notifications;
  
  // Notification channel constants
  static const String _channelId = 'basic_alarm_channel';
  static const String _channelName = 'Basic Alarms';
  static const String _channelDescription = 'General purpose alarms';
  
  BasicAlarmService(this._notifications);
  
  /// Schedule a basic alarm
  Future<void> scheduleBasicAlarm(BasicAlarm alarm) async {
    // Cancel existing notifications for this alarm first
    await cancelBasicAlarm(alarm.id);
    
    if (!alarm.isActive) return;
    
    if (alarm.isOneTime) {
      await _scheduleOneTimeAlarm(alarm);
    } else {
      await _scheduleRecurringAlarm(alarm);
    }
  }
  
  Future<void> _scheduleOneTimeAlarm(BasicAlarm alarm) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
    );
    
    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(Duration(days: 1));
    }
    
    final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);
    
    await _notifications.zonedSchedule(
      alarm.id.hashCode,
      alarm.label,
      'Time to wake up!',
      scheduledTZ,
      _buildNotificationDetails(alarm),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: 
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'basic_alarm',
        'alarmId': alarm.id,
        'scheduledTime': scheduledDate.millisecondsSinceEpoch,
      }),
    );
  }
  
  Future<void> _scheduleRecurringAlarm(BasicAlarm alarm) async {
    final now = DateTime.now();
    
    for (final dayOfWeek in alarm.repeatDays) {
      // Calculate next occurrence of this day
      var scheduledDate = _getNextWeekday(now, dayOfWeek);
      scheduledDate = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        alarm.time.hour,
        alarm.time.minute,
      );
      
      // If this is today but the time has passed, move to next week
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(Duration(days: 7));
      }
      
      final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);
      final notificationId = '${alarm.id}_$dayOfWeek'.hashCode;
      
      await _notifications.zonedSchedule(
        notificationId,
        alarm.label,
        'Time to wake up! (${_getDayName(dayOfWeek)})',
        scheduledTZ,
        _buildNotificationDetails(alarm),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: 
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: jsonEncode({
          'type': 'basic_alarm',
          'alarmId': alarm.id,
          'dayOfWeek': dayOfWeek,
          'scheduledTime': scheduledDate.millisecondsSinceEpoch,
        }),
      );
    }
  }
  
  DateTime _getNextWeekday(DateTime date, int dayOfWeek) {
    final daysUntilTarget = (dayOfWeek - date.weekday) % 7;
    return date.add(Duration(days: daysUntilTarget));
  }
  
  String _getDayName(int dayOfWeek) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayOfWeek - 1];
  }
  
  NotificationDetails _buildNotificationDetails(BasicAlarm alarm) {
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      ongoing: false,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
    );
    
    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
      categoryIdentifier: 'basic_alarm',
    );
    
    return NotificationDetails(android: android, iOS: ios);
  }
  
  /// Cancel a specific basic alarm
  Future<void> cancelBasicAlarm(String alarmId) async {
    final pending = await _notifications.pendingNotificationRequests();
    
    for (final request in pending) {
      if (request.payload != null) {
        try {
          final payload = jsonDecode(request.payload!);
          if (payload['type'] == 'basic_alarm' && payload['alarmId'] == alarmId) {
            await _notifications.cancel(request.id);
          }
        } catch (e) {
          // Invalid payload, skip
        }
      }
    }
  }
  
  /// Cancel all basic alarms
  Future<void> cancelAllBasicAlarms() async {
    final pending = await _notifications.pendingNotificationRequests();
    
    for (final request in pending) {
      if (request.payload != null) {
        try {
          final payload = jsonDecode(request.payload!);
          if (payload['type'] == 'basic_alarm') {
            await _notifications.cancel(request.id);
          }
        } catch (e) {
          // Invalid payload, skip
        }
      }
    }
  }
  
  /// Get all pending basic alarm notifications
  Future<List<PendingNotificationRequest>> getPendingBasicAlarms() async {
    final pending = await _notifications.pendingNotificationRequests();
    
    return pending.where((request) {
      if (request.payload == null) return false;
      
      try {
        final payload = jsonDecode(request.payload!);
        return payload['type'] == 'basic_alarm';
      } catch (e) {
        return false;
      }
    }).toList();
  }
  
  /// Get pending basic alarms count
  Future<int> getPendingBasicAlarmsCount() async {
    final pending = await getPendingBasicAlarms();
    return pending.length;
  }
}