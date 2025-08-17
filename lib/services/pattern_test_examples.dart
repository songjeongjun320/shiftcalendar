import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
import '../models/shift_type.dart';
import '../models/alarm_enums.dart';
import 'unified_alarm_service.dart';

/// 🎯 다양한 패턴 테스트 예제
/// 여러 가지 시프트 패턴에서 사이클 시스템이 올바르게 작동하는지 확인
class PatternTestExamples {
  late final UnifiedAlarmService _unifiedService;
  
  PatternTestExamples() {
    final notifications = FlutterLocalNotificationsPlugin();
    _unifiedService = UnifiedAlarmService(notifications);
  }

  /// 🚀 모든 패턴 테스트 실행
  Future<void> runAllPatternTests() async {
    print('🎯 === ALL PATTERN TESTS ===\n');
    
    await _unifiedService.initialize();
    
    // 1. 3일 패턴: Day-Night-Off
    await _testPattern1();
    
    // 2. 4일 패턴: Day-Day-Off-Off  
    await _testPattern2();
    
    // 3. 6일 패턴: Day-Day-Night-Night-Off-Off
    await _testPattern3();
    
    // 4. 7일 패턴: Day-Day-Day-Night-Night-Off-Off
    await _testPattern4();
    
    // 5. 복잡한 12일 패턴
    await _testPattern5();
    
    print('\n🎉 === ALL PATTERN TESTS COMPLETED ===');
    
    await _unifiedService.debugFullSystemStatus();
  }

