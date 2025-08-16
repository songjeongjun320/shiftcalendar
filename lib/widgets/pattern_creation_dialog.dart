import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/shift_type.dart';

class PatternCreationDialog extends StatefulWidget {
  final Function(String name, List<ShiftType> cycle, DateTime startDate) onPatternCreated;
  
  const PatternCreationDialog({
    super.key, 
    required this.onPatternCreated,
  });
  
  @override
  State<PatternCreationDialog> createState() => _PatternCreationDialogState();
}

class _PatternCreationDialogState extends State<PatternCreationDialog> {
  final _nameController = TextEditingController();
  final List<ShiftType> _currentCycle = [];
  DateTime _selectedStartDate = DateTime.now().add(Duration(days: 1)); // Default to tomorrow
  
  final List<Map<String, dynamic>> _presetPatterns = [
    {
      'name': 'Day-Day-Night-Night-Off-Off',
      'cycle': [ShiftType.day, ShiftType.day, ShiftType.night, ShiftType.night, ShiftType.off, ShiftType.off],
    },
    {
      'name': 'Day-Night-Off',
      'cycle': [ShiftType.day, ShiftType.night, ShiftType.off],
    },
    {
      'name': 'Day-Day-Off',
      'cycle': [ShiftType.day, ShiftType.day, ShiftType.off],
    },
    {
      'name': 'Night-Night-Off-Off',
      'cycle': [ShiftType.night, ShiftType.night, ShiftType.off, ShiftType.off],
    },
    {
      'name': 'Day-Off',
      'cycle': [ShiftType.day, ShiftType.off],
    },
  ];
  
  bool _showCustomBuilder = false;
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(l10n.createShiftPattern),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_showCustomBuilder) ...[
              Text(
                l10n.choosePresetPattern,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: 16),
              ..._presetPatterns.map((preset) => Card(
                child: ListTile(
                  title: Text(preset['name']),
                  subtitle: Wrap(
                    spacing: 4,
                    children: (preset['cycle'] as List<ShiftType>)
                        .map((shift) => Chip(
                              label: Text(shift.localizedShortCode(context)),
                              backgroundColor: _getShiftColor(shift),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                  onTap: () => _selectPresetPattern(preset['name'], preset['cycle']),
                ),
              )),
              SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(() => _showCustomBuilder = true),
                icon: Icon(Icons.build),
                label: Text(l10n.createCustomPattern),
              ),
            ] else ...[
              _buildCustomPatternBuilder(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        if (_showCustomBuilder)
          FilledButton(
            onPressed: _canCreateCustomPattern() ? _createCustomPattern : null,
            child: Text(l10n.create),
          ),
      ],
    );
  }
  
  Widget _buildCustomPatternBuilder() {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _showCustomBuilder = false),
              icon: Icon(Icons.arrow_back),
            ),
            Text(
              l10n.customPattern,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.patternName,
            hintText: l10n.patternNameHint,
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() {}), // Trigger UI update
        ),
        SizedBox(height: 16),
        
        // Start date selector
        _buildStartDateSelector(l10n),
        SizedBox(height: 16),
        
        Text(
          l10n.buildYourCycle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ShiftType.values.map((shiftType) => ActionChip(
            label: Text(shiftType.localizedDisplayName(context)),
            backgroundColor: _getShiftColor(shiftType),
            onPressed: () => _addShiftToCustomCycle(shiftType),
          )).toList(),
        ),
        SizedBox(height: 16),
        if (_currentCycle.isNotEmpty) ...[
          Text(
            l10n.currentCycleDays(_currentCycle.length),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 4,
              children: _currentCycle.asMap().entries.map((entry) {
                final index = entry.key;
                final shift = entry.value;
                return Chip(
                  label: Text('${index + 1}. ${shift.localizedShortCode(context)}'),
                  backgroundColor: _getShiftColor(shift),
                  deleteIcon: Icon(Icons.close, size: 16),
                  onDeleted: () => _removeShiftFromCustomCycle(index),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 8),
          TextButton.icon(
            onPressed: _currentCycle.isNotEmpty ? _clearCustomCycle : null,
            icon: Icon(Icons.clear_all),
            label: Text(l10n.clearAll),
          ),
        ],
      ],
    );
  }
  
  void _selectPresetPattern(String name, List<ShiftType> cycle) {
    _showStartDateSelectionDialog(name, cycle);
    Navigator.of(context).pop();
  }
  
  void _addShiftToCustomCycle(ShiftType shiftType) {
    if (_currentCycle.length < 14) { // Limit to 14 days max
      setState(() {
        _currentCycle.add(shiftType);
      });
    }
  }
  
  void _removeShiftFromCustomCycle(int index) {
    setState(() {
      _currentCycle.removeAt(index);
    });
  }
  
  void _clearCustomCycle() {
    setState(() {
      _currentCycle.clear();
    });
  }
  
  bool _canCreateCustomPattern() {
    return _nameController.text.trim().isNotEmpty && _currentCycle.isNotEmpty;
  }
  
  Widget _buildStartDateSelector(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.patternStartDate,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: _selectStartDate,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMd().format(_selectedStartDate),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        DateFormat.EEEE().format(_selectedStartDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        // Quick date selection buttons
        Wrap(
          spacing: 8,
          children: [
            _buildQuickDateChip(l10n.tomorrow, DateTime.now().add(Duration(days: 1))),
            _buildQuickDateChip(l10n.nextMonday, _getNextMonday()),
            _buildQuickDateChip(l10n.chooseDate, null),
          ],
        ),
      ],
    );
  }
  
  Widget _buildQuickDateChip(String label, DateTime? date) {
    final isSelected = date != null && 
        _selectedStartDate.year == date.year &&
        _selectedStartDate.month == date.month &&
        _selectedStartDate.day == date.day;
    
    return ActionChip(
      label: Text(label),
      onPressed: () {
        if (date != null) {
          setState(() {
            _selectedStartDate = date;
          });
        } else {
          _selectStartDate();
        }
      },
      backgroundColor: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
    );
  }
  
  DateTime _getNextMonday() {
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    final nextMonday = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
    return DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
  }
  
  Future<void> _selectStartDate() async {
    final l10n = AppLocalizations.of(context)!;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      helpText: l10n.selectStartDate,
    );
    
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked;
      });
    }
  }
  
  void _createCustomPattern() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && _currentCycle.isNotEmpty) {
      widget.onPatternCreated(name, List.from(_currentCycle), _selectedStartDate);
      Navigator.of(context).pop();
    }
  }
  
  void _showStartDateSelectionDialog(String name, List<ShiftType> cycle) {
    final l10n = AppLocalizations.of(context)!;
    DateTime selectedDate = DateTime.now().add(Duration(days: 1)); // Default to tomorrow
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.patternStartsOn),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.startDateHint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 16),
              
              // Date display
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                    helpText: l10n.selectStartDate,
                  );
                  
                  if (picked != null) {
                    setDialogState(() {
                      selectedDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.yMMMd().format(selectedDate),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              DateFormat.EEEE().format(selectedDate),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Quick selection buttons
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: Text(l10n.tomorrow),
                    onPressed: () {
                      setDialogState(() {
                        selectedDate = DateTime.now().add(Duration(days: 1));
                      });
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.nextMonday),
                    onPressed: () {
                      setDialogState(() {
                        selectedDate = _getNextMonday();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                widget.onPatternCreated(name, cycle, selectedDate);
                Navigator.of(context).pop(); // Close date selection dialog
                Navigator.of(context).pop(); // Close pattern creation dialog
              },
              child: Text(l10n.create),
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