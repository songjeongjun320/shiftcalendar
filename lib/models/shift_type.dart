enum ShiftType {
  day('Day', 'D', 'Working day shift'),
  night('Night', 'N', 'Working night shift'),
  off('Off', 'O', 'Day off');
  
  const ShiftType(this.displayName, this.shortCode, this.description);
  
  final String displayName;
  final String shortCode;
  final String description;
  
  @override
  String toString() => displayName;
}