import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
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
  
  /// Convert ShiftAlarm to multiple BasicAlarm objects for upcoming shift dates
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
    
    // Find upcoming shift dates (next 30 days)
    final upcomingShifts = pattern.getUpcomingShifts(
      shiftAlarm.targetShiftTypes, 
      30 // days ahead - reasonable horizon
    );
    
    print('   Found ${upcomingShifts.length} upcoming shift dates for target types: ${shiftAlarm.targetShiftTypes.map((t) => t.displayName).join(', ')}');
    
    // Create BasicAlarm for each shift occurrence
    for (int i = 0; i < upcomingShifts.length && i < 30; i++) { // Limit to 30 alarms
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
  
  /// Cancel all BasicAlarms associated with a ShiftAlarm
  Future<void> cancelShiftAlarms(String shiftAlarmId) async {
    print('🗑️ Cancelling BasicAlarms for ShiftAlarm: $shiftAlarmId');
    
    // Get all stored BasicAlarms
    final allBasicAlarms = await _basicAlarmService.getAllBasicAlarms();
    
    // Find and cancel alarms that belong to this shift alarm
    // Updated to match new ID format: ${shiftAlarm.id}_${alarmType.value}_${dateStr}_${timeStr}
    final shiftBasicAlarms = allBasicAlarms.where(
      (alarm) => alarm.id.startsWith('${shiftAlarmId}_')
    ).toList();
    
    for (final alarm in shiftBasicAlarms) {
      await _basicAlarmService.cancelBasicAlarm(alarm.id);
      print('   ✅ Cancelled: ${alarm.label} (ID: ${alarm.id})');
    }
    
    print('✅ Cancelled ${shiftBasicAlarms.length} BasicAlarms for ShiftAlarm: $shiftAlarmId');
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
    
    // Updated to match new ID format: ${shiftAlarm.id}_${alarmType.value}_${dateStr}_${timeStr}
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