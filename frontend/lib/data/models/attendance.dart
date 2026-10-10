enum AttendanceStatus { present, absent, late, halfDay, leave }

AttendanceStatus _parseStatus(String? s) => switch (s?.toUpperCase()) {
      'ABSENT' => AttendanceStatus.absent,
      'LATE' => AttendanceStatus.late,
      'HALF_DAY' => AttendanceStatus.halfDay,
      'LEAVE' => AttendanceStatus.leave,
      _ => AttendanceStatus.present,
    };

class Attendance {
  final int id;
  final int employeeId;
  final String employeeCode;
  final String employeeFullName;
  final int departmentId;
  final String departmentName;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final DateTime? checkIn2;
  final DateTime? checkOut2;
  final AttendanceStatus status;
  final double? workingHours;
  final double? overtimeHours;
  final String? note;

  const Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeFullName,
    required this.departmentId,
    required this.departmentName,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.checkIn2,
    this.checkOut2,
    required this.status,
    this.workingHours,
    this.overtimeHours,
    this.note,
  });

  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
        id: j['id'],
        employeeId: j['employeeId'],
        employeeCode: j['employeeCode'] ?? '',
        employeeFullName: j['employeeFullName'] ?? '',
        departmentId: j['departmentId'] ?? 0,
        departmentName: j['departmentName'] ?? '',
        date: DateTime.parse(j['date']),
        checkIn: j['checkIn'] != null ? DateTime.tryParse(j['checkIn']) : null,
        checkOut:
            j['checkOut'] != null ? DateTime.tryParse(j['checkOut']) : null,
        checkIn2:
            j['checkIn2'] != null ? DateTime.tryParse(j['checkIn2']) : null,
        checkOut2:
            j['checkOut2'] != null ? DateTime.tryParse(j['checkOut2']) : null,
        status: _parseStatus(j['status']),
        workingHours: (j['workingHours'] as num?)?.toDouble(),
        overtimeHours: (j['overtimeHours'] as num?)?.toDouble(),
        note: j['note'],
      );
}

class TimesheetRow {
  final DateTime date;
  final String dayLabel;
  final bool weekend;
  /// Tên ngày lễ (bước J) — null nếu không phải ngày lễ.
  final String? holidayName;

  final String? shiftName;
  final String? shiftColor;
  final String? shiftStart; // "HH:mm"
  final String? shiftEnd;
  final int breakMinutes;

  final String? checkIn;
  final String? checkOut;
  final String? checkInRaw;
  final String? checkOutRaw;
  final bool checkInRounded;
  final bool checkOutRounded;
  final AttendanceStatus? status;
  final int? shiftAssignmentId;

  final String? requestedCheckIn;
  final String? requestedCheckInStatus;
  final String? requestedCheckOut;
  final String? requestedCheckOutStatus;
  final int? requestedOvertimeMinutes;
  final String? requestedOvertimeStatus;
  final List<AttendanceChangeRequest> requests;

  final double actualHours;
  final double totalHours;
  final double regularDayHours;
  final double otDayHours;
  final double regularNightHours;
  final double otNightHours;

  final int? leaveRequestId;
  final String? leaveCode;
  final String? leaveMode;
  final String? leaveStatus;
  final bool? leaveApplied;
  final String? leaveProcessedByName;
  final String? leaveProcessedAt;
  final String? leaveCreatedAt;
  final double? leaveAmount;
  final String? leaveFromTime;
  final String? leaveToTime;

  final int? attendanceId;
  final bool approved;
  final DateTime? approvedAt;
  final String? approvedByName;
  final List<String> workFlags;

  // Admin override
  final String? overrideCheckIn;
  final String? overrideCheckOut;
  final int? overrideBreakMinutes;
  final int? overrideOtDayMinutes;
  final int? overrideOtNightMinutes;
  final String? overrideNote;

  bool get hasOverride =>
      overrideCheckIn != null || overrideCheckOut != null ||
      overrideOtDayMinutes != null || overrideOtNightMinutes != null;

