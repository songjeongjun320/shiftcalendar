import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'l10n/app_localizations.dart';
import 'shift_calendar_app.dart';
import 'services/language_service.dart';
import 'services/reliable_alarm_service.dart';
import 'widgets/alarm_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

Future<void> _onDidReceiveNotificationResponse(
    NotificationResponse response) async {
  print('🔔 Notification tapped! Action: ${response.actionId}, Payload: ${response.payload}');
  
  if (response.payload != null) {
    try {
      final payload = jsonDecode(response.payload!);
      print('📋 Parsed payload: $payload');
      
      // Handle action buttons
      if (response.actionId == 'alarm_dismiss') {
        print('🛑 User chose to dismiss alarm via notification');
        await _notifications.cancel(payload['notificationId'] ?? 0);
        return;
      } else if (response.actionId == 'alarm_snooze') {
        print('⏰ User chose to snooze alarm via notification');
        await _notifications.cancel(payload['notificationId'] ?? 0);
        // TODO: Implement snooze logic
        return;
      }

      // Auto-trigger or manual trigger - show alarm screen
      await _showAlarmScreen(payload);
      
    } catch (e) {
      print('❌ Error handling notification response: $e');
    }
  } else {
    print('⚠️ No payload in notification response');
  }
}

Future<void> _showAlarmScreen(Map<String, dynamic> payload) async {
  print('🎯 Showing alarm screen with payload: $payload');
  
  // Check if navigator is available
  if (navigatorKey.currentState != null) {
    print('✅ Navigator available - pushing to alarm screen');
    
    // Try to push the alarm screen route
    try {
      await navigatorKey.currentState!.pushNamed('/alarm', arguments: payload);
      print('✅ Successfully navigated to alarm screen');
    } catch (e) {
      print('❌ Error navigating to alarm screen: $e');
      await _fallbackAlarmDisplay(payload);
    }
  } else {
    print('❌ Navigator not available - using fallback approach');
    await _fallbackAlarmDisplay(payload);
  }
}

Future<void> _fallbackAlarmDisplay(Map<String, dynamic> payload) async {
  print('🔄 Using fallback alarm display approach');
  
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
  print('🚨 Fallback full-screen notification sent');
  
  // Try again after a short delay
  Future.delayed(Duration(seconds: 2), () async {
    if (navigatorKey.currentState != null) {
      print('🔄 Retry: Navigator now available');
      try {
        await navigatorKey.currentState!.pushNamed('/alarm', arguments: payload);
        print('✅ Retry successful - navigated to alarm screen');
        // Cancel the fallback notification
        await _notifications.cancel(99999);
      } catch (e) {
        print('❌ Retry failed: $e');
      }
    }
  });
}

@pragma('vm:entry-point')
void _onDidReceiveBackgroundNotificationResponse(
    NotificationResponse response) async {
  print('🔔 Background notification tapped! Action: ${response.actionId}, Payload: ${response.payload}');
  
  // For background notifications, we need to be more aggressive
  if (response.payload != null) {
    try {
      final payload = jsonDecode(response.payload!);
      print('📋 Background parsed payload: $payload');
      
      // Handle action buttons in background
      if (response.actionId == 'alarm_dismiss') {
        print('🛑 Background dismiss - cancelling alarm notifications');
        await _notifications.cancel(payload['notificationId'] ?? 0);
        await _notifications.cancel(99998); // Cancel any existing fallback
        return;
      } else if (response.actionId == 'alarm_snooze') {
        print('⏰ Background snooze - will implement snooze logic');
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
      print('🚨 Background fallback notification sent with fullscreen intent');
    } catch (e) {
      print('❌ Error handling background notification response: $e');
    }
  } else {
    print('⚠️ No payload in background notification response');
  }
}

Future<void> _initializeNotifications() async {
  print('=== INITIALIZING NOTIFICATION SYSTEM ===');
  
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
    print('✅ Urgent alarm channel created');
  }

  // Initialize timezone with proper error handling FIRST
  print('Initializing timezone system...');
  tz.initializeTimeZones();
  try {
    final String timeZoneName = DateTime.now().timeZoneName;
    print('System timezone: $timeZoneName');
    final location = tz.getLocation(timeZoneName);
    tz.setLocalLocation(location);
    print('TZ location set to: ${tz.local.name}');
  } catch (e) {
    print('Failed to set timezone from system name: $e');
    // Fallback to system local timezone
    try {
      tz.setLocalLocation(tz.local);
      print('TZ fallback to local: ${tz.local.name}');
    } catch (e2) {
      print('Failed to set local timezone: $e2');
      // Ultimate fallback to UTC
      tz.setLocalLocation(tz.UTC);
      print('TZ ultimate fallback to UTC');
    }
  }

  // Request Android permissions with detailed logging
  if (androidSpecific != null) {
    print('Requesting Android permissions...');
    
    // Request notification permission
    final notificationPermission = await androidSpecific.requestNotificationsPermission();
    print('Notification permission result: $notificationPermission');
    
    // Request exact alarm permission (CRITICAL for scheduled alarms)
    final exactAlarmPermission = await androidSpecific.requestExactAlarmsPermission();
    print('Exact alarm permission result: $exactAlarmPermission');
    
    // Check if exact alarms can be scheduled
    final canScheduleExact = await androidSpecific.canScheduleExactNotifications();
    print('Can schedule exact notifications: $canScheduleExact');
    
    if (exactAlarmPermission != true || canScheduleExact != true) {
      print('🚨 CRITICAL: Exact alarm permissions not granted!');
      print('📋 User must manually grant SCHEDULE_EXACT_ALARM permission in app settings');
    } else {
      print('✅ All Android permissions granted successfully');
    }
  }

  // Request iOS permissions
  final iosSpecific = _notifications
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
  if (iosSpecific != null) {
    print('Requesting iOS permissions...');
    final iosPermissions = await iosSpecific.requestPermissions(
      alert: true, 
      badge: true, 
      sound: true
    );
    print('iOS permissions result: $iosPermissions');
  }
  
  print('=== NOTIFICATION SYSTEM INITIALIZATION COMPLETE ===');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification systems
  await _initializeNotifications();
  
  // Initialize reliable alarm service
  await ReliableAlarmService.initialize();
  
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
          print('🔔 Alarm route accessed!');
          
          try {
            final routeSettings = ModalRoute.of(context)?.settings;
            if (routeSettings?.arguments == null) {
              print('⚠️ No arguments provided to alarm route');
              return AlarmScreen(
                alarmTitle: 'Alarm',
                alarmMessage: 'Your alarm is ringing.',
                alarmTone: 'sounds/wakeupcall.mp3',
                alarmVolume: 0.9,
                notificationId: 0,
              );
            }
            
            final args = routeSettings!.arguments as Map<String, dynamic>;
            print('📋 Alarm route arguments: $args');
            
            return AlarmScreen(
              alarmTitle: args['title'] ?? 'Alarm',
              alarmMessage: args['message'] ?? 'Your shift is starting soon.',
              alarmTone: args['alarmTone'],
              alarmVolume: args['alarmVolume'],
              notificationId: args['notificationId'],
            );
          } catch (e) {
            print('❌ Error creating alarm screen: $e');
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

