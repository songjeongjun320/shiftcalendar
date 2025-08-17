import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
import '../models/basic_alarm.dart';
import '../models/alarm_enums.dart';
import 'basic_alarm_service.dart';

/// 🎯 Cycle-Based Alarm Manager
/// 사이클 기반 알람 관리 시스템 - 6일 패턴으로 효율적 관리
/// 
/// 핵심 개념:
/// 1. 한 사이클(6일)분만 알람 생성 → 최대 6개 알람
/// 2. 알람 트리거 → 자동 소모 → 개수 감소  
/// 3. 0개 되면 → 다음 사이클 자동 생성
/// 4. SHIFT 알람과 기본 알람 독립적 관리
class CycleAlarmManager {
  final BasicAlarmService _basicAlarmService;
  static const String _shiftAlarmCountKey = 'shift_alarm_count';
  static const String _basicAlarmCountKey = 'basic_alarm_count';
  static const String _lastCycleGeneratedKey = 'last_cycle_generated';
  
  // 사이클 설정
  static const int MIN_ALARMS_THRESHOLD = 2; // 2개 이하면 리필
  static const int MAX_ALARMS_PER_CYCLE = 20; // 한 사이클 최대 알람 수 (패턴에 따라 가변)
  
  // 🔄 자동 리필 콜백 (순환 의존성 방지)
  Future<void> Function()? _autoRefillCallback;

  CycleAlarmManager(this._basicAlarmService);
  
  /// 🔗 자동 리필 콜백 설정
  void setAutoRefillCallback(Future<void> Function() callback) {
    _autoRefillCallback = callback;
    print('🔗 AUTO-REFILL callback registered');
  }

  /// 🔄 사이클 기반 SHIFT 알람 생성
  /// 패턴의 실제 사이클 길이에 맞춰 한 사이클분만 생성
  Future<List<BasicAlarm>> generateShiftAlarmCycle(
    ShiftAlarm shiftAlarm, 
    ShiftPattern pattern,
  ) async {
    print('🔄 CYCLE MANAGER: Generating one cycle for ${shiftAlarm.title}');
    print('   Pattern: ${pattern.name}');
    
    // 🎯 패턴의 실제 사이클 길이 사용 (동적)
    final actualCycleLength = pattern.cycle.length;
    print('   Actual cycle length: $actualCycleLength days');
    
    final createdAlarms = <BasicAlarm>[];
    
    // 현재 SHIFT 알람 개수 확인
    final currentCount = await getShiftAlarmCount();
    print('   Current SHIFT alarm count: $currentCount');
    
    // 다음 사이클의 시작 날짜 계산
    final lastGenerated = await getLastCycleGenerated();
    final cycleStartDate = lastGenerated?.add(Duration(days: 1)) ?? DateTime.now();
    
    print('   Cycle start date: ${cycleStartDate.toString().substring(0, 10)}');
    
    // 🎯 패턴의 실제 사이클 길이만큼 시프트 찾기
    final cycleShifts = <DateTime>[];
    for (int i = 0; i < actualCycleLength; i++) {
      final checkDate = cycleStartDate.add(Duration(days: i));
      final shiftType = pattern.getShiftForDate(checkDate);
      
      // 타겟 시프트 타입과 일치하는지 확인
      if (shiftAlarm.targetShiftTypes.contains(shiftType)) {
        cycleShifts.add(checkDate);
        print('   ✅ Found target shift: ${checkDate.toString().substring(0, 10)} - ${shiftType.displayName}');
      }
    }
    
    print('   Found ${cycleShifts.length} target shifts in this cycle');
    
    // 각 시프트 날짜에 대해 BasicAlarm 생성
    for (final shiftDate in cycleShifts) {
      final actualShiftType = pattern.getShiftForDate(shiftDate);
      
      // AlarmType 매핑
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
      
      // 고유 ID 생성 (사이클 기반)
      final dateStr = shiftDate.toIso8601String().split('T')[0];
      final timeStr = '${shiftAlarm.time.hour.toString().padLeft(2, '0')}${shiftAlarm.time.minute.toString().padLeft(2, '0')}';
      final cycleId = 'cycle_${shiftAlarm.id}_${alarmType.value}_${dateStr}_${timeStr}';
      
      final basicAlarm = BasicAlarm(
        id: cycleId,
        label: '🔄 ${shiftAlarm.title} (${actualShiftType.displayName})',
        time: shiftAlarm.time,
        repeatDays: {}, // 일회성 알람
        isActive: shiftAlarm.isActive,
        tone: shiftAlarm.settings.tone,
        volume: shiftAlarm.settings.volume,
        createdAt: DateTime.now(),
        type: alarmType,
        scheduledDate: shiftDate, // 특정 날짜 지정
      );
      
      // BasicAlarm 스케줄링
      await _basicAlarmService.scheduleBasicAlarm(basicAlarm);
      createdAlarms.add(basicAlarm);
      
      print('   📅 Created cycle alarm for ${dateStr} (${actualShiftType.displayName})');
    }
    
    // SHIFT 알람 카운트 업데이트 (기본 알람과 독립적)
    await updateShiftAlarmCount(currentCount + createdAlarms.length);
    
    // 마지막 생성 날짜 저장 (패턴의 실제 사이클 길이 사용)
    await saveLastCycleGenerated(cycleStartDate.add(Duration(days: actualCycleLength - 1)));
    
    print('✅ CYCLE GENERATED: ${createdAlarms.length} SHIFT alarms created');
    print('   Pattern cycle length: $actualCycleLength days');
    print('   Updated SHIFT count: ${currentCount + createdAlarms.length}');
    
    return createdAlarms;
  }

