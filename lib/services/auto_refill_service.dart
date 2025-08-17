import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
import 'basic_alarm_service.dart';

/// 🔄 Auto-Refill Service
/// 자동 리필 서비스 - 알람 개수 모니터링 및 자동 사이클 생성
/// 
/// 핵심 기능:
/// 1. 백그라운드에서 알람 개수 모니터링
/// 2. 임계값 이하로 떨어지면 자동 리필
/// 3. SHIFT 알람과 기본 알람 독립적 관리
/// 4. 활성 ShiftAlarm들을 자동으로 다음 사이클 생성
class AutoRefillService {
  final BasicAlarmService _basicAlarmService;
  
  // 주기적 체크를 위한 타이머
  Timer? _monitoringTimer;
  
  // 설정 키
  static const String _autoRefillEnabledKey = 'auto_refill_enabled';
  static const String _activeShiftAlarmsKey = 'active_shift_alarms';
  static const String _activeShiftPatternsKey = 'active_shift_patterns';
  
  // 모니터링 설정
  static const Duration MONITORING_INTERVAL = Duration(minutes: 30); // 30분마다 체크
  static const int REFILL_THRESHOLD = 2; // 2개 이하면 리필
  
  AutoRefillService(this._basicAlarmService);

  /// 🚀 자동 리필 서비스 시작
  Future<void> startAutoRefill() async {
    print('🚀 AUTO-REFILL: Starting service...');
    
    // 자동 리필 활성화 상태 저장
    await setAutoRefillEnabled(true);
    
    // 초기 체크 수행
    await performRefillCheck();
    
    // 주기적 모니터링 타이머 시작
    _monitoringTimer = Timer.periodic(MONITORING_INTERVAL, (timer) async {
      await performRefillCheck();
    });
    
    print('✅ AUTO-REFILL: Service started with ${MONITORING_INTERVAL.inMinutes}min intervals');
  }

  /// 🛑 자동 리필 서비스 중지
  Future<void> stopAutoRefill() async {
    print('🛑 AUTO-REFILL: Stopping service...');
    
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    await setAutoRefillEnabled(false);
    
    print('✅ AUTO-REFILL: Service stopped');
  }

  /// 🔍 리필 체크 수행
  Future<void> performRefillCheck() async {
    if (!await isAutoRefillEnabled()) {
      print('⏸️ AUTO-REFILL: Service disabled, skipping check');
      return;
    }
    
    print('🔍 AUTO-REFILL: Performing check...');
    
    try {
      // SHIFT 알람 개수 체크
      final shiftCount = await _basicAlarmService.cycleManager.getShiftAlarmCount();
      final basicCount = await _basicAlarmService.cycleManager.getBasicAlarmCount();
      
      print('   Current counts - SHIFT: $shiftCount, Basic: $basicCount');
      
      // SHIFT 알람 리필 체크
      if (shiftCount <= REFILL_THRESHOLD) {
        print('🚨 AUTO-REFILL: SHIFT alarms below threshold ($REFILL_THRESHOLD)');
        await refillShiftAlarms();
      } else {
        print('✅ AUTO-REFILL: SHIFT alarms sufficient ($shiftCount)');
      }
      
      // 기본 알람은 수동 관리 (필요시 확장 가능)
      if (basicCount <= REFILL_THRESHOLD) {
        print('💡 AUTO-REFILL: Basic alarms low ($basicCount) - manual refill recommended');
      }
      
    } catch (e) {
      print('❌ AUTO-REFILL: Error during check: $e');
    }
  }

  /// 🔄 SHIFT 알람 자동 리필
  Future<void> refillShiftAlarms() async {
    print('🔄 AUTO-REFILL: Starting SHIFT alarm refill...');
    
    try {
      // 활성 ShiftAlarm들 가져오기
      final activeShiftAlarms = await getActiveShiftAlarms();
      final activePatterns = await getActiveShiftPatterns();
      
      if (activeShiftAlarms.isEmpty) {
        print('⚠️ AUTO-REFILL: No active ShiftAlarms found');
        return;
      }
      
      if (activePatterns.isEmpty) {
        print('⚠️ AUTO-REFILL: No active ShiftPatterns found');
        return;
      }
      
      print('   Found ${activeShiftAlarms.length} active ShiftAlarms');
      print('   Found ${activePatterns.length} active ShiftPatterns');
      
      int totalGenerated = 0;
      
      // 각 활성 ShiftAlarm에 대해 다음 사이클 생성
      for (final shiftAlarm in activeShiftAlarms) {
        // 해당 ShiftAlarm의 패턴 찾기
        final pattern = activePatterns.where((p) => p.id == shiftAlarm.patternId).firstOrNull;
        
        if (pattern == null) {
          print('   ⚠️ Pattern not found for ShiftAlarm: ${shiftAlarm.title}');
          continue;
        }
        
        print('   🔄 Generating cycle for: ${shiftAlarm.title}');
        
        // 다음 사이클 생성
        final generatedAlarms = await _basicAlarmService.cycleManager.generateShiftAlarmCycle(shiftAlarm, pattern);
        totalGenerated += generatedAlarms.length;
        
        print('     ✅ Generated ${generatedAlarms.length} alarms');
      }
      
      print('🎉 AUTO-REFILL: Completed! Generated $totalGenerated total alarms');
      
      // 리필 완료 후 상태 확인
      await _basicAlarmService.cycleManager.debugCycleStatus();
      
    } catch (e) {
      print('❌ AUTO-REFILL: Error during SHIFT alarm refill: $e');
    }
  }

