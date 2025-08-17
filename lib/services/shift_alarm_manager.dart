import 'dart:convert';
import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
import '../models/shift_type.dart';
import '../models/alarm_enums.dart';
import '../models/basic_alarm.dart';
import 'basic_alarm_service.dart';
import 'package:flutter/material.dart';

extension TimeOfDayExtension on TimeOfDay {
  String formatWithoutContext() {
    final hourString = hour.toString().padLeft(2, '0');
    final minuteString = minute.toString().padLeft(2, '0');
    return '$hourString:$minuteString';
  }
}

/// Manages shift alarms by converting them to multiple BasicAlarm objects
/// This approach leverages the proven BasicAlarm system instead of complex pattern calculations
class ShiftAlarmManager {
  final BasicAlarmService _basicAlarmService;
  final String patternId;
  
  ShiftAlarmManager(this._basicAlarmService, this.patternId);
  
  /// Convert ShiftAlarm to BasicAlarm objects using weekly recurring patterns
  /// This is much more efficient than creating 30+ individual alarms
  Future<List<BasicAlarm>> scheduleShiftAlarmsAsBasicAlarms(
    ShiftAlarm shiftAlarm, 
    ShiftPattern pattern,
  ) async {
    print('🔄 Converting ShiftAlarm to BasicAlarms...');
    print('   ShiftAlarm: ${shiftAlarm.title}');
    print('   Target shifts: ${shiftAlarm.targetShiftTypes.map((t) => t.displayName).join(', ')}');
    print('   Time: ${shiftAlarm.time.formatWithoutContext()}');
    
    final createdAlarms = <BasicAlarm>[];
    
    // CRITICAL FIX: Check for existing alarms and prevent duplicates
    final existingAlarms = await getShiftBasicAlarms(shiftAlarm.id);
    if (existingAlarms.isNotEmpty) {
      print('   ⚠️ Found ${existingAlarms.length} existing alarms for ${shiftAlarm.title}');
    }
    
    // Cancel existing alarms for this shift alarm first to prevent duplicates
    await cancelShiftAlarms(shiftAlarm.id);
    print('   🗑️ Cancelled existing alarms for ${shiftAlarm.title}');
    
    // OPTIMIZED: Find next 14 days worth of shifts (balanced approach)
    // This respects shift patterns while keeping alarm count reasonable
    final upcomingShifts = pattern.getUpcomingShifts(
      shiftAlarm.targetShiftTypes, 
      14 // 2 weeks ahead - covers full cycle patterns
    );
    
    print('   Found ${upcomingShifts.length} upcoming shift dates for target types: ${shiftAlarm.targetShiftTypes.map((t) => t.displayName).join(', ')}');
    
    // Create BasicAlarm for each shift occurrence (max 10 per alarm type for 2 weeks)
    for (int i = 0; i < upcomingShifts.length && i < 10; i++) { // Limit to 10 alarms max per type
      final shiftDate = upcomingShifts[i];
      final actualShiftType = pattern.getShiftForDate(shiftDate);
      
      // CRITICAL: Only create alarm if the actual shift type matches the alarm's target types
      if (!shiftAlarm.targetShiftTypes.contains(actualShiftType)) {
        print('   ⏭️ Skipping ${shiftDate.toString().substring(0, 10)} - actual shift: ${actualShiftType.displayName}, target: ${shiftAlarm.targetShiftTypes.map((t) => t.displayName).join(', ')}');
        continue;
      }
      
      print('   ✅ Match found! ${shiftDate.toString().substring(0, 10)} - shift: ${actualShiftType.displayName}');
      
      // Map shift type to alarm type
      final AlarmType alarmType;
      switch (actualShiftType.name) {
        case 'day_shift':
          alarmType = AlarmType.day;
          break;
        case 'night_shift':
          alarmType = AlarmType.night;
          break;
        case 'day_off':
          alarmType = AlarmType.off;
          break;
        default:
          alarmType = AlarmType.basic;
      }
      
      // Generate unique ID including date and shift type to prevent conflicts
      final dateStr = shiftDate.toIso8601String().split('T')[0]; // YYYY-MM-DD
      final timeStr = '${shiftAlarm.time.hour.toString().padLeft(2, '0')}${shiftAlarm.time.minute.toString().padLeft(2, '0')}';
      final uniqueId = '${shiftAlarm.id}_${alarmType.value}_${dateStr}_${timeStr}';
      
      final basicAlarm = BasicAlarm(
        id: uniqueId,
        label: '${shiftAlarm.title} (${actualShiftType.displayName})',
        time: shiftAlarm.time,
        repeatDays: {}, // One-time alarm for specific shift date
        isActive: shiftAlarm.isActive,
        tone: shiftAlarm.settings.tone,
        volume: shiftAlarm.settings.volume,
        createdAt: DateTime.now(),
        type: alarmType, // Set proper alarm type
        scheduledDate: shiftDate, // CRITICAL: Set specific date for this alarm
      );
      
      print('   📅 Creating BasicAlarm for ${shiftDate.toString().substring(0, 10)} (${actualShiftType.displayName})');
      
      // Schedule using proven BasicAlarm system
      await _basicAlarmService.scheduleBasicAlarm(basicAlarm);
      createdAlarms.add(basicAlarm);
    }
    
    print('✅ Created ${createdAlarms.length} BasicAlarms for ShiftAlarm: ${shiftAlarm.title}');
    return createdAlarms;
  }
  
