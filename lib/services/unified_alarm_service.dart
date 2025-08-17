import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
import '../models/basic_alarm.dart';
import 'basic_alarm_service.dart';
import 'cycle_alarm_manager.dart';
import 'auto_refill_service.dart';

/// 🎯 Unified Alarm Service
/// 통합 알람 서비스 - SHIFT 알람과 기본 알람의 독립적 관리
/// 
/// 핵심 원칙:
/// 1. SHIFT 알람 ≠ 기본 알람 (완전 분리)
/// 2. 각각 독립적인 카운트 관리
/// 3. 각각 독립적인 생명주기
/// 4. 통합된 인터페이스 제공
class UnifiedAlarmService {
  final FlutterLocalNotificationsPlugin _notifications;
  
  // 🔧 서비스 인스턴스들
  late final BasicAlarmService _basicAlarmService;
  late final CycleAlarmManager _cycleManager;
  late final AutoRefillService _autoRefillService;
  
  // 📊 분리된 상태 관리
  bool _isInitialized = false;
  bool _autoRefillActive = false;

  UnifiedAlarmService(this._notifications) {
    _initializeServices();
  }

  /// 🚀 서비스 초기화
  void _initializeServices() {
    print('🚀 UNIFIED SERVICE: Initializing all alarm services...');
    
    // 기본 알람 서비스 초기화
    _basicAlarmService = BasicAlarmService(_notifications);
    
    // 사이클 매니저 초기화 (기본 알람 서비스 기반)
    _cycleManager = _basicAlarmService.cycleManager;
    
    // 자동 리필 서비스 초기화
    _autoRefillService = AutoRefillService(_basicAlarmService);
    
    
    // 🔗 자동 리필 콜백 연결
    _cycleManager.setAutoRefillCallback(() async {
      await _autoRefillService.performRefillCheck();
    });
    
    print('✅ UNIFIED SERVICE: All services initialized');
  }

