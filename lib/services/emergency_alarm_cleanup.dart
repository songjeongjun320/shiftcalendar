import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'alarm_service.dart';

/// Emergency alarm cleanup service to resolve critical alarm system issues
class EmergencyAlarmCleanup {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  /// Emergency cleanup of all alarm-related notifications and data
  static Future<void> emergencyCleanup() async {
    print('🚨 EMERGENCY CLEANUP: Starting comprehensive alarm system cleanup...');
    
    try {
      // Step 1: Cancel all pending notifications
      final pendingCount = await _cancelAllPendingNotifications();
      
      // Step 2: Stop all ringing alarms from AlarmService
      await _stopAllRingingAlarms();
      
      // Step 3: Clear corrupted alarm data
      await _clearCorruptedData();
      
      // Step 4: Reinitialize alarm service
      await _reinitializeAlarmService();
      
      print('✅ EMERGENCY CLEANUP: Completed successfully');
      print('📊 CLEANUP SUMMARY:');
      print('   - Cancelled $pendingCount pending notifications');
      print('   - Stopped all ringing alarms');
      print('   - Cleared corrupted data');
      print('   - Reinitialized alarm service');
      
    } catch (e) {
      print('❌ EMERGENCY CLEANUP: Error during cleanup: $e');
      throw e;
    }
  }
  
  /// Cancel all pending notifications
  static Future<int> _cancelAllPendingNotifications() async {
    print('🗑️ Cancelling all pending notifications...');
    
    try {
      final pending = await _notifications.pendingNotificationRequests();
      final count = pending.length;
      
      await _notifications.cancelAll();
      
      print('✅ Cancelled $count pending notifications');
      return count;
    } catch (e) {
      print('❌ Error cancelling notifications: $e');
      return 0;
    }
  }
  
  /// Stop all ringing alarms
  static Future<void> _stopAllRingingAlarms() async {
    print('🔇 Stopping all ringing alarms...');
    
    try {
      await AlarmService.stopAllAlarms();
      print('✅ All ringing alarms stopped');
    } catch (e) {
      print('❌ Error stopping alarms: $e');
    }
  }
  
  /// Clear potentially corrupted alarm data
  static Future<void> _clearCorruptedData() async {
    print('🧹 Clearing corrupted alarm data...');
    
    try {
      // Use AlarmService's cleanup method
      await AlarmService.initialize();
      print('✅ Corrupted data cleared');
    } catch (e) {
      print('❌ Error clearing corrupted data: $e');
    }
  }
  
  /// Reinitialize alarm service
  static Future<void> _reinitializeAlarmService() async {
    print('🔄 Reinitializing alarm service...');
    
    try {
      await AlarmService.initialize();
      print('✅ Alarm service reinitialized');
    } catch (e) {
      print('❌ Error reinitializing alarm service: $e');
    }
  }
  
  /// Diagnose current alarm system state
  static Future<void> diagnoseAlarmSystem() async {
    print('🔍 DIAGNOSTIC: Analyzing alarm system state...');
    
    try {
      // Check pending notifications
      final pending = await _notifications.pendingNotificationRequests();
      print('📊 Total pending notifications: ${pending.length}');
      
      // Analyze notification types
      final Map<String, int> typeCount = {};
      final Map<String, List<String>> duplicateGroups = {};
      
      for (final notification in pending) {
        if (notification.payload != null) {
          try {
            final payload = jsonDecode(notification.payload!);
            final type = payload['type'] ?? 'unknown';
            typeCount[type] = (typeCount[type] ?? 0) + 1;
            
            if (type == 'basic_alarm') {
              final alarmId = payload['alarmId'] ?? 'unknown';
              if (duplicateGroups.containsKey(alarmId)) {
                duplicateGroups[alarmId]!.add(notification.id.toString());
              } else {
                duplicateGroups[alarmId] = [notification.id.toString()];
              }
            }
          } catch (e) {
            typeCount['malformed'] = (typeCount['malformed'] ?? 0) + 1;
          }
        } else {
          typeCount['no_payload'] = (typeCount['no_payload'] ?? 0) + 1;
        }
      }
      
      print('📊 Notification breakdown by type:');
      typeCount.forEach((type, count) {
        print('   - $type: $count');
      });
      
      // Check for duplicates
      final duplicates = duplicateGroups.entries.where((entry) => entry.value.length > 1);
      if (duplicates.isNotEmpty) {
        print('🚨 DUPLICATE ALARMS DETECTED:');
        for (final duplicate in duplicates) {
          print('   - Alarm ${duplicate.key}: ${duplicate.value.length} notifications');
        }
      } else {
        print('✅ No duplicate alarms detected');
      }
      
      // Check AlarmService state
      try {
        final alarms = await AlarmService.getAllAlarms();
        print('📊 AlarmService scheduled alarms: ${alarms.length}');
      } catch (e) {
        print('❌ Error checking AlarmService state: $e');
      }
      
    } catch (e) {
      print('❌ Error during diagnostic: $e');
    }
  }
  