  /// OPTIMIZED VERSION: Create weekly recurring alarms instead of 30+ individual ones
  /// This reduces total pending notifications from 60+ to ~10-15 max
  Future<List<BasicAlarm>> scheduleShiftAlarmsAsWeeklyRecurring(
    ShiftAlarm shiftAlarm, 
    ShiftPattern pattern,
  ) async {
    print('🔄 OPTIMIZED: Converting ShiftAlarm to weekly recurring BasicAlarms...');
    print('   ShiftAlarm: ${shiftAlarm.title}');
    print('   Target shifts: ${shiftAlarm.targetShiftTypes.map((t) => t.displayName).join(', ')}');
    print('   Time: ${shiftAlarm.time.formatWithoutContext()}');
    
    final createdAlarms = <BasicAlarm>[];
    
    // Cancel existing alarms for this shift alarm first
    await cancelShiftAlarms(shiftAlarm.id);
    print('   🗑️ Cancelled existing alarms for ${shiftAlarm.title}');
    
    // Get pattern cycle info - assuming most shift patterns are weekly
    final patternLength = pattern.cycle.length;
    print('   Pattern length: $patternLength days');
    
    // For each target shift type, find which days of the week it occurs
    final weeklySchedule = <int, ShiftType>{}; // weekday -> shift type
    
    // Analyze the pattern to find weekly recurring days
    final today = DateTime.now();
    for (int dayOffset = 0; dayOffset < 14; dayOffset++) { // Check 2 weeks to find pattern
      final checkDate = today.add(Duration(days: dayOffset));
      final shiftType = pattern.getShiftForDate(checkDate);
      
      if (shiftAlarm.targetShiftTypes.contains(shiftType)) {
        final weekday = checkDate.weekday; // 1=Monday, 7=Sunday
        weeklySchedule[weekday] = shiftType;
        print('   Found ${shiftType.displayName} on weekday $weekday (${_getWeekdayName(weekday)})');
      }
    }
    
    // Create ONE recurring BasicAlarm for each weekday that has target shifts
    for (final entry in weeklySchedule.entries) {
      final weekday = entry.key;
      final shiftType = entry.value;
      
      // Map shift type to alarm type
      final AlarmType alarmType;
      switch (shiftType.name) {
        case 'day_shift':
          alarmType = AlarmType.day;
          break;
        case 'night_shift':
          alarmType = AlarmType.night;
          break;
        case 'day_off':
          alarmType = AlarmType.off;
          break;
        default:
          alarmType = AlarmType.basic;
      }
      
      // Generate unique ID for this weekday occurrence
      final weeklyAlarmId = '${shiftAlarm.id}_weekly_${alarmType.value}_${weekday}';
      
      final weeklyBasicAlarm = BasicAlarm(
        id: weeklyAlarmId,
        label: '${shiftAlarm.title} (${shiftType.displayName} - ${_getWeekdayName(weekday)})',
        time: shiftAlarm.time,
        repeatDays: {weekday}, // Repeat only on this weekday
        isActive: shiftAlarm.isActive,
        tone: shiftAlarm.settings.tone,
        volume: shiftAlarm.settings.volume,
        createdAt: DateTime.now(),
        type: alarmType,
        // No scheduledDate for recurring alarms
      );
      
      print('   📅 Creating weekly recurring BasicAlarm for ${_getWeekdayName(weekday)} (${shiftType.displayName})');
      
      // Schedule using BasicAlarm recurring system
      await _basicAlarmService.scheduleBasicAlarm(weeklyBasicAlarm);
      createdAlarms.add(weeklyBasicAlarm);
    }
    
    print('✅ OPTIMIZED: Created ${createdAlarms.length} weekly recurring BasicAlarms for ShiftAlarm: ${shiftAlarm.title}');
    print('   This replaces ${30 * shiftAlarm.targetShiftTypes.length} individual alarms!');
    return createdAlarms;
  }
  
