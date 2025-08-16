import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:ui';

/// Service to validate alarm triggers and detect when alarms should fire but don't
class AlarmTriggerValidator {
  final FlutterLocalNotificationsPlugin _notifications;
  Timer? _validationTimer;
  final List<MissedAlarm> _missedAlarms = [];
  bool _isRunning = false;
  
  AlarmTriggerValidator(this._notifications);
  
  /// Start real-time alarm trigger validation
  void startValidation() {
    if (_isRunning) return;
    
    _isRunning = true;
    print('🔍 ALARM TRIGGER VALIDATOR STARTED');
    
    // Check every 30 seconds for missed alarms
    _validationTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      await _checkForMissedAlarms();
    });
    
    print('✅ Validator checking every 30 seconds for missed alarms');
  }
  
  /// Stop alarm trigger validation
  void stopValidation() {
    _validationTimer?.cancel();
    _validationTimer = null;
    _isRunning = false;
    print('🛑 ALARM TRIGGER VALIDATOR STOPPED');
  }
  
  /// Check for alarms that should have triggered but didn't
  Future<void> _checkForMissedAlarms() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final pending = await _notifications.pendingNotificationRequests();
      
      print('🔍 Validator check at ${now.toString().substring(11, 19)}');
      
      // Filter to only alarm-related notifications
      final alarmNotifications = pending.where((req) {
        if (req.payload == null) return false;
        try {
          final payload = jsonDecode(req.payload!);
          return payload.containsKey('alarmId') || payload['type'] == 'basic_alarm';
        } catch (e) {
          return false;
        }
      }).toList();
      
      int missedCount = 0;
      int upcomingCount = 0;
      
      for (final notification in alarmNotifications) {
        try {
          final payload = jsonDecode(notification.payload!);
          final scheduledTime = DateTime.fromMillisecondsSinceEpoch(
            payload['scheduledTime'] as int
          );
          
          final timeDiff = now.difference(scheduledTime.toLocal());
          
          // Check if alarm is overdue (more than 2 minutes late)
          if (timeDiff.inMinutes >= 2 && timeDiff.inMinutes <= 60) {
            await _handleMissedAlarm(notification, scheduledTime, timeDiff);
            missedCount++;
          }
          // Track upcoming alarms (next 10 minutes)
          else if (timeDiff.inMinutes < 0 && timeDiff.inMinutes > -10) {
            final minutesUntil = -timeDiff.inMinutes;
            print('⏰ Upcoming: ${notification.title} in ${minutesUntil}m');
            upcomingCount++;
          }
          // Check if alarm should trigger RIGHT NOW (within 1 minute window)
          else if (timeDiff.inMinutes >= 0 && timeDiff.inMinutes < 2) {
            await _handleCurrentAlarm(notification, scheduledTime, timeDiff);
          }
        } catch (e) {
          print('⚠️ Error processing notification ${notification.id}: $e');
        }
      }
      
      if (missedCount == 0 && upcomingCount == 0) {
        print('✅ No missed or upcoming alarms detected');
      } else {
        print('📊 Summary: ${missedCount} missed, ${upcomingCount} upcoming');
      }
      
    } catch (e) {
      print('❌ Error in missed alarm check: $e');
    }
  }
  
  /// Handle a missed alarm by logging and attempting recovery
  Future<void> _handleMissedAlarm(
    PendingNotificationRequest notification,
    DateTime scheduledTime,
    Duration timeDiff,
  ) async {
    final missedAlarm = MissedAlarm(
      notificationId: notification.id,
      title: notification.title ?? 'Unknown Alarm',
      scheduledTime: scheduledTime,
      detectedTime: DateTime.now(),
      overdueBy: timeDiff,
    );
    
    // Add to missed alarms list (avoid duplicates)
    if (!_missedAlarms.any((m) => m.notificationId == notification.id)) {
      _missedAlarms.add(missedAlarm);
      
      print('🚨 MISSED ALARM DETECTED!');
      print('   ID: ${notification.id}');
      print('   Title: ${notification.title}');
      print('   Scheduled: $scheduledTime');
      print('   Overdue by: ${timeDiff.inMinutes} minutes');
      
      // Attempt to trigger a recovery notification
      await _triggerRecoveryNotification(missedAlarm, notification.payload);
      
      // Remove the original missed notification from pending list
      await _notifications.cancel(notification.id);
      print('   Cancelled original notification ${notification.id}');
    }
  }
  
  /// Handle an alarm that should trigger right now
  Future<void> _handleCurrentAlarm(
    PendingNotificationRequest notification,
    DateTime scheduledTime,
    Duration timeDiff,
  ) async {
    print('🎯 ALARM DUE NOW!');
    print('   ID: ${notification.id}');
    print('   Title: ${notification.title}');
    print('   Scheduled: $scheduledTime');
    print('   Time difference: ${timeDiff.inSeconds} seconds');
    
    // If the alarm is more than 30 seconds overdue, manually trigger it
    if (timeDiff.inSeconds > 30) {
      print('🔧 Manually triggering overdue alarm...');
      await _triggerManualAlarm(notification);
    }
  }
  
  /// Trigger a recovery notification for a missed alarm
  Future<void> _triggerRecoveryNotification(
    MissedAlarm missedAlarm,
    String? originalPayload,
  ) async {
    try {
      print('🔧 Triggering recovery notification for missed alarm ${missedAlarm.notificationId}');
      
      final recoveryId = 900000 + (missedAlarm.notificationId % 99999); // Unique recovery ID
      
      Map<String, dynamic> payload = {};
      if (originalPayload != null) {
        try {
          payload = jsonDecode(originalPayload);
        } catch (e) {
          print('⚠️ Could not parse original payload: $e');
        }
      }
      
      // Add recovery information
      payload['isRecovery'] = true;
      payload['originalScheduledTime'] = missedAlarm.scheduledTime.millisecondsSinceEpoch;
      payload['overdueByMinutes'] = missedAlarm.overdueBy.inMinutes;
      
      await _notifications.show(
        recoveryId,
        '⚠️ MISSED: ${missedAlarm.title}',
        'This alarm was scheduled for ${_formatTime(missedAlarm.scheduledTime)} (${missedAlarm.overdueBy.inMinutes}m ago)',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'recovery_channel',
            'Missed Alarms',
            channelDescription: 'Recovery notifications for missed alarms',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            color: const Color.fromARGB(255, 255, 87, 34), // Orange for missed alarms
            ongoing: true,
            autoCancel: false,
          ),
        ),
        payload: jsonEncode(payload),
      );
      
      print('✅ Recovery notification sent with ID: $recoveryId');
    } catch (e) {
      print('❌ Failed to send recovery notification: $e');
    }
  }
  
  /// Manually trigger an alarm that should be firing now
  Future<void> _triggerManualAlarm(PendingNotificationRequest originalNotification) async {
    try {
      final manualId = 800000 + (originalNotification.id % 99999); // Unique manual ID
      
      Map<String, dynamic> payload = {};
      if (originalNotification.payload != null) {
        try {
          payload = jsonDecode(originalNotification.payload!);
        } catch (e) {
          print('⚠️ Could not parse original payload: $e');
        }
      }
      
      // Add manual trigger information
      payload['isManualTrigger'] = true;
      payload['originalNotificationId'] = originalNotification.id;
      
      await _notifications.show(
        manualId,
        '🔔 ${originalNotification.title}',
        originalNotification.body ?? 'Your alarm is ready!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'manual_trigger_channel',
            'Manual Alarm Triggers',
            channelDescription: 'Manually triggered alarms',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            ongoing: true,
            autoCancel: false,
          ),
        ),
        payload: jsonEncode(payload),
      );
      
      print('✅ Manual alarm trigger sent with ID: $manualId');
      
      // Remove the original notification since we manually triggered it
      await _notifications.cancel(originalNotification.id);
      print('   Cancelled original notification ${originalNotification.id}');
      
    } catch (e) {
      print('❌ Failed to manually trigger alarm: $e');
    }
  }
  
  /// Get all missed alarms detected so far
  List<MissedAlarm> get missedAlarms => List.unmodifiable(_missedAlarms);
  
  /// Clear missed alarms history
  void clearMissedAlarms() {
    _missedAlarms.clear();
    print('🧹 Cleared missed alarms history');
  }
  
  /// Get validation status
  bool get isRunning => _isRunning;
  
  /// Format time for display
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Data class for tracking missed alarms
class MissedAlarm {
  final int notificationId;
  final String title;
  final DateTime scheduledTime;
  final DateTime detectedTime;
  final Duration overdueBy;
  
  const MissedAlarm({
    required this.notificationId,
    required this.title,
    required this.scheduledTime,
    required this.detectedTime,
    required this.overdueBy,
  });
  
  @override
  String toString() {
    return 'MissedAlarm(id: $notificationId, title: $title, overdue: ${overdueBy.inMinutes}m)';
  }
}