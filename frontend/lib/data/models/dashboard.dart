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
