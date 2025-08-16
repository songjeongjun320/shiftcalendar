import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../l10n/app_localizations.dart';
import '../models/basic_alarm.dart';
import '../models/shift_alarm.dart';

class BasicAlarmDialog extends StatefulWidget {
  final BasicAlarm? alarm; // null for new alarm, existing alarm for edit
  final Function(BasicAlarm) onAlarmCreated;
  
  const BasicAlarmDialog({
    super.key,
    this.alarm,
    required this.onAlarmCreated,
  });
  
  @override
  State<BasicAlarmDialog> createState() => _BasicAlarmDialogState();
}

class _BasicAlarmDialogState extends State<BasicAlarmDialog> {
  final _labelController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Set<int> _selectedDays = <int>{};
  AlarmTone _selectedTone = AlarmTone.wakeupcall;
  double _selectedVolume = 0.8;
  bool _isActive = true;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<String> _getWeekdays(AppLocalizations l10n) {
    return [
      l10n.monday, l10n.tuesday, l10n.wednesday, l10n.thursday, 
      l10n.friday, l10n.saturday, l10n.sunday
    ];
  }
  
  @override
  void initState() {
    super.initState();
    
    if (widget.alarm != null) {
      // Editing existing alarm
      final alarm = widget.alarm!;
      _labelController.text = alarm.label;
      _selectedTime = alarm.time;
      _selectedDays = Set.from(alarm.repeatDays);
      _selectedTone = alarm.tone;
      _selectedVolume = alarm.volume;
      _isActive = alarm.isActive;
    } else {
      // Creating new alarm
      _labelController.text = 'Alarm'; // Will be localized in build method
    }
  }
  
  @override
  void dispose() {
    _labelController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekdays = _getWeekdays(l10n);
    
    // Set default label if creating new alarm
    if (widget.alarm == null && _labelController.text == 'Alarm') {
      _labelController.text = l10n.newAlarm;
    }
    
    return AlertDialog(
      title: Text(widget.alarm == null ? l10n.newAlarm : l10n.editAlarm),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label field
              TextField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: l10n.label,
                  hintText: 'Wake up', // Generic hint, could be localized if needed
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              
              // Time picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule),
                title: Text(l10n.time),
                subtitle: Text(_selectedTime.format(context)),
                onTap: _selectTime,
              ),
              
              // Repeat days
              SizedBox(height: 16),
              Text(
                l10n.repeat,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: 8),
              
              // Quick repeat options
              Row(
                children: [
                  _buildQuickRepeatChip(l10n.once, {}),
                  SizedBox(width: 8),
                  _buildQuickRepeatChip(l10n.daily, {1, 2, 3, 4, 5, 6, 7}),
                  SizedBox(width: 8),
                  _buildQuickRepeatChip(l10n.weekdays, {1, 2, 3, 4, 5}),
                ],
              ),
              SizedBox(height: 8),
              
              // Individual day selection
              Wrap(
                spacing: 8,
                children: List.generate(7, (index) {
                  final dayNumber = index + 1;
                  final isSelected = _selectedDays.contains(dayNumber);
                  
                  return FilterChip(
                    label: Text(weekdays[index].substring(0, 3)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(dayNumber);
                        } else {
                          _selectedDays.remove(dayNumber);
                        }
                      });
                    },
                  );
                }),
              ),
              
              SizedBox(height: 16),
              
              // Alarm tone
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.music_note),
                title: Text(l10n.alarmTone),
                subtitle: Text(_selectedTone.localizedDisplayName(context)),
                onTap: _selectTone,
              ),
              
              SizedBox(height: 16),
              
              // Volume control
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
                      onChangeEnd: (value) {
                        _playPreviewSound();
                      },
                    ),
                  ),
                  Icon(Icons.volume_up, size: 20),
                ],
              ),
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
          onPressed: _canSave() ? _saveAlarm : null,
          child: Text(widget.alarm == null ? l10n.create : l10n.save),
        ),
      ],
    );
  }
  
  Widget _buildQuickRepeatChip(String label, Set<int> days) {
    final isSelected = _selectedDays.length == days.length && 
                      _selectedDays.every((day) => days.contains(day));
    
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setState(() {
          _selectedDays = Set.from(days);
        });
      },
      backgroundColor: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
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
  
  void _playPreviewSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(_selectedVolume);
      final soundPath = 'sounds/${_selectedTone.soundPath}.mp3';
      print('Playing preview sound: $soundPath at volume $_selectedVolume');
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      print('Error playing preview sound: $e');
      // Show user feedback for audio issues
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('소리 재생 중 오류가 발생했습니다: ${e.toString()}'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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
                _playPreviewSound();
                Navigator.of(context).pop();
              }
            },
          )).toList(),
        ),
      ),
    );
  }
  
  bool _canSave() {
    return _labelController.text.trim().isNotEmpty;
  }
  
  void _saveAlarm() {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;
    
    final alarm = BasicAlarm(
      id: widget.alarm?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      time: _selectedTime,
      repeatDays: Set.from(_selectedDays),
      isActive: _isActive,
      tone: _selectedTone,
      volume: _selectedVolume,
      createdAt: widget.alarm?.createdAt ?? DateTime.now(),
    );
    
    widget.onAlarmCreated(alarm);
    Navigator.of(context).pop();
  }
}