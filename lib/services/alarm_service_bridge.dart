import '../models/shift_alarm.dart';
import 'reliable_alarm_service.dart';

/// Bridge service to integrate all alarm types with ReliableAlarmService
/// Provides common mapping functions and utilities for alarm services
class AlarmServiceBridge {
  
  /// Schedule alarm using ReliableAlarmService with AlarmSettings
  static Future<bool> scheduleWithReliableService({
    required int id,
    required DateTime scheduledTime,
    required String title,
    required String message,
    required AlarmSettings settings,
  }) async {
    try {
      print('🌉 AlarmServiceBridge: Scheduling alarm via ReliableAlarmService');
      print('   ID: $id');
      print('   Time: $scheduledTime');
      print('   Title: $title');
      print('   Tone: ${settings.tone.soundPath}');
      print('   Volume: ${settings.volume}');
      
      final success = await ReliableAlarmService.scheduleAlarm(
        id: id,
        scheduledTime: scheduledTime,
        title: title,
        message: message,
        soundPath: 'sounds/${settings.tone.soundPath}.mp3',
        volume: settings.volume,
        vibrate: settings.vibration,
      );
      
      if (success) {
        print('✅ AlarmServiceBridge: Successfully scheduled via ReliableAlarmService');
      } else {
        print('❌ AlarmServiceBridge: Failed to schedule via ReliableAlarmService');
      }
      
      return success;
    } catch (e) {
      print('❌ AlarmServiceBridge: Error scheduling alarm - $e');
      return false;
    }
  }
  
  /// Schedule alarm with basic settings for BasicAlarm (no AlarmSettings)
  static Future<bool> scheduleBasicAlarmWithReliableService({
    required int id,
    required DateTime scheduledTime,
    required String title,
    required String message,
    String? customTone,
    double? customVolume,
    bool? customVibration,
  }) async {
    try {
      print('🌉 AlarmServiceBridge: Scheduling basic alarm via ReliableAlarmService');
      print('   ID: $id');
      print('   Time: $scheduledTime');
      print('   Title: $title');
      
      // Use provided settings or defaults
      final soundPath = customTone ?? 'sounds/wakeupcall.mp3';
      final volume = customVolume ?? 0.9;
      final vibrate = customVibration ?? true;
      
      print('   Sound: $soundPath');
      print('   Volume: $volume');
      
      final success = await ReliableAlarmService.scheduleAlarm(
        id: id,
        scheduledTime: scheduledTime,
        title: title,
        message: message,
        soundPath: soundPath,
        volume: volume,
        vibrate: vibrate,
      );
      
      if (success) {
        print('✅ AlarmServiceBridge: Successfully scheduled basic alarm via ReliableAlarmService');
      } else {
        print('❌ AlarmServiceBridge: Failed to schedule basic alarm via ReliableAlarmService');
      }
      
      return success;
    } catch (e) {
      print('❌ AlarmServiceBridge: Error scheduling basic alarm - $e');
      return false;
    }
  }
  
  /// Cancel alarm from ReliableAlarmService
  static Future<bool> cancelWithReliableService(int id) async {
    try {
      print('🌉 AlarmServiceBridge: Cancelling alarm via ReliableAlarmService - ID: $id');
      
      final success = await ReliableAlarmService.cancelAlarm(id);
      
      if (success) {
        print('✅ AlarmServiceBridge: Successfully cancelled via ReliableAlarmService');
      } else {
        print('⚠️ AlarmServiceBridge: Failed to cancel via ReliableAlarmService');
      }
      
      return success;
    } catch (e) {
      print('❌ AlarmServiceBridge: Error cancelling alarm - $e');
      return false;
    }
  }
  
  /// Convert basic alarm properties to default AlarmSettings
  static AlarmSettings createDefaultAlarmSettings({
    String? tone,
    double? volume,
    bool? vibration,
    bool? sound,
  }) {
    return AlarmSettings(
      vibration: vibration ?? true,
      sound: sound ?? true,
      tone: tone != null 
          ? AlarmTone.values.firstWhere(
              (t) => t.soundPath == tone,
              orElse: () => AlarmTone.wakeupcall,
            )
          : AlarmTone.wakeupcall,
      volume: volume ?? 0.9,
      snooze: true,
      snoozeDuration: 10,
      maxSnoozeCount: 3,
    );
  }
}