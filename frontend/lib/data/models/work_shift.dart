enum ShiftType { work, halfAm, halfPm, dayOff, holiday }

extension ShiftTypeX on ShiftType {
  String get label => switch (this) {
        ShiftType.work    => 'Ca làm việc',
        ShiftType.halfAm  => 'Nửa ngày sáng',
        ShiftType.halfPm  => 'Nửa ngày chiều',
        ShiftType.dayOff  => 'Ngày nghỉ',
        ShiftType.holiday => 'Ngày lễ',
      };

  String get apiName => switch (this) {
        ShiftType.work    => 'WORK',
        ShiftType.halfAm  => 'HALF_AM',
        ShiftType.halfPm  => 'HALF_PM',
        ShiftType.dayOff  => 'DAY_OFF',
        ShiftType.holiday => 'HOLIDAY',
      };

  bool get isWorkType =>
      this == ShiftType.work || this == ShiftType.halfAm || this == ShiftType.halfPm;

  static ShiftType fromApi(String? s) => switch (s) {
        'HALF_AM'  => ShiftType.halfAm,
        'HALF_PM'  => ShiftType.halfPm,
        'DAY_OFF'  => ShiftType.dayOff,
        'HOLIDAY'  => ShiftType.holiday,
        _          => ShiftType.work,
      };
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
  final ShiftType type;
  final String? startTime;
  final String? endTime;
  final String? breakStart;
  final String? breakEnd;
  final int? workMinutes;
  final String color;
  final bool active;
  final List<DeptRef> departments;

  const WorkShift({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.startTime,
    this.endTime,
    this.breakStart,
    this.breakEnd,
    this.workMinutes,
    required this.color,
    required this.active,
    required this.departments,
  });

  factory WorkShift.fromJson(Map<String, dynamic> m) => WorkShift(
        id: m['id'] as int,
        name: m['name'] as String,
        code: m['code'] as String,
        type: ShiftTypeX.fromApi(m['type'] as String?),
        startTime: m['startTime'] as String?,
        endTime: m['endTime'] as String?,
        breakStart: m['breakStart'] as String?,
        breakEnd: m['breakEnd'] as String?,
        workMinutes: m['workMinutes'] as int?,
        color: (m['color'] as String?) ?? '#1976D2',
        active: m['active'] as bool? ?? true,
        departments: (m['departments'] as List?)
                ?.map((e) => DeptRef.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String get timeLabel {
    if (!type.isWorkType) return type.label;
    if (startTime != null && endTime != null) return '$startTime – $endTime';
    return type.label;
  }

  String get workHoursLabel {
    if (workMinutes == null) return '';
    final h = workMinutes! ~/ 60;
    final m = workMinutes! % 60;
    return m == 0 ? '${h}h' : '${h}h${m}p';
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
  final ShiftType? shiftType;
  final String workDate;
  final String? note;
  final String? customStartTime;
  final String? customEndTime;
  final String? customBreakStart;
  final String? customBreakEnd;
  final bool isCustom;

  const ShiftAssignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.shiftId,
    this.shiftName,
    this.shiftCode,
    required this.shiftColor,
    this.shiftType,
    required this.workDate,
    this.note,
    this.customStartTime,
    this.customEndTime,
    this.customBreakStart,
    this.customBreakEnd,
    this.isCustom = false,
  });

  factory ShiftAssignment.fromJson(Map<String, dynamic> m) => ShiftAssignment(
        id: m['id'] as int,
        employeeId: m['employeeId'] as int,
        employeeName: m['employeeName'] as String,
        shiftId: m['shiftId'] as int?,
        shiftName: m['shiftName'] as String?,
        shiftCode: m['shiftCode'] as String?,
        shiftColor: (m['shiftColor'] as String?) ?? '#607D8B',
        shiftType: m['shiftType'] != null
            ? ShiftTypeX.fromApi(m['shiftType'] as String)
            : null,
        workDate: m['workDate'] as String,
        note: m['note'] as String?,
        customStartTime: m['customStartTime'] as String?,
        customEndTime: m['customEndTime'] as String?,
        customBreakStart: m['customBreakStart'] as String?,
        customBreakEnd: m['customBreakEnd'] as String?,
        isCustom: m['custom'] as bool? ?? false,
      );
}
