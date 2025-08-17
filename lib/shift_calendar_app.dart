import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'l10n/app_localizations.dart';
import 'models/shift_pattern.dart';
import 'models/shift_type.dart';
import 'models/alarm_enums.dart';
import 'models/shift_alarm.dart';
import 'models/basic_alarm.dart';
import 'services/shift_scheduling_service.dart';
import 'services/shift_notification_service.dart';
import 'services/shift_storage_service.dart';
import 'services/basic_alarm_service.dart';
import 'services/language_service.dart';
import 'services/alarm_diagnostic_service.dart';
import 'services/alarm_trigger_validator.dart';
import 'widgets/pattern_creation_dialog.dart';
import 'widgets/basic_alarm_dialog.dart';
import 'widgets/shift_alarm_settings_dialog.dart';
import 'widgets/alarm_debug_screen.dart';

class ShiftCalendarApp extends StatefulWidget {
  final FlutterLocalNotificationsPlugin notifications;
  final Function(Locale) onLanguageChanged;
  final Locale currentLocale;
  
  const ShiftCalendarApp({
    super.key, 
    required this.notifications,
    required this.onLanguageChanged,
    required this.currentLocale,
  });
  
  @override
  State<ShiftCalendarApp> createState() => _ShiftCalendarAppState();
}

class _ShiftCalendarAppState extends State<ShiftCalendarApp> {
  final _schedulingService = ShiftSchedulingService();
  late final ShiftNotificationService _notificationService;
  late final BasicAlarmService _basicAlarmService;
  late final AlarmDiagnosticService _diagnosticService;
  late final AlarmTriggerValidator _triggerValidator;
  final _storageService = ShiftStorageService();
  final _uuid = Uuid();
  
