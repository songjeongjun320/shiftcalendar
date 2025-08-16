import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import '../main.dart';

/// Reliable alarm service using the alarm package with foreground service
/// This replaces flutter_local_notifications for scheduled alarms
class ReliableAlarmService {
  static StreamSubscription<AlarmSettings>? _alarmStreamSubscription;
  
  /// Initialize the alarm service
  static Future<void> initialize() async {
    await Alarm.init();
    print('✅ Reliable alarm service initialized');
    
    // Listen for alarm triggers and automatically show alarm screen
    _startAlarmListener();
  }
  
  /// Start listening for alarm triggers
  static void _startAlarmListener() {
    print('🎧 Starting alarm stream listener...');
    
    _alarmStreamSubscription?.cancel(); // Cancel any existing subscription
    
    _alarmStreamSubscription = Alarm.ringStream.stream.listen(
      (alarmSettings) {
        print('🚨 ALARM RINGING! ID: ${alarmSettings.id}');
        print('📋 Alarm details: ${alarmSettings.notificationTitle}');
        
        // Automatically show alarm screen
        _showAlarmScreenFromStream(alarmSettings);
      },
      onError: (error) {
        print('❌ Error in alarm stream: $error');
      },
    );
    
    print('✅ Alarm stream listener started');
  }
  
  /// Show alarm screen when alarm triggers from stream
  static Future<void> _showAlarmScreenFromStream(AlarmSettings alarmSettings) async {
    print('🎯 Auto-triggering alarm screen for ID: ${alarmSettings.id}');
    
    try {
      // Prepare payload for alarm screen
      final payload = {
        'type': 'reliable_alarm',
        'alarmId': alarmSettings.id.toString(),
        'title': alarmSettings.notificationTitle,
        'message': alarmSettings.notificationBody,
        'notificationId': alarmSettings.id,
        'alarmTone': alarmSettings.assetAudioPath,
        'alarmVolume': alarmSettings.volume,
      };
      
      // Try to navigate to alarm screen
      if (navigatorKey.currentState != null) {
        print('✅ Navigator available - auto-pushing to alarm screen');
        
        await navigatorKey.currentState!.pushNamed('/alarm', arguments: payload);
        print('✅ Successfully auto-navigated to alarm screen');
        
      } else {
        print('❌ Navigator not available - alarm will continue ringing');
        print('📱 User must manually open the app to see alarm screen');
      }
      
    } catch (e) {
      print('❌ Error auto-showing alarm screen: $e');
    }
  }
  
  /// Schedule a reliable alarm that will trigger even if app is killed
  static Future<bool> scheduleAlarm({
    required int id,
    required DateTime scheduledTime,
    required String title,
    required String message,
    String? soundPath,
    double volume = 0.8,
    bool vibrate = true,
  }) async {
    try {
      // Create alarm settings
      final alarmSettings = AlarmSettings(
        id: id,
        dateTime: scheduledTime,
        assetAudioPath: soundPath ?? 'sounds/wakeupcall.mp3',
        loopAudio: true,  // Keep playing until dismissed
        vibrate: vibrate,
        volume: volume,
        fadeDuration: 3.0,  // Gradually increase volume
        notificationTitle: title,
        notificationBody: message,
        enableNotificationOnKill: true,  // Show notification if app is killed
        
        // Android specific settings for reliability
        androidFullScreenIntent: true,  // Show fullscreen when locked
      );
      
      // Schedule the alarm
      final success = await Alarm.set(alarmSettings: alarmSettings);
      
      if (success) {
        print('✅ Reliable alarm scheduled successfully:');
        print('   ID: $id');
        print('   Time: $scheduledTime');
        print('   Title: $title');
      } else {
        print('❌ Failed to schedule reliable alarm: $id');
      }
      
      return success;
    } catch (e) {
      print('❌ Error scheduling reliable alarm: $e');
      return false;
    }
  }
  
  /// Cancel a specific alarm
  static Future<bool> cancelAlarm(int id) async {
    try {
      final success = await Alarm.stop(id);
      if (success) {
        print('✅ Alarm cancelled: $id');
      } else {
        print('⚠️ Failed to cancel alarm: $id');
      }
      return success;
    } catch (e) {
      print('❌ Error cancelling alarm: $e');
      return false;
    }
  }
  
  /// Get all currently scheduled alarms
  static List<AlarmSettings> getAllAlarms() {
    return Alarm.getAlarms();
  }
  
  /// Check if a specific alarm is scheduled
  static Future<bool> isAlarmSet(int id) async {
    final isRinging = await Alarm.isRinging(id);
    final isScheduled = getAllAlarms().any((alarm) => alarm.id == id);
    return isRinging || isScheduled;
  }
  
  /// Stop all currently ringing alarms
  static Future<void> stopAllAlarms() async {
    final alarms = getAllAlarms();
    for (final alarm in alarms) {
      final isRinging = await Alarm.isRinging(alarm.id);
      if (isRinging) {
        await Alarm.stop(alarm.id);
      }
    }
    print('✅ All ringing alarms stopped');
  }
  
  /// Schedule shift alarm using reliable system
  static Future<bool> scheduleShiftAlarm({
    required String shiftType,
    required DateTime alarmTime,
    required String alarmTone,
    double volume = 0.9,
  }) async {
    final id = alarmTime.millisecondsSinceEpoch ~/ 1000; // Unique ID based on time
    
    return await scheduleAlarm(
      id: id,
      scheduledTime: alarmTime,
      title: '$shiftType Shift Alarm',
      message: 'Time for your $shiftType shift!',
      soundPath: 'sounds/$alarmTone',
      volume: volume,
      vibrate: true,
    );
  }
  
  /// Test immediate alarm (for debugging)
  static Future<bool> testImmediateAlarm() async {
    final testTime = DateTime.now().add(Duration(seconds: 5));
    
    return await scheduleAlarm(
      id: 99999,
      scheduledTime: testTime,
      title: 'RELIABLE TEST ALARM',
      message: 'This is a test of the reliable alarm system',
      volume: 0.9,
    );
  }
}