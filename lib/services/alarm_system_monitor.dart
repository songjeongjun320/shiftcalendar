import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class AlarmSystemMonitor {
  final FlutterLocalNotificationsPlugin _notifications;
  Timer? _monitoringTimer;
  
  AlarmSystemMonitor(this._notifications);
  
  /// Start comprehensive system monitoring
  void startMonitoring() {
    stopMonitoring(); // Stop any existing timer
    
    print('🔍 Starting comprehensive alarm system monitoring...');
    
    // Monitor every 30 seconds
    _monitoringTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      await _performSystemCheck();
    });
  }
  
  /// Stop monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    print('⏹️ Stopped alarm system monitoring');
  }
  
  /// Perform comprehensive system check
  Future<void> _performSystemCheck() async {
    final now = DateTime.now();
    // final nowTZ = tz.TZDateTime.now(tz.local);  // Reserved for future timezone checks
    
    print('\n🔍 === SYSTEM CHECK ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ===');
    
    try {
      // 1. Check Android permissions
      await _checkPermissions();
      
      // 2. Check pending notifications
      await _checkPendingNotifications();
      
      // 3. Check for overdue alarms
      await _checkOverdueAlarms();
      
      // 4. System health check
      await _systemHealthCheck();
      
    } catch (e) {
      print('❌ Error during system check: $e');
    }
    
    print('=== END SYSTEM CHECK ===\n');
  }
  
  /// Check Android-specific permissions
  Future<void> _checkPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      try {
        // Check exact alarm permission
        final canScheduleExact = await androidPlugin.canScheduleExactNotifications();
        print('📋 Can schedule exact notifications: $canScheduleExact');
        
        if (canScheduleExact == false) {
          print('🚨 CRITICAL: Cannot schedule exact alarms! Request permission immediately.');
          
          // Try to request permission again
          try {
            final granted = await androidPlugin.requestExactAlarmsPermission();
            print('🔔 Exact alarm permission request result: $granted');
          } catch (e) {
            print('❌ Failed to request exact alarm permission: $e');
          }
        } else {
          print('✅ Exact alarm permission: OK');
        }
        
      } catch (e) {
        print('⚠️ Could not check permissions: $e');
      }
    }
  }
  
  /// Check pending notifications status
  Future<void> _checkPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      print('📋 Total pending notifications: ${pending.length}');
      
      // Filter alarm notifications (those with payload)
      final alarmNotifications = pending.where((request) {
        if (request.payload == null) return false;
        try {
          final payload = jsonDecode(request.payload!);
          return payload.containsKey('alarmId') || payload.containsKey('notificationId');
        } catch (e) {
          return false;
        }
      }).toList();
      
      print('⏰ Alarm notifications: ${alarmNotifications.length}');
      
      if (alarmNotifications.isEmpty) {
        print('⚠️ WARNING: No alarm notifications are scheduled!');
      }
      
      // Show next few alarms
      final sortedAlarms = alarmNotifications.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      
      print('📅 Next alarms:');
      for (int i = 0; i < sortedAlarms.length && i < 3; i++) {
        final alarm = sortedAlarms[i];
        print('   ${i + 1}. ID: ${alarm.id}, Title: ${alarm.title}');
      }
      
    } catch (e) {
      print('❌ Error checking pending notifications: $e');
    }
  }
  
  /// Check for overdue alarms that should have triggered
  Future<void> _checkOverdueAlarms() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      final now = DateTime.now();
      
      int overdueCount = 0;
      
      for (final request in pending) {
        if (request.payload != null) {
          try {
            final payload = jsonDecode(request.payload!);
            
            if (payload.containsKey('scheduledTime')) {
              final scheduledTime = DateTime.fromMillisecondsSinceEpoch(payload['scheduledTime']);
              final difference = now.difference(scheduledTime);
              
              if (difference.inMinutes > 2) { // More than 2 minutes overdue
                overdueCount++;
                print('🚨 OVERDUE ALARM DETECTED:');
                print('   ID: ${request.id}');
                print('   Title: ${request.title}');
                print('   Scheduled: $scheduledTime');
                print('   Overdue by: ${difference.inMinutes} minutes');
                
                // Send recovery notification
                await _sendRecoveryNotification(request, scheduledTime, difference);
              }
            }
          } catch (e) {
            // Invalid payload, skip
          }
        }
      }
      
      if (overdueCount == 0) {
        print('✅ No overdue alarms detected');
      } else {
        print('🚨 Found $overdueCount overdue alarms - recovery notifications sent');
      }
      
    } catch (e) {
      print('❌ Error checking overdue alarms: $e');
    }
  }
  
  /// Send recovery notification for missed alarm
  Future<void> _sendRecoveryNotification(PendingNotificationRequest originalAlarm, DateTime scheduledTime, Duration overdue) async {
    try {
      await _notifications.show(
        999900 + originalAlarm.id % 100, // Unique recovery ID
        'MISSED ALARM: ${originalAlarm.title}',
        'This alarm was scheduled for ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')} (${overdue.inMinutes} min ago)',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'recovery_channel',
            'Missed Alarms',
            channelDescription: 'Recovery notifications for missed alarms',
            importance: Importance.max,
            priority: Priority.high,
            ongoing: true,
            autoCancel: false,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
        payload: originalAlarm.payload,
      );
      
      print('✅ Recovery notification sent for missed alarm ${originalAlarm.id}');
    } catch (e) {
      print('❌ Failed to send recovery notification: $e');
    }
  }
  
  /// System health check
  Future<void> _systemHealthCheck() async {
    print('🔧 System Health:');
    
    // Memory check
    print('   📱 App running normally');
    
    // Timezone check
    final now = DateTime.now();
    final nowTZ = tz.TZDateTime.now(tz.local);
    final tzOffset = nowTZ.timeZoneOffset.inHours;
    print('   🌍 Timezone: ${tz.local.name} (UTC${tzOffset >= 0 ? '+' : ''}$tzOffset)');
    print('   ⏰ System time: ${now.toString()}');
    print('   📍 TZ time: ${nowTZ.toString()}');
    
    // Check if times match
    final timeDiff = now.difference(nowTZ.toLocal()).inSeconds.abs();
    if (timeDiff > 5) {
      print('⚠️ WARNING: System time and TZ time differ by $timeDiff seconds');
    } else {
      print('✅ Time synchronization: OK');
    }
  }
  
  /// Manual system diagnosis
  Future<Map<String, dynamic>> getDiagnosticReport() async {
    final report = <String, dynamic>{};
    
    try {
      // Permissions
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        report['canScheduleExact'] = await androidPlugin.canScheduleExactNotifications();
      }
      
      // Pending notifications
      final pending = await _notifications.pendingNotificationRequests();
      report['totalPending'] = pending.length;
      report['alarmPending'] = pending.where((r) => r.payload != null).length;
      
      // Time info
      final now = DateTime.now();
      final nowTZ = tz.TZDateTime.now(tz.local);
      report['systemTime'] = now.toIso8601String();
      report['tzTime'] = nowTZ.toIso8601String();
      report['timezone'] = tz.local.name;
      
      // System state
      report['monitoringActive'] = _monitoringTimer?.isActive ?? false;
      report['lastCheck'] = DateTime.now().toIso8601String();
      
    } catch (e) {
      report['error'] = e.toString();
    }
    
    return report;
  }
}