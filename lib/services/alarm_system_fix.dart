import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'emergency_cleanup_service.dart';
import 'unified_alarm_service.dart';

/// 🎯 Alarm System Fix - 원클릭 해결사
/// 현재 알람 문제를 한 번에 해결하는 서비스
/// 
/// 사용법:
/// ```dart
/// await AlarmSystemFix.fixCurrentProblems(notifications);
/// ```
class AlarmSystemFix {
  
  /// 🚨 현재 알람 문제 완전 해결
  /// 60개 중복 알람 → 정상 사이클 시스템으로 변환
  static Future<void> fixCurrentProblems(FlutterLocalNotificationsPlugin notifications) async {
    print('🎯 === ALARM SYSTEM FIX STARTED ===');
    print('Target: Fix 60 duplicate alarms → Clean cycle system');
    
    final cleanup = EmergencyCleanupService(notifications);
    final unified = UnifiedAlarmService(notifications);
    
    try {
      // 1단계: 현재 상태 진단
      print('\n🔍 STEP 1: Diagnosing current problems...');
      await cleanup.diagnoseCurrentState();
      
      // 2단계: 중복 알람 정리
      print('\n🗑️ STEP 2: Cleaning up duplicates...');
      await cleanup.cleanupDuplicatesOnly();
      
      // 3단계: 남은 문제 정리
      print('\n🧹 STEP 3: Final cleanup...');
      await cleanup.performEmergencyCleanup();
      
      // 4단계: 새 시스템 적용
      print('\n🚀 STEP 4: Applying new cycle system...');
      await unified.initialize();
      
      // 5단계: 검증
      print('\n✅ STEP 5: Verifying fix...');
      await _verifyFix(notifications, unified);
      
      print('\n🎉 === ALARM SYSTEM FIX COMPLETED ===');
      print('✅ System is now using efficient cycle-based approach');
      print('📊 Expected alarm count: 6-12 (instead of 60+)');
      
    } catch (e) {
      print('\n❌ === FIX FAILED ===');
      print('Error: $e');
      print('💡 Try manual cleanup or restart app');
      rethrow;
    }
  }
  
  /// 🔧 빠른 중복 제거만
  static Future<void> quickDuplicateFix(FlutterLocalNotificationsPlugin notifications) async {
    print('🔧 Quick duplicate fix...');
    
    final cleanup = EmergencyCleanupService(notifications);
    
    try {
      await cleanup.cleanupDuplicatesOnly();
      
      final pending = await notifications.pendingNotificationRequests();
      print('✅ Quick fix completed. Remaining alarms: ${pending.length}');
      
    } catch (e) {
      print('❌ Quick fix failed: $e');
    }
  }
  
  /// 📊 시스템 상태 체크
  static Future<AlarmSystemStatus> checkSystemStatus(FlutterLocalNotificationsPlugin notifications) async {
    try {
      final pending = await notifications.pendingNotificationRequests();
      
      // 중복 검사
      final alarmIds = <String>[];
      final duplicates = <String>[];
      
      for (final notification in pending) {
        if (notification.payload != null) {
          final match = RegExp(r'"alarmId":"([^"]+)"').firstMatch(notification.payload!);
          if (match != null) {
            final alarmId = match.group(1)!;
            if (alarmIds.contains(alarmId)) {
              if (!duplicates.contains(alarmId)) {
                duplicates.add(alarmId);
              }
            } else {
              alarmIds.add(alarmId);
            }
          }
        }
      }
      
      // 상태 분석
      final status = AlarmSystemStatus(
        totalAlarms: pending.length,
        uniqueAlarms: alarmIds.length,
        duplicateAlarms: duplicates.length,
        systemHealth: _calculateHealth(pending.length, duplicates.length),
        needsCleanup: pending.length > 20 || duplicates.isNotEmpty,
        recommendedAction: _getRecommendedAction(pending.length, duplicates.length),
      );
      
      return status;
      
    } catch (e) {
      return AlarmSystemStatus(
        totalAlarms: -1,
        uniqueAlarms: -1,
        duplicateAlarms: -1,
        systemHealth: SystemHealth.error,
        needsCleanup: true,
        recommendedAction: 'Emergency cleanup required due to error: $e',
      );
    }
  }
  
  /// 검증 함수
  static Future<void> _verifyFix(FlutterLocalNotificationsPlugin notifications, UnifiedAlarmService unified) async {
    final pending = await notifications.pendingNotificationRequests();
    final systemStatus = await unified.getFullSystemStatus();
    
    print('📊 Fix Results:');
    print('   Total notifications: ${pending.length}');
    print('   System health: ${systemStatus['systemHealth']}');
    print('   Auto-refill active: ${systemStatus['autoRefillActive']}');
    
    if (pending.length <= 12) {
      print('✅ SUCCESS: Alarm count is now reasonable (${pending.length} ≤ 12)');
    } else {
      print('⚠️ WARNING: Still too many alarms (${pending.length} > 12)');
    }
  }
  
  /// 건강 상태 계산
  static SystemHealth _calculateHealth(int totalAlarms, int duplicates) {
    if (totalAlarms <= 12 && duplicates == 0) {
      return SystemHealth.excellent;
    } else if (totalAlarms <= 20 && duplicates <= 5) {
      return SystemHealth.good;
    } else if (totalAlarms <= 40) {
      return SystemHealth.warning;
    } else {
      return SystemHealth.critical;
    }
  }
  
  /// 권장 액션 결정
  static String _getRecommendedAction(int totalAlarms, int duplicates) {
    if (totalAlarms <= 12 && duplicates == 0) {
      return 'System is healthy - no action needed';
    } else if (duplicates > 0 && totalAlarms <= 40) {
      return 'Run quick duplicate fix';
    } else {
      return 'Run full system cleanup';
    }
  }
}

/// 📊 시스템 상태 정보
class AlarmSystemStatus {
  final int totalAlarms;
  final int uniqueAlarms;
  final int duplicateAlarms;
  final SystemHealth systemHealth;
  final bool needsCleanup;
  final String recommendedAction;
  
  AlarmSystemStatus({
    required this.totalAlarms,
    required this.uniqueAlarms,
    required this.duplicateAlarms,
    required this.systemHealth,
    required this.needsCleanup,
    required this.recommendedAction,
  });
  
  @override
  String toString() {
    return '''
📊 Alarm System Status:
   Total Alarms: $totalAlarms
   Unique Alarms: $uniqueAlarms
   Duplicates: $duplicateAlarms
   Health: ${systemHealth.name}
   Needs Cleanup: $needsCleanup
   Recommended: $recommendedAction
''';
  }
}

/// 시스템 건강 상태
enum SystemHealth {
  excellent,
  good, 
  warning,
  critical,
  error,
}

extension SystemHealthExtension on SystemHealth {
  String get name {
    switch (this) {
      case SystemHealth.excellent:
        return 'Excellent ✅';
      case SystemHealth.good:
        return 'Good 🟢';
      case SystemHealth.warning:
        return 'Warning ⚠️';
      case SystemHealth.critical:
        return 'Critical 🚨';
      case SystemHealth.error:
        return 'Error ❌';
    }
  }
}