  String _getWeekdayName(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }
  
  /// Helper method: Force cancel any notifications that match shift alarm ID pattern
  Future<void> _forceCancelShiftNotifications(String shiftAlarmId) async {
    print('   🧹 Force cancelling notifications containing: $shiftAlarmId');
    
    // Use the BasicAlarmService method to get all pending notifications
    final allPending = await _basicAlarmService.getPendingBasicAlarms();
    
    for (final request in allPending) {
      // Check if this notification is related to our shift alarm
      bool shouldCancel = false;
      
      if (request.payload != null) {
        try {
          final payload = jsonDecode(request.payload!);
          final alarmId = payload['alarmId'] as String?;
          if (alarmId != null && alarmId.contains(shiftAlarmId)) {
            shouldCancel = true;
          }
        } catch (e) {
          // If payload parsing fails, check title/body
          if (request.title != null && request.title!.contains(shiftAlarmId)) {
            shouldCancel = true;
          }
        }
      }
      
      if (shouldCancel) {
        print('     🧹 Force cancelling notification: ${request.id} (${request.title})');
        await _basicAlarmService.cancelBasicAlarm(request.id.toString());
      }
    }
  }
  
  /// Helper method: Count remaining notifications for a shift alarm
  Future<int> _countRemainingShiftNotifications(String shiftAlarmId) async {
    final allPending = await _basicAlarmService.getPendingBasicAlarms();
    int count = 0;
    
    for (final request in allPending) {
      if (request.payload != null) {
        try {
          final payload = jsonDecode(request.payload!);
          final alarmId = payload['alarmId'] as String?;
          if (alarmId != null && alarmId.contains(shiftAlarmId)) {
            count++;
          }
        } catch (e) {
          // If payload parsing fails, check title
          if (request.title != null && request.title!.contains(shiftAlarmId)) {
            count++;
          }
        }
      }
    }
    
    return count;
  }
  
