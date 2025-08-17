import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/basic_alarm.dart';
import '../models/alarm_enums.dart';
import '../main.dart';
import 'alarm_service_bridge.dart';
import 'cycle_alarm_manager.dart';

class BasicAlarmService {
  final FlutterLocalNotificationsPlugin _notifications;
  static const _basicAlarmsKey = 'basic_alarms';
  
  // Timer tracking for cleanup
  static final Map<String, Timer> _activeTimers = {};
  
  // 🔄 Cycle-based alarm management
  late final CycleAlarmManager _cycleManager;
  
  // Notification channel constants
  static const String _channelId = 'basic_alarm_channel';
  static const String _channelName = 'Basic Alarms';
  static const String _channelDescription = 'General purpose alarms';
  
  BasicAlarmService(this._notifications) {
    _cycleManager = CycleAlarmManager(this);
  }
  
  /// 🔄 Get access to cycle manager for external operations
  CycleAlarmManager get cycleManager => _cycleManager;
  
  /// Initialize the basic alarm service and create notification channels
  Future<void> initialize() async {
    await _createNotificationChannels();
    print('BasicAlarmService initialized');
  }

  Future<List<BasicAlarm>> getAllBasicAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Try to get as String first (new format)
    final alarmsJson = prefs.getString(_basicAlarmsKey);
    