  ShiftPattern? _currentPattern;
  List<ShiftAlarm> _currentAlarms = [];
  List<BasicAlarm> _basicAlarms = [];
  List<ShiftSchedulePreview> _upcomingShifts = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _notificationService = ShiftNotificationService(widget.notifications, _schedulingService);
    _basicAlarmService = BasicAlarmService(widget.notifications);
    _diagnosticService = AlarmDiagnosticService(widget.notifications);
    _triggerValidator = AlarmTriggerValidator(widget.notifications);
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);
    
    await _notificationService.initialize();
    await _basicAlarmService.initialize(); // Add basic alarm service initialization
    await _loadCurrentPattern();
    await _loadBasicAlarms();
    
    // Start diagnostic monitoring and trigger validation
    _diagnosticService.startDiagnosticMonitoring();
    _triggerValidator.startValidation();
    
    // Debug pending alarms after initialization
    print('=== DEBUGGING PENDING ALARMS AFTER INIT ===');
    await _notificationService.debugPendingNotifications();
    await _basicAlarmService.debugPendingBasicAlarms();
    await _diagnosticService.forceDiagnosticCheck();
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _loadCurrentPattern() async {
    final activePattern = await _storageService.getActivePattern();
    
    if (activePattern != null) {
      var alarms = await _storageService.getAlarmsForPattern(activePattern.id);
      
      // --- Data Migration & Cleanup Logic ---
      bool alarmsChanged = false;
      
      // 1. Group alarms by type and remove duplicates, keeping the newest
      final Map<AlarmType, List<ShiftAlarm>> groupedAlarms = {};
      for (final alarm in alarms) {
        groupedAlarms.putIfAbsent(alarm.alarmType, () => []).add(alarm);
      }
      
      final List<ShiftAlarm> cleanedAlarms = [];
      for (final type in groupedAlarms.keys) {
        var group = groupedAlarms[type]!;
        if (group.length > 1) {
          alarmsChanged = true;
          group.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
          final alarmToKeep = group.first;
          cleanedAlarms.add(alarmToKeep);
          // Delete the older duplicates
          for (int i = 1; i < group.length; i++) {
            await _storageService.deleteAlarm(group[i].id);
          }
        } else {
          cleanedAlarms.add(group.first);
        }
      }
      
      // 2. Check for missing default alarm types and add them
      final existingAlarmTypes = cleanedAlarms.map((a) => a.alarmType).toSet();
      final defaultAlarms = _createDefaultAlarms(activePattern.id);
      
      for (final defaultAlarm in defaultAlarms) {
        if (!existingAlarmTypes.contains(defaultAlarm.alarmType)) {
          await _storageService.saveAlarm(defaultAlarm);
          cleanedAlarms.add(defaultAlarm);
          alarmsChanged = true;
        }
      }

      // 3. If any changes were made, reschedule notifications
      if (alarmsChanged) {
        alarms = cleanedAlarms; // Update the list with the cleaned/added alarms
        await _notificationService.scheduleShiftAlarms(alarms, activePattern);
      }
      // --- End of Data Migration & Cleanup Logic ---

      final upcomingShifts = _schedulingService.getUpcomingShifts(activePattern);
      
      setState(() {
        _currentPattern = activePattern;
        _currentAlarms = alarms;
        _upcomingShifts = upcomingShifts;
      });
    }
  }

  Future<void> _loadBasicAlarms() async {
    final alarms = await _basicAlarmService.getAllBasicAlarms();
    if (mounted) {
      setState(() {
        _basicAlarms = alarms;
      });
    }
  }
  
  
  List<ShiftAlarm> _createDefaultAlarms(String patternId) {
    final dayAlarm = ShiftAlarm(
      id: _uuid.v4(),
      patternId: patternId,
      alarmType: AlarmType.day,
      targetShiftTypes: {ShiftType.day},
      time: const TimeOfDay(hour: 6, minute: 0),
      title: 'Day Shift Alarm',
      message: 'Time to get ready for your day shift!',
      settings: const AlarmSettings(),
      createdAt: DateTime.now(),
    );
    
    final nightAlarm = ShiftAlarm(
      id: _uuid.v4(),
      patternId: patternId,
      alarmType: AlarmType.night,
      targetShiftTypes: {ShiftType.night},
      time: const TimeOfDay(hour: 18, minute: 0),
      title: 'Night Shift Alarm',
      message: 'Time to get ready for your night shift!',
      settings: const AlarmSettings(),
      createdAt: DateTime.now(),
    );

    final offAlarm = ShiftAlarm(
      id: _uuid.v4(),
      patternId: patternId,
      alarmType: AlarmType.off,
      targetShiftTypes: {ShiftType.off},
      time: const TimeOfDay(hour: 9, minute: 0),
      title: 'Day Off Alarm',
      message: 'Enjoy your day off!',
      settings: const AlarmSettings(),
      createdAt: DateTime.now(),
    );
    
    return [dayAlarm, nightAlarm, offAlarm];
  }

  Future<void> _clearAllData() async {
    await _notificationService.cancelAllAlarms();
    await _storageService.clearAllData();
    
    setState(() {
      _currentPattern = null;
      _currentAlarms = [];
      _upcomingShifts = [];
    });
  }

  void _showPatternCreationDialog() {
    showDialog(
      context: context,
      builder: (context) => PatternCreationDialog(
        onPatternCreated: _createCustomPattern,
      ),
    );
  }

  Future<void> _createCustomPattern(String name, List<ShiftType> cycle, DateTime startDate) async {
    final pattern = ShiftPattern(
      id: _uuid.v4(),
      name: name,
      cycle: cycle,
      startDate: startDate, // ✅ Use user-selected date
      createdAt: DateTime.now(),
    );
    
    await _storageService.savePattern(pattern);
    await _storageService.setActivePattern(pattern.id);
    
    // Create default alarms for the new pattern
    final defaultAlarms = _createDefaultAlarms(pattern.id);
    for (final alarm in defaultAlarms) {
      await _storageService.saveAlarm(alarm);
    }
    
    // Schedule notifications
    await _notificationService.scheduleShiftAlarms(defaultAlarms, pattern);
    
    await _loadCurrentPattern();
  }
  
  Future<void> _toggleAlarm(ShiftAlarm alarm) async {
    final updatedAlarm = alarm.copyWith(isActive: !alarm.isActive);
    await _storageService.saveAlarm(updatedAlarm);
    
    if (_currentPattern != null) {
      // Reschedule all alarms for this pattern
      final allAlarms = await _storageService.getAlarmsForPattern(_currentPattern!.id);
      await _notificationService.scheduleShiftAlarms(allAlarms, _currentPattern!);
    }
    
    await _loadCurrentPattern();
  }

  void _showShiftAlarmSettingsDialog(ShiftAlarm alarm) {
    showDialog(
      context: context,
      builder: (context) => ShiftAlarmSettingsDialog(
        alarm: alarm,
        onAlarmUpdated: _updateShiftAlarm,
      ),
    );
  }
  
  Future<void> _updateShiftAlarm(ShiftAlarm updatedAlarm) async {
    await _storageService.saveAlarm(updatedAlarm);
    
    if (_currentPattern != null) {
      // Reschedule all alarms for this pattern
      final allAlarms = await _storageService.getAlarmsForPattern(_currentPattern!.id);
      await _notificationService.scheduleShiftAlarms(allAlarms, _currentPattern!);
    }
    
    await _loadCurrentPattern();
    
    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alarm settings updated'), // Can be localized if needed
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  

  void _showBasicAlarmDialog([BasicAlarm? alarm]) {
    showDialog(
      context: context,
      builder: (context) => BasicAlarmDialog(
        alarm: alarm,
        onAlarmCreated: _saveBasicAlarm,
      ),
    );
  }

  Future<void> _saveBasicAlarm(BasicAlarm alarm) async {
    await _basicAlarmService.scheduleBasicAlarm(alarm);

    // 🔧 FIX: Immediately update UI state without redundant reloading
    if (mounted) {
      setState(() {
        _basicAlarms.removeWhere((a) => a.id == alarm.id);
        _basicAlarms.add(alarm);
        _basicAlarms.sort((a, b) => 
          (a.time.hour * 60 + a.time.minute) - 
          (b.time.hour * 60 + b.time.minute));
      });
    }

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alarm.isActive 
              ? l10n.alarmSavedAndScheduled
              : l10n.alarmSavedInactive),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleBasicAlarm(BasicAlarm alarm) async {
    final updatedAlarm = alarm.copyWith(isActive: !alarm.isActive);
    
    // Schedule or cancel with the service
    await _basicAlarmService.scheduleBasicAlarm(updatedAlarm);
    
    // Update the UI state directly
    if (mounted) {
      setState(() {
        final index = _basicAlarms.indexWhere((a) => a.id == alarm.id);
        if (index != -1) {
          _basicAlarms[index] = updatedAlarm;
        }
      });
    }
  }

  Future<void> _deleteBasicAlarm(BasicAlarm alarm) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAlarm),
        content: Text('${l10n.deleteAlarmConfirm} "${alarm.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _basicAlarmService.cancelBasicAlarm(alarm.id);
      
      // 🔧 FIX: Immediately update UI state without redundant reloading
      if (mounted) {
        setState(() {
          _basicAlarms.removeWhere((a) => a.id == alarm.id);
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.alarmDeleted),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSettingsDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.language),
              title: Text(l10n.language),
              subtitle: Text(LanguageService().getLanguageDisplayName(widget.currentLocale)),
              onTap: _showLanguageSelector,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector() {
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).pop(); // Close settings dialog first
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LanguageService.supportedLocales.map((locale) => RadioListTile<Locale>(
            title: Text(LanguageService().getLanguageDisplayName(locale)),
            value: locale,
            groupValue: widget.currentLocale,
            onChanged: (selectedLocale) {
              if (selectedLocale != null) {
                widget.onLanguageChanged(selectedLocale);
                Navigator.of(context).pop();
              }
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _diagnosticService.stopDiagnosticMonitoring();
    _triggerValidator.stopValidation();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AlarmDebugScreen(
                    diagnosticService: _diagnosticService,
                    triggerValidator: _triggerValidator,
                  ),
                ),
              );
            },
            tooltip: 'Alarm Diagnostics',
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: l10n.settings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildMainContent(),
      floatingActionButton: _currentPattern != null ? FloatingActionButton.extended(
        onPressed: () => _showBasicAlarmDialog(),
        icon: Icon(Icons.alarm_add),
        label: Text(l10n.addAlarm),
      ) : null,
    );
  }
  
  Widget _buildMainContent() {
    if (_currentPattern == null) {
      return _buildWelcomeScreen();
    }
    
    return _buildDashboard();
  }
  
  Widget _buildWelcomeScreen() {
    final l10n = AppLocalizations.of(context)!;
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.schedule,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: 24),
          Text(
            l10n.welcomeTitle,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            l10n.welcomeDescription,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _showPatternCreationDialog,
            icon: Icon(Icons.add),
            label: Text(l10n.createPattern),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCurrentPatternCard(),
          SizedBox(height: 16),
          _buildUpcomingShiftsCard(),
          SizedBox(height: 16),
          _buildAlarmsCard(),
          SizedBox(height: 16),
          _buildBasicAlarmsCard(),
          SizedBox(height: 16),
          _buildActionsCard(),
        ],
      ),
    );
  }
  
  Widget _buildCurrentPatternCard() {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pattern, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 8),
                Text(
                  l10n.currentPattern,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              _currentPattern!.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _currentPattern!.cycle
                  .map((shift) => Chip(
                        label: Text(shift.localizedShortCode(context)),
                        backgroundColor: _getShiftColor(shift),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildAlarmsCard() {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alarm, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 8),
                Text(
                  l10n.alarms,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_currentAlarms.isEmpty)
              Text(l10n.noAlarmsConfigured)
            else
              ..._getSortedAlarms().map((alarm) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: alarm.isActive,
                          onChanged: (_) => _toggleAlarm(alarm),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.brightness_1,
                          color: _getAlarmTypeColor(alarm.alarmType),
                          size: 16,
                        ),
                      ],
                    ),
                    title: Text(alarm.title),
                    subtitle: Text(
                      '${alarm.time.format(context)} for ${alarm.getLocalizedTargetShiftTypesDisplay(context)}',
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.settings_outlined),
                      onPressed: () => _showShiftAlarmSettingsDialog(alarm),
                      tooltip: 'Alarm settings',
                    ),
                  )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBasicAlarmsCard() {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alarm, color: Theme.of(context).colorScheme.secondary),
                SizedBox(width: 8),
                Text(
                  l10n.basicAlarms,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Spacer(),
                TextButton.icon(
                  onPressed: () => _showBasicAlarmDialog(),
                  icon: Icon(Icons.add, size: 16),
                  label: Text(l10n.add),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_basicAlarms.isEmpty)
              Text(l10n.noBasicAlarmsConfigured)
            else
              ..._basicAlarms.map((alarm) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Switch(
                          value: alarm.isActive,
                          onChanged: (_) => _toggleBasicAlarm(alarm),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alarm.label,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                '${alarm.time.format(context)} • ${alarm.getLocalizedRepeatDaysDisplay(context)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _showBasicAlarmDialog(alarm);
                                break;
                              case 'delete':
                                _deleteBasicAlarm(alarm);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text(l10n.edit),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 16),
                                  SizedBox(width: 8),
                                  Text(l10n.delete),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUpcomingShiftsCard() {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 8),
                Text(
                  l10n.upcomingShifts,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _upcomingShifts.map((preview) => Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: preview.isToday
                            ? Theme.of(context).colorScheme.primaryContainer
                            : _getShiftColor(preview.shiftType),
                        borderRadius: BorderRadius.circular(8),
                        border: preview.isToday
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            preview.weekdayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(preview.dateDisplay),
                          SizedBox(height: 4),
                          Text(
                            preview.shiftType.localizedShortCode(context),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionsCard() {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.actions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _clearAllData,
              icon: Icon(Icons.clear_all),
              label: Text(l10n.clearAllData),
            ),
          ],
        ),
      ),
    );
  }
  
  List<ShiftAlarm> _getSortedAlarms() {
    final sorted = List<ShiftAlarm>.from(_currentAlarms);
    sorted.sort((a, b) {
      // Sort by alarm type priority (day -> night -> off)
      final aPriority = a.alarmType.index;
      final bPriority = b.alarmType.index;
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      
      // Then by time
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      if (aMinutes != bMinutes) {
        return aMinutes.compareTo(bMinutes);
      }
      
      // Finally, for stable sorting when shift type and time are equal,
      // sort by creation time to maintain consistent position
      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }
  
  Color _getAlarmTypeColor(AlarmType alarmType) {
    switch (alarmType) {
      case AlarmType.day:
        return Colors.orangeAccent;
      case AlarmType.night:
        return Colors.indigo;
      case AlarmType.off:
        return Colors.green;
      case AlarmType.basic:
        return Colors.blueGrey;
    }
  }

  Color _getShiftColor(ShiftType shiftType) {
    switch (shiftType) {
      case ShiftType.day:
        return Colors.orange.shade200;
      case ShiftType.night:
        return Colors.indigo.shade200;
      case ShiftType.off:
        return Colors.green.shade200;
    }
  }
}