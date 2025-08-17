import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'basic_alarm_service.dart';
import 'unified_alarm_service.dart';

/// 🚨 Emergency Cleanup Service
/// 기존 알람 시스템 완전 정리 및 새 사이클 시스템 적용
/// 
/// 사용 시나리오:
/// 1. 60개 중복 알람 문제 해결
/// 2. 기존 알람 시스템에서 새 시스템으로 마이그레이션
/// 3. 시스템 오류 발생 시 완전 초기화
class EmergencyCleanupService {
  final FlutterLocalNotificationsPlugin _notifications;
  late final BasicAlarmService _basicAlarmService;
  late final UnifiedAlarmService _unifiedService;

  EmergencyCleanupService(this._notifications) {
    _basicAlarmService = BasicAlarmService(_notifications);
    _unifiedService = UnifiedAlarmService(_notifications);
  }

  /// 🚨 완전 시스템 정리 실행
  Future<void> performEmergencyCleanup() async {
    print('🚨 === EMERGENCY CLEANUP STARTED ===');
    print('⚠️  This will remove ALL existing alarms and reset the system');
    
    try {
      // 1단계: 모든 알람 정리
      await _clearAllAlarms();
      
      // 2단계: 앱 데이터 정리
      await _clearAppData();
      
      // 3단계: 시스템 초기화
      await _initializeNewSystem();
      
      // 4단계: 상태 확인
      await _verifyCleanup();
      
      print('🎉 === EMERGENCY CLEANUP COMPLETED ===');
      print('✅ System is now clean and ready for the new cycle-based approach');
      
    } catch (e) {
      print('❌ Emergency cleanup failed: $e');
      rethrow;
    }
  }

  /// 1단계: 모든 알람 완전 정리
  Future<void> _clearAllAlarms() async {
    print('\n🗑️ STEP 1: Clearing all alarms...');
    
    // 1.1 기존 BasicAlarmService로 정리
    try {
      await _basicAlarmService.cancelAllBasicAlarms();
      print('   ✅ BasicAlarmService: All alarms cancelled');
    } catch (e) {
      print('   ⚠️ BasicAlarmService cleanup error: $e');
    }
    
    // 1.2 Flutter Local Notifications 완전 정리
    try {
      await _notifications.cancelAll();
      print('   ✅ Flutter Local Notifications: All notifications cancelled');
    } catch (e) {
      print('   ⚠️ Notification cleanup error: $e');
    }
    
    // 1.3 개별 알람 강제 삭제
    try {
      final pending = await _notifications.pendingNotificationRequests();
      print('   📊 Found ${pending.length} pending notifications');
      
      for (final notification in pending) {
        try {
          await _notifications.cancel(notification.id);
        } catch (e) {
          print('   ⚠️ Failed to cancel notification ${notification.id}: $e');
        }
      }
      
      print('   ✅ Individual notifications: All forced cancellation completed');
    } catch (e) {
      print('   ⚠️ Individual notification cleanup error: $e');
    }
  }

  /// 2단계: 앱 데이터 정리
  Future<void> _clearAppData() async {
    print('\n🧹 STEP 2: Clearing app data...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 2.1 알람 관련 키 찾기
      final allKeys = prefs.getKeys();
      final alarmKeys = allKeys.where((key) => 
        key.contains('alarm') || 
        key.contains('shift') || 
        key.contains('notification') ||
        key.contains('cycle') ||
        key.contains('basic_alarms') ||
        key.contains('shift_alarm') ||
        key.contains('pending')
      ).toList();
      
      print('   📋 Found ${alarmKeys.length} alarm-related data keys');
      
      // 2.2 알람 데이터 삭제
      for (final key in alarmKeys) {
        try {
          await prefs.remove(key);
          print('   🗑️ Removed: $key');
        } catch (e) {
          print('   ⚠️ Failed to remove $key: $e');
        }
      }
      
      // 2.3 사이클 매니저 데이터 초기화
      await prefs.setInt('shift_alarm_count', 0);
      await prefs.setInt('basic_alarm_count', 0);
      await prefs.remove('last_cycle_generated');
      
      print('   ✅ App data cleanup completed');
      
    } catch (e) {
      print('   ❌ App data cleanup error: $e');
    }
  }

