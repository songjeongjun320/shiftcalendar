import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
import 'shift_scheduling_service.dart';

class ShiftNotificationService {
  final FlutterLocalNotificationsPlugin _notifications;
  final ShiftSchedulingService _schedulingService;
  
  // Notification channel constants
  static const String _channelId = 'shift_alarm_channel';
  static const String _channelName = 'Shift Alarms';
  static const String _channelDescription = 'Notifications for shift-based alarms';
  
  ShiftNotificationService(this._notifications, this._schedulingService);
  
  /// Initialize notification system with shift-specific settings
  Future<void> initialize() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _notifications.initialize(initSettings);
    
    // Request permissions
    final androidSpecific = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidSpecific?.requestExactAlarmsPermission();
    await androidSpecific?.requestNotificationsPermission();
    
    final iosSpecific = _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosSpecific?.requestPermissions(
      alert: true, 
      badge: true, 
      sound: true
    );
  }
  
  /// Schedule all alarms for a shift pattern
  Future<void> scheduleShiftAlarms(
    List<ShiftAlarm> alarms, 
    ShiftPattern pattern,
  ) async {
    // Cancel existing notifications for this pattern first
    await _cancelPatternAlarms(pattern.id);
    
    for (final alarm in alarms.where((a) => a.isActive)) {
      final schedule = await _schedulingService.calculateAlarmSchedule(alarm, pattern);
      
      for (final notification in schedule) {
        await _scheduleNotification(notification, alarm, pattern);
      }
    }
  }
  
  /// Schedule a single notification
  Future<void> _scheduleNotification(
    ScheduledNotification notification,
    ShiftAlarm alarm,
    ShiftPattern pattern,
  ) async {
    final scheduledDate = tz.TZDateTime.from(notification.scheduledTime, tz.local);
    
    await _notifications.zonedSchedule(
      notification.id,
      notification.title,
      notification.message,
      scheduledDate,
      _buildNotificationDetails(alarm.settings),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: 
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'alarmId': alarm.id,
        'patternId': pattern.id,
        'shiftType': notification.shiftType.name,
        'notificationId': notification.id,
        'scheduledTime': notification.scheduledTime.millisecondsSinceEpoch,
      }),
    );
  }
  
  /// Build platform-specific notification details
  NotificationDetails _buildNotificationDetails(AlarmSettings settings) {
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: settings.sound,
      enableVibration: settings.vibration,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: false,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
    );
    
    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
      categoryIdentifier: 'shift_alarm',
    );
    
    return NotificationDetails(android: android, iOS: ios);
  }
  
  /// Cancel all alarms for a specific pattern
  Future<void> _cancelPatternAlarms(String patternId) async {
    final pending = await _notifications.pendingNotificationRequests();
    
    for (final request in pending) {
      if (request.payload != null) {
        try {
          final payload = jsonDecode(request.payload!);
          if (payload['patternId'] == patternId) {
            await _notifications.cancel(request.id);
          }
        } catch (e) {
          // Invalid payload, skip
        }
      }
    }
  }
  
  /// Cancel a specific alarm
  Future<void> cancelAlarm(String alarmId) async {
    final pending = await _notifications.pendingNotificationRequests();
    
    for (final request in pending) {
      if (request.payload != null) {
        try {
          final payload = jsonDecode(request.payload!);
          if (payload['alarmId'] == alarmId) {
            await _notifications.cancel(request.id);
          }
        } catch (e) {
          // Invalid payload, skip
        }
      }
    }
  }
  
  /// Cancel all scheduled notifications
  Future<void> cancelAllAlarms() async {
    await _notifications.cancelAll();
  }
  
  /// Get all pending shift alarm notifications
  Future<List<PendingNotificationRequest>> getPendingShiftAlarms() async {
    final pending = await _notifications.pendingNotificationRequests();
    
    return pending.where((request) {
      if (request.payload == null) return false;
      
      try {
        final payload = jsonDecode(request.payload!);
        return payload.containsKey('alarmId') && payload.containsKey('patternId');
      } catch (e) {
        return false;
      }
    }).toList();
  }
  
  /// Get pending notifications count for a specific pattern
  Future<int> getPendingAlarmCount(String patternId) async {
    final pending = await getPendingShiftAlarms();
    
    return pending.where((request) {
      try {
        final payload = jsonDecode(request.payload!);
        return payload['patternId'] == patternId;
      } catch (e) {
        return false;
      }
    }).length;
  }
  
  /// Reschedule all active alarms (call after pattern changes)
  Future<void> rescheduleAllAlarms(
    List<ShiftAlarm> allAlarms,
    List<ShiftPattern> allPatterns,
  ) async {
    await cancelAllAlarms();
    
    for (final pattern in allPatterns.where((p) => p.isActive)) {
      final patternAlarms = allAlarms
          .where((a) => a.patternId == pattern.id)
          .toList();
      
      await scheduleShiftAlarms(patternAlarms, pattern);
    }
  }
  
  /// Get notification statistics
  Future<Map<String, int>> getNotificationStats() async {
    final pending = await getPendingShiftAlarms();
    final Map<String, int> stats = {
      'total': pending.length,
      'day_shifts': 0,
      'night_shifts': 0,
      'patterns': <String>{}.length,
    };
    
    final patterns = <String>{};
    
    for (final request in pending) {
      try {
        final payload = jsonDecode(request.payload!);
        patterns.add(payload['patternId']);
        
        final shiftType = payload['shiftType'];
        if (shiftType == 'day') stats['day_shifts'] = (stats['day_shifts'] ?? 0) + 1;
        if (shiftType == 'night') stats['night_shifts'] = (stats['night_shifts'] ?? 0) + 1;
      } catch (e) {
        // Skip invalid payloads
      }
    }
    
    stats['patterns'] = patterns.length;
    return stats;
  }
}