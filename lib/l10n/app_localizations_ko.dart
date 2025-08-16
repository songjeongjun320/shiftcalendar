// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '교대 달력';

  @override
  String get welcomeTitle => '교대 달력에 오신 것을 환영합니다';

  @override
  String get welcomeDescription =>
      '고정된 요일이 아닌 근무 사이클에 따라 자동으로 알람을 예약하는 교대 패턴을 만들어보세요.';

  @override
  String get createPattern => '패턴 만들기';

  @override
  String get useSamplePattern => '샘플 패턴 사용';

  @override
  String get samplePatternDescription =>
      '직접 패턴을 만들거나 샘플 주-주-야-야-휴-휴 패턴을 사용하세요.';

  @override
  String get currentPattern => '현재 패턴';

  @override
  String get todayShift => '오늘의 근무';

  @override
  String get alarms => '알람';

  @override
  String get basicAlarms => '기본 알람';

  @override
  String get upcomingShifts => '다가오는 근무';

  @override
  String get actions => '작업';

  @override
  String get dayShift => '주간 근무';

  @override
  String get nightShift => '야간 근무';

  @override
  String get offShift => '휴무';

  @override
  String get day => '주간';

  @override
  String get night => '야간';

  @override
  String get off => '휴무';

  @override
  String get add => '추가';

  @override
  String get addAlarm => '알람 추가';

  @override
  String get edit => '편집';

  @override
  String get delete => '삭제';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get create => '만들기';

  @override
  String get newAlarm => '새 알람';

  @override
  String get editAlarm => '알람 편집';

  @override
  String get label => '라벨';

  @override
  String get time => '시간';

  @override
  String get repeat => '반복';

  @override
  String get alarmTone => '알람 소리';

  @override
  String get volume => '볼륨';

  @override
  String get active => '활성화';

  @override
  String get enableThisAlarm => '이 알람 활성화';

  @override
  String get once => '한 번';

  @override
  String get daily => '매일';

  @override
  String get weekdays => '평일';

  @override
  String get weekends => '주말';

  @override
  String get everyDay => '매일';

  @override
  String get monday => '월요일';

  @override
  String get tuesday => '화요일';

  @override
  String get wednesday => '수요일';

  @override
  String get thursday => '목요일';

  @override
  String get friday => '금요일';

  @override
  String get saturday => '토요일';

  @override
  String get sunday => '일요일';

  @override
  String get mon => '월';

  @override
  String get tue => '화';

  @override
  String get wed => '수';

  @override
  String get thu => '목';

  @override
  String get fri => '금';

  @override
  String get sat => '토';

  @override
  String get sun => '일';

  @override
  String get bell => '벨';

  @override
  String get chime => '차임';

  @override
  String get classic => '클래식';

  @override
  String get gentle => '부드러움';

  @override
  String get radar => '레이더';

  @override
  String get annoyingAlarm => '짜증나는 알람';

  @override
  String get cinematicEpicTrailer => '영화 예고편';

  @override
  String get emergencyAlarm => '비상 경보';

  @override
  String get firefighterAlarm => '소방관 알람';

  @override
  String get funnyAlarm => '재미있는 알람';

  @override
  String get gentleAcoustic => '부드러운 어쿠스틱';

  @override
  String get wakeupCall => '모닝콜';

  @override
  String get deleteAlarm => '알람 삭제';

  @override
  String get deleteAlarmConfirm => '정말로 삭제하시겠습니까';

  @override
  String get alarmDeleted => '알람이 삭제되었습니다';

  @override
  String get alarmTimeUpdated => '알람 시간이 다음으로 업데이트되었습니다';

  @override
  String get alarmSavedAndScheduled => '알람이 저장되고 예약되었습니다';

  @override
  String get alarmSavedInactive => '알람이 저장되었습니다 (비활성화)';

  @override
  String get clearAllData => '모든 데이터 지우기';

  @override
  String get noAlarmsConfigured => '구성된 알람이 없습니다';

  @override
  String get noBasicAlarmsConfigured => '구성된 기본 알람이 없습니다';

  @override
  String get patternCreationTitle => '교대 패턴 만들기';

  @override
  String get choosePresetPattern => '프리셋 패턴을 선택하세요:';

  @override
  String get createCustomPattern => '사용자 정의 패턴 만들기';

  @override
  String get customPattern => '사용자 정의 패턴';

  @override
  String get patternName => '패턴 이름';

  @override
  String get buildYourCycle => '사이클을 구성하세요:';

  @override
  String currentCycle(Object count) {
    return '현재 사이클 ($count일):';
  }

  @override
  String get clearAll => '모두 지우기';

  @override
  String get patternNameHint => '예: 나만의 패턴';

  @override
  String currentCycleDays(Object count) {
    return '현재 사이클 ($count일):';
  }

  @override
  String get createShiftPattern => '교대 패턴 만들기';

  @override
  String get selectAlarmTime => '알람 시간 선택';

  @override
  String get selectAlarmTone => '알람음 선택';

  @override
  String editAlarmTimeFor(Object title) {
    return '$title의 알람 시간을 선택하세요';
  }

  @override
  String get settings => '설정';

  @override
  String get language => '언어';

  @override
  String get selectLanguage => '언어 선택';

  @override
  String get close => '닫기';

  @override
  String get english => 'English';

  @override
  String get korean => '한국어';

  @override
  String get editAlarmTime => '알람 시간 편집';

  @override
  String get sound => '소리';

  @override
  String get vibration => '진동';

  @override
  String get snooze => '다시알림';

  @override
  String get alarmSettingsUpdated => '알람 설정이 업데이트되었습니다';

  @override
  String get patternStartDate => '패턴 시작일';

  @override
  String get selectStartDate => '시작일 선택';

  @override
  String get startDateHint => '이 패턴을 언제부터 시작할까요?';

  @override
  String get tomorrow => '내일';

  @override
  String get nextMonday => '다음 주 월요일';

  @override
  String get chooseDate => '날짜 선택';

  @override
  String get patternStartsOn => '패턴 시작일';
}
