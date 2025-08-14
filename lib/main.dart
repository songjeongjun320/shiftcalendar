import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'l10n/app_localizations.dart';
import 'shift_calendar_app.dart';
import 'services/language_service.dart';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit, iOS: iosInit);
  await _notifications.initialize(initSettings);

  final androidSpecific = _notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidSpecific?.requestNotificationsPermission();

  final iosSpecific = _notifications
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
  await iosSpecific?.requestPermissions(alert: true, badge: true, sound: true);

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeNotifications();
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
      home: ShiftCalendarApp(
        notifications: _notifications,
        onLanguageChanged: _changeLanguage,
        currentLocale: _currentLocale,
      ),
    );
  }
}