  const TimesheetRow({
    required this.date,
    required this.dayLabel,
    required this.weekend,
    this.holidayName,
    this.shiftName,
    this.shiftColor,
    this.shiftStart,
    this.shiftEnd,
    required this.breakMinutes,
    this.checkIn,
    this.checkOut,
    this.checkInRaw,
    this.checkOutRaw,
    this.checkInRounded = false,
    this.checkOutRounded = false,
    this.status,
    this.shiftAssignmentId,
    this.requestedCheckIn,
    this.requestedCheckInStatus,
    this.requestedCheckOut,
    this.requestedCheckOutStatus,
    this.requestedOvertimeMinutes,
    this.requestedOvertimeStatus,
    this.requests = const [],
    required this.actualHours,
    required this.totalHours,
    required this.regularDayHours,
    required this.otDayHours,
    required this.regularNightHours,
    required this.otNightHours,
    this.leaveRequestId,
    this.leaveCode,
    this.leaveMode,
    this.leaveStatus,
    this.leaveApplied,
    this.leaveProcessedByName,
    this.leaveProcessedAt,
    this.leaveCreatedAt,
    this.leaveAmount,
    this.leaveFromTime,
    this.leaveToTime,
    this.attendanceId,
    this.approved = false,
    this.approvedAt,
    this.approvedByName,
    this.workFlags = const [],
    this.overrideCheckIn,
    this.overrideCheckOut,
    this.overrideBreakMinutes,
    this.overrideOtDayMinutes,
    this.overrideOtNightMinutes,
    this.overrideNote,
  });

  factory TimesheetRow.fromJson(Map<String, dynamic> j) => TimesheetRow(
        date: DateTime.parse(j['date']),
        dayLabel: j['dayLabel'] ?? '',
        weekend: j['weekend'] ?? false,
        holidayName: j['holidayName'] as String?,
        shiftName: j['shiftName'],
        shiftColor: j['shiftColor'],
        shiftStart: j['shiftStart'],
        shiftEnd: j['shiftEnd'],
        breakMinutes: j['breakMinutes'] ?? 0,
        checkIn: j['checkIn'],
        checkOut: j['checkOut'],
        checkInRaw: j['checkInRaw'] as String?,
        checkOutRaw: j['checkOutRaw'] as String?,
        checkInRounded: j['checkInRounded'] as bool? ?? false,
        checkOutRounded: j['checkOutRounded'] as bool? ?? false,
        status: j['status'] != null ? _parseStatus(j['status']) : null,
        shiftAssignmentId: (j['shiftAssignmentId'] as num?)?.toInt(),
        requestedCheckIn: j['requestedCheckIn'],
        requestedCheckInStatus: j['requestedCheckInStatus'],
        requestedCheckOut: j['requestedCheckOut'],
        requestedCheckOutStatus: j['requestedCheckOutStatus'],
        requestedOvertimeMinutes:
            (j['requestedOvertimeMinutes'] as num?)?.toInt(),
        requestedOvertimeStatus: j['requestedOvertimeStatus'],
        requests: (j['requests'] as List<dynamic>?)
                ?.map((e) =>
                    AttendanceChangeRequest.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        actualHours: (j['actualHours'] as num?)?.toDouble() ?? 0,
        totalHours: (j['totalHours'] as num?)?.toDouble() ?? 0,
        regularDayHours: (j['regularDayHours'] as num?)?.toDouble() ?? 0,
        otDayHours: (j['otDayHours'] as num?)?.toDouble() ?? 0,
        regularNightHours: (j['regularNightHours'] as num?)?.toDouble() ?? 0,
        otNightHours: (j['otNightHours'] as num?)?.toDouble() ?? 0,
        leaveRequestId: (j['leaveRequestId'] as num?)?.toInt(),
        leaveCode: j['leaveCode'] as String?,
        leaveMode: j['leaveMode'] as String?,
        leaveStatus: j['leaveStatus'] as String?,
        leaveApplied: j['leaveApplied'] as bool?,
        leaveProcessedByName: j['leaveProcessedByName'] as String?,
        leaveProcessedAt: j['leaveProcessedAt'] as String?,
        leaveCreatedAt: j['leaveCreatedAt'] as String?,
        leaveAmount: (j['leaveAmount'] as num?)?.toDouble(),
        leaveFromTime: j['leaveFromTime'] as String?,
        leaveToTime: j['leaveToTime'] as String?,
        attendanceId: (j['attendanceId'] as num?)?.toInt(),
        approved: j['approved'] as bool? ?? false,
        approvedAt: j['approvedAt'] != null ? DateTime.tryParse(j['approvedAt'] as String) : null,
        approvedByName: j['approvedByName'] as String?,
        workFlags: (j['workFlags'] as String?)?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? const [],
        overrideCheckIn: j['overrideCheckIn'] as String?,
        overrideCheckOut: j['overrideCheckOut'] as String?,
        overrideBreakMinutes: (j['overrideBreakMinutes'] as num?)?.toInt(),
        overrideOtDayMinutes: (j['overrideOtDayMinutes'] as num?)?.toInt(),
        overrideOtNightMinutes: (j['overrideOtNightMinutes'] as num?)?.toInt(),
        overrideNote: j['overrideNote'] as String?,
      );
}

class DayViewRow {
  final int employeeId;
  final String employeeCode;
  final String employeeFullName;
  final int departmentId;
  final String departmentName;
  final DateTime date;
  final String dayLabel;
  final bool weekend;
  /// Tên ngày lễ (bước J) — null nếu không phải ngày lễ.
  final String? holidayName;

