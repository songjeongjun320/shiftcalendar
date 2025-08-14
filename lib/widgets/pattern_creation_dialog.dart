import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/shift_type.dart';

class PatternCreationDialog extends StatefulWidget {
  final Function(String name, List<ShiftType> cycle) onPatternCreated;
  
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
            '${l10n.currentCycleDays(_currentCycle.length)}',
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
    widget.onPatternCreated(name, cycle);
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
  
  void _createCustomPattern() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && _currentCycle.isNotEmpty) {
      widget.onPatternCreated(name, List.from(_currentCycle));
      Navigator.of(context).pop();
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