  /// Cancel all BasicAlarms associated with a ShiftAlarm
  /// ENHANCED: Also searches pending notifications directly for orphaned alarms
  Future<void> cancelShiftAlarms(String shiftAlarmId) async {
    print('🗑️ Cancelling BasicAlarms for ShiftAlarm: $shiftAlarmId');
    
    // Method 1: Cancel from stored BasicAlarms
    final allBasicAlarms = await _basicAlarmService.getAllBasicAlarms();
    final shiftBasicAlarms = allBasicAlarms.where(
      (alarm) => alarm.id.startsWith('${shiftAlarmId}_')
    ).toList();
    
    print('   Found ${shiftBasicAlarms.length} stored BasicAlarms to cancel');
    for (final alarm in shiftBasicAlarms) {
      print('     - Will cancel: ${alarm.id} (${alarm.label})');
      await _basicAlarmService.cancelBasicAlarm(alarm.id);
      print('   ✅ Cancelled stored: ${alarm.label}');
    }
    
    // Method 2: CRITICAL FIX - Also check pending notifications directly
    // This catches orphaned notifications that aren't in SharedPreferences
    final pendingAlarms = await _basicAlarmService.getPendingBasicAlarms();
    int orphanedCount = 0;
    
    for (final pending in pendingAlarms) {
      if (pending.payload != null) {
        try {
          final payload = jsonDecode(pending.payload!);
          final pendingAlarmId = payload['alarmId'] as String?;
          
          // Check if this notification belongs to our ShiftAlarm
          if (pendingAlarmId != null && pendingAlarmId.startsWith('${shiftAlarmId}_')) {
            print('   🚨 Found orphaned notification: ${pending.id} for alarm ${pendingAlarmId}');
            await _basicAlarmService.cancelBasicAlarm(pendingAlarmId);
            orphanedCount++;
          }
        } catch (e) {
          // Invalid payload, skip
        }
      }
    }
    
    // Method 3: CRITICAL FIX - Force cancel any remaining notifications that contain shift ID
    // This is an aggressive cleanup for notifications that might be orphaned
    await _forceCancelShiftNotifications(shiftAlarmId);
    int aggressiveCount = await _countRemainingShiftNotifications(shiftAlarmId);
    
    if (orphanedCount > 0) {
      print('   🧹 Cleaned up $orphanedCount orphaned notifications');
    }
    if (aggressiveCount > 0) {
      print('   🧹 Aggressive cleanup: $aggressiveCount additional notifications');
    }
    
    final totalCancelled = shiftBasicAlarms.length + orphanedCount + aggressiveCount;
    print('✅ Cancelled $totalCancelled total alarms for ShiftAlarm: $shiftAlarmId');
  }
  
  /// EMERGENCY CLEANUP: Force remove ALL basic alarms to solve orphaned notification problem
  Future<void> forceCleanupAllShiftAlarms() async {
    print('🚨 FORCE CLEANUP: Removing ALL basic alarms...');
    
    try {
      // Method 1: Cancel all stored BasicAlarms
      await _basicAlarmService.cancelAllBasicAlarms();
      print('   ✅ Cancelled all stored BasicAlarms');
      
      // Method 2: Get current pending count for diagnosis
      final initialPending = await _basicAlarmService.getPendingBasicAlarms();
      print('   📊 Current pending notifications: ${initialPending.length}');
      
      // Method 3: Cancel all pending notifications that look like shift alarms
      final allPending = await _basicAlarmService.getPendingBasicAlarms();
      int forceCancelledCount = 0;
      
      for (final pending in allPending) {
        if (pending.payload != null) {
          try {
            final payload = jsonDecode(pending.payload!);
            final alarmId = payload['alarmId'] as String?;
            
            // If it looks like a shift alarm (contains UUID pattern), force cancel it
            if (alarmId != null && (alarmId.contains('_basic_') || alarmId.contains('_weekly_') || alarmId.length > 30)) {
              print('   🧹 Force cancelling: ${pending.id} (${alarmId})');
              // Use the BasicAlarmService method to cancel by specific alarm ID
              await _basicAlarmService.cancelBasicAlarm(alarmId);
              forceCancelledCount++;
            }
          } catch (e) {
            // If payload parsing fails but looks like alarm, try direct cancellation
            if (pending.title != null && (
                pending.title!.contains('Shift Alarm') || 
                pending.title!.contains('ALARM TRIGGER') ||
                pending.title!.contains('Off') ||
                pending.title!.contains('Day') ||
                pending.title!.contains('Night')
            )) {
              print('   🧹 Force cancelling by pattern: ${pending.id} (${pending.title})');
              await _basicAlarmService.cancelBasicAlarm(pending.id.toString());
              forceCancelledCount++;
            } else {
              print('   ⚠️ Skipping malformed notification: ${pending.id} - $e');
            }
          }
        }
      }
      
      // Method 4: Final verification count
      final finalPending = await _basicAlarmService.getPendingBasicAlarms();
      print('   📊 Final pending notifications: ${finalPending.length}');
      
      print('   🧹 Force cancelled $forceCancelledCount pending notifications');
      print('   📉 Reduced from ${initialPending.length} to ${finalPending.length} notifications');
      print('✅ FORCE CLEANUP completed successfully');
      
    } catch (e) {
      print('❌ Error during force cleanup: $e');
      print('⚠️ Continuing anyway...');
    }
  }
  