  final String? shiftName;
  final String? shiftColor;
  final String? shiftStart;
  final String? shiftEnd;
  final int breakMinutes;

  final String? checkIn;
  final String? checkOut;
  final String? checkInRaw;
  final String? checkOutRaw;
  final bool checkInRounded;
  final bool checkOutRounded;
  final AttendanceStatus? status;
  final int? shiftAssignmentId;

  final String? requestedCheckIn;
  final String? requestedCheckInStatus;
  final String? requestedCheckOut;
  final String? requestedCheckOutStatus;
  final int? requestedOvertimeMinutes;
  final String? requestedOvertimeScope;
  final String? requestedOvertimePeriod;
  final String? requestedOvertimeStatus;
  final List<AttendanceChangeRequest> requests;

  final int? attendanceId;

  final double actualHours;
  final double totalHours;
  final double regularDayHours;
  final double otDayHours;
  final double regularNightHours;
  final double otNightHours;

  final int? leaveRequestId;
  final String? leaveCode;
  final String? leaveMode;
  final String? leaveStatus;
  final bool? leaveApplied;
  final String? leaveProcessedByName;
  final String? leaveProcessedAt;
  final String? leaveCreatedAt;
  final double? leaveAmount;
  final String? leaveFromTime;
  final String? leaveToTime;

  final bool approved;
  final String? approvedAt;
  final String? approvedByName;
  final List<DayViewLeaveInfo> leaves;
  final List<String> workFlags;

  // Admin override
  final String? overrideCheckIn;
  final String? overrideCheckOut;
  final int? overrideBreakMinutes;
  final int? overrideOtDayMinutes;
  final int? overrideOtNightMinutes;
  final String? overrideNote;

  bool get hasOverride =>
      overrideCheckIn != null || overrideCheckOut != null ||
      overrideOtDayMinutes != null || overrideOtNightMinutes != null;

