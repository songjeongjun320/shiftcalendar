import 'shift_type.dart';

class ShiftPattern {
  final String id;
  final String name;
  final List<ShiftType> cycle;
  final DateTime startDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  const ShiftPattern({
    required this.id,
    required this.name,
    required this.cycle,
    required this.startDate,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });
  
  int get cycleDuration => cycle.length;
  
  /// Calculate what shift type applies on a given date
  ShiftType getShiftForDate(DateTime date) {
    final daysSinceStart = _daysBetween(startDate, date);
    final cyclePosition = daysSinceStart % cycleDuration;
    final adjustedPosition = cyclePosition >= 0 ? cyclePosition : cyclePosition + cycleDuration;
    return cycle[adjustedPosition];
  }
  
  /// Calculate days between two dates (ignoring time)
  int _daysBetween(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return endDate.difference(startDate).inDays;
  }
  
  /// Get the next occurrence of a specific shift type
  DateTime? getNextShiftDate(ShiftType targetShift, {DateTime? fromDate}) {
    final searchFrom = fromDate ?? DateTime.now();
    
    // Search for the next 60 days to find the target shift
    for (int i = 0; i < 60; i++) {
      final checkDate = DateTime(
        searchFrom.year,
        searchFrom.month,
        searchFrom.day + i,
      );
      
      if (getShiftForDate(checkDate) == targetShift) {
        return checkDate;
      }
    }
    
    return null; // Not found within 60 days
  }
  
  /// Get upcoming shifts of specific types within a date range
  List<DateTime> getUpcomingShifts(Set<ShiftType> targetShifts, int daysAhead) {
    final results = <DateTime>[];
    final today = DateTime.now();
    
    for (int i = 0; i < daysAhead; i++) {
      final checkDate = DateTime(
        today.year,
        today.month,
        today.day + i,
      );
      
      if (targetShifts.contains(getShiftForDate(checkDate))) {
        results.add(checkDate);
      }
    }
    
    return results;
  }
  
  ShiftPattern copyWith({
    String? id,
    String? name,
    List<ShiftType>? cycle,
    DateTime? startDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShiftPattern(
      id: id ?? this.id,
      name: name ?? this.name,
      cycle: cycle ?? this.cycle,
      startDate: startDate ?? this.startDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cycle': cycle.map((e) => e.name).toList(),
      'start_date': startDate.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }
  
  static ShiftPattern fromMap(Map<String, dynamic> map) {
    return ShiftPattern(
      id: map['id'],
      name: map['name'],
      cycle: (map['cycle'] as List)
          .map((name) => ShiftType.values.firstWhere((e) => e.name == name))
          .toList(),
      startDate: DateTime.fromMillisecondsSinceEpoch(map['start_date']),
      isActive: map['is_active'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
    );
  }
  
  @override
  String toString() {
    final cycleStr = cycle.map((e) => e.shortCode).join(' ');
    return '$name: [$cycleStr] (${isActive ? 'Active' : 'Inactive'})';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShiftPattern &&
        other.id == id &&
        other.name == name &&
        other.cycle.length == cycle.length &&
        _listsEqual(other.cycle, cycle) &&
        other.startDate == startDate &&
        other.isActive == isActive;
  }
  
  @override
  int get hashCode {
    return Object.hash(id, name, cycle, startDate, isActive);
  }
  
  bool _listsEqual(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}