  /// 3단계: 새 시스템 초기화
  Future<void> _initializeNewSystem() async {
    print('\n🚀 STEP 3: Initializing new system...');
    
    try {
      // 3.1 UnifiedAlarmService 초기화
      await _unifiedService.initialize();
      print('   ✅ UnifiedAlarmService initialized');
      
      // 3.2 BasicAlarmService 초기화
      await _basicAlarmService.initialize();
      print('   ✅ BasicAlarmService initialized');
      
      print('   🎉 New cycle-based system ready!');
      
    } catch (e) {
      print('   ❌ New system initialization error: $e');
    }
  }

  /// 4단계: 정리 상태 확인
  Future<void> _verifyCleanup() async {
    print('\n🔍 STEP 4: Verifying cleanup...');
    
    try {
      // 4.1 남은 알람 개수 확인
      final pending = await _notifications.pendingNotificationRequests();
      print('   📊 Remaining notifications: ${pending.length}');
      
      if (pending.isNotEmpty) {
        print('   ⚠️ WARNING: Some notifications still remain');
        for (final notification in pending.take(5)) {
          print('     - ID: ${notification.id}, Title: ${notification.title}');
        }
      } else {
        print('   ✅ All notifications successfully cleared');
      }
      
      // 4.2 시스템 상태 확인
      final systemStatus = await _unifiedService.getFullSystemStatus();
      print('   📈 System Status:');
      print('     - Initialized: ${systemStatus['initialized']}');
      print('     - Auto-Refill Active: ${systemStatus['autoRefillActive']}');
      print('     - System Health: ${systemStatus['systemHealth']}');
      
      // 4.3 앱 데이터 상태 확인
      final prefs = await SharedPreferences.getInstance();
      final shiftCount = prefs.getInt('shift_alarm_count') ?? -1;
      final basicCount = prefs.getInt('basic_alarm_count') ?? -1;
      
      print('   📊 Alarm Counts:');
      print('     - SHIFT alarms: $shiftCount');
      print('     - Basic alarms: $basicCount');
      
      if (shiftCount == 0 && basicCount == 0) {
        print('   ✅ Alarm counts successfully reset');
      } else {
        print('   ⚠️ WARNING: Alarm counts not properly reset');
      }
      
    } catch (e) {
      print('   ❌ Verification error: $e');
    }
  }

  /// 🛠️ 선택적 정리 옵션들

  /// SHIFT 알람만 정리
  Future<void> cleanupShiftAlarmsOnly() async {
    print('🔄 Cleaning up SHIFT alarms only...');
    
    try {
      final pending = await _notifications.pendingNotificationRequests();
      int shiftAlarmCount = 0;
      
      for (final notification in pending) {
        // SHIFT 알람 식별 (ID 패턴 기반)
        if (notification.payload?.contains('shift') == true ||
            notification.payload?.contains('Day Shift') == true ||
            notification.payload?.contains('Night Shift') == true ||
            notification.payload?.contains('Day Off') == true) {
          
          await _notifications.cancel(notification.id);
          shiftAlarmCount++;
        }
      }
      
      // SHIFT 카운트 리셋
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('shift_alarm_count', 0);
      
      print('✅ Cleaned up $shiftAlarmCount SHIFT alarms');
      
    } catch (e) {
      print('❌ SHIFT alarm cleanup error: $e');
    }
  }

