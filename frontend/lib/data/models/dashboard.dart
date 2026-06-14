class DashboardTodayStats {
  final int totalEmployees;
  final int present;
  final int onLeave;
  final int absent;
  final int late;

  const DashboardTodayStats({
    required this.totalEmployees,
    required this.present,
    required this.onLeave,
    required this.absent,
    required this.late,
  });

  factory DashboardTodayStats.fromJson(Map<String, dynamic> j) =>
      DashboardTodayStats(
        totalEmployees: (j['totalEmployees'] as num).toInt(),
        present: (j['present'] as num).toInt(),
        onLeave: (j['onLeave'] as num).toInt(),
        absent: (j['absent'] as num).toInt(),
        late: (j['late'] as num).toInt(),
      );
}

class DashboardAttendanceRow {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final bool late;

  const DashboardAttendanceRow({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    this.checkIn,
    this.checkOut,
    required this.status,
    required this.late,
  });

  factory DashboardAttendanceRow.fromJson(Map<String, dynamic> j) =>
      DashboardAttendanceRow(
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: j['employeeCode'] ?? '',
        employeeName: j['employeeName'] ?? '',
        departmentName: j['departmentName'],
        checkIn: j['checkIn'] != null ? DateTime.tryParse(j['checkIn']) : null,
        checkOut:
            j['checkOut'] != null ? DateTime.tryParse(j['checkOut']) : null,
        status: j['status'] ?? 'PRESENT',
        late: j['late'] == true,
      );
}

class DashboardRecentPayroll {
  final int year;
  final int month;
  final double totalNetSalary;
  final int employeeCount;
  final String status;

  const DashboardRecentPayroll({
    required this.year,
    required this.month,
    required this.totalNetSalary,
    required this.employeeCount,
    required this.status,
  });

  factory DashboardRecentPayroll.fromJson(Map<String, dynamic> j) =>
      DashboardRecentPayroll(
        year: (j['year'] as num).toInt(),
        month: (j['month'] as num).toInt(),
        totalNetSalary: (j['totalNetSalary'] as num?)?.toDouble() ?? 0,
        employeeCount: (j['employeeCount'] as num).toInt(),
        status: j['status'] ?? 'DRAFT',
      );
}

// ── Analytics models ─────────────────────────────────────────────────────────

class DashboardMonthlySalaryStat {
  final int month;
  final double totalNetSalary;
  final int employeeCount;

  const DashboardMonthlySalaryStat({
    required this.month,
    required this.totalNetSalary,
    required this.employeeCount,
  });

  factory DashboardMonthlySalaryStat.fromJson(Map<String, dynamic> j) =>
      DashboardMonthlySalaryStat(
        month: (j['month'] as num).toInt(),
        totalNetSalary: (j['totalNetSalary'] as num?)?.toDouble() ?? 0,
        employeeCount: (j['employeeCount'] as num).toInt(),
      );
}

class DashboardDailyAttendanceStat {
  final DateTime date;
  final int present;
  final int late;
  final int absent;
  final double totalHours;
  final double estimatedCost;
  final List<DashboardDailyAttendanceGradeBreakdown> gradeBreakdown;

  const DashboardDailyAttendanceStat({
    required this.date,
    required this.present,
    required this.late,
    required this.absent,
    required this.totalHours,
    required this.estimatedCost,
    required this.gradeBreakdown,
  });