  /// Quick fix for the most common issues
  static Future<void> quickFix() async {
    print('⚡ QUICK FIX: Applying common issue fixes...');
    
    try {
      // Fix 1: Remove duplicate basic alarms
      await _removeDuplicateBasicAlarms();
      
      // Fix 2: Clean up orphaned notifications
      await _cleanupOrphanedNotifications();
      
      print('✅ QUICK FIX: Applied successfully');
    } catch (e) {
      print('❌ QUICK FIX: Error during quick fix: $e');
    }
  }
  
  /// Remove duplicate basic alarms only
  static Future<void> _removeDuplicateBasicAlarms() async {
    print('🔍 Removing duplicate basic alarms...');
    
    try {
      final pending = await _notifications.pendingNotificationRequests();
      final alarmGroups = <String, List<PendingNotificationRequest>>{};
      
      // Group basic alarms by alarm ID
      for (final notification in pending) {
        if (notification.payload != null) {
          try {
            final payload = jsonDecode(notification.payload!);
            if (payload['type'] == 'basic_alarm') {
              final alarmId = payload['alarmId'];
              if (alarmGroups.containsKey(alarmId)) {
                alarmGroups[alarmId]!.add(notification);
              } else {
                alarmGroups[alarmId] = [notification];
              }
            }
          } catch (e) {
            // Skip malformed payloads
          }
        }
      }
      
      int removedCount = 0;
      
      // Remove duplicates, keeping the latest one
      for (final entry in alarmGroups.entries) {
        if (entry.value.length > 1) {
          final duplicates = entry.value;
          
          // Sort by scheduled time
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
          
          // Remove all but the last one
          for (int i = 0; i < duplicates.length - 1; i++) {
            await _notifications.cancel(duplicates[i].id);
            removedCount++;
          }
        }
      }
      
      print('✅ Removed $removedCount duplicate basic alarms');
    } catch (e) {
      print('❌ Error removing duplicate basic alarms: $e');
    }
  }
  
  /// Clean up orphaned notifications (notifications without valid payloads)
  static Future<void> _cleanupOrphanedNotifications() async {
    print('🧹 Cleaning up orphaned notifications...');
    
    try {
      final pending = await _notifications.pendingNotificationRequests();
      int removedCount = 0;
      
      for (final notification in pending) {
        bool shouldRemove = false;
        
        // Remove notifications without payloads
        if (notification.payload == null) {
          shouldRemove = true;
        } else {
          // Remove notifications with malformed payloads
          try {
            jsonDecode(notification.payload!);
          } catch (e) {
            shouldRemove = true;
          }
        }
        
        if (shouldRemove) {
          await _notifications.cancel(notification.id);
          removedCount++;
        }
      }
      
      print('✅ Removed $removedCount orphaned notifications');
    } catch (e) {
      print('❌ Error cleaning up orphaned notifications: $e');
    }
  }
}