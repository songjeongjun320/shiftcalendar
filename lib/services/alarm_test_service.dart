import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:ui';

/// Service for testing alarm functionality with immediate triggers
class AlarmTestService {
  final FlutterLocalNotificationsPlugin _notifications;
  
  AlarmTestService(this._notifications);
  
  /// Test immediate alarm trigger (5 seconds from now)
  Future<void> testImmediateAlarm() async {
    print('🧪 TESTING IMMEDIATE ALARM');
    
    final now = tz.TZDateTime.now(tz.local);
    final testTime = now.add(Duration(seconds: 5));
    
    print('⏰ Current time: $now');
    print('🎯 Test alarm scheduled for: $testTime');
    print('⏱️ Alarm will trigger in 5 seconds');
    
    // Check permissions first
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final canScheduleExact = await androidPlugin.canScheduleExactNotifications();
      print('🔐 Can schedule exact notifications: $canScheduleExact');
      
      if (canScheduleExact != true) {
        print('❌ CRITICAL: Cannot schedule exact alarms!');
        print('📱 Please enable exact alarm permission in Android settings');
        // Create a manual notification instead
        await _createManualTestNotification();
        return;
      }
    }
    
    const testId = 999998;
    
    try {
      await _notifications.zonedSchedule(
        testId,
        '🧪 TEST ALARM',
        'This test alarm should trigger in 5 seconds. If you see this, your alarm system is working!',
        testTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'test_alarm_channel',
            'Test Alarms',
            channelDescription: 'Test notifications for alarm debugging',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            color: const Color.fromARGB(255, 76, 175, 80), // Green for test
            ongoing: true,
            autoCancel: false,
            showWhen: true,
            when: testTime.millisecondsSinceEpoch,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode({
          'type': 'test_alarm',
          'testId': testId,
          'scheduledTime': testTime.millisecondsSinceEpoch,
          'message': 'Test alarm triggered successfully!',
          'debugInfo': {
            'scheduledAt': DateTime.now().millisecondsSinceEpoch,
            'timezone': tz.local.name,
            'timezoneOffset': testTime.timeZoneOffset.inMinutes,
          },
        }),
      );
      
      print('✅ Test alarm scheduled successfully!');
      print('🔔 Watch for the notification in 5 seconds...');
      
      // Verify it was scheduled
      await _verifyTestAlarmScheduled(testId);
      
    } catch (e) {
      print('❌ ERROR scheduling test alarm: $e');
      // Fallback to manual notification
      await _createManualTestNotification();
    }
  }
  
  /// Test alarm 30 seconds from now (for longer testing)
  Future<void> testDelayedAlarm() async {
    print('🧪 TESTING DELAYED ALARM (30 seconds)');
    
    final now = tz.TZDateTime.now(tz.local);
    final testTime = now.add(Duration(seconds: 30));
    
    print('⏰ Current time: $now');
    print('🎯 Test alarm scheduled for: $testTime');
    print('⏱️ Alarm will trigger in 30 seconds');
    
    const testId = 999997;
    
    try {
      await _notifications.zonedSchedule(
        testId,
        '🧪 DELAYED TEST ALARM',
        'This delayed test alarm should trigger in 30 seconds.',
        testTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'test_alarm_channel',
            'Test Alarms',
            channelDescription: 'Test notifications for alarm debugging',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            color: const Color.fromARGB(255, 255, 152, 0), // Orange for delayed test
            ongoing: true,
            autoCancel: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode({
          'type': 'delayed_test_alarm',
          'testId': testId,
          'scheduledTime': testTime.millisecondsSinceEpoch,
          'message': 'Delayed test alarm triggered successfully!',
        }),
      );
      
      print('✅ Delayed test alarm scheduled successfully!');
      print('🔔 Watch for the notification in 30 seconds...');
      
    } catch (e) {
      print('❌ ERROR scheduling delayed test alarm: $e');
    }
  }
  
  /// Create a manual test notification (fallback when exact alarms can't be scheduled)
  Future<void> _createManualTestNotification() async {
    print('📱 Creating manual test notification as fallback...');
    
    try {
      await _notifications.show(
        999999,
        '📱 MANUAL TEST NOTIFICATION',
        'This is a manual test since exact alarms cannot be scheduled. Check your Android settings to enable exact alarm permission.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'test_manual_channel',
            'Manual Test Notifications',
            channelDescription: 'Manual test notifications when exact alarms fail',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            color: const Color.fromARGB(255, 244, 67, 54), // Red for manual
            ongoing: true,
            autoCancel: false,
          ),
        ),
        payload: jsonEncode({
          'type': 'manual_test',
          'message': 'Manual test notification - exact alarms not available',
        }),
      );
      
      print('✅ Manual test notification sent');
    } catch (e) {
      print('❌ Failed to send manual test notification: $e');
    }
  }
  
  /// Verify that the test alarm was scheduled
  Future<void> _verifyTestAlarmScheduled(int testId) async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      final testAlarm = pending.where((req) => req.id == testId).firstOrNull;
      
      if (testAlarm != null) {
        print('✅ Verification: Test alarm found in pending list');
        print('   ID: ${testAlarm.id}');
        print('   Title: ${testAlarm.title}');
      } else {
        print('❌ Verification FAILED: Test alarm NOT found in pending list!');
        print('   Total pending notifications: ${pending.length}');
        print('   This indicates the scheduling failed silently');
      }
    } catch (e) {
      print('⚠️ Could not verify test alarm: $e');
    }
  }
  
  /// Cancel all test alarms
  Future<void> cancelTestAlarms() async {
    print('🧹 Cancelling all test alarms...');
    
    try {
      // Cancel specific test IDs
      await _notifications.cancel(999997);
      await _notifications.cancel(999998);
      await _notifications.cancel(999999);
      
      print('✅ Test alarms cancelled');
    } catch (e) {
      print('⚠️ Error cancelling test alarms: $e');
    }
  }
  
  /// Get current system status for alarm testing
  Future<Map<String, dynamic>> getTestSystemStatus() async {
    final now = tz.TZDateTime.now(tz.local);
    final pending = await _notifications.pendingNotificationRequests();
    
    // Check Android-specific capabilities
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    bool? canScheduleExact;
    
    if (androidPlugin != null) {
      try {
        canScheduleExact = await androidPlugin.canScheduleExactNotifications();
      } catch (e) {
        print('Error checking exact alarm capability: $e');
      }
    }
    
    // Find test alarms in pending list
    final testAlarms = pending.where((req) {
      return req.id == 999997 || req.id == 999998 || req.id == 999999;
    }).toList();
    
    return {
      'currentTime': now.toIso8601String(),
      'timezone': tz.local.name,
      'canScheduleExactAlarms': canScheduleExact,
      'totalPendingNotifications': pending.length,
      'pendingTestAlarms': testAlarms.length,
      'testAlarmIds': testAlarms.map((a) => a.id).toList(),
      'systemReady': canScheduleExact == true,
      'recommendation': canScheduleExact == true 
          ? 'System ready for alarm testing'
          : 'Enable exact alarm permission in Android settings',
    };
  }
}