  /// Update ShiftAlarm by recreating associated BasicAlarms
  Future<void> updateShiftAlarms(
    ShiftAlarm shiftAlarm, 
    ShiftPattern pattern,
  ) async {
    print('🔄 Updating ShiftAlarm: ${shiftAlarm.title}');
    
    // Cancel existing BasicAlarms
    await cancelShiftAlarms(shiftAlarm.id);
    
    // Create new BasicAlarms with updated settings
    await scheduleShiftAlarmsAsBasicAlarms(shiftAlarm, pattern);
    
    print('✅ Updated ShiftAlarm successfully');
  }
  
  /// Get all BasicAlarms associated with a ShiftAlarm
  Future<List<BasicAlarm>> getShiftBasicAlarms(String shiftAlarmId) async {
    final allBasicAlarms = await _basicAlarmService.getAllBasicAlarms();
    
    // Updated to match both old and new ID formats:
    // Old: ${shiftAlarm.id}_${alarmType.value}_${dateStr}_${timeStr}
    // New: ${shiftAlarm.id}_weekly_${alarmType.value}_${weekday}
    return allBasicAlarms.where(
      (alarm) => alarm.id.startsWith('${shiftAlarmId}_')
    ).toList();
  }
  
  /// Test method: Create immediate shift alarm for testing
  Future<BasicAlarm?> createTestShiftAlarm(
    String shiftType,
    {int secondsFromNow = 10}
  ) async {
    print('🧪 Creating test shift alarm for $shiftType (${secondsFromNow}s from now)');
    
    final testTime = DateTime.now().add(Duration(seconds: secondsFromNow));
    final timeOfDay = TimeOfDay(hour: testTime.hour, minute: testTime.minute);
    
    // Map shift type to tone and alarm type
    AlarmTone testTone;
    AlarmType testAlarmType;
    switch (shiftType) {
      case 'day_shift':
        testTone = AlarmTone.wakeupcall;
        testAlarmType = AlarmType.day;
        break;
      case 'night_shift':
        testTone = AlarmTone.emergencyAlarm;
        testAlarmType = AlarmType.night;
        break;
      case 'day_off':
        testTone = AlarmTone.gentleAcoustic;
        testAlarmType = AlarmType.off;
        break;
      default:
        testTone = AlarmTone.wakeupcall;
        testAlarmType = AlarmType.basic;
    }
    
    final testAlarm = BasicAlarm(
      id: 'test_shift_${shiftType}_${DateTime.now().millisecondsSinceEpoch}',
      label: 'TEST ${shiftType.toUpperCase()} (${secondsFromNow}s)',
      time: timeOfDay,
      repeatDays: {},
      isActive: true,
      tone: testTone,
      volume: 0.9,
      createdAt: DateTime.now(),
      type: testAlarmType, // NEW: Set proper alarm type
    );
    
    print('   Test alarm scheduled for: ${testTime.toString()}');
    print('   Using tone: ${testTone.displayName}');
    
    await _basicAlarmService.scheduleBasicAlarm(testAlarm);
    
    print('✅ Test shift alarm created successfully');
    return testAlarm;
  }
}