  const DayViewRow({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeFullName,
    required this.departmentId,
    required this.departmentName,
    required this.date,
    required this.dayLabel,
    required this.weekend,
    this.holidayName,
    this.shiftName,
    this.shiftColor,
    this.shiftStart,
    this.shiftEnd,
    required this.breakMinutes,
    this.checkIn,
    this.checkOut,
    this.checkInRaw,
    this.checkOutRaw,
    this.checkInRounded = false,
    this.checkOutRounded = false,
    this.status,
    this.shiftAssignmentId,
    this.requestedCheckIn,
    this.requestedCheckInStatus,
    this.requestedCheckOut,
    this.requestedCheckOutStatus,
    this.requestedOvertimeMinutes,
    this.requestedOvertimeScope,
    this.requestedOvertimePeriod,
    this.requestedOvertimeStatus,
    this.attendanceId,
    this.requests = const [],
    required this.actualHours,
    required this.totalHours,
    required this.regularDayHours,
    required this.otDayHours,
    required this.regularNightHours,
    required this.otNightHours,
    this.leaveRequestId,
    this.leaveCode,
    this.leaveMode,
    this.leaveStatus,
    this.leaveApplied,
    this.leaveProcessedByName,
    this.leaveProcessedAt,
    this.leaveCreatedAt,
    this.leaveAmount,
    this.leaveFromTime,
    this.leaveToTime,
    this.approved = false,
    this.approvedAt,
    this.approvedByName,
    this.leaves = const [],
    this.workFlags = const [],
    this.overrideCheckIn,
    this.overrideCheckOut,
    this.overrideBreakMinutes,
    this.overrideOtDayMinutes,
    this.overrideOtNightMinutes,
    this.overrideNote,
  });

