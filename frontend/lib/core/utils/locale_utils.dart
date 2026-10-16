import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../data/models/attendance.dart';
import '../../data/models/payroll.dart';

/// Mã ngôn ngữ đang dùng ("vi" / "en") — truyền cho DateFormat để ngày, thứ theo ngôn ngữ người dùng, không cố định tiếng Việt.
String localeCode(BuildContext context) => Localizations.localeOf(context).languageCode;

/// Thứ viết tắt theo ngôn ngữ (T2…CN / Mon…Sun); [weekday] theo DateTime.weekday (1 = thứ hai).
String weekdayShort(BuildContext context, int weekday) {
  final s = AppLocalizations.of(context);
  return [s.dowMon, s.dowTue, s.dowWed, s.dowThu, s.dowFri, s.dowSat, s.dowSun][weekday - 1];
}

/// Tháng viết tắt theo ngôn ngữ (T1…T12 / Jan…Dec).
String monthShort(BuildContext context, int month) =>
    localeCode(context) == 'vi' ? 'T$month' : DateFormat.MMM('en').format(DateTime(2000, month));

/// "Thứ Năm, 15/10/2026" / "Thursday, 15/10/2026".
String fullDayLabel(BuildContext context, DateTime date) =>
    DateFormat('EEEE, dd/MM/yyyy', localeCode(context)).format(date);

String attendanceStatusLabel(AppLocalizations s, AttendanceStatus st) => switch (st) {
      AttendanceStatus.present => s.present,
      AttendanceStatus.absent => s.absent,
      AttendanceStatus.late => s.late,
      AttendanceStatus.leave => s.leave,
      AttendanceStatus.halfDay => s.xlFilterHalfDay,
    };

String payrollStatusLabel(AppLocalizations s, PayrollStatus st) => switch (st) {
      PayrollStatus.draft => s.payrollStatusDraft,
      PayrollStatus.approved => s.approved,
      PayrollStatus.paid => s.payrollStatusPaid,
    };
