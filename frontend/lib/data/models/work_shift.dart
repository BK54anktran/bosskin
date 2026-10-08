import 'package:bosskin/l10n/app_localizations.dart';

bool _parseBool(dynamic v, {bool defaultVal = false}) {
  if (v == null) return defaultVal;
  if (v is bool) return v;
  if (v is int) return v != 0;
  return defaultVal;
}

class DeptRef {
  final int id;
  final String name;
  const DeptRef({required this.id, required this.name});
  factory DeptRef.fromJson(Map<String, dynamic> m) =>
      DeptRef(id: m['id'] as int, name: m['name'] as String);
}

class WorkShift {
  final int id;
  final String name;
  final String code;
  final String? startTime;
  final String? endTime;
  final String? breakStart;
  final String? breakEnd;
  final int? workMinutes;
  final String? groupName;
  final String color;
  final bool active;
  final List<DeptRef> departments;

  const WorkShift({
    required this.id,
    required this.name,
    required this.code,
    this.startTime,
    this.endTime,
    this.breakStart,
    this.breakEnd,
    this.workMinutes,
    this.groupName,
    required this.color,
    required this.active,
    required this.departments,
  });

  factory WorkShift.fromJson(Map<String, dynamic> m) => WorkShift(
        id: m['id'] as int,
        name: m['name'] as String,
        code: m['code'] as String,
        startTime: m['startTime'] as String?,
        endTime: m['endTime'] as String?,
        breakStart: m['breakStart'] as String?,
        breakEnd: m['breakEnd'] as String?,
        workMinutes: m['workMinutes'] as int?,
        groupName: m['groupName'] as String?,
        color: (m['color'] as String?) ?? '#1976D2',
        active: _parseBool(m['active'], defaultVal: true),
        departments: (m['departments'] as List?)
                ?.map((e) => DeptRef.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String get timeLabel {
    if (startTime != null && endTime != null) return '$startTime – $endTime';
    return '';
  }

  String workHoursLabel(AppLocalizations s) {
    if (workMinutes == null) return '';
    final h = workMinutes! ~/ 60;
    final m = workMinutes! % 60;
    return m == 0 ? '${h}h' : s.uiHoursMinutesShort('$h', '$m');
  }
}

class ShiftAssignment {
  final int id;
  final int employeeId;
  final String employeeName;
  final int? shiftId;
  final String? shiftName;
  final String? shiftCode;
  final String shiftColor;
  final String workDate;
  final String? note;
  final String? customStartTime;
  final String? customEndTime;
  final String? customBreakStart;
  final String? customBreakEnd;
  final bool isCustom;
  final bool hasAttendance;
  final bool approved;

  const ShiftAssignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.shiftId,
    this.shiftName,
    this.shiftCode,
    required this.shiftColor,
    required this.workDate,
    this.note,
    this.customStartTime,
    this.customEndTime,
    this.customBreakStart,
    this.customBreakEnd,
    this.isCustom = false,
    this.hasAttendance = false,
    this.approved = false,
  });

  factory ShiftAssignment.fromJson(Map<String, dynamic> m) => ShiftAssignment(
        id: m['id'] as int,
        employeeId: m['employeeId'] as int,
        employeeName: m['employeeName'] as String,
        shiftId: m['shiftId'] as int?,
        shiftName: m['shiftName'] as String?,
        shiftCode: m['shiftCode'] as String?,
        shiftColor: (m['shiftColor'] as String?) ?? '#607D8B',
        workDate: m['workDate'] as String,
        note: m['note'] as String?,
        customStartTime: m['customStartTime'] as String?,
        customEndTime: m['customEndTime'] as String?,
        customBreakStart: m['customBreakStart'] as String?,
        customBreakEnd: m['customBreakEnd'] as String?,
        isCustom: _parseBool(m['custom']),
        hasAttendance: _parseBool(m['hasAttendance']),
        approved: _parseBool(m['approved']),
      );
}
