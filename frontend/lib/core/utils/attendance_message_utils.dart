import 'package:bosskin/l10n/app_localizations.dart';

String attendanceMessage(AppLocalizations s, String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return s.noShiftsToday;

  switch (value) {
    case 'attendanceAccountNotLinked':
      return s.attendanceAccountNotLinked;
    case 'attendanceCheckInOutDisabled':
      return s.attendanceCheckInOutDisabled;
    case 'attendanceNoShiftsOnDate':
      return s.attendanceNoShiftsOnDate;
    case 'attendanceNoShiftsToday':
      return s.noShiftsToday;
    case 'attendanceNoShiftFreeCheckIn':
      return s.attendanceNoShiftFreeCheckIn;
    default:
      return value;
  }
}