  factory DashboardDailyAttendanceStat.fromJson(Map<String, dynamic> j) =>
      DashboardDailyAttendanceStat(
        date: DateTime.parse(j['date']),
        present: (j['present'] as num).toInt(),
        late: (j['late'] as num).toInt(),
        absent: (j['absent'] as num).toInt(),
        totalHours: (j['totalHours'] as num?)?.toDouble() ?? 0,
        estimatedCost: (j['estimatedCost'] as num?)?.toDouble() ?? 0,
        gradeBreakdown: (j['gradeBreakdown'] as List? ?? const [])
            .map((e) =>
                DashboardDailyAttendanceGradeBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DashboardDailyAttendanceGradeBreakdown {
  final int? salaryGradeId;
  final String? salaryGradeCode;
  final String? salaryGradeName;
  final String? payType;
  final double totalHours;
  final double estimatedCost;
  final int employeeCount;

  const DashboardDailyAttendanceGradeBreakdown({
    this.salaryGradeId,
    this.salaryGradeCode,
    this.salaryGradeName,
    this.payType,
    required this.totalHours,
    required this.estimatedCost,
    required this.employeeCount,
  });

  factory DashboardDailyAttendanceGradeBreakdown.fromJson(Map<String, dynamic> j) =>
      DashboardDailyAttendanceGradeBreakdown(
        salaryGradeId: (j['salaryGradeId'] as num?)?.toInt(),
        salaryGradeCode: j['salaryGradeCode'] as String?,
        salaryGradeName: j['salaryGradeName'] as String?,
        payType: j['payType'] as String?,
        totalHours: (j['totalHours'] as num?)?.toDouble() ?? 0,
        estimatedCost: (j['estimatedCost'] as num?)?.toDouble() ?? 0,
        employeeCount: (j['employeeCount'] as num?)?.toInt() ?? 0,
      );
}

class DashboardTopLateEmployee {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final int lateDays;

  const DashboardTopLateEmployee({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    required this.lateDays,
  });

  factory DashboardTopLateEmployee.fromJson(Map<String, dynamic> j) =>
      DashboardTopLateEmployee(
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: j['employeeCode'] ?? '',
        employeeName: j['employeeName'] ?? '',
        departmentName: j['departmentName'],
        lateDays: (j['lateDays'] as num).toInt(),
      );
}

class DashboardAnalyticsData {
  final int year;
  final List<DashboardMonthlySalaryStat> salaryTrend;
  final List<DashboardDailyAttendanceStat> attendanceTrend;
  final List<DashboardTopLateEmployee> topLate;
  final DashboardRangeStats overallStats;

  const DashboardAnalyticsData({
    required this.year,
    required this.salaryTrend,
    required this.attendanceTrend,
    required this.topLate,
    required this.overallStats,
  });

  factory DashboardAnalyticsData.fromJson(Map<String, dynamic> j) =>
      DashboardAnalyticsData(
        year: (j['year'] as num).toInt(),
        salaryTrend: (j['salaryTrend'] as List)
            .map((e) => DashboardMonthlySalaryStat.fromJson(e))
            .toList(),
        attendanceTrend: (j['attendanceTrend'] as List)
            .map((e) => DashboardDailyAttendanceStat.fromJson(e))
            .toList(),
        topLate: (j['topLate'] as List)
            .map((e) => DashboardTopLateEmployee.fromJson(e))
            .toList(),
        overallStats: DashboardRangeStats.fromJson(
            j['overallStats'] as Map<String, dynamic>),
      );
}

class DashboardRangeStats {
  final int totalEmployees;
  final int totalWorkDays;
  final int totalLateDays;
  final int totalAbsentDays;
  final int totalLeaveDays;

  const DashboardRangeStats({
    required this.totalEmployees,
    required this.totalWorkDays,
    required this.totalLateDays,
    required this.totalAbsentDays,
    required this.totalLeaveDays,
  });

  factory DashboardRangeStats.fromJson(Map<String, dynamic> j) =>
      DashboardRangeStats(
        totalEmployees: (j['totalEmployees'] as num).toInt(),
        totalWorkDays: (j['totalWorkDays'] as num).toInt(),
        totalLateDays: (j['totalLateDays'] as num).toInt(),
        totalAbsentDays: (j['totalAbsentDays'] as num).toInt(),
        totalLeaveDays: (j['totalLeaveDays'] as num).toInt(),
      );
}

class DashboardRangeEmployeeRow {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final int leaveDays;

  const DashboardRangeEmployeeRow({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.leaveDays,
  });

  factory DashboardRangeEmployeeRow.fromJson(Map<String, dynamic> j) =>
      DashboardRangeEmployeeRow(
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: j['employeeCode'] ?? '',
        employeeName: j['employeeName'] ?? '',
        departmentName: j['departmentName'],
        presentDays: (j['presentDays'] as num).toInt(),
        lateDays: (j['lateDays'] as num).toInt(),
        absentDays: (j['absentDays'] as num).toInt(),
        leaveDays: (j['leaveDays'] as num).toInt(),
      );
}

class DashboardRangeDailyPoint {
  final DateTime date;
  final int present;
  final int late;
  final int absent;
  final int onLeave;

  const DashboardRangeDailyPoint({
    required this.date,
    required this.present,
    required this.late,
    required this.absent,
    required this.onLeave,
  });

  factory DashboardRangeDailyPoint.fromJson(Map<String, dynamic> j) =>
      DashboardRangeDailyPoint(
        date: DateTime.parse(j['date']),
        present: (j['present'] as num).toInt(),
        late: (j['late'] as num).toInt(),
        absent: (j['absent'] as num).toInt(),
        onLeave: (j['onLeave'] as num).toInt(),
      );
}

class DashboardRangeData {
  final DateTime from;
  final DateTime to;
  final DashboardRangeStats stats;
  final List<DashboardRangeEmployeeRow> rows;
  final List<DashboardRangeDailyPoint> dailyTrend;

  const DashboardRangeData({
    required this.from,
    required this.to,
    required this.stats,
    required this.rows,
    required this.dailyTrend,
  });

  factory DashboardRangeData.fromJson(Map<String, dynamic> j) =>
      DashboardRangeData(
        from: DateTime.parse(j['from']),
        to: DateTime.parse(j['to']),
        stats: DashboardRangeStats.fromJson(j['stats'] as Map<String, dynamic>),
        rows: (j['rows'] as List)
            .map((e) => DashboardRangeEmployeeRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyTrend: (j['dailyTrend'] as List? ?? const [])
            .map((e) => DashboardRangeDailyPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DashboardData {
  final DateTime date;
  final DashboardTodayStats todayStats;
  final List<DashboardAttendanceRow> todayAttendance;
  final DashboardRecentPayroll? recentPayroll;

  const DashboardData({
    required this.date,
    required this.todayStats,
    required this.todayAttendance,
    this.recentPayroll,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        date: DateTime.parse(j['date']),
        todayStats: DashboardTodayStats.fromJson(
            j['todayStats'] as Map<String, dynamic>),
        todayAttendance: (j['todayAttendance'] as List)
            .map((e) =>
                DashboardAttendanceRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentPayroll: j['recentPayroll'] != null
            ? DashboardRecentPayroll.fromJson(
                j['recentPayroll'] as Map<String, dynamic>)
            : null,
      );
}

// ── KPI Summary ───────────────────────────────────────────────────────────────

class DashboardKpiData {
  final int totalActiveEmployees;
  final int newHiresThisMonth;
  final int newHiresLastMonth;
  final int resignedThisMonth;
  final double attritionRate;
  final int todayPresent;
  final int todayAbsent;
  final int todayOnLeave;
  final int todayLate;
  final double todayAttendanceRate;
  final double currentMonthPayroll;
  final int currentMonthPayrollCount;
  final String currentMonthPayrollStatus;
  final DateTime date;

  const DashboardKpiData({
    required this.totalActiveEmployees,
    required this.newHiresThisMonth,
    required this.newHiresLastMonth,
    required this.resignedThisMonth,
    required this.attritionRate,
    required this.todayPresent,
    required this.todayAbsent,
    required this.todayOnLeave,
    required this.todayLate,
    required this.todayAttendanceRate,
    required this.currentMonthPayroll,
    required this.currentMonthPayrollCount,
    required this.currentMonthPayrollStatus,
    required this.date,
  });

  factory DashboardKpiData.fromJson(Map<String, dynamic> j) => DashboardKpiData(
        totalActiveEmployees: (j['totalActiveEmployees'] as num).toInt(),
        newHiresThisMonth: (j['newHiresThisMonth'] as num).toInt(),
        newHiresLastMonth: (j['newHiresLastMonth'] as num).toInt(),
        resignedThisMonth: (j['resignedThisMonth'] as num).toInt(),
        attritionRate: (j['attritionRate'] as num?)?.toDouble() ?? 0,
        todayPresent: (j['todayPresent'] as num).toInt(),
        todayAbsent: (j['todayAbsent'] as num).toInt(),
        todayOnLeave: (j['todayOnLeave'] as num).toInt(),
        todayLate: (j['todayLate'] as num).toInt(),
        todayAttendanceRate: (j['todayAttendanceRate'] as num?)?.toDouble() ?? 0,
        currentMonthPayroll: (j['currentMonthPayroll'] as num?)?.toDouble() ?? 0,
        currentMonthPayrollCount: (j['currentMonthPayrollCount'] as num).toInt(),
        currentMonthPayrollStatus: j['currentMonthPayrollStatus'] ?? 'DRAFT',
        date: DateTime.parse(j['date']),
      );
}

// ── Risk & Warnings ───────────────────────────────────────────────────────────

class DashboardRiskData {
  final List<DashboardRepeatedLateRisk> repeatedLate;
  final List<DashboardMissingCheckoutRisk> missingCheckout;
  final List<DashboardProbationEndingRisk> probationEnding;
  final List<DashboardNoSalaryGradeRisk> noSalaryGrade;
  final int totalWarnings;

  const DashboardRiskData({
    required this.repeatedLate,
    required this.missingCheckout,
    required this.probationEnding,
    required this.noSalaryGrade,
    required this.totalWarnings,
  });

  factory DashboardRiskData.fromJson(Map<String, dynamic> j) => DashboardRiskData(
        repeatedLate: (j['repeatedLate'] as List? ?? const [])
            .map((e) => DashboardRepeatedLateRisk.fromJson(e as Map<String, dynamic>))
            .toList(),
        missingCheckout: (j['missingCheckout'] as List? ?? const [])
            .map((e) => DashboardMissingCheckoutRisk.fromJson(e as Map<String, dynamic>))
            .toList(),
        probationEnding: (j['probationEnding'] as List? ?? const [])
            .map((e) => DashboardProbationEndingRisk.fromJson(e as Map<String, dynamic>))
            .toList(),
        noSalaryGrade: (j['noSalaryGrade'] as List? ?? const [])
            .map((e) => DashboardNoSalaryGradeRisk.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalWarnings: (j['totalWarnings'] as num).toInt(),
      );
}

class DashboardRepeatedLateRisk {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final int lateDaysThisMonth;

  const DashboardRepeatedLateRisk({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    required this.lateDaysThisMonth,
  });

  factory DashboardRepeatedLateRisk.fromJson(Map<String, dynamic> j) =>
      DashboardRepeatedLateRisk(
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: j['employeeCode'] ?? '',
        employeeName: j['employeeName'] ?? '',
        departmentName: j['departmentName'],
        lateDaysThisMonth: (j['lateDaysThisMonth'] as num).toInt(),
      );
}

class DashboardMissingCheckoutRisk {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final String? checkInTime;

  const DashboardMissingCheckoutRisk({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    this.checkInTime,
  });

  factory DashboardMissingCheckoutRisk.fromJson(Map<String, dynamic> j) =>
      DashboardMissingCheckoutRisk(
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: j['employeeCode'] ?? '',
        employeeName: j['employeeName'] ?? '',
        departmentName: j['departmentName'],
        checkInTime: j['checkInTime'] as String?,
      );
}

class DashboardProbationEndingRisk {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final DateTime joinDate;
  final DateTime probationEnd;
  final int daysLeft;

  const DashboardProbationEndingRisk({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    required this.joinDate,
    required this.probationEnd,
    required this.daysLeft,
  });

  factory DashboardProbationEndingRisk.fromJson(Map<String, dynamic> j) =>
      DashboardProbationEndingRisk(
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: j['employeeCode'] ?? '',
        employeeName: j['employeeName'] ?? '',
        departmentName: j['departmentName'],
        joinDate: DateTime.parse(j['joinDate']),
        probationEnd: DateTime.parse(j['probationEnd']),
        daysLeft: (j['daysLeft'] as num).toInt(),
      );
}

class DashboardNoSalaryGradeRisk {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;

  const DashboardNoSalaryGradeRisk({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
  });

  factory DashboardNoSalaryGradeRisk.fromJson(Map<String, dynamic> j) =>
      DashboardNoSalaryGradeRisk(
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: j['employeeCode'] ?? '',
        employeeName: j['employeeName'] ?? '',
        departmentName: j['departmentName'],
      );
}
