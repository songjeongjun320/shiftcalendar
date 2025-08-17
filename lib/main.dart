import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'l10n/app_localizations.dart';
import 'shift_calendar_app.dart';
import 'services/language_service.dart';
import 'services/alarm_service.dart';
import 'widgets/alarm_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

Future<void> _onDidReceiveNotificationResponse(
    NotificationResponse response) async {
  if (response.payload != null) {
    try {
      final payload = jsonDecode(response.payload!);
      
      // Handle action buttons
      if (response.actionId == 'alarm_dismiss') {
        await _notifications.cancel(payload['notificationId'] ?? 0);
        return;
      } else if (response.actionId == 'alarm_snooze') {
        await _notifications.cancel(payload['notificationId'] ?? 0);
        // TODO: Implement snooze logic
        return;
      } else if (response.actionId == 'auto_trigger_alarm') {
        // This should automatically trigger the alarm screen
        await _showAlarmScreen(payload);
        return;
      }

      // Auto-trigger or manual trigger - show alarm screen
      await _showAlarmScreen(payload);
      
    } catch (e) {
      debugPrint('Error decoding notification payload: $e');
    }
  } else {
  }
}

Future<void> _showAlarmScreen(Map<String, dynamic> payload) async {
  // Check if navigator is available
  if (navigatorKey.currentState != null) {
    // Try to push the alarm screen route
    try {
      await navigatorKey.currentState!.pushNamed('/alarm', arguments: payload);
    } catch (e) {
      await _fallbackAlarmDisplay(payload);
    }
  } else {
    await _fallbackAlarmDisplay(payload);
  }
}

Future<void> _fallbackAlarmDisplay(Map<String, dynamic> payload) async {
  // Show a persistent full-screen notification to bring app to foreground
  await _notifications.show(
    99999, 
    'ALARM: ${payload['title'] ?? 'Alarm'}', 
    'Tap to open alarm screen - ${payload['message'] ?? 'Your alarm is ringing'}',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'urgent_alarm_channel',
        'Urgent Alarms', 
        channelDescription: 'Critical alarm notifications',
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'alarm_dismiss',
            'Dismiss',
            titleColor: Color.fromARGB(255, 255, 0, 0),
          ),
          AndroidNotificationAction(
            'alarm_snooze', 
            'Snooze',
            titleColor: Color.fromARGB(255, 255, 165, 0),
          ),
        ],
      ),
    ),
    payload: jsonEncode(payload),
  );
  
  // Try again after a short delay
  Future.delayed(Duration(seconds: 2), () async {
    if (navigatorKey.currentState != null) {
      try {
        await navigatorKey.currentState!.pushNamed('/alarm', arguments: payload);
        // Cancel the fallback notification
        await _notifications.cancel(99999);
      } catch (e) {
        debugPrint('Error pushing alarm screen from fallback: $e');
      }
    }
  });
}

