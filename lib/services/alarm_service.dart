import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

/// Main alarm service using the alarm package with foreground service
/// This is the primary alarm system for the app
class AlarmService {
  static StreamSubscription<AlarmSettings>? _alarmStreamSubscription;
  
  /// Initialize the alarm service
  static Future<void> initialize() async {
    try {
      // Clear any corrupted alarm data first
      await _clearCorruptedAlarmData();
      
      await Alarm.init();
      
      // Listen for alarm triggers and automatically show alarm screen
      _startAlarmListener();
    } catch (e) {
      print('❌ Error during alarm initialization: $e');
      // Continue app startup even if alarm init fails
      print('⚠️ Continuing app startup without alarm service');
    }
  }
  
  /// Clear corrupted alarm data that might cause JSON parsing errors
  static Future<void> _clearCorruptedAlarmData() async {
    try {
      // Clear all stored alarm data to avoid JSON parsing errors
      // This will remove any corrupted alarm settings from SharedPreferences
      print('🧹 Clearing potentially corrupted alarm data...');
      
      // Import shared_preferences for cleaning
      final prefs = await SharedPreferences.getInstance();
      
      // Remove any alarm-related keys that might be corrupted
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith('alarm_') || key.contains('AlarmSettings')) {
          await prefs.remove(key);
          print('🗑️ Removed corrupted key: $key');
        }
      }
      
      print('✅ Alarm data cleanup completed');
      
    } catch (e) {
      print('⚠️ Error during alarm data cleanup: $e');
      // Continue anyway
    }
  }
  
  /// Start listening for alarm triggers
  static void _startAlarmListener() {
    print('🎧 Starting alarm stream listener...');
    
    _alarmStreamSubscription?.cancel(); // Cancel any existing subscription
    
    _alarmStreamSubscription = Alarm.ringStream.stream.listen(
      (alarmSettings) {
        print('🚨 ALARM RINGING! ID: ${alarmSettings.id}');
        print('📋 Alarm details: ${alarmSettings.notificationSettings.title}');
        
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
        'title': alarmSettings.notificationSettings.title,
        'message': alarmSettings.notificationSettings.body,
        'notificationId': alarmSettings.id,
        'alarmTone': alarmSettings.assetAudioPath,
        'alarmVolume': alarmSettings.volumeSettings.volume ?? 0.8,
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
      // Validate input parameters first
      if (title.isEmpty) {
        print('⚠️ Warning: Empty title provided, using default');
        title = 'Alarm';
      }
      
      if (message.isEmpty) {
        print('⚠️ Warning: Empty message provided, using default');
        message = 'Time for your alarm!';
      }
      
      // Create alarm settings with explicit validation
      final alarmSettings = AlarmSettings(
        id: id,
        dateTime: scheduledTime,
        assetAudioPath: soundPath ?? 'assets/sounds/wakeupcall.mp3',
        loopAudio: true,  // Keep playing until dismissed
        vibrate: vibrate,
        volumeSettings: VolumeSettings.fade(
          volume: volume.clamp(0.0, 1.0), // Ensure volume is valid
          fadeDuration: const Duration(seconds: 3),
        ),
        notificationSettings: NotificationSettings(
          title: title.trim(),
          body: message.trim(),
        ),
        
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
      print('❌ Error details: ${e.toString()}');
      
      // Try to continue without the alarm service backup
      print('⚠️ Continuing without reliable alarm backup for ID: $id');
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
  static Future<List<AlarmSettings>> getAllAlarms() async {
    return await Alarm.getAlarms();
  }
  
  /// Check if a specific alarm is scheduled
  static Future<bool> isAlarmSet(int id) async {
    final isRinging = await Alarm.isRinging(id);
    final alarms = await getAllAlarms();
    final isScheduled = alarms.any((alarm) => alarm.id == id);
    return isRinging || isScheduled;
  }
  
  /// Stop all currently ringing alarms
  static Future<void> stopAllAlarms() async {
    final alarms = await getAllAlarms();
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