import 'package:flutter_test/flutter_test.dart';
import 'package:shiftcalendar/models/shift_pattern.dart';
import 'package:shiftcalendar/models/shift_type.dart';
import 'package:shiftcalendar/services/shift_scheduling_service.dart';

void main() {
  group('ShiftPattern', () {
    test('should calculate correct shift for date', () {
      // Create a Day-Day-Night-Night-Off-Off pattern starting on Monday
      final pattern = ShiftPattern(
        id: 'test-pattern',
        name: 'Test Pattern',
        cycle: [
          ShiftType.day,    // Monday (Day 0)
          ShiftType.day,    // Tuesday (Day 1)
          ShiftType.night,  // Wednesday (Day 2)
          ShiftType.night,  // Thursday (Day 3)
          ShiftType.off,    // Friday (Day 4)
          ShiftType.off,    // Saturday (Day 5)
        ],
        startDate: DateTime(2024, 1, 1), // Monday
        createdAt: DateTime.now(),
      );

      // Test first cycle
      expect(pattern.getShiftForDate(DateTime(2024, 1, 1)), ShiftType.day);    // Monday - Day
      expect(pattern.getShiftForDate(DateTime(2024, 1, 2)), ShiftType.day);    // Tuesday - Day
      expect(pattern.getShiftForDate(DateTime(2024, 1, 3)), ShiftType.night);  // Wednesday - Night
      expect(pattern.getShiftForDate(DateTime(2024, 1, 4)), ShiftType.night);  // Thursday - Night
      expect(pattern.getShiftForDate(DateTime(2024, 1, 5)), ShiftType.off);    // Friday - Off
      expect(pattern.getShiftForDate(DateTime(2024, 1, 6)), ShiftType.off);    // Saturday - Off

      // Test second cycle starts on Sunday (Day 6)
      expect(pattern.getShiftForDate(DateTime(2024, 1, 7)), ShiftType.day);    // Sunday - Day (cycle repeats)
      expect(pattern.getShiftForDate(DateTime(2024, 1, 8)), ShiftType.day);    // Monday - Day
      expect(pattern.getShiftForDate(DateTime(2024, 1, 9)), ShiftType.night);  // Tuesday - Night
    });

    test('should handle date before start date', () {
      final pattern = ShiftPattern(
        id: 'test-pattern',
        name: 'Test Pattern',
        cycle: [ShiftType.day, ShiftType.night, ShiftType.off],
        startDate: DateTime(2024, 1, 5), // Friday
        createdAt: DateTime.now(),
      );

      // Date before start date should still work (negative modulo handling)
      expect(pattern.getShiftForDate(DateTime(2024, 1, 4)), ShiftType.off);   // Thursday (day before start)
      expect(pattern.getShiftForDate(DateTime(2024, 1, 3)), ShiftType.night); // Wednesday (2 days before)
      expect(pattern.getShiftForDate(DateTime(2024, 1, 2)), ShiftType.day);   // Tuesday (3 days before)
    });

    test('should find next shift date correctly', () {
      final pattern = ShiftPattern(
        id: 'test-pattern',
        name: 'Test Pattern',
        cycle: [ShiftType.day, ShiftType.night, ShiftType.off],
        startDate: DateTime(2024, 1, 1),
        createdAt: DateTime.now(),
      );

      // Next day shift from start
      final nextDay = pattern.getNextShiftDate(ShiftType.day, fromDate: DateTime(2024, 1, 1));
      expect(nextDay, DateTime(2024, 1, 1)); // Same day if it matches

      // Next night shift from day 1
      final nextNight = pattern.getNextShiftDate(ShiftType.night, fromDate: DateTime(2024, 1, 1));
      expect(nextNight, DateTime(2024, 1, 2)); // Next day

      // Next off day
      final nextOff = pattern.getNextShiftDate(ShiftType.off, fromDate: DateTime(2024, 1, 1));
      expect(nextOff, DateTime(2024, 1, 3)); // Two days later
    });

    test('should get upcoming shifts correctly', () {
      final pattern = ShiftPattern(
        id: 'test-pattern',
        name: 'Test Pattern',
        cycle: [ShiftType.day, ShiftType.night, ShiftType.off],
        startDate: DateTime(2024, 1, 1),
        createdAt: DateTime.now(),
      );

      final upcomingDays = pattern.getUpcomingShifts({ShiftType.day}, 6);
      expect(upcomingDays.length, 2); // Days 1 and 4 (every 3 days)
      expect(upcomingDays[0], DateTime(2024, 1, 1));
      expect(upcomingDays[1], DateTime(2024, 1, 4));

      final upcomingWorkDays = pattern.getUpcomingShifts({ShiftType.day, ShiftType.night}, 6);
      expect(upcomingWorkDays.length, 4); // Days 1, 2, 4, 5
    });
  });

  group('ShiftSchedulingService', () {
    late ShiftSchedulingService service;

    setUp(() {
      service = ShiftSchedulingService();
    });

    test('should get current shift correctly', () {
      final pattern = ShiftPattern(
        id: 'test-pattern',
        name: 'Test Pattern',
        cycle: [ShiftType.day, ShiftType.night, ShiftType.off],
        startDate: DateTime.now().subtract(Duration(days: 1)), // Started yesterday
        createdAt: DateTime.now(),
      );

      final currentShift = service.getCurrentShift(pattern);
      expect(currentShift, isA<ShiftType>());
    });

    test('should generate upcoming shifts preview', () {
      final pattern = ShiftPattern(
        id: 'test-pattern',
        name: 'Test Pattern',
        cycle: [ShiftType.day, ShiftType.night, ShiftType.off],
        startDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final preview = service.getUpcomingShifts(pattern, daysAhead: 7);
      expect(preview.length, 7);
      expect(preview[0].isToday, true);
      
      // Check that preview has correct structure
      for (final day in preview) {
        expect(day.date, isA<DateTime>());
        expect(day.shiftType, isA<ShiftType>());
        expect(day.weekdayName, isA<String>());
        expect(day.dateDisplay, isA<String>());
      }
    });
  });

  group('Edge Cases', () {
    test('should handle leap year correctly', () {
      final pattern = ShiftPattern(
        id: 'test-pattern',
        name: 'Test Pattern',
        cycle: [ShiftType.day, ShiftType.off],
        startDate: DateTime(2024, 2, 28), // Day before leap day
        createdAt: DateTime.now(),
      );

      expect(pattern.getShiftForDate(DateTime(2024, 2, 28)), ShiftType.day);
      expect(pattern.getShiftForDate(DateTime(2024, 2, 29)), ShiftType.off); // Leap day
      expect(pattern.getShiftForDate(DateTime(2024, 3, 1)), ShiftType.day);  // Day after leap day
    });

    test('should handle year boundaries correctly', () {
      final pattern = ShiftPattern(
        id: 'test-pattern',
        name: 'Test Pattern',
        cycle: [ShiftType.day, ShiftType.night],
        startDate: DateTime(2023, 12, 31), // New Year's Eve
        createdAt: DateTime.now(),
      );

      expect(pattern.getShiftForDate(DateTime(2023, 12, 31)), ShiftType.day);
      expect(pattern.getShiftForDate(DateTime(2024, 1, 1)), ShiftType.night);  // New Year's Day
      expect(pattern.getShiftForDate(DateTime(2024, 1, 2)), ShiftType.day);    // Day after
    });

    test('should handle single day cycle', () {
      final pattern = ShiftPattern(
        id: 'test-pattern',
        name: 'Test Pattern',
        cycle: [ShiftType.day], // Every day is a day shift
        startDate: DateTime(2024, 1, 1),
        createdAt: DateTime.now(),
      );

      // Should always be day shift
      for (int i = 0; i < 10; i++) {
        expect(pattern.getShiftForDate(DateTime(2024, 1, 1 + i)), ShiftType.day);
      }
    });

    test('should handle very long cycle', () {
      final pattern = ShiftPattern(
        id: 'test-pattern',
        name: 'Test Pattern',
        cycle: List.generate(28, (index) => 
            index % 3 == 0 ? ShiftType.day :
            index % 3 == 1 ? ShiftType.night : ShiftType.off), // 28-day cycle
        startDate: DateTime(2024, 1, 1),
        createdAt: DateTime.now(),
      );

      // Test that it cycles correctly after 28 days
      final startShift = pattern.getShiftForDate(DateTime(2024, 1, 1));
      final cycleShift = pattern.getShiftForDate(DateTime(2024, 1, 29)); // 28 days later
      expect(startShift, cycleShift);
    });
  });
}