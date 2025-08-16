import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/basic_alarm.dart';
import '../main.dart';
import 'alarm_service_bridge.dart';

class BasicAlarmService {
  final FlutterLocalNotificationsPlugin _notifications;
  
  // Notification channel constants
  static const String _channelId = 'basic_alarm_channel';
  static const String _channelName = 'Basic Alarms';
  static const String _channelDescription = 'General purpose alarms';
  
  BasicAlarmService(this._notifications);
  
  /// Initialize the basic alarm service and create notification channels
  Future<void> initialize() async {
    await _createNotificationChannels();
    print('BasicAlarmService initialized');
  }
  
  /// Create notification channels for basic alarms
  Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Main alarm channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color.fromARGB(255, 255, 0, 0),
          showBadge: true,
        ),
      );
      print('Created basic alarm notification channel: $_channelId');

      // Alarm trigger channel (for automatic screen triggers)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'alarm_trigger_channel',
          'Alarm Triggers',
          description: 'Internal alarm screen triggers',
          importance: Importance.max,
          playSound: false,
          enableVibration: false,
          enableLights: false,
          showBadge: false,
        ),
      );
      print('Created alarm trigger notification channel: alarm_trigger_channel');
    }
  }
  
  /// Schedule a basic alarm
  Future<void> scheduleBasicAlarm(BasicAlarm alarm) async {
    print('=== BASIC ALARM SERVICE: scheduleBasicAlarm called ===');
    print('Alarm ID: ${alarm.id}');
    print('Label: ${alarm.label}');
    print('Time: ${alarm.time}');
    print('Active: ${alarm.isActive}');
    print('One-time: ${alarm.isOneTime}');
    
    try {
      // Cancel existing notifications for this alarm first
      await cancelBasicAlarm(alarm.id);
      print('Cancelled existing notifications for alarm ${alarm.id}');
      
      if (!alarm.isActive) {
        print('Alarm is inactive, skipping scheduling');
        return;
      }
      
      if (alarm.isOneTime) {
        print('Scheduling one-time alarm...');
        await _scheduleOneTimeAlarm(alarm);
      } else {
        print('Scheduling recurring alarm...');
        await _scheduleRecurringAlarm(alarm);
      }
      
      print('=== BASIC ALARM SCHEDULING COMPLETED ===');
    } catch (e) {
      print('ERROR in scheduleBasicAlarm: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }
  
  Future<void> _scheduleOneTimeAlarm(BasicAlarm alarm) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
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
    
    // Fix timezone handling - create proper TZDateTime instead of converting
    final scheduledTZ = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
    );
    
    print('Scheduling one-time alarm for: $scheduledTZ (${alarm.label})');
    
    final payload = jsonEncode({
      'type': 'basic_alarm',
      'alarmId': alarm.id,
      'title': alarm.label,
      'message': 'Time to wake up!',
      'scheduledTime': scheduledDate.millisecondsSinceEpoch,
      'notificationId': alarm.id.hashCode,
      'alarmTone': 'sounds/wakeupcall.mp3',
      'alarmVolume': 0.9,
    });

    await _notifications.zonedSchedule(
      alarm.id.hashCode,
      alarm.label,
      'Time to wake up!',
      scheduledTZ,
      _buildNotificationDetails(alarm),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    // Schedule automatic alarm screen trigger
    await _scheduleAlarmScreenTrigger(alarm, scheduledTZ, payload);
    
    // IMPORTANT: Also schedule with ReliableAlarmService for guaranteed triggering
    try {
      print('🌉 Scheduling with ReliableAlarmService using BasicAlarm settings...');
      final reliableSuccess = await AlarmServiceBridge.scheduleBasicAlarmWithReliableService(
        id: alarm.id.hashCode,
        scheduledTime: scheduledDate,
        title: alarm.label,
        message: 'Time to wake up!',
        customTone: 'sounds/${alarm.tone.soundPath}.mp3',
        customVolume: alarm.volume,
        customVibration: true,
      );
      
      if (reliableSuccess) {
        print('✅ Reliable alarm backup scheduled successfully with user settings');
        print('   Tone: ${alarm.tone.soundPath}');
        print('   Volume: ${alarm.volume}');
      } else {
        print('⚠️ Failed to schedule reliable alarm backup');
      }
    } catch (e) {
      print('❌ Error scheduling reliable alarm backup: $e');
      print('⚠️ Continuing with notification-only approach');
      // Don't rethrow - we want the notification to still work
    }
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
      
      // Fix timezone handling - create proper TZDateTime instead of converting
      final scheduledTZ = tz.TZDateTime(
        tz.local,
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        scheduledDate.hour,
        scheduledDate.minute,
      );
      
      print('Scheduling recurring alarm for: $scheduledTZ (${alarm.label} - ${_getDayName(dayOfWeek)})');
      final notificationId = '${alarm.id}_$dayOfWeek'.hashCode;
      
      final payload = jsonEncode({
        'type': 'basic_alarm',
        'alarmId': alarm.id,
        'title': alarm.label,
        'message': 'Time to wake up! (${_getDayName(dayOfWeek)})',
        'dayOfWeek': dayOfWeek,
        'scheduledTime': scheduledDate.millisecondsSinceEpoch,
        'notificationId': notificationId,
        'alarmTone': 'sounds/wakeupcall.mp3',
        'alarmVolume': 0.9,
      });

      await _notifications.zonedSchedule(
        notificationId,
        alarm.label,
        'Time to wake up! (${_getDayName(dayOfWeek)})',
        scheduledTZ,
        _buildNotificationDetails(alarm),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );

      // Schedule automatic alarm screen trigger
      await _scheduleAlarmScreenTrigger(alarm, scheduledTZ, payload);
      
      // IMPORTANT: Also schedule with ReliableAlarmService for guaranteed triggering
      try {
        print('🌉 Scheduling recurring alarm with ReliableAlarmService using BasicAlarm settings...');
        final reliableSuccess = await AlarmServiceBridge.scheduleBasicAlarmWithReliableService(
          id: notificationId,
          scheduledTime: scheduledDate,
          title: alarm.label,
          message: 'Time to wake up! (${_getDayName(dayOfWeek)})',
          customTone: 'sounds/${alarm.tone.soundPath}.mp3',
          customVolume: alarm.volume,
          customVibration: true,
        );
        
        if (reliableSuccess) {
          print('✅ Reliable alarm backup scheduled successfully for ${_getDayName(dayOfWeek)}');
          print('   Tone: ${alarm.tone.soundPath}');
          print('   Volume: ${alarm.volume}');
        } else {
          print('⚠️ Failed to schedule reliable alarm backup (${_getDayName(dayOfWeek)})');
        }
      } catch (e) {
        print('❌ Error scheduling reliable alarm backup for ${_getDayName(dayOfWeek)}: $e');
        print('⚠️ Continuing with notification-only approach');
        // Don't rethrow - we want the notification to still work
      }
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

  /// Schedule automatic alarm screen trigger for when alarm time arrives
  Future<void> _scheduleAlarmScreenTrigger(BasicAlarm alarm, tz.TZDateTime scheduledTime, String payload) async {
    print('🎯 Scheduling alarm screen trigger for: $scheduledTime');
    
    // Schedule a separate notification that will automatically trigger the alarm screen
    // This uses a different ID to avoid conflicts
    final triggerId = '${alarm.id}_trigger'.hashCode;
    
    await _notifications.zonedSchedule(
      triggerId,
      'ALARM TRIGGER',
      'Opening alarm screen...',
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_trigger_channel',
          'Alarm Triggers',
          channelDescription: 'Internal alarm screen triggers',
          importance: Importance.max,
          priority: Priority.high,
          playSound: false,
          enableVibration: false,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.secret, // Hide from user
          autoCancel: true,
          ongoing: false,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'auto_trigger_alarm',
              'Show Alarm',
              contextual: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    
    print('✅ Alarm screen trigger scheduled with ID: $triggerId');
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
      autoCancel: false,
      ongoing: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'alarm_dismiss',
          'Dismiss',
          titleColor: Color.fromARGB(255, 255, 0, 0),
        ),
        AndroidNotificationAction(
          'alarm_snooze',
          'Snooze',
          titleColor: Color.fromARGB(255, 255, 165, 0),
        ),
      ],
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
            
            // Also cancel reliable alarm backup using AlarmServiceBridge
            try {
              await AlarmServiceBridge.cancelWithReliableService(request.id);
            } catch (e) {
              print('⚠️ Failed to cancel reliable alarm backup: $e');
              // Continue with other cancellations
            }
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
            // Cancel flutter_local_notifications
            await _notifications.cancel(request.id);
            
            // Also cancel ReliableAlarmService backup using AlarmServiceBridge
            try {
              await AlarmServiceBridge.cancelWithReliableService(request.id);
            } catch (e) {
              print('⚠️ BasicAlarmService: Failed to cancel reliable alarm backup: $e');
              // Continue with other cancellations
            }
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
  
  /// Debug method - check pending basic alarms
  Future<void> debugPendingBasicAlarms() async {
    final pending = await _notifications.pendingNotificationRequests();
    final basicAlarms = pending.where((req) {
      if (req.payload == null) return false;
      try {
        final payload = jsonDecode(req.payload!);
        return payload['type'] == 'basic_alarm';
      } catch (e) {
        return false;
      }
    }).toList();
    
    print('=== BASIC ALARMS DEBUG ===');
    print('Total pending notifications: ${pending.length}');
    print('Basic alarm notifications: ${basicAlarms.length}');
    
    for (final alarm in basicAlarms) {
      print('Basic Alarm ID: ${alarm.id}');
      print('Title: ${alarm.title}');
      print('Body: ${alarm.body}');
      try {
        final payload = jsonDecode(alarm.payload!);
        print('Scheduled time: ${DateTime.fromMillisecondsSinceEpoch(payload['scheduledTime'])}');
      } catch (e) {
        print('Could not parse payload: $e');
      }
      print('---');
    }
    
    if (basicAlarms.isEmpty) {
      print('WARNING: No basic alarms are scheduled!');
    }
  }
}