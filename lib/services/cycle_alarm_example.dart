import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
import '../models/shift_type.dart';
import '../models/basic_alarm.dart';
import '../models/alarm_enums.dart';
import 'unified_alarm_service.dart';

/// 🎯 Cycle-Based Alarm System Usage Example
/// 사이클 기반 알람 시스템 사용 예제
/// 
/// 이 예제는 새로운 시스템의 사용법을 보여줍니다:
/// 1. 한 사이클(6일)분만 생성
/// 2. 자동 소모 및 리필
/// 3. SHIFT vs 기본 알람 독립 관리
class CycleAlarmExample {
  late final UnifiedAlarmService _unifiedService;
  
  CycleAlarmExample() {
    final notifications = FlutterLocalNotificationsPlugin();
    _unifiedService = UnifiedAlarmService(notifications);
  }

  /// 🚀 시스템 초기화 및 데모 실행
  Future<void> runDemo() async {
    print('🎯 === CYCLE-BASED ALARM SYSTEM DEMO ===');
    
    try {
      // 1. 시스템 초기화
      await _unifiedService.initialize();
      print('\n✅ System initialized successfully');
      
      // 2. SHIFT 알람 생성 데모
      await _demonstrateShiftAlarms();
      
      // 3. 기본 알람 생성 데모
      await _demonstrateBasicAlarms();
      
      // 4. 독립적 관리 데모
      await _demonstrateIndependentManagement();
      
      // 5. 자동 리필 데모
      await _demonstrateAutoRefill();
      
      print('\n🎉 === DEMO COMPLETED SUCCESSFULLY ===');
      
    } catch (e) {
      print('❌ Demo failed: $e');
    }
  }