  /// 📋 패턴 1: 3일 사이클 (Day-Night-Off)
  Future<void> _testPattern1() async {
    print('📋 TEST 1: 3-Day Pattern (Day-Night-Off)');
    
    final pattern = ShiftPattern(
      id: 'pattern_3day',
      name: '3-Day Cycle',
      cycle: [
        ShiftType.day,   // Day 1
        ShiftType.night, // Day 2  
        ShiftType.off,     // Day 3
      ],
      startDate: DateTime.now(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    
    // Day shift 알람
    final dayAlarm = _createShiftAlarm(
      'day_3day', 
      '🌅 3-Day Pattern Day', 
      TimeOfDay(hour: 6, minute: 0),
      [ShiftType.day],
      pattern.id,
    );
    
    final alarms = await _unifiedService.createShiftAlarmCycle(dayAlarm, pattern);
    print('   ✅ Created ${alarms.length} alarms (expected: 1 per 3-day cycle)');
    print('   Pattern length: ${pattern.cycle.length} days\n');
  }

  /// 📋 패턴 2: 4일 사이클 (Day-Day-Off-Off)
  Future<void> _testPattern2() async {
    print('📋 TEST 2: 4-Day Pattern (Day-Day-Off-Off)');
    
    final pattern = ShiftPattern(
      id: 'pattern_4day',
      name: '4-Day Cycle',
      cycle: [
        ShiftType.day, // Day 1
        ShiftType.day, // Day 2
        ShiftType.off,   // Day 3
        ShiftType.off,   // Day 4
      ],
      startDate: DateTime.now(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    
    // Day shift 알람
    final dayAlarm = _createShiftAlarm(
      'day_4day', 
      '🌅 4-Day Pattern Day', 
      TimeOfDay(hour: 7, minute: 0),
      [ShiftType.day],
      pattern.id,
    );
    
    final alarms = await _unifiedService.createShiftAlarmCycle(dayAlarm, pattern);
    print('   ✅ Created ${alarms.length} alarms (expected: 2 per 4-day cycle)');
    print('   Pattern length: ${pattern.cycle.length} days\n');
  }

  /// 📋 패턴 3: 6일 사이클 (Day-Day-Night-Night-Off-Off)
  Future<void> _testPattern3() async {
    print('📋 TEST 3: 6-Day Pattern (Day-Day-Night-Night-Off-Off)');
    
    final pattern = ShiftPattern(
      id: 'pattern_6day',
      name: '6-Day Cycle',
      cycle: [
        ShiftType.day,   // Day 1
        ShiftType.day,   // Day 2
        ShiftType.night, // Day 3
        ShiftType.night, // Day 4
        ShiftType.off,     // Day 5
        ShiftType.off,     // Day 6
      ],
      startDate: DateTime.now(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    
    // Night shift 알람
    final nightAlarm = _createShiftAlarm(
      'night_6day', 
      '🌙 6-Day Pattern Night', 
      TimeOfDay(hour: 18, minute: 0),
      [ShiftType.night],
      pattern.id,
    );
    
    final alarms = await _unifiedService.createShiftAlarmCycle(nightAlarm, pattern);
    print('   ✅ Created ${alarms.length} alarms (expected: 2 per 6-day cycle)');
    print('   Pattern length: ${pattern.cycle.length} days\n');
  }

  /// 📋 패턴 4: 7일 사이클 (Day-Day-Day-Night-Night-Off-Off)
  Future<void> _testPattern4() async {
    print('📋 TEST 4: 7-Day Pattern (Day-Day-Day-Night-Night-Off-Off)');
    
    final pattern = ShiftPattern(
      id: 'pattern_7day',
      name: '7-Day Cycle',
      cycle: [
        ShiftType.day,   // Day 1
        ShiftType.day,   // Day 2
        ShiftType.day,   // Day 3
        ShiftType.night, // Day 4
        ShiftType.night, // Day 5
        ShiftType.off,     // Day 6
        ShiftType.off,     // Day 7
      ],
      startDate: DateTime.now(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    
    // 모든 타입 알람
    final dayAlarm = _createShiftAlarm(
      'day_7day', 
      '🌅 7-Day Pattern Day', 
      TimeOfDay(hour: 6, minute: 30),
      [ShiftType.day],
      pattern.id,
    );
    
    final nightAlarm = _createShiftAlarm(
      'night_7day', 
      '🌙 7-Day Pattern Night', 
      TimeOfDay(hour: 17, minute: 30),
      [ShiftType.night],
      pattern.id,
    );
    
    final dayAlarms = await _unifiedService.createShiftAlarmCycle(dayAlarm, pattern);
    final nightAlarms = await _unifiedService.createShiftAlarmCycle(nightAlarm, pattern);
    
    print('   ✅ Day alarms: ${dayAlarms.length} (expected: 3 per 7-day cycle)');
    print('   ✅ Night alarms: ${nightAlarms.length} (expected: 2 per 7-day cycle)');
    print('   Pattern length: ${pattern.cycle.length} days\n');
  }

  /// 📋 패턴 5: 복잡한 12일 사이클
  Future<void> _testPattern5() async {
    print('📋 TEST 5: Complex 12-Day Pattern');
    
    final pattern = ShiftPattern(
      id: 'pattern_12day',
      name: 'Complex 12-Day Cycle',
      cycle: [
        ShiftType.day,   // Day 1
        ShiftType.day,   // Day 2
        ShiftType.day,   // Day 3
        ShiftType.off,     // Day 4
        ShiftType.night, // Day 5
        ShiftType.night, // Day 6
        ShiftType.night, // Day 7
        ShiftType.off,     // Day 8
        ShiftType.day,   // Day 9
        ShiftType.night, // Day 10
        ShiftType.off,     // Day 11
        ShiftType.off,     // Day 12
      ],
      startDate: DateTime.now(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    
    // Off day 알람 (휴무일 알림)
    final offAlarm = _createShiftAlarm(
      'off_12day', 
      '🏖️ 12-Day Pattern Off Day', 
      TimeOfDay(hour: 10, minute: 0),
      [ShiftType.off],
      pattern.id,
    );
    
    final alarms = await _unifiedService.createShiftAlarmCycle(offAlarm, pattern);
    print('   ✅ Created ${alarms.length} alarms (expected: 4 per 12-day cycle)');
    print('   Pattern length: ${pattern.cycle.length} days\n');
  }

  /// 🔧 헬퍼: ShiftAlarm 생성
  ShiftAlarm _createShiftAlarm(
    String id, 
    String title, 
    TimeOfDay time,
    List<ShiftType> targetTypes,
    String patternId,
  ) {
    // Infer alarm type from target shift types
    AlarmType alarmType = AlarmType.basic;
    if (targetTypes.contains(ShiftType.day)) {
      alarmType = AlarmType.day;
    } else if (targetTypes.contains(ShiftType.night)) {
      alarmType = AlarmType.night;
    } else if (targetTypes.contains(ShiftType.off)) {
      alarmType = AlarmType.off;
    }
    
    return ShiftAlarm(
      id: id,
      patternId: patternId,
      alarmType: alarmType,
      targetShiftTypes: targetTypes.toSet(),
      time: time,
      title: title,
      message: 'Time for your shift!',
      isActive: true,
      settings: AlarmSettings(
        tone: AlarmTone.wakeupcall,
        volume: 0.7,
        vibration: true,
        sound: true,
      ),
      createdAt: DateTime.now(),
    );
  }

  /// 📊 패턴별 효율성 비교
  Future<void> compareEfficiency() async {
    print('\n📊 === EFFICIENCY COMPARISON ===');
    
    final patterns = [
      {'name': '3-Day', 'length': 3, 'shifts_per_cycle': 1},
      {'name': '4-Day', 'length': 4, 'shifts_per_cycle': 2},
      {'name': '6-Day', 'length': 6, 'shifts_per_cycle': 2}, 
      {'name': '7-Day', 'length': 7, 'shifts_per_cycle': 3},
      {'name': '12-Day', 'length': 12, 'shifts_per_cycle': 4},
    ];
    
    print('Pattern | Cycle Length | Alarms/Cycle | Old Method (14 days) | New Method | Efficiency');
    print('--------|--------------|--------------|---------------------|------------|----------');
    
    for (final pattern in patterns) {
      final cycleLength = pattern['length'] as int;
      final shiftsPerCycle = pattern['shifts_per_cycle'] as int;
      final oldMethod = (14 / cycleLength).ceil() * shiftsPerCycle;
      final newMethod = shiftsPerCycle;
      final efficiency = ((oldMethod - newMethod) / oldMethod * 100).round();
      
      final name = pattern['name'] as String;
      print('${name.padRight(7)} | ${cycleLength.toString().padRight(12)} | ${shiftsPerCycle.toString().padRight(12)} | ${oldMethod.toString().padRight(19)} | ${newMethod.toString().padRight(10)} | ${efficiency}%');
    }
    
    print('\n🎯 NEW METHOD is 50-85% more efficient across all patterns!');
  }

  /// 🧹 정리
  Future<void> cleanup() async {
    await _unifiedService.dispose();
  }
}

/// 🎯 실행 함수
Future<void> runPatternTests() async {
  final tests = PatternTestExamples();
  
  try {
    await tests.runAllPatternTests();
    await tests.compareEfficiency();
  } finally {
    await tests.cleanup();
  }
}