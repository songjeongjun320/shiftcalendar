import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Calendar'**
  String get appTitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Shift Calendar'**
  String get welcomeTitle;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Create shift patterns that automatically schedule alarms based on your work cycle, not fixed weekdays.'**
  String get welcomeDescription;

  /// No description provided for @createPattern.
  ///
  /// In en, this message translates to:
  /// **'Create Pattern'**
  String get createPattern;

  /// No description provided for @useSamplePattern.
  ///
  /// In en, this message translates to:
  /// **'Use Sample Pattern'**
  String get useSamplePattern;

  /// No description provided for @samplePatternDescription.
  ///
  /// In en, this message translates to:
  /// **'Pattern: Day-Day-Night-Night-Off-Off'**
  String get samplePatternDescription;

  /// No description provided for @currentPattern.
  ///
  /// In en, this message translates to:
  /// **'Current Pattern'**
  String get currentPattern;

  /// No description provided for @todayShift.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Shift'**
  String get todayShift;

  /// No description provided for @alarms.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get alarms;

  /// No description provided for @basicAlarms.
  ///
  /// In en, this message translates to:
  /// **'Basic Alarms'**
  String get basicAlarms;

  /// No description provided for @upcomingShifts.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Shifts'**
  String get upcomingShifts;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @dayShift.
  ///
  /// In en, this message translates to:
  /// **'Day Shift'**
  String get dayShift;

  /// No description provided for @nightShift.
  ///
  /// In en, this message translates to:
  /// **'Night Shift'**
  String get nightShift;

  /// No description provided for @offShift.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get offShift;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @night.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get night;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAlarm.
  ///
  /// In en, this message translates to:
  /// **'Add Alarm'**
  String get addAlarm;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @newAlarm.
  ///
  /// In en, this message translates to:
  /// **'New Alarm'**
  String get newAlarm;

  /// No description provided for @editAlarm.
  ///
  /// In en, this message translates to:
  /// **'Edit Alarm'**
  String get editAlarm;

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @alarmTone.
  ///
  /// In en, this message translates to:
  /// **'Alarm tone'**
  String get alarmTone;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @enableThisAlarm.
  ///
  /// In en, this message translates to:
  /// **'Enable this alarm'**
  String get enableThisAlarm;

  /// No description provided for @once.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get once;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get weekdays;

  /// No description provided for @weekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get weekends;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @bell.
  ///
  /// In en, this message translates to:
  /// **'Bell'**
  String get bell;

  /// No description provided for @chime.
  ///
  /// In en, this message translates to:
  /// **'Chime'**
  String get chime;

  /// No description provided for @classic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get classic;

  /// No description provided for @gentle.
  ///
  /// In en, this message translates to:
  /// **'Gentle'**
  String get gentle;

  /// No description provided for @radar.
  ///
  /// In en, this message translates to:
  /// **'Radar'**
  String get radar;

  /// No description provided for @annoyingAlarm.
  ///
  /// In en, this message translates to:
  /// **'Annoying Alarm'**
  String get annoyingAlarm;

  /// No description provided for @cinematicEpicTrailer.
  ///
  /// In en, this message translates to:
  /// **'Cinematic Epic Trailer'**
  String get cinematicEpicTrailer;

  /// No description provided for @emergencyAlarm.
  ///
  /// In en, this message translates to:
  /// **'Emergency Alarm'**
  String get emergencyAlarm;

  /// No description provided for @firefighterAlarm.
  ///
  /// In en, this message translates to:
  /// **'Firefighter Alarm'**
  String get firefighterAlarm;

  /// No description provided for @funnyAlarm.
  ///
  /// In en, this message translates to:
  /// **'Funny Alarm'**
  String get funnyAlarm;

  /// No description provided for @gentleAcoustic.
  ///
  /// In en, this message translates to:
  /// **'Gentle Acoustic'**
  String get gentleAcoustic;

  /// No description provided for @wakeupCall.
  ///
  /// In en, this message translates to:
  /// **'Wake Up Call'**
  String get wakeupCall;

  /// No description provided for @deleteAlarm.
  ///
  /// In en, this message translates to:
  /// **'Delete Alarm'**
  String get deleteAlarm;

  /// No description provided for @deleteAlarmConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get deleteAlarmConfirm;

  /// No description provided for @alarmDeleted.
  ///
  /// In en, this message translates to:
  /// **'Alarm deleted'**
  String get alarmDeleted;

  /// No description provided for @alarmTimeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Alarm time updated to'**
  String get alarmTimeUpdated;

  /// No description provided for @alarmSavedAndScheduled.
  ///
  /// In en, this message translates to:
  /// **'Alarm saved and scheduled'**
  String get alarmSavedAndScheduled;

  /// No description provided for @alarmSavedInactive.
  ///
  /// In en, this message translates to:
  /// **'Alarm saved (inactive)'**
  String get alarmSavedInactive;

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data'**
  String get clearAllData;

  /// No description provided for @noAlarmsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No alarms configured'**
  String get noAlarmsConfigured;

  /// No description provided for @noBasicAlarmsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No basic alarms configured'**
  String get noBasicAlarmsConfigured;

  /// No description provided for @patternCreationTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Shift Pattern'**
  String get patternCreationTitle;

  /// No description provided for @choosePresetPattern.
  ///
  /// In en, this message translates to:
  /// **'Choose a preset pattern:'**
  String get choosePresetPattern;

  /// No description provided for @createCustomPattern.
  ///
  /// In en, this message translates to:
  /// **'Create Custom Pattern'**
  String get createCustomPattern;

  /// No description provided for @customPattern.
  ///
  /// In en, this message translates to:
  /// **'Custom Pattern'**
  String get customPattern;

  /// No description provided for @patternName.
  ///
  /// In en, this message translates to:
  /// **'Pattern Name'**
  String get patternName;

  /// No description provided for @buildYourCycle.
  ///
  /// In en, this message translates to:
  /// **'Build your cycle:'**
  String get buildYourCycle;

  /// No description provided for @currentCycle.
  ///
  /// In en, this message translates to:
  /// **'Current cycle ({count} days):'**
  String currentCycle(Object count);

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @patternNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., My Custom Pattern'**
  String get patternNameHint;

  /// No description provided for @currentCycleDays.
  ///
  /// In en, this message translates to:
  /// **'Current cycle ({count} days):'**
  String currentCycleDays(Object count);

  /// No description provided for @createShiftPattern.
  ///
  /// In en, this message translates to:
  /// **'Create Shift Pattern'**
  String get createShiftPattern;

  /// No description provided for @selectAlarmTime.
  ///
  /// In en, this message translates to:
  /// **'Select alarm time'**
  String get selectAlarmTime;

  /// No description provided for @selectAlarmTone.
  ///
  /// In en, this message translates to:
  /// **'Select alarm tone'**
  String get selectAlarmTone;

  /// No description provided for @editAlarmTimeFor.
  ///
  /// In en, this message translates to:
  /// **'Select alarm time for {title}'**
  String editAlarmTimeFor(Object title);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @korean.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get korean;

  /// No description provided for @editAlarmTime.
  ///
  /// In en, this message translates to:
  /// **'Edit alarm time'**
  String get editAlarmTime;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @snooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get snooze;

  /// No description provided for @alarmSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Alarm settings updated'**
  String get alarmSettingsUpdated;

  /// No description provided for @patternStartDate.
  ///
  /// In en, this message translates to:
  /// **'Pattern Start Date'**
  String get patternStartDate;

  /// No description provided for @selectStartDate.
  ///
  /// In en, this message translates to:
  /// **'Select start date'**
  String get selectStartDate;

  /// No description provided for @startDateHint.
  ///
  /// In en, this message translates to:
  /// **'Select the date your first shift (Day) begins.'**
  String get startDateHint;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @nextMonday.
  ///
  /// In en, this message translates to:
  /// **'Next Monday'**
  String get nextMonday;

  /// No description provided for @chooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose Date'**
  String get chooseDate;

  /// No description provided for @patternStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Pattern Starts On'**
  String get patternStartsOn;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