    if (alarmsJson != null) {
      try {
        final alarmsList = jsonDecode(alarmsJson) as List;
        return alarmsList
            .map((json) => BasicAlarm.fromMap(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error parsing basic alarms from String format: $e');
        // Fall through to try legacy format
      }
    }
    
    // Try to get as StringList (legacy format) for migration
    try {
      final legacyAlarmsJson = prefs.getStringList(_basicAlarmsKey);
      if (legacyAlarmsJson != null) {
        print('🔄 Migrating basic alarms from legacy StringList format...');
        final alarms = legacyAlarmsJson
            .map((json) => BasicAlarm.fromMap(jsonDecode(json)))
            .toList();
        
        // Save in new format
        await _saveBasicAlarms(alarms);
        print('✅ Successfully migrated ${alarms.length} basic alarms to new format');
        
        return alarms;
      }
    } catch (e) {
      print('Error migrating basic alarms from legacy format: $e');
    }
    
    return [];
  }

  Future<void> _saveBasicAlarms(List<BasicAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = alarms.map((alarm) => alarm.toMap()).toList();
    await prefs.setString(_basicAlarmsKey, jsonEncode(alarmsJson));
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
    
    // CRITICAL FIX: Check for duplicate alarms before scheduling
    final existingAlarms = await getPendingBasicAlarms();
    final duplicates = existingAlarms.where((req) {
      if (req.payload == null) return false;
      try {
        final payload = jsonDecode(req.payload!);
        return payload['alarmId'] == alarm.id;
      } catch (e) {
        return false;
      }
    }).toList();
    
    if (duplicates.isNotEmpty) {
      print('⚠️ Found ${duplicates.length} existing notifications for alarm ${alarm.id}');
      print('   🚫 DUPLICATE PREVENTION: Will cancel existing notifications first');
      
      // Force cancel all existing duplicates before scheduling new one
      for (final duplicate in duplicates) {
        try {
          final payload = jsonDecode(duplicate.payload!);
          final existingAlarmId = payload['alarmId'];
          print('     - Cancelling duplicate notification ${duplicate.id} for alarm $existingAlarmId');
          await cancelBasicAlarm(existingAlarmId);
        } catch (e) {
          print('     - Failed to cancel duplicate: $e');
        }
      }
      
      print('   ✅ Removed ${duplicates.length} duplicate notifications');
    }
    
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
    
    // CRITICAL FIX: Use specific scheduledDate if provided (for shift alarms)
    late tz.TZDateTime scheduledDate;
    
    if (alarm.scheduledDate != null) {
      // Use the specific date from the alarm
      scheduledDate = tz.TZDateTime(
        tz.local,
        alarm.scheduledDate!.year,
        alarm.scheduledDate!.month,
        alarm.scheduledDate!.day,
        alarm.time.hour,
        alarm.time.minute,
      );
      print('🎯 Using specific scheduled date: ${alarm.scheduledDate!.toString().substring(0, 10)} at ${alarm.time.hour.toString().padLeft(2, '0')}:${alarm.time.minute.toString().padLeft(2, '0')}');
    } else {
      // Default behavior for regular one-time alarms
      scheduledDate = tz.TZDateTime(
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
      print('⏰ Using default next occurrence: ${scheduledDate.toString()}');
    }
    
    print('Scheduling one-time alarm for: $scheduledDate (${alarm.label})');
    
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
      scheduledDate,
      _buildNotificationDetails(alarm),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    // Schedule alarm screen trigger for automatic alarm screen opening
    await _scheduleAlarmScreenTrigger(alarm, scheduledDate, payload);
    
    print('✅ Scheduled one-time alarm: ${alarm.label} for $scheduledDate');
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

      // Schedule alarm screen trigger for automatic alarm screen opening
      await _scheduleAlarmScreenTrigger(alarm, scheduledTZ, payload);
      
      print('✅ Scheduled recurring alarm for ${_getDayName(dayOfWeek)}: $scheduledTZ');
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
    
    // CRITICAL FIX: Also set up a Timer to directly trigger the alarm screen
    // This provides a backup mechanism if the notification doesn't automatically trigger
    final now = tz.TZDateTime.now(tz.local);
    final timeDifference = scheduledTime.difference(now);
    
    if (timeDifference.inMilliseconds > 0) {
      // Store timer for cleanup when alarm is cancelled
      final timer = Timer(timeDifference, () async {
        print('⏰ Timer-based alarm screen trigger firing for alarm ${alarm.id}');
        
        // Remove timer from tracking once it fires
        _activeTimers.remove(alarm.id);
        
        try {
          // Parse the payload for the alarm screen
          Map<String, dynamic> alarmPayload = {};
          try {
            alarmPayload = jsonDecode(payload);
          } catch (e) {
            print('⚠️ Could not parse alarm payload, using defaults: $e');
            alarmPayload = {
              'title': alarm.label,
              'message': 'Your alarm is ringing!',
              'notificationId': triggerId,
            };
          }
          
          // 🗑️ AUTO-CONSUME: 알람이 트리거되면 자동으로 소모
          print('🗑️ Timer: Auto-consuming triggered alarm...');
          await consumeTriggeredAlarm(alarm.id, alarmPayload);
          
          // Directly navigate to alarm screen via Timer (not notification)
          if (navigatorKey.currentState != null) {
            print('🎯 Timer: Navigator available - pushing to alarm screen');
            await navigatorKey.currentState!.pushNamed('/alarm', arguments: alarmPayload);
            print('✅ Timer: Successfully auto-navigated to alarm screen');
          } else {
            print('❌ Timer: Navigator not available - alarm screen will not show automatically');
          }
        } catch (e) {
          print('❌ Timer: Error auto-triggering alarm screen: $e');
        }
      });
      
      // Track the timer for cleanup
      _activeTimers[alarm.id] = timer;
      
      print('✅ Timer-based alarm screen trigger set for ${timeDifference.inMinutes} minutes from now');
    } else {
      print('⚠️ Scheduled time is in the past, skipping Timer-based trigger');
    }
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
    print('🗑️ Cancelling basic alarm: $alarmId');
    
    // Cancel associated timer if it exists
    final timer = _activeTimers.remove(alarmId);
    if (timer != null) {
      timer.cancel();
      print('   ✅ Cancelled timer for alarm $alarmId');
    }
    
    final pending = await _notifications.pendingNotificationRequests();
    int cancelledCount = 0;
    
    // Cancel all notifications related to this alarm (including triggers)
    for (final request in pending) {
      if (request.payload != null) {
        try {
          final payload = jsonDecode(request.payload!);
          if (payload['type'] == 'basic_alarm' && payload['alarmId'] == alarmId) {
            await _notifications.cancel(request.id);
            cancelledCount++;
            print('   ✅ Cancelled notification ${request.id} (${request.title})');
            
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
      // Also cancel trigger notifications for this alarm
      else if (request.title == 'ALARM TRIGGER' && request.id.toString().contains(alarmId.hashCode.toString())) {
        await _notifications.cancel(request.id);
        cancelledCount++;
        print('   ✅ Cancelled trigger notification ${request.id}');
      }
    }
    
    print('✅ Cancelled $cancelledCount notifications for alarm $alarmId');
  }
  
  /// Cancel alarms by type (day/night/off/basic)
  Future<void> cancelAlarmsByType(AlarmType alarmType) async {
    print('🗑️ Cancelling all ${alarmType.displayName} alarms...');
    
    final alarms = await getAllBasicAlarms();
    final targetAlarms = alarms.where((alarm) => alarm.type == alarmType).toList();
    
    print('   Found ${targetAlarms.length} ${alarmType.displayName} alarms to cancel');
    
    // Cancel each alarm of the specified type
    for (final alarm in targetAlarms) {
      await cancelBasicAlarm(alarm.id);
      print('   ✅ Cancelled: ${alarm.label}');
    }
    
    print('✅ Successfully cancelled ${targetAlarms.length} ${alarmType.displayName} alarms');
  }

  /// Get alarms by type
  Future<List<BasicAlarm>> getAlarmsByType(AlarmType alarmType) async {
    final alarms = await getAllBasicAlarms();
    return alarms.where((alarm) => alarm.type == alarmType).toList();
  }

  /// Cancel all basic alarms
  Future<void> cancelAllBasicAlarms() async {
    print('🗑️ Cancelling all basic alarms...');
    
    // Cancel all active timers
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    print('   ✅ Cancelled ${_activeTimers.length} active timers');
    
    final pending = await _notifications.pendingNotificationRequests();
    int cancelledCount = 0;
    
    await _saveBasicAlarms([]);
    
    for (final request in pending) {
      if (request.payload != null) {
        try {
          final payload = jsonDecode(request.payload!);
          if (payload['type'] == 'basic_alarm') {
            // Cancel flutter_local_notifications
            await _notifications.cancel(request.id);
            cancelledCount++;
            
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
      // Also cancel any trigger notifications
      else if (request.title == 'ALARM TRIGGER') {
        await _notifications.cancel(request.id);
        cancelledCount++;
      }
    }
    
    print('✅ Cancelled $cancelledCount basic alarm notifications');
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
  
  /// 🗑️ AUTO-CONSUME: 알람 트리거 시 자동 소모
  /// 사이클 기반 관리를 위해 알람이 울릴 때 자동으로 삭제하고 카운트 감소
  Future<void> consumeTriggeredAlarm(String alarmId, Map<String, dynamic> payload) async {
    print('🗑️ AUTO-CONSUME: Processing triggered alarm $alarmId');
    
    try {
      // 사이클 알람인지 확인 (ID에 'cycle_'이 포함되어 있으면 SHIFT 알람)
      final isShiftAlarm = alarmId.contains('cycle_');
      
      if (isShiftAlarm) {
        print('   🔄 SHIFT alarm detected - triggering cycle consumption');
        await _cycleManager.consumeAlarm(alarmId, isShiftAlarm: true);
      } else {
        print('   ⚡ Basic alarm detected - triggering basic consumption');
        await _cycleManager.consumeAlarm(alarmId, isShiftAlarm: false);
      }
      
      // 알람 정보 출력
      final title = payload['title'] ?? 'Unknown Alarm';
      final scheduledTime = payload['scheduledTime'];
      if (scheduledTime != null) {
        final alarmTime = DateTime.fromMillisecondsSinceEpoch(scheduledTime);
        print('   ✅ Consumed: $title at ${alarmTime.toString()}');
      }
      
    } catch (e) {
      print('❌ Error in auto-consume: $e');
      // 에러가 발생해도 알람 화면은 계속 표시되어야 함
    }
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
    print('Active timers: ${_activeTimers.length}');
    
    // Group by alarm ID to detect duplicates
    final Map<String, List<PendingNotificationRequest>> alarmGroups = {};
    
    for (final alarm in basicAlarms) {
      print('Basic Alarm ID: ${alarm.id}');
      print('Title: ${alarm.title}');
      print('Body: ${alarm.body}');
      try {
        final payload = jsonDecode(alarm.payload!);
        final alarmId = payload['alarmId'];
        if (alarmGroups.containsKey(alarmId)) {
          alarmGroups[alarmId]!.add(alarm);
        } else {
          alarmGroups[alarmId] = [alarm];
        }
        print('Alarm ID: $alarmId');
        print('Scheduled time: ${DateTime.fromMillisecondsSinceEpoch(payload['scheduledTime'])}');
      } catch (e) {
        print('Could not parse payload: $e');
      }
      print('---');
    }
    
    // Report duplicates with detailed information
    final duplicates = alarmGroups.entries.where((entry) => entry.value.length > 1);
    if (duplicates.isNotEmpty) {
      print('🚨 DUPLICATE ALARMS DETECTED:');
      for (final duplicate in duplicates) {
        print('   Alarm ID ${duplicate.key}: ${duplicate.value.length} notifications');
        
        // Show details of each duplicate
        for (int i = 0; i < duplicate.value.length; i++) {
          final req = duplicate.value[i];
          try {
            final payload = jsonDecode(req.payload!);
            final scheduledTime = DateTime.fromMillisecondsSinceEpoch(payload['scheduledTime']);
            print('     [$i] Notification ID: ${req.id}, Scheduled: $scheduledTime, Title: ${req.title}');
          } catch (e) {
            print('     [$i] Notification ID: ${req.id}, Title: ${req.title} (payload error: $e)');
          }
        }
      }
      
      print('📊 DUPLICATE SUMMARY:');
      print('   Total unique alarms: ${alarmGroups.length}');
      print('   Alarms with duplicates: ${duplicates.length}');
      print('   Total duplicate notifications: ${duplicates.fold(0, (sum, entry) => sum + entry.value.length)}');
      
      // 🗑️ AUTO-CLEANUP: Remove duplicates automatically
      await cleanupDuplicateAlarms();
    }
    
    if (basicAlarms.isEmpty) {
      print('WARNING: No basic alarms are scheduled!');
    }
  }
  
  /// 🗑️ Cleanup duplicate alarms automatically
  Future<void> cleanupDuplicateAlarms() async {
    print('🧹 CLEANUP: Starting automatic duplicate alarm removal...');
    
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
    
    // Group by alarm ID to find duplicates
    final Map<String, List<PendingNotificationRequest>> alarmGroups = {};
    
    for (final alarm in basicAlarms) {
      try {
        final payload = jsonDecode(alarm.payload!);
        final alarmId = payload['alarmId'];
        if (alarmGroups.containsKey(alarmId)) {
          alarmGroups[alarmId]!.add(alarm);
        } else {
          alarmGroups[alarmId] = [alarm];
        }
      } catch (e) {
        // Skip malformed alarms
        print('⚠️ Skipping malformed alarm ${alarm.id}: $e');
      }
    }
    
    int removedCount = 0;
    
    // For each group with duplicates, keep only the latest one
    for (final entry in alarmGroups.entries) {
      if (entry.value.length > 1) {
        final duplicates = entry.value;
        print('   🔍 Found ${duplicates.length} duplicates for alarm ${entry.key}');
        
        // Sort by scheduled time to keep the latest
        duplicates.sort((a, b) {
          try {
            final payloadA = jsonDecode(a.payload!);
            final payloadB = jsonDecode(b.payload!);
            final timeA = payloadA['scheduledTime'] as int;
            final timeB = payloadB['scheduledTime'] as int;
            return timeA.compareTo(timeB);
          } catch (e) {
            return 0;
          }
        });
        
        // Cancel all but the last (latest) one
        for (int i = 0; i < duplicates.length - 1; i++) {
          final duplicate = duplicates[i];
          print('     🗑️ Removing duplicate notification ${duplicate.id}');
          await _notifications.cancel(duplicate.id);
          removedCount++;
        }
        
        print('     ✅ Kept latest notification ${duplicates.last.id} for alarm ${entry.key}');
      }
    }
    
    print('✅ CLEANUP COMPLETE: Removed $removedCount duplicate notifications');
  }
}