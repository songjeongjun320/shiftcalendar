import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import 'l10n/app_localizations.dart';
import 'models/shift_pattern.dart';
import 'models/shift_alarm.dart';
import 'models/shift_type.dart';
import 'models/basic_alarm.dart';
import 'services/shift_scheduling_service.dart';
import 'services/shift_notification_service.dart';
import 'services/shift_storage_service.dart';
import 'services/basic_alarm_service.dart';
import 'services/language_service.dart';
import 'widgets/pattern_creation_dialog.dart';
import 'widgets/basic_alarm_dialog.dart';

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
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);
    
    await _notificationService.initialize();
    await _loadCurrentPattern();
    await _loadBasicAlarms();
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _loadCurrentPattern() async {
    final activePattern = await _storageService.getActivePattern();
    
    if (activePattern != null) {
      final alarms = await _storageService.getAlarmsForPattern(activePattern.id);
      final upcomingShifts = _schedulingService.getUpcomingShifts(activePattern);
      
      setState(() {
        _currentPattern = activePattern;
        _currentAlarms = alarms;
        _upcomingShifts = upcomingShifts;
      });
    }
  }

  Future<void> _loadBasicAlarms() async {
    final alarms = await _storageService.getAllBasicAlarms();
    setState(() {
      _basicAlarms = alarms;
    });
  }
  
  Future<void> _createSamplePattern() async {
    final pattern = ShiftPattern(
      id: _uuid.v4(),
      name: 'Day-Day-Night-Night-Off-Off',
      cycle: [
        ShiftType.day,
        ShiftType.day,
        ShiftType.night,
        ShiftType.night,
        ShiftType.off,
        ShiftType.off,
      ],
      startDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
    
    await _storageService.savePattern(pattern);
    await _storageService.setActivePattern(pattern.id);
    
    // Create sample alarms
    final dayAlarm = ShiftAlarm(
      id: _uuid.v4(),
      patternId: pattern.id,
      targetShiftTypes: {ShiftType.day},
      time: TimeOfDay(hour: 6, minute: 0),
      title: 'Day Shift Alarm',
      message: 'Time to get ready for your {shift} shift!',
      settings: AlarmSettings(),
      createdAt: DateTime.now(),
    );
    
    final nightAlarm = ShiftAlarm(
      id: _uuid.v4(),
      patternId: pattern.id,
      targetShiftTypes: {ShiftType.night},
      time: TimeOfDay(hour: 18, minute: 0),
      title: 'Night Shift Alarm',
      message: 'Time to get ready for your {shift} shift!',
      settings: AlarmSettings(),
      createdAt: DateTime.now(),
    );
    
    await _storageService.saveAlarm(dayAlarm);
    await _storageService.saveAlarm(nightAlarm);
    
    // Schedule notifications
    await _notificationService.scheduleShiftAlarms([dayAlarm, nightAlarm], pattern);
    
    await _loadCurrentPattern();
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

  Future<void> _createCustomPattern(String name, List<ShiftType> cycle) async {
    final pattern = ShiftPattern(
      id: _uuid.v4(),
      name: name,
      cycle: cycle,
      startDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
    
    await _storageService.savePattern(pattern);
    await _storageService.setActivePattern(pattern.id);
    
    // Create default alarms for each shift type in the pattern
    final uniqueShiftTypes = cycle.where((type) => type != ShiftType.off).toSet();
    
    for (final shiftType in uniqueShiftTypes) {
      final defaultTime = shiftType == ShiftType.night ? TimeOfDay(hour: 18, minute: 0) : TimeOfDay(hour: 6, minute: 0);
      final alarm = ShiftAlarm(
        id: _uuid.v4(),
        patternId: pattern.id,
        targetShiftTypes: {shiftType},
        time: defaultTime,
        title: '${shiftType.displayName} Shift Alarm',
        message: 'Time to get ready for your ${shiftType.displayName.toLowerCase()} shift!',
        settings: AlarmSettings(),
        createdAt: DateTime.now(),
      );
      
      await _storageService.saveAlarm(alarm);
    }
    
    // Schedule notifications
    final allAlarms = await _storageService.getAlarmsForPattern(pattern.id);
    await _notificationService.scheduleShiftAlarms(allAlarms, pattern);
    
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

  Future<void> _editAlarmTime(ShiftAlarm alarm) async {
    final l10n = AppLocalizations.of(context)!;
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: alarm.time,
      helpText: '${alarm.title} ${l10n.selectAlarmTime}',
    );
    
    if (newTime != null) {
      final updatedAlarm = alarm.copyWith(time: newTime);
      await _storageService.saveAlarm(updatedAlarm);
      
      if (_currentPattern != null) {
        // Reschedule all alarms for this pattern
        final allAlarms = await _storageService.getAlarmsForPattern(_currentPattern!.id);
        await _notificationService.scheduleShiftAlarms(allAlarms, _currentPattern!);
      }
      
      await _loadCurrentPattern();
      
      // Show confirmation
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.alarmTimeUpdated} ${newTime.format(context)}'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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
    await _storageService.saveBasicAlarm(alarm);
    await _basicAlarmService.scheduleBasicAlarm(alarm);
    await _loadBasicAlarms();
    
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alarm.isActive 
              ? l10n.alarmSavedAndScheduled
              : l10n.alarmSavedInactive),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleBasicAlarm(BasicAlarm alarm) async {
    final updatedAlarm = alarm.copyWith(isActive: !alarm.isActive);
    await _storageService.saveBasicAlarm(updatedAlarm);
    
    if (updatedAlarm.isActive) {
      await _basicAlarmService.scheduleBasicAlarm(updatedAlarm);
    } else {
      await _basicAlarmService.cancelBasicAlarm(updatedAlarm.id);
    }
    
    await _loadBasicAlarms();
  }

  Future<void> _deleteBasicAlarm(BasicAlarm alarm) async {
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
      await _storageService.deleteBasicAlarm(alarm.id);
      await _loadBasicAlarms();
      
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.alarmDeleted),
            duration: Duration(seconds: 2),
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
          OutlinedButton.icon(
            onPressed: _createSamplePattern,
            icon: Icon(Icons.auto_awesome),
            label: Text(l10n.useSamplePattern),
          ),
          SizedBox(height: 16),
          Text(
            l10n.samplePatternDescription,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
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
                        label: Text(shift.shortCode),
                        backgroundColor: _getShiftColor(shift),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCurrentShiftCard() {
    final currentShift = _schedulingService.getCurrentShift(_currentPattern!);
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 8),
                Text(
                  'Today\'s Shift',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getShiftColor(currentShift),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currentShift.displayName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
              ..._currentAlarms.map((alarm) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: alarm.isActive,
                      onChanged: (_) => _toggleAlarm(alarm),
                    ),
                    title: Text(alarm.title),
                    subtitle: Text(
                      '${alarm.time.format(context)} for ${alarm.targetShiftTypesDisplay}',
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit_outlined),
                      onPressed: () => _editAlarmTime(alarm),
                      tooltip: l10n.editAlarmTime,
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
                                '${alarm.time.format(context)} • ${alarm.repeatDaysDisplay}',
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
                            preview.shiftType.shortCode,
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
            SizedBox(height: 8),
            FutureBuilder<Map<String, int>>(
              future: _notificationService.getNotificationStats(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final stats = snapshot.data!;
                  return Text(
                    '${l10n.scheduledNotifications(stats['total'] ?? 0)}\n'
                    '${l10n.dayShiftAlarms(stats['day_shifts'] ?? 0)}\n'
                    '${l10n.nightShiftAlarms(stats['night_shifts'] ?? 0)}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
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