  /// 🎯 전체 시스템 초기화
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ UNIFIED SERVICE: Already initialized');
      return;
    }
    
    print('🎯 UNIFIED SERVICE: Starting full initialization...');
    
    try {
      // BasicAlarmService 초기화
      await _basicAlarmService.initialize();
      print('   ✅ BasicAlarmService initialized');
      
      // 자동 리필 서비스 시작
      await _autoRefillService.startAutoRefill();
      _autoRefillActive = true;
      print('   ✅ AutoRefillService started');
      
      _isInitialized = true;
      print('🎉 UNIFIED SERVICE: Full initialization completed');
      
      // 초기 상태 출력
      await debugFullSystemStatus();
      
    } catch (e) {
      print('❌ UNIFIED SERVICE: Initialization failed: $e');
      rethrow;
    }
  }

  // ===========================================
  // 🔄 SHIFT 알람 관리 (사이클 기반)
  // ===========================================

  /// SHIFT 알람 생성 (새로운 사이클 기반 방식)
  Future<List<BasicAlarm>> createShiftAlarmCycle(
    ShiftAlarm shiftAlarm, 
    ShiftPattern pattern,
  ) async {
    print('🔄 UNIFIED: Creating SHIFT alarm cycle...');
    
    // 활성 상태 저장 (자동 리필용)
    await _saveActiveShiftData([shiftAlarm], [pattern]);
    
    // 사이클 생성
    final result = await _cycleManager.generateShiftAlarmCycle(shiftAlarm, pattern);
    
    print('✅ UNIFIED: SHIFT cycle created with ${result.length} alarms');
    return result;
  }

  /// SHIFT 알람 여러 개 생성
  Future<void> createMultipleShiftAlarmCycles(
    List<ShiftAlarm> shiftAlarms, 
    List<ShiftPattern> patterns,
  ) async {
    print('🔄 UNIFIED: Creating multiple SHIFT alarm cycles...');
    print('   ShiftAlarms: ${shiftAlarms.length}');
    print('   Patterns: ${patterns.length}');
    
    // 활성 상태 저장 (자동 리필용)
    await _saveActiveShiftData(shiftAlarms, patterns);
    
    int totalCreated = 0;
    
    for (final shiftAlarm in shiftAlarms.where((a) => a.isActive)) {
      final pattern = patterns.where((p) => p.id == shiftAlarm.patternId).firstOrNull;
      
      if (pattern != null && pattern.isActive) {
        final result = await _cycleManager.generateShiftAlarmCycle(shiftAlarm, pattern);
        totalCreated += result.length;
        print('   ✅ ${shiftAlarm.title}: ${result.length} alarms');
      } else {
        print('   ⚠️ ${shiftAlarm.title}: Pattern not found or inactive');
      }
    }
    
    print('🎉 UNIFIED: Total SHIFT alarms created: $totalCreated');
  }

  /// SHIFT 알람 개수 조회
  Future<int> getShiftAlarmCount() async {
    return await _cycleManager.getShiftAlarmCount();
  }

  /// SHIFT 알람 상태 조회
  Future<Map<String, dynamic>> getShiftAlarmStatus() async {
    return await _cycleManager.getSystemStatus();
  }

  // ===========================================
  // ⚡ 기본 알람 관리 (독립적)
  // ===========================================

  /// 기본 알람 생성
  Future<void> createBasicAlarm(BasicAlarm alarm) async {
    print('⚡ UNIFIED: Creating basic alarm: ${alarm.label}');
    
    await _basicAlarmService.scheduleBasicAlarm(alarm);
    
    // 기본 알람 카운트 증가 (SHIFT와 독립적)
    final currentCount = await _cycleManager.getBasicAlarmCount();
    await _cycleManager.updateBasicAlarmCount(currentCount + 1);
    
    print('✅ UNIFIED: Basic alarm created. Count: ${currentCount + 1}');
  }

  /// 기본 알람 개수 조회
  Future<int> getBasicAlarmCount() async {
    return await _cycleManager.getBasicAlarmCount();
  }

  /// 기본 알람 목록 조회
  Future<List<BasicAlarm>> getAllBasicAlarms() async {
    return await _basicAlarmService.getAllBasicAlarms();
  }

  /// 기본 알람 취소
  Future<void> cancelBasicAlarm(String alarmId) async {
    print('🗑️ UNIFIED: Canceling basic alarm: $alarmId');
    
    await _basicAlarmService.cancelBasicAlarm(alarmId);
    
    // 기본 알람 카운트 감소 (SHIFT와 독립적)
    final currentCount = await _cycleManager.getBasicAlarmCount();
    if (currentCount > 0) {
      await _cycleManager.updateBasicAlarmCount(currentCount - 1);
    }
    
    print('✅ UNIFIED: Basic alarm canceled. Count: ${currentCount - 1}');
  }

  // ===========================================
  // 🛠️ 공통 관리 기능
  // ===========================================

  /// 모든 알람 취소 (SHIFT + 기본)
  Future<void> cancelAllAlarms() async {
    print('🗑️ UNIFIED: Canceling ALL alarms...');
    
    await _basicAlarmService.cancelAllBasicAlarms();
    await _cycleManager.resetAllCycles();
    
    print('✅ UNIFIED: All alarms canceled');
  }

  /// 자동 리필 수동 트리거
  Future<void> triggerManualRefill() async {
    print('🔧 UNIFIED: Triggering manual refill...');
    await _autoRefillService.manualRefillTrigger();
  }

  /// 전체 시스템 상태 조회
  Future<Map<String, dynamic>> getFullSystemStatus() async {
    final shiftStatus = await getShiftAlarmStatus();
    final autoRefillStatus = await _autoRefillService.getServiceStatus();
    final pendingCount = await _basicAlarmService.getPendingBasicAlarmsCount();
    
    return {
      'initialized': _isInitialized,
      'autoRefillActive': _autoRefillActive,
      'shiftAlarms': shiftStatus,
      'autoRefill': autoRefillStatus,
      'totalPendingNotifications': pendingCount,
      'systemHealth': _calculateSystemHealth(shiftStatus, autoRefillStatus),
    };
  }

  /// 시스템 건강 상태 계산
  String _calculateSystemHealth(Map<String, dynamic> shiftStatus, Map<String, dynamic> autoRefillStatus) {
    final shiftCount = shiftStatus['shiftAlarmCount'] as int;
    final autoRefillEnabled = autoRefillStatus['autoRefillEnabled'] as bool;
    
    if (shiftCount > 2 && autoRefillEnabled) {
      return 'excellent';
    } else if (shiftCount > 0 && autoRefillEnabled) {
      return 'good';
    } else if (shiftCount > 0) {
      return 'warning';
    } else {
      return 'critical';
    }
  }

  // ===========================================
  // 📋 활성 데이터 관리 (자동 리필용)
  // ===========================================

  /// 활성 SHIFT 데이터 저장
  Future<void> _saveActiveShiftData(List<ShiftAlarm> alarms, List<ShiftPattern> patterns) async {
    final activeAlarms = alarms.where((a) => a.isActive).toList();
    final activePatterns = patterns.where((p) => p.isActive).toList();
    
    await _autoRefillService.saveActiveShiftAlarms(activeAlarms);
    await _autoRefillService.saveActiveShiftPatterns(activePatterns);
    
    print('📋 UNIFIED: Saved ${activeAlarms.length} active ShiftAlarms, ${activePatterns.length} active patterns');
  }

  // ===========================================
  // 🔍 디버그 및 정리
  // ===========================================

  /// 전체 시스템 상태 디버그 출력
  Future<void> debugFullSystemStatus() async {
    print('\n=== UNIFIED ALARM SERVICE STATUS ===');
    
    final fullStatus = await getFullSystemStatus();
    
    print('System Initialized: ${fullStatus['initialized']}');
    print('Auto-Refill Active: ${fullStatus['autoRefillActive']}');
    print('System Health: ${fullStatus['systemHealth']}');
    print('Total Pending Notifications: ${fullStatus['totalPendingNotifications']}');
    
    print('\n--- SHIFT ALARMS ---');
    final shiftStatus = fullStatus['shiftAlarms'] as Map<String, dynamic>;
    print('Count: ${shiftStatus['shiftAlarmCount']}');
    print('Health: ${shiftStatus['systemHealth']}');
    print('Needs Refill: ${shiftStatus['needsRefill']}');
    
    print('\n--- BASIC ALARMS ---');
    print('Count: ${shiftStatus['basicAlarmCount']}');
    
    print('\n--- AUTO-REFILL ---');
    final autoRefillStatus = fullStatus['autoRefill'] as Map<String, dynamic>;
    print('Enabled: ${autoRefillStatus['autoRefillEnabled']}');
    print('Monitoring: ${autoRefillStatus['monitoringActive']}');
    print('Active ShiftAlarms: ${autoRefillStatus['activeShiftAlarms']}');
    print('Active Patterns: ${autoRefillStatus['activePatterns']}');
    
    print('===================================\n');
  }

  /// 서비스 정리
  Future<void> dispose() async {
    print('🧹 UNIFIED: Disposing all services...');
    
    await _autoRefillService.dispose();
    _autoRefillActive = false;
    _isInitialized = false;
    
    print('✅ UNIFIED: All services disposed');
  }
}