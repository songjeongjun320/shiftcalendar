import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/shift_alarm.dart';
import '../models/basic_alarm.dart';

class ShiftAlarmSettingsDialog extends StatefulWidget {
  final ShiftAlarm alarm;
  final Function(ShiftAlarm) onAlarmUpdated;
  
  const ShiftAlarmSettingsDialog({
    super.key,
    required this.alarm,
    required this.onAlarmUpdated,
  });
  
  @override
  State<ShiftAlarmSettingsDialog> createState() => _ShiftAlarmSettingsDialogState();
}

class _ShiftAlarmSettingsDialogState extends State<ShiftAlarmSettingsDialog> {
  late TimeOfDay _selectedTime;
  late bool _soundEnabled;
  late AlarmTone _selectedTone;
  late double _selectedVolume;
  late bool _vibrationEnabled;
  late bool _snoozeEnabled;
  late int _snoozeDuration;
  late int _maxSnoozeCount;
  late bool _isActive;
  
  @override
  void initState() {
    super.initState();
    
    _selectedTime = widget.alarm.time;
    _soundEnabled = widget.alarm.settings.sound;
    _selectedTone = AlarmTone.bell; // Default, can be enhanced to match soundPath
    _selectedVolume = widget.alarm.settings.volume;
    _vibrationEnabled = widget.alarm.settings.vibration;
    _snoozeEnabled = widget.alarm.settings.snooze;
    _snoozeDuration = widget.alarm.settings.snoozeDuration;
    _maxSnoozeCount = widget.alarm.settings.maxSnoozeCount;
    _isActive = widget.alarm.isActive;
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text('${l10n.editAlarm} - ${widget.alarm.title}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule),
                title: Text(l10n.time),
                subtitle: Text(_selectedTime.format(context)),
                onTap: _selectTime,
              ),
              
              Divider(),
              
              // Sound settings
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.sound),
                subtitle: Text('Enable alarm sound'),
                value: _soundEnabled,
                onChanged: (value) => setState(() => _soundEnabled = value),
              ),
              
              // Alarm tone (only when sound is enabled)
              if (_soundEnabled) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.music_note),
                  title: Text(l10n.alarmTone),
                  subtitle: Text(_selectedTone.localizedDisplayName(context)),
                  onTap: _selectTone,
                ),
                
                // Volume control
                SizedBox(height: 16),
                Text(
                  l10n.volume,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.volume_down, size: 20),
                    Expanded(
                      child: Slider(
                        value: _selectedVolume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: '${(_selectedVolume * 100).round()}%',
                        onChanged: (value) {
                          setState(() {
                            _selectedVolume = value;
                          });
                        },
                      ),
                    ),
                    Icon(Icons.volume_up, size: 20),
                  ],
                ),
              ],
              
              SizedBox(height: 16),
              
              // Vibration
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.vibration),
                subtitle: Text('Enable vibration'),
                value: _vibrationEnabled,
                onChanged: (value) => setState(() => _vibrationEnabled = value),
              ),
              
              // Snooze settings
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.snooze),
                subtitle: Text('Allow snooze functionality'),
                value: _snoozeEnabled,
                onChanged: (value) => setState(() => _snoozeEnabled = value),
              ),
              
              if (_snoozeEnabled) ...[
                SizedBox(height: 16),
                Text(
                  'Snooze Duration',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _snoozeDuration,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [5, 10, 15, 30].map((minutes) => 
                    DropdownMenuItem(
                      value: minutes,
                      child: Text('$minutes minutes'),
                    ),
                  ).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _snoozeDuration = value);
                    }
                  },
                ),
                
                SizedBox(height: 16),
                Text(
                  'Max Snooze Count',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _maxSnoozeCount,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [1, 2, 3, 5, 10].map((count) => 
                    DropdownMenuItem(
                      value: count,
                      child: Text('$count times'),
                    ),
                  ).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _maxSnoozeCount = value);
                    }
                  },
                ),
              ],
              
              SizedBox(height: 16),
              
              // Active switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.active),
                subtitle: Text(l10n.enableThisAlarm),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saveSettings,
          child: Text(l10n.save),
        ),
      ],
    );
  }
  
  Future<void> _selectTime() async {
    final l10n = AppLocalizations.of(context)!;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: l10n.selectAlarmTime,
    );
    
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }
  
  void _selectTone() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectAlarmTone),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AlarmTone.values.map((tone) => RadioListTile<AlarmTone>(
            title: Text(tone.localizedDisplayName(context)),
            value: tone,
            groupValue: _selectedTone,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedTone = value;
                });
                Navigator.of(context).pop();
              }
            },
          )).toList(),
        ),
      ),
    );
  }
  
  void _saveSettings() {
    final updatedSettings = widget.alarm.settings.copyWith(
      sound: _soundEnabled,
      soundPath: _selectedTone.soundPath,
      volume: _selectedVolume,
      vibration: _vibrationEnabled,
      snooze: _snoozeEnabled,
      snoozeDuration: _snoozeDuration,
      maxSnoozeCount: _maxSnoozeCount,
    );
    
    final updatedAlarm = widget.alarm.copyWith(
      time: _selectedTime,
      settings: updatedSettings,
      isActive: _isActive,
    );
    
    widget.onAlarmUpdated(updatedAlarm);
    Navigator.of(context).pop();
  }
}