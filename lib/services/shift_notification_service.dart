import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
import 'shift_scheduling_service.dart';
import 'alarm_service_bridge.dart';
import 'shift_alarm_manager.dart';
import 'basic_alarm_service.dart';

class ShiftNotificationService {
  final FlutterLocalNotificationsPlugin _notifications;
  final ShiftSchedulingService _schedulingService;
  late final ShiftAlarmManager _shiftAlarmManager;
  
  // Notification channel constants
  static const String _channelId = 'shift_alarm_channel';
  static const String _channelName = 'Shift Alarms';
  static const String _channelDescription = 'Notifications for shift-based alarms';
  
  ShiftNotificationService(this._notifications, this._schedulingService) {
    // Initialize ShiftAlarmManager with BasicAlarmService
    final basicAlarmService = BasicAlarmService(_notifications);
    _shiftAlarmManager = ShiftAlarmManager(basicAlarmService, ""); // Pass empty string for patternId
  }
  
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
    
    // Create notification channels for Android
    await _createNotificationChannels();
    
    // Validate and request permissions
    final permissionsGranted = await _validateAndRequestPermissions();
    if (!permissionsGranted) {
      throw Exception('Required permissions not granted for alarm functionality');
    }
  }
  
  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Create the main alarm channel
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
      print('Created shift alarm notification channel: $_channelId');
    }
  }

  /// Validate and request all required permissions
  Future<bool> _validateAndRequestPermissions() async {
    final androidSpecific = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidSpecific != null) {
      // Request exact alarm permission
      final bool? exactAlarmPermissionGranted = await androidSpecific.requestExactAlarmsPermission();
      print('Exact alarm permission granted: $exactAlarmPermissionGranted');
      if (exactAlarmPermissionGranted != true) {
        print('ERROR: Exact alarm permission denied - alarms will not work!');
        return false;
      }
      
      // Request notification permission
      final notificationPermission = 
          await androidSpecific.requestNotificationsPermission();
      print('Notification permission granted: $notificationPermission');
      if (notificationPermission != true) {
        print('ERROR: Notification permission denied - alarms will not work!');
        return false;
      }
      
      // Request battery optimization exemption for reliable alarm delivery - CRITICAL FIX
      try {
        // final bool? batteryOptimizationResult = await androidSpecific.requestIgnoreBatteryOptimizations();
        // print('🔋 Battery optimization exemption requested: $batteryOptimizationResult');
        // if (batteryOptimizationResult != true) {
        //   print('⚠️ WARNING: Battery optimization exemption not granted - alarms may not work reliably!');
        //   print('💡 SOLUTION: Please manually disable battery optimization for this app in settings');
        // } else {
        //   print('✅ Battery optimization exemption granted - alarms should work reliably');
        // }
        print('TODO: Implement a reliable way to request battery optimization exemption.');
      } catch (e) {
        print('❌ Could not request battery optimization exemption: $e');
        // Don't fail initialization for this, but warn the user
        print('⚠️ WARNING: Unable to request battery optimization exemption - alarms may not work reliably!');
      }
    }
    
    // Request iOS permissions
    final iosSpecific = _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosSpecific != null) {
      final iosPermissions = await iosSpecific.requestPermissions(
        alert: true, 
        badge: true, 
        sound: true
      );
      if (iosPermissions != true) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Schedule all alarms for a shift pattern
  /// NEW SIMPLE APPROACH: Use BasicAlarm system instead of complex scheduling
  Future<void> scheduleShiftAlarms(
    List<ShiftAlarm> alarms, 
    ShiftPattern pattern,
  ) async {
    print('🚀 NEW SHIFT ALARM SYSTEM: Converting to BasicAlarms...');
    print('   Pattern: ${pattern.name}');
    print('   Total alarms: ${alarms.length}');
    print('   Active alarms: ${alarms.where((a) => a.isActive).length}');
    print('   Inactive alarms: ${alarms.where((a) => !a.isActive).length}');
    
    // IMPORTANT: Cancel BasicAlarms for ALL alarms (active and inactive)
    // This ensures that disabled alarms are properly cancelled
    for (final alarm in alarms) {
      print('🗑️ Cancelling existing BasicAlarms for: ${alarm.title} (active: ${alarm.isActive})');
      await _shiftAlarmManager.cancelShiftAlarms(alarm.id);
    }
    
    // Only schedule BasicAlarms for ACTIVE ShiftAlarms
    for (final alarm in alarms.where((a) => a.isActive)) {
      try {
        print('📋 Processing ACTIVE ShiftAlarm: ${alarm.title}');
        
        // OPTIMIZED: Use weekly recurring pattern instead of 30+ individual alarms
        // This reduces total pending notifications from 60+ to ~10-15 max
        final createdBasicAlarms = await _shiftAlarmManager.scheduleShiftAlarmsAsWeeklyRecurring(
          alarm, 
          pattern,
        );
        
        print('✅ Created ${createdBasicAlarms.length} BasicAlarms for ${alarm.title}');
        
      } catch (e) {
        print('❌ Error processing ShiftAlarm ${alarm.title}: $e');
      }
    }
    
    print('🎉 NEW SHIFT ALARM SYSTEM: All shift alarms processed successfully!');
    print('   Active alarms scheduled, inactive alarms cancelled');
  }

  /// LEGACY METHOD: Keep for compatibility but deprecated
  Future<void> scheduleShiftAlarmsLegacy(
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
    // Enhanced timezone handling with detailed logging
    final now = tz.TZDateTime.now(tz.local);
    print('🕐 Current time: $now (${now.timeZoneName})');
    print('📅 Original scheduled time: ${notification.scheduledTime}');
    
    // Create proper TZDateTime using the notification's scheduled time
    final scheduledDate = tz.TZDateTime(
      tz.local,
      notification.scheduledTime.year,
      notification.scheduledTime.month,
      notification.scheduledTime.day,
      notification.scheduledTime.hour,
      notification.scheduledTime.minute,
    );
    
    print('🎯 Final scheduled time: $scheduledDate (${scheduledDate.timeZoneName})');
    print('⏱️ Time difference: ${scheduledDate.difference(now).inMinutes} minutes from now');
    
    // Validate that the scheduled time is in the future
    if (scheduledDate.isBefore(now)) {
      print('⚠️ WARNING: Attempting to schedule alarm in the past: $scheduledDate');
      print('   Current time: $now');
      print('   Difference: ${now.difference(scheduledDate).inMinutes} minutes ago');
      return; // Don't schedule past alarms
    }
    
    // Check Android permissions before scheduling
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final canScheduleExact = await androidPlugin.canScheduleExactNotifications();
      print('🔐 Can schedule exact notifications: $canScheduleExact');
      if (canScheduleExact != true) {
        print('🚨 CRITICAL: Cannot schedule exact alarms - permission not granted!');
        print('📱 User must enable exact alarm permission in Android settings');
        // Still try to schedule, but warn that it might not work
      }
    }
    
    print('📢 Scheduling alarm for: $scheduledDate (${notification.title})');
    
    try {
      await _notifications.zonedSchedule(
        notification.id,
        notification.title,
        notification.message,
        scheduledDate,
        _buildNotificationDetails(alarm.settings),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode({
          'alarmId': alarm.id,
          'patternId': pattern.id,
          'shiftType': notification.shiftType.name,
          'notificationId': notification.id,
          'scheduledTime': notification.scheduledTime.millisecondsSinceEpoch,
          'title': notification.title,
          'message': notification.message,
          'alarmTone': 'sounds/${alarm.settings.tone.soundPath}.mp3',
          'alarmVolume': alarm.settings.volume,
          'debugInfo': {
            'scheduledAt': DateTime.now().millisecondsSinceEpoch,
            'timezone': tz.local.name,
            'timezoneOffset': scheduledDate.timeZoneOffset.inMinutes,
          },
        }),
      );
      
      print('✅ Successfully scheduled notification ID: ${notification.id} for $scheduledDate');
      
      // Verify the alarm was actually scheduled
      await _verifyAlarmScheduled(notification.id, scheduledDate);
      
      // IMPORTANT: Also schedule with ReliableAlarmService for guaranteed triggering
      try {
        print('🌉 Scheduling with ReliableAlarmService as backup...');
        final reliableSuccess = await AlarmServiceBridge.scheduleWithReliableService(
          id: notification.id,
          scheduledTime: notification.scheduledTime,
          title: notification.title,
          message: notification.message,
          settings: alarm.settings,
        );
        
        if (reliableSuccess) {
          print('✅ ReliableAlarmService backup scheduled successfully');
        } else {
          print('⚠️ Failed to schedule ReliableAlarmService backup - will rely on notification only');
        }
      } catch (e) {
        print('❌ Error scheduling ReliableAlarmService backup: $e');
        print('⚠️ Continuing with notification-only approach');
        // Don't rethrow - we want the notification to still work even if ReliableAlarmService fails
      }
      
    } catch (e) {
      print('❌ ERROR scheduling notification: $e');
      print('   Notification ID: ${notification.id}');
      print('   Scheduled time: $scheduledDate');
      print('   Current time: $now');
      rethrow;
    }
  }
  
  /// Verify that an alarm was actually scheduled
  Future<void> _verifyAlarmScheduled(int notificationId, tz.TZDateTime expectedTime) async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      final foundAlarm = pending.where((req) => req.id == notificationId).firstOrNull;
      
      if (foundAlarm != null) {
        print('✅ Verification: Alarm $notificationId found in pending list');
        print('   Title: ${foundAlarm.title}');
        print('   Body: ${foundAlarm.body}');
      } else {
        print('❌ Verification FAILED: Alarm $notificationId NOT found in pending list!');
        print('   Expected time: $expectedTime');
        print('   Total pending alarms: ${pending.length}');
      }
    } catch (e) {
      print('⚠️ Could not verify alarm scheduling: $e');
    }
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
      sound: settings.sound
          ? RawResourceAndroidNotificationSound(settings.tone.soundPath)
          : null,
      enableVibration: settings.vibration,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: true,
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
            // Cancel flutter_local_notifications
            await _notifications.cancel(request.id);
            
            // Also cancel ReliableAlarmService backup using AlarmServiceBridge
            try {
              await AlarmServiceBridge.cancelWithReliableService(request.id);
            } catch (e) {
              print('⚠️ ShiftNotificationService: Failed to cancel reliable alarm backup for pattern $patternId: $e');
              // Continue with other cancellations
            }
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
            // Cancel flutter_local_notifications
            await _notifications.cancel(request.id);
            
            // Also cancel ReliableAlarmService backup using AlarmServiceBridge
            try {
              await AlarmServiceBridge.cancelWithReliableService(request.id);
              print('✅ ShiftNotificationService: Cancelled both notification and reliable alarm for ID: ${request.id}');
            } catch (e) {
              print('⚠️ ShiftNotificationService: Failed to cancel reliable alarm backup: $e');
              // Continue with other cancellations - notification cancel still succeeded
            }
          }
        } catch (e) {
          // Invalid payload, skip
        }
      }
    }
  }
  
  /// Cancel all scheduled notifications
  Future<void> cancelAllAlarms() async {
    // Get all pending notifications first to cancel ReliableAlarmService backups
    try {
      final pending = await _notifications.pendingNotificationRequests();
      
      // Cancel ReliableAlarmService backups for shift alarms
      for (final request in pending) {
        if (request.payload != null) {
          try {
            final payload = jsonDecode(request.payload!);
            if (payload.containsKey('alarmId') && payload.containsKey('patternId')) {
              // This is a shift alarm notification
              try {
                await AlarmServiceBridge.cancelWithReliableService(request.id);
              } catch (e) {
                // Continue with other cancellations
              }
            }
          } catch (e) {
            // Invalid payload, skip
          }
        }
      }
    } catch (e) {
      print('⚠️ ShiftNotificationService: Error cancelling ReliableAlarmService backups: $e');
    }
    
    // Cancel all flutter_local_notifications
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
  
  /// Debug method - check current scheduled notifications
  Future<void> debugPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    print('=== PENDING NOTIFICATIONS DEBUG ===');
    print('Total pending notifications: ${pending.length}');
    
    for (final notification in pending) {
      print('ID: ${notification.id}');
      print('Title: ${notification.title}');
      print('Body: ${notification.body}');
      print('Payload: ${notification.payload}');
      print('---');
    }
    
    if (pending.isEmpty) {
      print('WARNING: No notifications are currently scheduled!');
    }
  }
}