  /// 📋 SHIFT 알람 생성 데모
  Future<void> _demonstrateShiftAlarms() async {
    print('\n📋 === SHIFT ALARMS DEMO ===');
    
    // Day-Day-Night-Night-Off-Off 패턴 생성
    final shiftPattern = ShiftPattern(
      id: 'demo_pattern_001',
      name: 'Demo 6-Day Pattern',
      cycle: [
        ShiftType.day,    // Day 1
        ShiftType.day,    // Day 2
        ShiftType.night,  // Day 3
        ShiftType.night,  // Day 4
        ShiftType.off,      // Day 5
        ShiftType.off,      // Day 6
      ],
      startDate: DateTime.now(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    
    // SHIFT 알람 생성 (Day shifts용)
    final dayShiftAlarm = ShiftAlarm(
      id: 'demo_day_alarm_001',
      patternId: shiftPattern.id,
      alarmType: AlarmType.day,
      targetShiftTypes: {ShiftType.day},
      time: TimeOfDay(hour: 6, minute: 0),
      title: '🌅 Day Shift Alarm',
      message: 'Time for day shift!',
      isActive: true,
      settings: AlarmSettings(
        tone: AlarmTone.wakeupcall,
        volume: 0.8,
        vibration: true,
        sound: true,
      ),
      createdAt: DateTime.now(),
    );
    
    // SHIFT 알람 생성 (Night shifts용)
    final nightShiftAlarm = ShiftAlarm(
      id: 'demo_night_alarm_001',
      patternId: shiftPattern.id,
      alarmType: AlarmType.night,
      targetShiftTypes: {ShiftType.night},
      time: TimeOfDay(hour: 18, minute: 0),
      title: '🌙 Night Shift Alarm',
      message: 'Time for night shift!',
      isActive: true,
      settings: AlarmSettings(
        tone: AlarmTone.emergencyAlarm,
        volume: 0.9,
        vibration: true,
        sound: true,
      ),
      createdAt: DateTime.now(),
    );
    
    // 사이클 생성
    final dayAlarms = await _unifiedService.createShiftAlarmCycle(dayShiftAlarm, shiftPattern);
    final nightAlarms = await _unifiedService.createShiftAlarmCycle(nightShiftAlarm, shiftPattern);
    
    print('✅ Created ${dayAlarms.length} day shift alarms');
    print('✅ Created ${nightAlarms.length} night shift alarms');
    
    // SHIFT 알람 상태 확인
    final shiftCount = await _unifiedService.getShiftAlarmCount();
    print('📊 Total SHIFT alarms: $shiftCount');
  }

  /// ⚡ 기본 알람 생성 데모
  Future<void> _demonstrateBasicAlarms() async {
    print('\n⚡ === BASIC ALARMS DEMO ===');
    
    // 기본 알람 생성 (일반 알람)
    final basicAlarm1 = BasicAlarm(
      id: 'demo_basic_001',
      label: '⏰ Morning Exercise',
      time: TimeOfDay(hour: 7, minute: 0),
      repeatDays: {1, 2, 3, 4, 5}, // 월-금
      isActive: true,
      tone: AlarmTone.gentleAcoustic,
      volume: 0.6,
      createdAt: DateTime.now(),
      type: AlarmType.basic,
    );
    
    final basicAlarm2 = BasicAlarm(
      id: 'demo_basic_002',
      label: '💊 Take Medicine',
      time: TimeOfDay(hour: 20, minute: 0),
      repeatDays: {1, 2, 3, 4, 5, 6, 7}, // 매일
      isActive: true,
      tone: AlarmTone.gentleAcoustic,
      volume: 0.7,
      createdAt: DateTime.now(),
      type: AlarmType.basic,
    );
    
    // 기본 알람 생성
    await _unifiedService.createBasicAlarm(basicAlarm1);
    await _unifiedService.createBasicAlarm(basicAlarm2);
    
    // 기본 알람 상태 확인
    final basicCount = await _unifiedService.getBasicAlarmCount();
    print('📊 Total basic alarms: $basicCount');
  }

  /// 🔄 독립적 관리 데모
  Future<void> _demonstrateIndependentManagement() async {
    print('\n🔄 === INDEPENDENT MANAGEMENT DEMO ===');
    
    // 각 타입별 개수 확인
    final shiftCount = await _unifiedService.getShiftAlarmCount();
    final basicCount = await _unifiedService.getBasicAlarmCount();
    
    print('Before operations:');
    print('   SHIFT alarms: $shiftCount');
    print('   Basic alarms: $basicCount');
    
    // 기본 알람 하나 취소 (SHIFT에 영향 없음)
    await _unifiedService.cancelBasicAlarm('demo_basic_001');
    
    final shiftCountAfter = await _unifiedService.getShiftAlarmCount();
    final basicCountAfter = await _unifiedService.getBasicAlarmCount();
    
    print('After canceling one basic alarm:');
    print('   SHIFT alarms: $shiftCountAfter (unchanged ✅)');
    print('   Basic alarms: $basicCountAfter (decreased ✅)');
    
    // 독립성 확인
    if (shiftCount == shiftCountAfter && basicCount > basicCountAfter) {
      print('🎉 INDEPENDENCE CONFIRMED: SHIFT and Basic alarms are managed separately!');
    } else {
      print('❌ INDEPENDENCE FAILED: Alarms are not properly separated');
    }
  }

  /// 🔄 자동 리필 데모
  Future<void> _demonstrateAutoRefill() async {
    print('\n🔄 === AUTO-REFILL DEMO ===');
    
    print('Current system status:');
    await _unifiedService.debugFullSystemStatus();
    
    // 수동 리필 트리거
    print('Triggering manual refill check...');
    await _unifiedService.triggerManualRefill();
    
    print('Auto-refill demo completed');
  }

  /// 🧹 데모 정리
  Future<void> cleanup() async {
    print('\n🧹 === CLEANING UP DEMO ===');
    
    await _unifiedService.cancelAllAlarms();
    await _unifiedService.dispose();
    
    print('✅ Demo cleanup completed');
  }

  /// 📊 빠른 상태 체크
  Future<void> quickStatusCheck() async {
    print('\n📊 === QUICK STATUS CHECK ===');
    
    final status = await _unifiedService.getFullSystemStatus();
    
    print('System Health: ${status['systemHealth']}');
    print('SHIFT Alarms: ${(status['shiftAlarms'] as Map)['shiftAlarmCount']}');
    print('Basic Alarms: ${(status['shiftAlarms'] as Map)['basicAlarmCount']}');
    print('Auto-Refill: ${(status['autoRefill'] as Map)['autoRefillEnabled']}');
    
    final health = status['systemHealth'] as String;
    if (health == 'excellent' || health == 'good') {
      print('✅ System is working well!');
    } else {
      print('⚠️ System needs attention');
    }
  }
}

/// 🎯 사용 예제 함수
/// 앱의 메인에서 호출하여 사이클 시스템을 테스트할 수 있습니다
Future<void> runCycleAlarmDemo() async {
  final demo = CycleAlarmExample();
  
  try {
    await demo.runDemo();
    await demo.quickStatusCheck();
  } finally {
    await demo.cleanup();
  }
}