  factory DayViewRow.fromJson(Map<String, dynamic> j) => DayViewRow(
        employeeId: j['employeeId'] as int,
        employeeCode: j['employeeCode'] as String? ?? '',
        employeeFullName: j['employeeFullName'] as String? ?? '',
        departmentId: j['departmentId'] as int? ?? 0,
        departmentName: j['departmentName'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        dayLabel: j['dayLabel'] as String? ?? '',
        weekend: j['weekend'] as bool? ?? false,
        holidayName: j['holidayName'] as String?,
        shiftName: j['shiftName'] as String?,
        shiftColor: j['shiftColor'] as String?,
        shiftStart: j['shiftStart'] as String?,
        shiftEnd: j['shiftEnd'] as String?,
        breakMinutes: j['breakMinutes'] as int? ?? 0,
        checkIn: j['checkIn'] as String?,
        checkOut: j['checkOut'] as String?,
        checkInRaw: j['checkInRaw'] as String?,
        checkOutRaw: j['checkOutRaw'] as String?,
        checkInRounded: j['checkInRounded'] as bool? ?? false,
        checkOutRounded: j['checkOutRounded'] as bool? ?? false,
        status: j['status'] != null ? _parseStatus(j['status'] as String?) : null,
        shiftAssignmentId: (j['shiftAssignmentId'] as num?)?.toInt(),
        requestedCheckIn: j['requestedCheckIn'] as String?,
        requestedCheckInStatus: j['requestedCheckInStatus'] as String?,
        requestedCheckOut: j['requestedCheckOut'] as String?,
        requestedCheckOutStatus: j['requestedCheckOutStatus'] as String?,
        requestedOvertimeMinutes:
            (j['requestedOvertimeMinutes'] as num?)?.toInt(),
        requestedOvertimeScope: j['requestedOvertimeScope'] as String?,
        requestedOvertimePeriod: j['requestedOvertimePeriod'] as String?,
        requestedOvertimeStatus: j['requestedOvertimeStatus'] as String?,
        attendanceId: (j['attendanceId'] as num?)?.toInt(),
        requests: (j['requests'] as List<dynamic>?)
                ?.map((e) =>
                    AttendanceChangeRequest.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        actualHours: (j['actualHours'] as num?)?.toDouble() ?? 0,
        totalHours: (j['totalHours'] as num?)?.toDouble() ?? 0,
        regularDayHours: (j['regularDayHours'] as num?)?.toDouble() ?? 0,
        otDayHours: (j['otDayHours'] as num?)?.toDouble() ?? 0,
        regularNightHours: (j['regularNightHours'] as num?)?.toDouble() ?? 0,
        otNightHours: (j['otNightHours'] as num?)?.toDouble() ?? 0,
        leaveRequestId: (j['leaveRequestId'] as num?)?.toInt(),
        leaveCode: j['leaveCode'] as String?,
        leaveMode: j['leaveMode'] as String?,
        leaveStatus: j['leaveStatus'] as String?,
        leaveApplied: j['leaveApplied'] as bool?,
        leaveProcessedByName: j['leaveProcessedByName'] as String?,
        leaveProcessedAt: j['leaveProcessedAt'] as String?,
        leaveCreatedAt: j['leaveCreatedAt'] as String?,
        leaveAmount: (j['leaveAmount'] as num?)?.toDouble(),
        leaveFromTime: j['leaveFromTime'] as String?,
        leaveToTime: j['leaveToTime'] as String?,
        approved: j['approved'] as bool? ?? false,
        approvedAt: j['approvedAt'] as String?,
        approvedByName: j['approvedByName'] as String?,
        leaves: (j['leaves'] as List<dynamic>?)
            ?.map((e) => DayViewLeaveInfo.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
        workFlags: (j['workFlags'] as String?)?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? const [],
        overrideCheckIn: j['overrideCheckIn'] as String?,
        overrideCheckOut: j['overrideCheckOut'] as String?,
        overrideBreakMinutes: (j['overrideBreakMinutes'] as num?)?.toInt(),
        overrideOtDayMinutes: (j['overrideOtDayMinutes'] as num?)?.toInt(),
        overrideOtNightMinutes: (j['overrideOtNightMinutes'] as num?)?.toInt(),
        overrideNote: j['overrideNote'] as String?,
      );
}

class DayViewLeaveInfo {
  final int leaveRequestId;
  final String? leaveCode;
  final String? leaveMode;
  final String? leaveStatus;
  final bool? leaveApplied;
  final String? leaveProcessedByName;
  final String? leaveProcessedAt;
  final String? leaveCreatedAt;
  final double? leaveAmount;
  final String? leaveFromTime;
  final String? leaveToTime;

  const DayViewLeaveInfo({
    required this.leaveRequestId,
    this.leaveCode,
    this.leaveMode,
    this.leaveStatus,
    this.leaveApplied,
    this.leaveProcessedByName,
    this.leaveProcessedAt,
    this.leaveCreatedAt,
    this.leaveAmount,
    this.leaveFromTime,
    this.leaveToTime,
  });

  factory DayViewLeaveInfo.fromJson(Map<String, dynamic> j) => DayViewLeaveInfo(
        leaveRequestId: j['leaveRequestId'] as int,
        leaveCode: j['leaveCode'] as String?,
        leaveMode: j['leaveMode'] as String?,
        leaveStatus: j['leaveStatus'] as String?,
        leaveApplied: j['leaveApplied'] as bool?,
        leaveProcessedByName: j['leaveProcessedByName'] as String?,
        leaveProcessedAt: j['leaveProcessedAt'] as String?,
        leaveCreatedAt: j['leaveCreatedAt'] as String?,
        leaveAmount: (j['leaveAmount'] as num?)?.toDouble(),
        leaveFromTime: j['leaveFromTime'] as String?,
        leaveToTime: j['leaveToTime'] as String?,
      );
}

class AttendanceChangeRequest {
  final int id;
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final int? departmentId;
  final String departmentName;
  final String requestDate;
  final String requestType;
  final String? requestedCheckIn;
  final String? requestedCheckOut;
  final int? requestedOvertimeMinutes;
  final String? requestedOvertimeScope;
  final String? requestedOvertimePeriod;
  final int? shiftAssignmentId;
  final String? shiftName;
  final String? shiftStart;
  final String? shiftEnd;
  final String? note;
  final String status;
  final bool applied;
  final String? adminNote;
  final String? processedByName;
  final String? createdAt;
  final String? processedAt;
  final String? updatedAt;

  const AttendanceChangeRequest({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentId,
    required this.departmentName,
    required this.requestDate,
    required this.requestType,
    this.requestedCheckIn,
    this.requestedCheckOut,
    this.requestedOvertimeMinutes,
    this.requestedOvertimeScope,
    this.requestedOvertimePeriod,
    this.shiftAssignmentId,
    this.shiftName,
    this.shiftStart,
    this.shiftEnd,
    this.note,
    required this.status,
    this.applied = true,
    this.adminNote,
    this.processedByName,
    this.createdAt,
    this.processedAt,
    this.updatedAt,
  });

  AttendanceChangeRequest copyWith({
    int? id,
    int? employeeId,
    String? employeeCode,
    String? employeeName,
    int? departmentId,
    String? departmentName,
    String? requestDate,
    String? requestType,
    String? requestedCheckIn,
    String? requestedCheckOut,
    int? requestedOvertimeMinutes,
    String? requestedOvertimeScope,
    String? requestedOvertimePeriod,
    int? shiftAssignmentId,
    String? shiftName,
    String? shiftStart,
    String? shiftEnd,
    String? note,
    String? status,
    bool? applied,
    String? adminNote,
    String? processedByName,
    String? createdAt,
    String? processedAt,
    String? updatedAt,
  }) {
    return AttendanceChangeRequest(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeCode: employeeCode ?? this.employeeCode,
      employeeName: employeeName ?? this.employeeName,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      requestDate: requestDate ?? this.requestDate,
      requestType: requestType ?? this.requestType,
      requestedCheckIn: requestedCheckIn ?? this.requestedCheckIn,
      requestedCheckOut: requestedCheckOut ?? this.requestedCheckOut,
      requestedOvertimeMinutes:
          requestedOvertimeMinutes ?? this.requestedOvertimeMinutes,
      requestedOvertimeScope:
          requestedOvertimeScope ?? this.requestedOvertimeScope,
      requestedOvertimePeriod:
          requestedOvertimePeriod ?? this.requestedOvertimePeriod,
      shiftAssignmentId: shiftAssignmentId ?? this.shiftAssignmentId,
      shiftName: shiftName ?? this.shiftName,
      shiftStart: shiftStart ?? this.shiftStart,
      shiftEnd: shiftEnd ?? this.shiftEnd,
      note: note ?? this.note,
      status: status ?? this.status,
      applied: applied ?? this.applied,
      adminNote: adminNote ?? this.adminNote,
      processedByName: processedByName ?? this.processedByName,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AttendanceChangeRequest.fromJson(Map<String, dynamic> j) =>
      AttendanceChangeRequest(
        id: j['id'] as int,
        employeeId: j['employeeId'] as int,
        employeeCode: j['employeeCode'] as String,
        employeeName: j['employeeName'] as String,
        departmentId: (j['departmentId'] as num?)?.toInt(),
        departmentName: j['departmentName'] as String,
        requestDate: j['requestDate'] as String,
        requestType: j['requestType'] as String,
        requestedCheckIn: j['requestedCheckIn'] as String?,
        requestedCheckOut: j['requestedCheckOut'] as String?,
        requestedOvertimeMinutes:
            (j['requestedOvertimeMinutes'] as num?)?.toInt(),
        requestedOvertimeScope: j['requestedOvertimeScope'] as String?,
        requestedOvertimePeriod: j['requestedOvertimePeriod'] as String?,
        shiftAssignmentId: (j['shiftAssignmentId'] as num?)?.toInt(),
        shiftName: j['shiftName'] as String?,
        shiftStart: j['shiftStart'] as String?,
        shiftEnd: j['shiftEnd'] as String?,
        note: j['note'] as String?,
        status: j['status'] as String,
        applied: j['applied'] as bool? ?? true,
        adminNote: j['adminNote'] as String?,
        processedByName: j['processedByName'] as String?,
        createdAt: j['createdAt'] as String?,
        processedAt: j['processedAt'] as String?,
        updatedAt: j['updatedAt'] as String?,
      );
}

class AttendanceSummary {
  final int employeeId;
  final int year;
  final int month;
  final int totalWorkDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int leaveDays;
  final double totalWorkingHours;
  final double totalOvertimeHours;

  const AttendanceSummary({
    required this.employeeId,
    required this.year,
    required this.month,
    required this.totalWorkDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.leaveDays,
    required this.totalWorkingHours,
    required this.totalOvertimeHours,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) =>
      AttendanceSummary(
        employeeId: j['employeeId'],
        year: j['year'],
        month: j['month'],
        totalWorkDays: j['totalWorkDays'] ?? 0,
        presentDays: j['presentDays'] ?? 0,
        absentDays: j['absentDays'] ?? 0,
        lateDays: j['lateDays'] ?? 0,
        leaveDays: j['leaveDays'] ?? 0,
        totalWorkingHours: (j['totalWorkingHours'] as num?)?.toDouble() ?? 0,
        totalOvertimeHours: (j['totalOvertimeHours'] as num?)?.toDouble() ?? 0,
      );
}

class SelfShiftInfo {
  final int? id;
  final String name;
  final String? color;
  final String startTime;
  final String endTime;
  final String checkInFrom;
  final String checkInTo;
  final String checkOutFrom;
  final String checkOutTo;

  const SelfShiftInfo({
    this.id,
    required this.name,
    this.color,
    required this.startTime,
    required this.endTime,
    required this.checkInFrom,
    required this.checkInTo,
    required this.checkOutFrom,
    required this.checkOutTo,
  });

  factory SelfShiftInfo.fromJson(Map<String, dynamic> j) => SelfShiftInfo(
        id: (j['id'] as num?)?.toInt(),
        name: j['name'] as String? ?? '',
        color: j['color'] as String?,
        startTime: j['startTime'] as String? ?? '',
        endTime: j['endTime'] as String? ?? '',
        checkInFrom: j['checkInFrom'] as String? ?? '',
        checkInTo: j['checkInTo'] as String? ?? '',
        checkOutFrom: j['checkOutFrom'] as String? ?? '',
        checkOutTo: j['checkOutTo'] as String? ?? '',
      );
}

class AllowedLocation {
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String source;

  const AllowedLocation({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.source,
  });

  factory AllowedLocation.fromJson(Map<String, dynamic> j) => AllowedLocation(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        radiusMeters: (j['radiusMeters'] as num).toInt(),
        source: j['source'] as String? ?? '',
      );
}

class SelfTodayAttendance {
  final bool enabled;
  final String? message;
  final int? employeeId;
  final String? employeeName;
  final DateTime? date; // ngày hiệu lực của ca
  final SelfShiftInfo? shift;
  final List<SelfShiftInfo> shifts;
  final Attendance? attendance;
  final bool canCheckIn;
  final bool canCheckOut;
  final List<AllowedLocation>? allowedLocations; // null = free

  const SelfTodayAttendance({
    required this.enabled,
    this.message,
    this.employeeId,
    this.employeeName,
    this.date,
    this.shift,
    this.shifts = const [],
    this.attendance,
    required this.canCheckIn,
    required this.canCheckOut,
    this.allowedLocations,
  });

  factory SelfTodayAttendance.fromJson(Map<String, dynamic> j) =>
      SelfTodayAttendance(
        enabled: j['enabled'] as bool? ?? false,
        message: j['message'] as String?,
        employeeId: (j['employeeId'] as num?)?.toInt(),
        employeeName: j['employeeName'] as String?,
        date: j['date'] != null ? DateTime.parse(j['date'] as String) : null,
        shift: j['shift'] != null
            ? SelfShiftInfo.fromJson(j['shift'] as Map<String, dynamic>)
            : null,
        shifts: (j['shifts'] as List?)
                ?.map((e) => SelfShiftInfo.fromJson(e as Map<String, dynamic>))
                .toList() ??
            (j['shift'] != null
                ? [SelfShiftInfo.fromJson(j['shift'] as Map<String, dynamic>)]
                : const []),
        attendance: j['attendance'] != null
            ? Attendance.fromJson(j['attendance'] as Map<String, dynamic>)
            : null,
        canCheckIn: j['canCheckIn'] as bool? ?? false,
        canCheckOut: j['canCheckOut'] as bool? ?? false,
        allowedLocations: j['allowedLocations'] == null
            ? null
            : (j['allowedLocations'] as List)
                .map((e) => AllowedLocation.fromJson(e as Map<String, dynamic>))
                .toList(),
      );
}