  /// 📋 활성 ShiftAlarm들 관리
  Future<void> saveActiveShiftAlarms(List<ShiftAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = alarms.map((alarm) => alarm.toMap()).toList();
    await prefs.setString(_activeShiftAlarmsKey, jsonEncode(alarmsJson));
    print('📋 AUTO-REFILL: Saved ${alarms.length} active ShiftAlarms');
  }

  Future<List<ShiftAlarm>> getActiveShiftAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString(_activeShiftAlarmsKey);
    
    if (alarmsJson == null) return [];
    
    try {
      final alarmsList = jsonDecode(alarmsJson) as List;
      return alarmsList
          .map((json) => ShiftAlarm.fromMap(json as Map<String, dynamic>))
          .where((alarm) => alarm.isActive) // 활성 알람만 필터링
          .toList();
    } catch (e) {
      print('❌ AUTO-REFILL: Error parsing active ShiftAlarms: $e');
      return [];
    }
  }

  /// 📋 활성 ShiftPattern들 관리
  Future<void> saveActiveShiftPatterns(List<ShiftPattern> patterns) async {
    final prefs = await SharedPreferences.getInstance();
    final patternsJson = patterns.map((pattern) => pattern.toMap()).toList();
    await prefs.setString(_activeShiftPatternsKey, jsonEncode(patternsJson));
    print('📋 AUTO-REFILL: Saved ${patterns.length} active ShiftPatterns');
  }

  Future<List<ShiftPattern>> getActiveShiftPatterns() async {
    final prefs = await SharedPreferences.getInstance();
    final patternsJson = prefs.getString(_activeShiftPatternsKey);
    
    if (patternsJson == null) return [];
    
    try {
      final patternsList = jsonDecode(patternsJson) as List;
      return patternsList
          .map((json) => ShiftPattern.fromMap(json as Map<String, dynamic>))
          .where((pattern) => pattern.isActive) // 활성 패턴만 필터링
          .toList();
    } catch (e) {
      print('❌ AUTO-REFILL: Error parsing active ShiftPatterns: $e');
      return [];
    }
  }

  /// ⚙️ 자동 리필 설정 관리
  Future<void> setAutoRefillEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoRefillEnabledKey, enabled);
    print('⚙️ AUTO-REFILL: Setting enabled = $enabled');
  }

  Future<bool> isAutoRefillEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoRefillEnabledKey) ?? false;
  }

  /// 🔧 수동 리필 트리거 (테스트용)
  Future<void> manualRefillTrigger() async {
    print('🔧 AUTO-REFILL: Manual refill triggered');
    await performRefillCheck();
  }

  /// 📊 자동 리필 서비스 상태
  Future<Map<String, dynamic>> getServiceStatus() async {
    final isEnabled = await isAutoRefillEnabled();
    final isRunning = _monitoringTimer?.isActive ?? false;
    final activeShiftAlarms = await getActiveShiftAlarms();
    final activePatterns = await getActiveShiftPatterns();
    final cycleStatus = await _basicAlarmService.cycleManager.getSystemStatus();
    
    return {
      'autoRefillEnabled': isEnabled,
      'monitoringActive': isRunning,
      'monitoringInterval': MONITORING_INTERVAL.inMinutes,
      'refillThreshold': REFILL_THRESHOLD,
      'activeShiftAlarms': activeShiftAlarms.length,
      'activePatterns': activePatterns.length,
      'cycleStatus': cycleStatus,
      'nextCheckIn': isRunning 
          ? '${MONITORING_INTERVAL.inMinutes} minutes' 
          : 'Monitoring stopped',
    };
  }

  /// 🔍 디버그 정보
  Future<void> debugServiceStatus() async {
    final status = await getServiceStatus();
    
    print('=== AUTO-REFILL SERVICE DEBUG ===');
    print('Service Enabled: ${status['autoRefillEnabled']}');
    print('Monitoring Active: ${status['monitoringActive']}');
    print('Check Interval: ${status['monitoringInterval']} minutes');
    print('Refill Threshold: ${status['refillThreshold']} alarms');
    print('Active ShiftAlarms: ${status['activeShiftAlarms']}');
    print('Active Patterns: ${status['activePatterns']}');
    print('Next Check: ${status['nextCheckIn']}');
    print('Cycle Status: ${status['cycleStatus']}');
    print('===============================');
  }

  /// 🧹 서비스 정리 (앱 종료 시 호출)
  Future<void> dispose() async {
    print('🧹 AUTO-REFILL: Disposing service...');
    await stopAutoRefill();
    print('✅ AUTO-REFILL: Service disposed');
  }
}