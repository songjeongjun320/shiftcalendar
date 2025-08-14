import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'selected_language';
  
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('ko', 'KR'),
  ];
  
  /// Get the currently selected language
  Future<Locale> getCurrentLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey);
    
    if (languageCode != null) {
      return Locale(languageCode);
    }
    
    // Default to system language if supported, otherwise English
    final systemLocale = PlatformDispatcher.instance.locale;
    if (supportedLocales.any((locale) => locale.languageCode == systemLocale.languageCode)) {
      return Locale(systemLocale.languageCode);
    }
    
    return const Locale('en', 'US');
  }
  
  /// Set the selected language
  Future<void> setLanguage(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
  }
  
  /// Get language display name
  String getLanguageDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'ko':
        return '한국어';
      default:
        return locale.languageCode;
    }
  }
  
  /// Check if locale is supported
  bool isSupported(Locale locale) {
    return supportedLocales.any((supported) => 
        supported.languageCode == locale.languageCode);
  }
}