  /// 중복 알람만 정리
  Future<void> cleanupDuplicatesOnly() async {
    print('🔍 Cleaning up duplicate alarms only...');
    
    try {
      final pending = await _notifications.pendingNotificationRequests();
      final alarmIdCounts = <String, List<int>>{};
      
      // 중복 찾기
      for (final notification in pending) {
        if (notification.payload != null) {
          try {
            // payload에서 alarmId 추출
            final payload = notification.payload!;
            if (payload.contains('alarmId')) {
              final match = RegExp(r'"alarmId":"([^"]+)"').firstMatch(payload);
              if (match != null) {
                final alarmId = match.group(1)!;
                alarmIdCounts[alarmId] = (alarmIdCounts[alarmId] ?? [])..add(notification.id);
              }
            }
          } catch (e) {
            // payload 파싱 실패 시 무시
          }
        }
      }
      
      // 중복 제거 (첫 번째만 남기고 나머지 삭제)
      int duplicatesRemoved = 0;
      for (final entry in alarmIdCounts.entries) {
        if (entry.value.length > 1) {
          // 첫 번째 제외하고 모두 삭제
          for (int i = 1; i < entry.value.length; i++) {
            await _notifications.cancel(entry.value[i]);
            duplicatesRemoved++;
          }
          print('   🗑️ Removed ${entry.value.length - 1} duplicates for alarm: ${entry.key}');
        }
      }
      
      print('✅ Removed $duplicatesRemoved duplicate notifications');
      
    } catch (e) {
      print('❌ Duplicate cleanup error: $e');
    }
  }

  /// 🧪 테스트용 기능들

  /// 현재 시스템 상태 진단
  Future<void> diagnoseCurrentState() async {
    print('\n🔍 === SYSTEM DIAGNOSIS ===');
    
    try {
      // 알람 개수 확인
      final pending = await _notifications.pendingNotificationRequests();
      print('📊 Total notifications: ${pending.length}');
      
      // 알람 타입별 분류
      final types = <String, int>{};
      final duplicates = <String, int>{};
      
      for (final notification in pending) {
        // 타입 분류
        if (notification.title?.contains('Day Shift') == true) {
          types['Day Shift'] = (types['Day Shift'] ?? 0) + 1;
        } else if (notification.title?.contains('Night Shift') == true) {
          types['Night Shift'] = (types['Night Shift'] ?? 0) + 1;
        } else if (notification.title?.contains('Day Off') == true) {
          types['Day Off'] = (types['Day Off'] ?? 0) + 1;
        } else if (notification.title?.contains('ALARM TRIGGER') == true) {
          types['Trigger'] = (types['Trigger'] ?? 0) + 1;
        } else {
          types['Other'] = (types['Other'] ?? 0) + 1;
        }
        
        // 중복 찾기
        if (notification.payload != null) {
          try {
            final match = RegExp(r'"alarmId":"([^"]+)"').firstMatch(notification.payload!);
            if (match != null) {
              final alarmId = match.group(1)!;
              duplicates[alarmId] = (duplicates[alarmId] ?? 0) + 1;
            }
          } catch (e) {
            // 무시
          }
        }
      }
      
      print('\n📋 Alarm Types:');
      types.forEach((type, count) {
        print('   $type: $count');
      });
      
      final duplicateCount = duplicates.values.where((count) => count > 1).length;
      print('\n🚨 Duplicates: $duplicateCount alarms have multiple notifications');
      
      // 앱 데이터 상태
      final prefs = await SharedPreferences.getInstance();
      final shiftCount = prefs.getInt('shift_alarm_count') ?? -1;
      final basicCount = prefs.getInt('basic_alarm_count') ?? -1;
      
      print('\n💾 App Data:');
      print('   SHIFT count: $shiftCount');
      print('   Basic count: $basicCount');
      
      print('\n💡 Recommendation:');
      if (pending.length > 20) {
        print('   🚨 Too many alarms detected - consider full cleanup');
      } else if (duplicateCount > 0) {
        print('   🔧 Duplicates detected - consider duplicate cleanup');
      } else {
        print('   ✅ System looks healthy');
      }
      
    } catch (e) {
      print('❌ Diagnosis error: $e');
    }
  }
}

/// 🚨 빠른 사용 함수들
Future<void> performEmergencySystemCleanup(FlutterLocalNotificationsPlugin notifications) async {
  final cleanup = EmergencyCleanupService(notifications);
  await cleanup.performEmergencyCleanup();
}

Future<void> cleanupDuplicateAlarmsOnly(FlutterLocalNotificationsPlugin notifications) async {
  final cleanup = EmergencyCleanupService(notifications);
  await cleanup.cleanupDuplicatesOnly();
}

Future<void> diagnoseAlarmSystem(FlutterLocalNotificationsPlugin notifications) async {
  final cleanup = EmergencyCleanupService(notifications);
  await cleanup.diagnoseCurrentState();
}