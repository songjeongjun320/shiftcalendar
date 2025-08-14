import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_pattern.dart';
import '../models/shift_alarm.dart';
import '../models/basic_alarm.dart';

class ShiftStorageService {
  static const String _patternsKey = 'shift_patterns';
  static const String _alarmsKey = 'shift_alarms';
  static const String _basicAlarmsKey = 'basic_alarms';
  static const String _activePatternKey = 'active_pattern_id';
  
  /// Save a shift pattern
  Future<void> savePattern(ShiftPattern pattern) async {
    final prefs = await SharedPreferences.getInstance();
    final patterns = await getAllPatterns();
    
    // Remove existing pattern with same ID
    patterns.removeWhere((p) => p.id == pattern.id);
    patterns.add(pattern);
    
    final patternsJson = patterns.map((p) => p.toMap()).toList();
    await prefs.setString(_patternsKey, jsonEncode(patternsJson));
  }
  
  /// Get a specific pattern by ID
  Future<ShiftPattern?> getPattern(String id) async {
    final patterns = await getAllPatterns();
    try {
      return patterns.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Get all shift patterns
  Future<List<ShiftPattern>> getAllPatterns() async {
    final prefs = await SharedPreferences.getInstance();
    final patternsJson = prefs.getString(_patternsKey);
    
    if (patternsJson == null) return [];
    
    try {
      final patternsList = jsonDecode(patternsJson) as List;
      return patternsList
          .map((json) => ShiftPattern.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Delete a pattern and its associated alarms
  Future<void> deletePattern(String id) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove pattern
    final patterns = await getAllPatterns();
    patterns.removeWhere((p) => p.id == id);
    
    final patternsJson = patterns.map((p) => p.toMap()).toList();
    await prefs.setString(_patternsKey, jsonEncode(patternsJson));
    
    // Remove associated alarms
    final alarms = await getAllAlarms();
    alarms.removeWhere((a) => a.patternId == id);
    
    final alarmsJson = alarms.map((a) => a.toMap()).toList();
    await prefs.setString(_alarmsKey, jsonEncode(alarmsJson));
    
    // Clear active pattern if it was deleted
    final activePatternId = await getActivePatternId();
    if (activePatternId == id) {
      await setActivePattern(null);
    }
  }
  
  /// Save a shift alarm
  Future<void> saveAlarm(ShiftAlarm alarm) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = await getAllAlarms();
    
    // Remove existing alarm with same ID
    alarms.removeWhere((a) => a.id == alarm.id);
    alarms.add(alarm);
    
    final alarmsJson = alarms.map((a) => a.toMap()).toList();
    await prefs.setString(_alarmsKey, jsonEncode(alarmsJson));
  }
  
  /// Get a specific alarm by ID
  Future<ShiftAlarm?> getAlarm(String id) async {
    final alarms = await getAllAlarms();
    try {
      return alarms.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Get all shift alarms
  Future<List<ShiftAlarm>> getAllAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString(_alarmsKey);
    
    if (alarmsJson == null) return [];
    
    try {
      final alarmsList = jsonDecode(alarmsJson) as List;
      return alarmsList
          .map((json) => ShiftAlarm.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Get alarms for a specific pattern
  Future<List<ShiftAlarm>> getAlarmsForPattern(String patternId) async {
    final allAlarms = await getAllAlarms();
    return allAlarms.where((a) => a.patternId == patternId).toList();
  }
  
  /// Delete an alarm
  Future<void> deleteAlarm(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = await getAllAlarms();
    
    alarms.removeWhere((a) => a.id == id);
    
    final alarmsJson = alarms.map((a) => a.toMap()).toList();
    await prefs.setString(_alarmsKey, jsonEncode(alarmsJson));
  }
  
  /// Set the active pattern
  Future<void> setActivePattern(String? patternId) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (patternId == null) {
      await prefs.remove(_activePatternKey);
    } else {
      await prefs.setString(_activePatternKey, patternId);
    }
  }
  
  /// Get the active pattern ID
  Future<String?> getActivePatternId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activePatternKey);
  }
  
  /// Get the active pattern
  Future<ShiftPattern?> getActivePattern() async {
    final activeId = await getActivePatternId();
    if (activeId == null) return null;
    return getPattern(activeId);
  }
  
  /// Save a basic alarm
  Future<void> saveBasicAlarm(BasicAlarm alarm) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = await getAllBasicAlarms();
    
    // Remove existing alarm with same ID
    alarms.removeWhere((a) => a.id == alarm.id);
    alarms.add(alarm);
    
    final alarmsJson = alarms.map((a) => a.toMap()).toList();
    await prefs.setString(_basicAlarmsKey, jsonEncode(alarmsJson));
  }
  
  /// Get all basic alarms
  Future<List<BasicAlarm>> getAllBasicAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString(_basicAlarmsKey);
    
    if (alarmsJson == null) return [];
    
    try {
      final alarmsList = jsonDecode(alarmsJson) as List;
      return alarmsList
          .map((json) => BasicAlarm.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Get a basic alarm by ID
  Future<BasicAlarm?> getBasicAlarm(String id) async {
    final alarms = await getAllBasicAlarms();
    try {
      return alarms.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Delete a basic alarm
  Future<void> deleteBasicAlarm(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = await getAllBasicAlarms();
    
    alarms.removeWhere((a) => a.id == id);
    
    final alarmsJson = alarms.map((a) => a.toMap()).toList();
    await prefs.setString(_basicAlarmsKey, jsonEncode(alarmsJson));
  }

  /// Clear all data (for testing or reset)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_patternsKey);
    await prefs.remove(_alarmsKey);
    await prefs.remove(_basicAlarmsKey);
    await prefs.remove(_activePatternKey);
  }
  
  /// Export all data as JSON
  Future<Map<String, dynamic>> exportData() async {
    final patterns = await getAllPatterns();
    final alarms = await getAllAlarms();
    final activePatternId = await getActivePatternId();
    
    return {
      'patterns': patterns.map((p) => p.toMap()).toList(),
      'alarms': alarms.map((a) => a.toMap()).toList(),
      'active_pattern_id': activePatternId,
      'export_timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  /// Import data from JSON
  Future<void> importData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Import patterns
    if (data.containsKey('patterns')) {
      await prefs.setString(_patternsKey, jsonEncode(data['patterns']));
    }
    
    // Import alarms
    if (data.containsKey('alarms')) {
      await prefs.setString(_alarmsKey, jsonEncode(data['alarms']));
    }
    
    // Import active pattern
    if (data.containsKey('active_pattern_id') && data['active_pattern_id'] != null) {
      await prefs.setString(_activePatternKey, data['active_pattern_id']);
    }
  }
  
  /// Get storage statistics
  Future<Map<String, int>> getStorageStats() async {
    final patterns = await getAllPatterns();
    final alarms = await getAllAlarms();
    
    return {
      'total_patterns': patterns.length,
      'active_patterns': patterns.where((p) => p.isActive).length,
      'total_alarms': alarms.length,
      'active_alarms': alarms.where((a) => a.isActive).length,
    };
  }
}