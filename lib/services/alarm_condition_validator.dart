import '../models/basic_alarm.dart';
import '../models/alarm_enums.dart';
import '../models/shift_type.dart';
import 'shift_storage_service.dart';

/// 알람 트리거 시점에 실시간으로 현재 날짜의 교대 타입과 알람 타입을 매칭 검증하는 서비스
/// 각 알람이 정확한 교대 조건에서만 작동하도록 보장합니다.
class AlarmConditionValidator {
  final ShiftStorageService _shiftStorageService;
  
  AlarmConditionValidator({ShiftStorageService? shiftStorageService})
      : _shiftStorageService = shiftStorageService ?? ShiftStorageService();
  
  /// 알람이 트리거되어야 하는지 실시간 검증
  /// 
  /// [alarm] 검증할 BasicAlarm 객체
  /// [triggerTime] 알람이 트리거되는 시점 (기본값: 현재 시간)
  /// 
  /// Returns: 알람이 트리거되어야 하면 true, 아니면 false
  Future<bool> shouldAlarmTrigger(
    BasicAlarm alarm, {
    DateTime? triggerTime,
  }) async {
    final checkTime = triggerTime ?? DateTime.now();
    
    print('🔍 AlarmConditionValidator: 알람 조건 검증 시작');
    print('   알람 ID: ${alarm.id}');
    print('   알람 타입: ${alarm.type.displayName}');
    print('   알람 라벨: ${alarm.label}');
    print('   검증 시간: ${checkTime.toString().substring(0, 19)}');
    
    // AlarmType.basic은 항상 허용 (기본 알람)
    if (alarm.type == AlarmType.basic) {
      print('   ✅ 기본 알람 타입 - 무조건 허용');
      return true;
    }
    
    try {
      // 현재 활성화된 교대 패턴 가져오기
      final activePattern = await _shiftStorageService.getActivePattern();
      
      if (activePattern == null) {
        print('   ⚠️ 활성 교대 패턴이 없음 - 알람 차단');
        return false;
      }
      
      print('   📋 활성 패턴: ${activePattern.name}');
      
      // 트리거 날짜의 실제 교대 타입 확인
      final actualShiftType = activePattern.getShiftForDate(checkTime);
      print('   📅 ${checkTime.toString().substring(0, 10)}의 실제 교대: ${actualShiftType.displayName}');
      
      // 알람 타입과 실제 교대 타입 매칭 검증
      final isMatching = _isAlarmTypeMatchingShift(alarm.type, actualShiftType);
      
      if (isMatching) {
        print('   ✅ 조건 매칭 성공 - 알람 허용');
        print('   📌 ${alarm.type.displayName} 알람이 ${actualShiftType.displayName} 교대에서 정상 트리거');
      } else {
        print('   🚫 조건 매칭 실패 - 알람 차단');
        print('   📌 ${alarm.type.displayName} 알람은 ${actualShiftType.displayName} 교대에서 트리거 불가');
      }
      
      return isMatching;
      
    } catch (e) {
      print('   ❌ 조건 검증 중 오류 발생: $e');
      // 오류 발생 시 안전하게 기본 알람으로 처리
      return alarm.type == AlarmType.basic;
    }
  }
  
  /// 알람 타입과 교대 타입이 매칭되는지 확인
  /// 
  /// [alarmType] 확인할 알람 타입
  /// [shiftType] 현재 교대 타입
  /// 
  /// Returns: 매칭되면 true, 아니면 false
  bool _isAlarmTypeMatchingShift(AlarmType alarmType, ShiftType shiftType) {
    switch (alarmType) {
      case AlarmType.day:
        // Day 알람은 Day Shift에서만 허용
        return shiftType == ShiftType.day;
      case AlarmType.night:
        // Night 알람은 Night Shift에서만 허용
        return shiftType == ShiftType.night;
      case AlarmType.off:
        // Off 알람은 Day Off에서만 허용
        return shiftType == ShiftType.off;
      case AlarmType.basic:
        // Basic 알람은 항상 허용
        return true;
    }
  }
  
