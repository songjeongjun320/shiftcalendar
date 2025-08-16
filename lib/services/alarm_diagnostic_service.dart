import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class AlarmDiagnosticService {
  final FlutterLocalNotificationsPlugin _notifications;
  Timer? _diagnosticTimer;
  bool _isRunning = false;
  
  /// Get the current monitoring status
  bool get isRunning => _isRunning;
  
  /// Get the notifications plugin instance
  FlutterLocalNotificationsPlugin get notifications => _notifications;
  
  AlarmDiagnosticService(this._notifications);
  
  /// Start continuous diagnostic monitoring
  void startDiagnosticMonitoring() {
    if (_isRunning) return;
    
    _isRunning = true;
    print('=== ALARM DIAGNOSTIC SERVICE STARTED ===');
    
    // Log current system information
    _logSystemInfo();
    
    // Start timer that checks every minute
    _diagnosticTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      await _performDiagnosticCheck();
    });
    
    print('Diagnostic monitoring active - checking every minute');
  }
  
  /// Stop diagnostic monitoring
  void stopDiagnosticMonitoring() {
    _diagnosticTimer?.cancel();
    _diagnosticTimer = null;
    _isRunning = false;
    print('=== ALARM DIAGNOSTIC SERVICE STOPPED ===');
  }
  
  /// Log current system information
  void _logSystemInfo() {
    final now = DateTime.now();
    final nowTZ = tz.TZDateTime.now(tz.local);
    
    print('=== SYSTEM DIAGNOSTIC INFO ===');
    print('Current DateTime: $now');
    print('Current TZDateTime: $nowTZ');
    print('System TimeZone: ${now.timeZoneName}');
    print('System TimeZone Offset: ${now.timeZoneOffset}');
    print('TZ Local Location: ${tz.local.name}');
    print('================================');
  }
  
  /// Perform diagnostic check every minute
  Future<void> _performDiagnosticCheck() async {
    final now = DateTime.now();
    final nowTZ = tz.TZDateTime.now(tz.local);
    
    print('🕐 DIAGNOSTIC CHECK: ${now.toString().substring(11, 16)} (${nowTZ.toString().substring(11, 16)})');
    
    // Check pending notifications
    final pending = await _notifications.pendingNotificationRequests();
    final alarmNotifications = pending.where((req) {
      if (req.payload == null) return false;
      try {
        final payload = jsonDecode(req.payload!);
        return payload.containsKey('alarmId') || payload['type'] == 'basic_alarm';
      } catch (e) {
        return false;
      }
    }).toList();
    
    print('📋 Total pending notifications: ${pending.length}');
    print('⏰ Alarm notifications: ${alarmNotifications.length}');
    
    // Check for alarms that should have triggered
    for (final notification in alarmNotifications) {
      try {
        final payload = jsonDecode(notification.payload!);
        final scheduledTime = DateTime.fromMillisecondsSinceEpoch(
          payload['scheduledTime'] as int
        );
        
        final timeDiff = now.difference(scheduledTime);
        
        if (timeDiff.inMinutes >= 0 && timeDiff.inMinutes <= 5) {
          if (timeDiff.inMinutes > 0) {
            print('🚨 MISSED ALARM DETECTED!');
            print('   Notification ID: ${notification.id}');
            print('   Title: ${notification.title}');
            print('   Scheduled: $scheduledTime');
            print('   Current: $now');
            print('   Overdue by: ${timeDiff.inMinutes} minutes');
            print('   Payload: ${notification.payload}');
          } else {
            print('⏰ ALARM DUE NOW!');
            print('   Notification ID: ${notification.id}');
            print('   Title: ${notification.title}');
            print('   Scheduled: $scheduledTime');
          }
        }
        
        // Show upcoming alarms (next 60 minutes)
        if (timeDiff.inMinutes < 0 && timeDiff.inMinutes > -60) {
          final minutesUntil = -timeDiff.inMinutes;
          print('⌛ Upcoming alarm in $minutesUntil minutes: ${notification.title}');
        }
      } catch (e) {
        print('❌ Error parsing notification payload: $e');
      }
    }
    
    // Check if any alarms are scheduled for the current exact minute
    await _checkCurrentMinuteAlarms(now, alarmNotifications);
  }
  
  /// Check if there are alarms scheduled for the current exact minute
  Future<void> _checkCurrentMinuteAlarms(DateTime now, List<PendingNotificationRequest> alarmNotifications) async {
    final currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    
    for (final notification in alarmNotifications) {
      try {
        final payload = jsonDecode(notification.payload!);
        final scheduledTime = DateTime.fromMillisecondsSinceEpoch(
          payload['scheduledTime'] as int
        );
        final scheduledMinute = DateTime(
          scheduledTime.year, 
          scheduledTime.month, 
          scheduledTime.day, 
          scheduledTime.hour, 
          scheduledTime.minute
        );
        
        if (currentMinute.isAtSameMomentAs(scheduledMinute)) {
          print('🔔 ALARM SHOULD TRIGGER NOW!');
          print('   Notification ID: ${notification.id}');
          print('   Title: ${notification.title}');
          print('   Expected time: $scheduledTime');
          print('   Current time: $now');
          
          // Test if we can manually trigger the notification
          await _testManualTrigger(notification);
        }
      } catch (e) {
        print('❌ Error checking current minute alarm: $e');
      }
    }
  }
  
  /// Test manual trigger of a notification
  Future<void> _testManualTrigger(PendingNotificationRequest originalNotification) async {
    try {
      print('🧪 Testing manual trigger for notification ${originalNotification.id}');
      
      // Try to manually show a test notification
      await _notifications.show(
        999999, // Use a distinct ID for test
        'TEST: ${originalNotification.title}',
        'This is a manual test of the alarm that should have triggered automatically',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Test Alarms',
            channelDescription: 'Test notifications for debugging',
            importance: Importance.max,
            priority: Priority.high,
            ongoing: true, // Make test alarm persistent too
            autoCancel: false, // Prevent automatic dismissal
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
        payload: jsonEncode({
          'notificationId': 999999,
          'title': 'TEST Alarm',
          'message': 'This is a manual test of the alarm system',
          'alarmTone': 'sounds/wakeupcall.mp3',
          'alarmVolume': 0.9,
        }),
      );
      
      print('✅ Manual test notification sent successfully');
    } catch (e) {
      print('❌ Failed to send manual test notification: $e');
    }
  }
  
  /// Get detailed system state for debugging
  Future<Map<String, dynamic>> getSystemState() async {
    final now = DateTime.now();
    final nowTZ = tz.TZDateTime.now(tz.local);
    final pending = await _notifications.pendingNotificationRequests();
    
    // Check Android permissions (if available)
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    bool? exactAlarmPermission;
    // bool? notificationPermission;  // Not currently used
    
    if (androidPlugin != null) {
      try {
        exactAlarmPermission = await androidPlugin.canScheduleExactNotifications();
        // Note: there's no direct way to check notification permission status
        // so we'll try to create a channel as a test
      } catch (e) {
        print('Error checking Android permissions: $e');
      }
    }
    
    return {
      'currentTime': now.toIso8601String(),
      'currentTZTime': nowTZ.toIso8601String(),
      'timeZone': now.timeZoneName,
      'timeZoneOffset': now.timeZoneOffset.inMinutes,
      'tzLocalLocation': tz.local.name,
      'pendingNotificationsCount': pending.length,
      'exactAlarmPermission': exactAlarmPermission,
      'diagnosticRunning': _isRunning,
      'pendingAlarms': pending.map((n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'payload': n.payload,
      }).toList(),
    };
  }
  
  /// Force check all pending alarms and report status
  Future<void> forceDiagnosticCheck() async {
    print('🔍 FORCE DIAGNOSTIC CHECK INITIATED');
    _logSystemInfo();
    await _performDiagnosticCheck();
    
    // Additional checks
    await _validateTimezoneSetup();
    await _validateNotificationChannels();
    await _validatePermissions();
  }
  
  /// Validate timezone setup
  Future<void> _validateTimezoneSetup() async {
    print('🌍 TIMEZONE VALIDATION:');
    
    try {
      final systemTime = DateTime.now();
      final tzTime = tz.TZDateTime.now(tz.local);
      
      print('   System time: $systemTime');
      print('   TZ time: $tzTime');
      print('   Difference: ${systemTime.difference(tzTime.toLocal()).inMilliseconds}ms');
      
      if (systemTime.difference(tzTime.toLocal()).abs().inSeconds > 1) {
        print('   ⚠️ WARNING: System time and TZ time differ significantly!');
      } else {
        print('   ✅ Timezone setup appears correct');
      }
    } catch (e) {
      print('   ❌ Timezone validation error: $e');
    }
  }
  
  /// Validate notification channels
  Future<void> _validateNotificationChannels() async {
    print('📢 NOTIFICATION CHANNELS VALIDATION:');
    
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      try {
        // Try to create a test channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'diagnostic_test',
            'Diagnostic Test',
            description: 'Test channel for alarm diagnostics',
            importance: Importance.max,
          ),
        );
        print('   ✅ Can create notification channels');
      } catch (e) {
        print('   ❌ Cannot create notification channels: $e');
      }
    } else {
      print('   ℹ️ Not running on Android platform');
    }
  }
  
  /// Validate permissions
  Future<void> _validatePermissions() async {
    print('🔐 PERMISSIONS VALIDATION:');
    
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      try {
        final canScheduleExact = await androidPlugin.canScheduleExactNotifications();
        print('   Exact alarm permission: $canScheduleExact');
        
        if (canScheduleExact != true) {
          print('   ❌ CRITICAL: Exact alarm permission not granted!');
          print('   📋 Solution: User must manually grant SCHEDULE_EXACT_ALARM permission');
        } else {
          print('   ✅ Exact alarm permission granted');
        }
      } catch (e) {
        print('   ❌ Permission check error: $e');
      }
    }
  }
}