  /// 🗑️ 알람 소모 (트리거 시 자동 호출)
  /// SHIFT 알람과 기본 알람을 독립적으로 관리
  Future<void> consumeAlarm(String alarmId, {bool isShiftAlarm = true}) async {
    print('🗑️ CONSUMING ALARM: $alarmId (isShift: $isShiftAlarm)');
    
    try {
      // 알람 취소
      await _basicAlarmService.cancelBasicAlarm(alarmId);
      
      // 해당 타입의 카운트 감소 (독립적 관리)
      if (isShiftAlarm && alarmId.contains('cycle_')) {
        final currentCount = await getShiftAlarmCount();
        await updateShiftAlarmCount(currentCount - 1);
        print('   ✅ SHIFT alarm consumed. Count: ${currentCount - 1}');
        
        // 자동 리필 체크
        await checkAndRefillShiftAlarms();
      } else {
        final currentCount = await getBasicAlarmCount();
        await updateBasicAlarmCount(currentCount - 1);
        print('   ✅ Basic alarm consumed. Count: ${currentCount - 1}');
      }
      
    } catch (e) {
      print('❌ Error consuming alarm $alarmId: $e');
    }
  }

  /// 🔍 SHIFT 알람 자동 리필 체크
  Future<void> checkAndRefillShiftAlarms() async {
    final currentCount = await getShiftAlarmCount();
    print('🔍 REFILL CHECK: Current SHIFT alarm count: $currentCount');
    
    if (currentCount <= MIN_ALARMS_THRESHOLD) {
      print('🚨 REFILL NEEDED: SHIFT alarm count below threshold ($MIN_ALARMS_THRESHOLD)');
      
      // 🔄 자동 리필 콜백 실행
      if (_autoRefillCallback != null) {
        print('🔄 Triggering auto-refill callback...');
        try {
          await _autoRefillCallback!();
          print('✅ Auto-refill callback completed');
        } catch (e) {
          print('❌ Auto-refill callback error: $e');
        }
      } else {
        print('⚠️ Auto-refill callback not registered');
        // 자동 리필 이벤트 발생 알림 (fallback)
        await _notifyRefillNeeded();
      }
    } else {
      print('✅ REFILL NOT NEEDED: SHIFT alarm count sufficient');
    }
  }

  /// 📊 SHIFT 알람 개수 관리 (기본 알람과 독립적)
  Future<int> getShiftAlarmCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_shiftAlarmCountKey) ?? 0;
  }

  Future<void> updateShiftAlarmCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shiftAlarmCountKey, count);
    print('📊 SHIFT alarm count updated: $count');
  }

  /// 📊 기본 알람 개수 관리 (SHIFT 알람과 독립적)
  Future<int> getBasicAlarmCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_basicAlarmCountKey) ?? 0;
  }

  Future<void> updateBasicAlarmCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_basicAlarmCountKey, count);
    print('📊 Basic alarm count updated: $count');
  }

  /// 📅 마지막 사이클 생성 날짜 관리
  Future<DateTime?> getLastCycleGenerated() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastCycleGeneratedKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<void> saveLastCycleGenerated(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCycleGeneratedKey, date.millisecondsSinceEpoch);
    print('📅 Last cycle generated date saved: ${date.toString().substring(0, 10)}');
  }

  /// 🔔 리필 필요 알림
  Future<void> _notifyRefillNeeded() async {
    // TODO: 앱에서 자동 리필 트리거하는 이벤트 발생
    // 예: EventBus, StreamController, Callback 등 사용
    print('🔔 REFILL EVENT: Notifying app to refill SHIFT alarms');
  }

  /// 🧹 전체 초기화 (디버깅용)
  Future<void> resetAllCycles() async {
    print('🧹 RESETTING ALL CYCLES...');
    
    await _basicAlarmService.cancelAllBasicAlarms();
    await updateShiftAlarmCount(0);
    await updateBasicAlarmCount(0);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastCycleGeneratedKey);
    
    print('✅ All cycles reset successfully');
  }

  /// 📈 시스템 상태 확인
  Future<Map<String, dynamic>> getSystemStatus() async {
    final shiftCount = await getShiftAlarmCount();
    final basicCount = await getBasicAlarmCount();
    final lastGenerated = await getLastCycleGenerated();
    final pendingAlarms = await _basicAlarmService.getPendingBasicAlarmsCount();
    
    return {
      'shiftAlarmCount': shiftCount,
      'basicAlarmCount': basicCount,
      'lastCycleGenerated': lastGenerated?.toString(),
      'pendingNotifications': pendingAlarms,
      'needsRefill': shiftCount <= MIN_ALARMS_THRESHOLD,
      'systemHealth': shiftCount > 0 ? 'healthy' : 'needs_attention',
    };
  }

  /// 🔍 디버그 정보 출력
  Future<void> debugCycleStatus() async {
    final status = await getSystemStatus();
    
    print('=== CYCLE MANAGER DEBUG ===');
    print('SHIFT Alarms: ${status['shiftAlarmCount']}');
    print('Basic Alarms: ${status['basicAlarmCount']}');
    print('Last Generated: ${status['lastCycleGenerated'] ?? 'Never'}');
    print('Pending Notifications: ${status['pendingNotifications']}');
    print('Needs Refill: ${status['needsRefill']}');
    print('System Health: ${status['systemHealth']}');
    print('===========================');
  }
}