# Shift Patterns Implementation Guide

## Overview

The ShiftCalendar app now supports **shift pattern-based alarms** that solve the core problem you described. Instead of fixed weekday alarms (Monday, Tuesday, etc.), the app creates **cyclical patterns** that automatically shift based on your work schedule.

## Problem Solved

### Your Original Problem:
- You wanted: **Monday-Tuesday alarms, Wednesday-Thursday alarms, Friday-Saturday alarms**
- This pattern should **repeat cyclically** (Sunday starts the cycle again)
- Current alarm apps only support fixed weekdays, not cyclical patterns

### Our Solution:
The app now creates **shift patterns** where alarms follow a cycle (e.g., Day-Day-Night-Night-Off-Off) instead of calendar weekdays.

## Key Features Implemented

### 1. **Shift Pattern System**
```text
// Example: Day-Day-Night-Night-Off-Off (6-day cycle)
ShiftPattern(
  cycle: [
    ShiftType.day,    // Position 0
    ShiftType.day,    // Position 1
    ShiftType.night,  // Position 2
    ShiftType.night,  // Position 3
    ShiftType.off,    // Position 4
    ShiftType.off,    // Position 5
  ],
  startDate: DateTime(2024, 1, 1), // When the pattern begins
)
```

### 2. **Automatic Shift Calculation**
The system calculates what shift applies on any given date:
```text
// If pattern started on Monday (Jan 1, 2024):
// Monday Jan 1: Day (position 0)
// Tuesday Jan 2: Day (position 1) 
// Wednesday Jan 3: Night (position 2)
// Thursday Jan 4: Night (position 3)
// Friday Jan 5: Off (position 4)
// Saturday Jan 6: Off (position 5)
// Sunday Jan 7: Day (position 0 - cycle repeats!)
```

### 3. **Smart Alarm Scheduling**
Alarms are scheduled based on shift types, not weekdays:
```text
ShiftAlarm(
  targetShiftTypes: {ShiftType.day, ShiftType.night}, // Only for work days
  time: TimeOfDay(hour: 6, minute: 0),
  title: 'Work Day Alarm',
  message: 'Time to get ready for your {shift} shift!',
)
```

### 4. **30-Day Rolling Schedule**
The system schedules notifications 30 days ahead and automatically reschedules as needed.

## Your Use Case Example

Based on your description, here's how your specific pattern would work:

### Pattern Setup:
```
Cycle: [Day, Day, Night, Night, Off, Off]
Start Date: Any Monday (e.g., January 1, 2024)
```

### Resulting Schedule:
- **Monday-Tuesday**: Day shifts (your Monday-Tuesday alarms)
- **Wednesday-Thursday**: Night shifts (your Wednesday-Thursday alarms)  
- **Friday-Saturday**: Off days (no alarms)
- **Sunday**: Cycle repeats - Day shift (like Monday)

### Alarms Configuration:
1. **Day Shift Alarm**: 6:00 AM for Day shifts
2. **Night Shift Alarm**: 6:00 PM for Night shifts
3. **Off Days**: No alarms

## Implementation Details

### Core Components

#### 1. **Data Models**
- `ShiftType`: Enum for Day, Night, Off
- `ShiftPattern`: Defines the cycle and calculates shifts for any date
- `ShiftAlarm`: Alarms that target specific shift types

#### 2. **Services**
- `ShiftSchedulingService`: Calculates when alarms should fire
- `ShiftNotificationService`: Integrates with Flutter's notification system
- `ShiftStorageService`: Persists patterns and alarms using SharedPreferences

#### 3. **Algorithm**
```text
ShiftType getShiftForDate(DateTime date) {
  final daysSinceStart = date.difference(startDate).inDays;
  final cyclePosition = daysSinceStart % cycleDuration;
  return cycle[cyclePosition >= 0 ? cyclePosition : cyclePosition + cycleDuration];
}
```

### Advanced Features

#### 1. **Multiple Patterns**
Support for multiple shift patterns simultaneously:
- Personal shift pattern
- Backup/coverage shifts
- Different departments

#### 2. **Flexible Alarm Targeting**
Alarms can target:
- Specific shift types: `{ShiftType.day}`
- Multiple shift types: `{ShiftType.day, ShiftType.night}`
- All shifts: `{ShiftType.day, ShiftType.night, ShiftType.off}`

#### 3. **Smart Message Templates**
Messages can include shift context:
```
"Time to get ready for your {shift} shift!" 
→ "Time to get ready for your Day shift!"
```

#### 4. **Persistent Across Restarts**
All patterns and alarms are saved locally and restored when the app starts.

## Usage Instructions

### 1. **Create a Pattern**
1. Open the app
2. Tap "Create Sample Pattern" (or create custom)
3. Define your cycle (e.g., Day-Day-Night-Night-Off-Off)
4. Set start date
5. Save pattern

### 2. **Set Up Alarms** 
1. Navigate to Alarms section
2. Create alarm with:
   - Time (e.g., 6:00 AM)
   - Target shifts (e.g., Day shifts only)
   - Custom message
3. Enable/disable as needed

### 3. **View Schedule**
The dashboard shows:
- Current shift status
- Upcoming shifts preview
- Active alarms
- Scheduled notification count

## Example Scenarios

### Scenario 1: Your Original Request
```
Pattern: Day-Day-Night-Night-Off-Off
Alarms:
- 6:00 AM for Day shifts (Mon-Tue in week 1, Sun-Mon in week 2)
- 6:00 PM for Night shifts (Wed-Thu in week 1, Tue-Wed in week 2)
- No alarms for Off days
```

### Scenario 2: Nurse Schedule
```
Pattern: Day-Day-Day-Off-Night-Night-Night-Off
Alarms:
- 5:30 AM for Day shifts
- 5:30 PM for Night shifts
- Off days: no alarms
```

### Scenario 3: Manufacturing
```
Pattern: Day-Day-Day-Day-Off-Off-Off
Alarms:
- 6:00 AM for Day shifts (4 days on, 3 days off)
```

## Technical Benefits

### 1. **Accurate Scheduling**
- Uses timezone-aware calculations
- Handles daylight saving time changes
- Works across year boundaries and leap years

### 2. **Efficient Notification Management**
- Schedules notifications 30 days ahead
- Automatically cancels/reschedules when patterns change
- Prevents notification conflicts

### 3. **Extensible Architecture**
- Easy to add new shift types
- Support for complex patterns
- Modular design for future features

## Testing

The implementation includes comprehensive tests covering:
- Basic shift calculations
- Edge cases (leap years, year boundaries)
- Different cycle lengths
- Date handling before/after start dates

## Future Enhancements

1. **Pattern Editor UI**: Visual drag-and-drop pattern creation
2. **Calendar View**: Month/week view showing shift schedule
3. **Exception Handling**: Vacation days, shift swaps
4. **Pattern Templates**: Common shift patterns (2-2-3, 4-4-4-4, etc.)
5. **Backup/Sync**: Cloud storage for pattern backup

## Conclusion

The shift pattern system successfully solves your original problem by:
1. ✅ Supporting cyclical patterns instead of fixed weekdays
2. ✅ Automatically calculating when alarms should fire based on shift cycles
3. ✅ Handling complex patterns like Day-Day-Night-Night-Off-Off
4. ✅ Providing a clean, maintainable architecture for future enhancements
5. ✅ Working reliably across different time zones and date boundaries

The app is now ready for testing with real shift schedules!