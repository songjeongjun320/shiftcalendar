import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

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

extension ShiftTypeLocalization on ShiftType {
  /// Get localized display name (e.g., "주간", "야간", "휴무")
  String localizedDisplayName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ShiftType.day:
        return l10n.day;
      case ShiftType.night:
        return l10n.night;
      case ShiftType.off:
        return l10n.off;
    }
  }
  
  /// Get localized short code (first character of localized name)
  String localizedShortCode(BuildContext context) {
    final localizedName = localizedDisplayName(context);
    return localizedName.isNotEmpty ? localizedName.substring(0, 1) : shortCode;
  }
  
  /// Get localized full shift name (e.g., "주간 근무", "야간 근무", "휴무")
  String localizedFullName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ShiftType.day:
        return l10n.dayShift;
      case ShiftType.night:
        return l10n.nightShift;
      case ShiftType.off:
        return l10n.offShift;
    }
  }
}