  /// 특정 날짜에 대해 알람 타입이 유효한지 미리 확인
  /// 
  /// [alarmType] 확인할 알람 타입
  /// [targetDate] 확인할 날짜
  /// 
  /// Returns: 해당 날짜에 알람이 유효하면 true, 아니면 false
  Future<bool> isAlarmValidForDate(AlarmType alarmType, DateTime targetDate) async {
    if (alarmType == AlarmType.basic) return true;
    
    try {
      final activePattern = await _shiftStorageService.getActivePattern();
      if (activePattern == null) return false;
      
      final shiftType = activePattern.getShiftForDate(targetDate);
      return _isAlarmTypeMatchingShift(alarmType, shiftType);
    } catch (e) {
      print('AlarmConditionValidator: 날짜 검증 중 오류: $e');
      return false;
    }
  }
  
  /// 현재 활성 패턴에서 특정 알람 타입이 유효한 다음 날짜 찾기
  /// 
  /// [alarmType] 찾을 알람 타입
  /// [startDate] 검색 시작 날짜 (기본값: 오늘)
  /// [maxDaysAhead] 최대 검색 일수 (기본값: 30일)
  /// 
  /// Returns: 다음 유효한 날짜, 없으면 null
  Future<DateTime?> getNextValidDateForAlarmType(
    AlarmType alarmType, {
    DateTime? startDate,
    int maxDaysAhead = 30,
  }) async {
    if (alarmType == AlarmType.basic) return DateTime.now();
    
    final searchStart = startDate ?? DateTime.now();
    
    try {
      final activePattern = await _shiftStorageService.getActivePattern();
      if (activePattern == null) return null;
      
      for (int i = 0; i < maxDaysAhead; i++) {
        final checkDate = searchStart.add(Duration(days: i));
        final shiftType = activePattern.getShiftForDate(checkDate);
        
        if (_isAlarmTypeMatchingShift(alarmType, shiftType)) {
          return checkDate;
        }
      }
      
      return null;
    } catch (e) {
      print('AlarmConditionValidator: 다음 유효 날짜 검색 중 오류: $e');
      return null;
    }
  }
  
  /// 디버깅을 위한 상세 조건 검증 정보 반환
  /// 
  /// [alarm] 검증할 알람
  /// [triggerTime] 검증 시간 (기본값: 현재 시간)
  /// 
  /// Returns: 검증 결과와 상세 정보가 담긴 Map
  Future<Map<String, dynamic>> getDetailedValidationInfo(
    BasicAlarm alarm, {
    DateTime? triggerTime,
  }) async {
    final checkTime = triggerTime ?? DateTime.now();
    
    try {
      final activePattern = await _shiftStorageService.getActivePattern();
      final actualShiftType = activePattern?.getShiftForDate(checkTime);
      final isValid = await shouldAlarmTrigger(alarm, triggerTime: checkTime);
      
      return {
        'alarm_id': alarm.id,
        'alarm_type': alarm.type.displayName,
        'alarm_label': alarm.label,
        'check_time': checkTime.toIso8601String(),
        'active_pattern_name': activePattern?.name,
        'actual_shift_type': actualShiftType?.displayName,
        'is_valid': isValid,
        'validation_rule': _getValidationRuleDescription(alarm.type),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      return {
        'alarm_id': alarm.id,
        'error': e.toString(),
        'is_valid': false,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }
  
  /// 알람 타입별 검증 규칙 설명 반환
  String _getValidationRuleDescription(AlarmType alarmType) {
    switch (alarmType) {
      case AlarmType.day:
        return 'Day 알람은 Day Shift (주간 근무)에서만 트리거됩니다';
      case AlarmType.night:
        return 'Night 알람은 Night Shift (야간 근무)에서만 트리거됩니다';
      case AlarmType.off:
        return 'Off 알람은 Day Off (휴무)에서만 트리거됩니다';
      case AlarmType.basic:
        return 'Basic 알람은 모든 날짜에서 트리거됩니다';
    }
  }
}