@pragma('vm:entry-point')
void _onDidReceiveBackgroundNotificationResponse(
    NotificationResponse response) async {
  // For background notifications, we need to be more aggressive
  if (response.payload != null) {
    try {
      final payload = jsonDecode(response.payload!);
      
      // Handle action buttons in background
      if (response.actionId == 'alarm_dismiss') {
        await _notifications.cancel(payload['notificationId'] ?? 0);
        await _notifications.cancel(99998); // Cancel any existing fallback
        return;
      } else if (response.actionId == 'alarm_snooze') {
        await _notifications.cancel(payload['notificationId'] ?? 0);
        await _notifications.cancel(99998); // Cancel any existing fallback
        // TODO: Implement snooze logic
        return;
      }
      
      // Try to show a persistent fullscreen notification to wake up the app
      await _notifications.show(
        99998, 
        'URGENT ALARM: ${payload['title'] ?? 'Alarm'}', 
        'ALARM IS RINGING! Tap to dismiss - ${payload['message'] ?? 'Your alarm needs attention'}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'urgent_alarm_channel',
            'Urgent Alarms', 
            channelDescription: 'Critical alarm notifications',
            importance: Importance.max,
            priority: Priority.high,
            ongoing: true,
            autoCancel: false,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            ticker: 'ALARM RINGING!',
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'alarm_dismiss',
                'Dismiss',
                titleColor: Color.fromARGB(255, 255, 0, 0),
              ),
              AndroidNotificationAction(
                'alarm_snooze', 
                'Snooze',
                titleColor: Color.fromARGB(255, 255, 165, 0),
              ),
            ],
          ),
        ),
        payload: response.payload,
      );
    } catch (e) {
      debugPrint('Error showing background notification: $e');
    }
  } else {
  }
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit, iOS: iosInit);

  await _notifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    onDidReceiveBackgroundNotificationResponse:
        _onDidReceiveBackgroundNotificationResponse,
  );
  
  // Create urgent alarm channel for fallback notifications
  final androidSpecific = _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
  if (androidSpecific != null) {
    await androidSpecific.createNotificationChannel(
      const AndroidNotificationChannel(
        'urgent_alarm_channel',
        'Urgent Alarms',
        description: 'Critical alarm notifications that require immediate attention',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 255, 0, 0),
        showBadge: true,
      ),
    );
  }

  // Initialize timezone with proper error handling FIRST
  tz.initializeTimeZones();
  try {
    final String timeZoneName = DateTime.now().timeZoneName;
    final location = tz.getLocation(timeZoneName);
    tz.setLocalLocation(location);
  } catch (e) {
    // Fallback to system local timezone
    try {
      tz.setLocalLocation(tz.local);
    } catch (e2) {
      // Ultimate fallback to UTC
      tz.setLocalLocation(tz.UTC);
    }
  }

  // Request Android permissions with detailed logging
  if (androidSpecific != null) {
    // Request notification permission
    await androidSpecific.requestNotificationsPermission();
    
    // Request exact alarm permission (CRITICAL for scheduled alarms)
    await androidSpecific.requestExactAlarmsPermission();
    
    // Check if exact alarms can be scheduled
    await androidSpecific.canScheduleExactNotifications();
    
  }

  // Request iOS permissions
  final iosSpecific = _notifications
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
  if (iosSpecific != null) {
    await iosSpecific.requestPermissions(
      alert: true, 
      badge: true, 
      sound: true
    );
  }

}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification systems
  await _initializeNotifications();
  
  // Initialize reliable alarm service
  await AlarmService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _languageService = LanguageService();
  Locale _currentLocale = const Locale('en', 'US');

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final locale = await _languageService.getCurrentLanguage();
    setState(() {
      _currentLocale = locale;
    });
  }

  void _changeLanguage(Locale locale) async {
    await _languageService.setLanguage(locale);
    setState(() {
      _currentLocale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ShiftCalendar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      locale: _currentLocale,
      supportedLocales: LanguageService.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routes: {
        '/': (context) => ShiftCalendarApp(
              notifications: _notifications,
              onLanguageChanged: _changeLanguage,
              currentLocale: _currentLocale,
            ),
        '/alarm': (context) {
          try {
            final routeSettings = ModalRoute.of(context)?.settings;
            if (routeSettings?.arguments == null) {
              return AlarmScreen(
                alarmTitle: 'Alarm',
                alarmMessage: 'Your alarm is ringing.',
                alarmTone: 'sounds/wakeupcall.mp3',
                alarmVolume: 0.9,
                notificationId: 0,
              );
            }
            
            final args = routeSettings!.arguments as Map<String, dynamic>;
            
            return AlarmScreen(
              alarmTitle: args['title'] ?? 'Alarm',
              alarmMessage: args['message'] ?? 'Your shift is starting soon.',
              alarmTone: args['alarmTone'],
              alarmVolume: args['alarmVolume'],
              notificationId: args['notificationId'],
            );
          } catch (e) {
            // Fallback alarm screen with default values
            return AlarmScreen(
              alarmTitle: 'Alarm',
              alarmMessage: 'Your alarm is ringing.',
              alarmTone: 'sounds/wakeupcall.mp3',
              alarmVolume: 0.9,
              notificationId: 0,
            );
          }
        },
      },
      initialRoute: '/',
    );
  }
}

