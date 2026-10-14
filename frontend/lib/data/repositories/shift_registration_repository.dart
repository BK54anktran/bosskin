import '../services/api_service.dart';

/// Đăng ký lịch làm việc (V23): đợt, khung đăng ký, ca có sẵn để chọn.
class RegRound {
  final int id;
  final String name;
  final DateTime fromDate;
  final DateTime toDate;
  /// DRAFT | OPEN | CLOSED
  final String status;
  final DateTime? closesAt;
  final String? earliestTime;
  final String? latestTime;
  final num? minHours;
  final num? maxHours;
  final int? minDays;
  final int? neededPerDay;
  final String? note;
  final List<({int id, String name})> departments;
  final int registeredCount;
  final int employeeCount;
  final String? createdByName;

  const RegRound({
    required this.id,
    required this.name,
    required this.fromDate,
    required this.toDate,
    required this.status,
    this.closesAt,
    this.earliestTime,
    this.latestTime,
    this.minHours,
    this.maxHours,
    this.minDays,
    this.neededPerDay,
    this.note,
    this.departments = const [],
    this.registeredCount = 0,
    this.employeeCount = 0,
    this.createdByName,
  });

  bool get isOpen => status == 'OPEN';
  bool get isDraft => status == 'DRAFT';

  List<DateTime> get days => [
        for (var d = fromDate; !d.isAfter(toDate); d = DateTime(d.year, d.month, d.day + 1)) d,
      ];

  factory RegRound.fromJson(Map<String, dynamic> m) => RegRound(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String,
        fromDate: DateTime.parse(m['fromDate'] as String),
        toDate: DateTime.parse(m['toDate'] as String),
        status: m['status'] as String,
        closesAt: m['closesAt'] != null ? DateTime.parse(m['closesAt'] as String) : null,
        earliestTime: m['earliestTime'] as String?,
        latestTime: m['latestTime'] as String?,
        minHours: m['minHours'] as num?,
        maxHours: m['maxHours'] as num?,
        minDays: (m['minDays'] as num?)?.toInt(),
        neededPerDay: (m['neededPerDay'] as num?)?.toInt(),
        note: m['note'] as String?,
        departments: ((m['departments'] as List?) ?? const [])
            .map((d) => (id: (d['id'] as num).toInt(), name: (d['name'] ?? '').toString()))
            .toList(),
        registeredCount: (m['registeredCount'] as num?)?.toInt() ?? 0,
        employeeCount: (m['employeeCount'] as num?)?.toInt() ?? 0,
        createdByName: m['createdByName'] as String?,
      );
}

/// Một khung đăng ký. kind: SHIFT | CUSTOM | ANY (rảnh cả ngày). status: PENDING | APPROVED | REJECTED.
class RegSlot {
  final int? id;
  final DateTime workDate;
  final String kind;
  final int? shiftId;
  final String? shiftCode;
  final String? startTime;
  final String? endTime;
  final String? note;
  final String status;

  const RegSlot({
    this.id,
    required this.workDate,
    required this.kind,
    this.shiftId,
    this.shiftCode,
    this.startTime,
    this.endTime,
    this.note,
    this.status = 'PENDING',
  });

  bool get isAny => kind == 'ANY';

  factory RegSlot.fromJson(Map<String, dynamic> m) => RegSlot(
        id: (m['id'] as num?)?.toInt(),
        workDate: DateTime.parse(m['workDate'] as String),
        kind: m['kind'] as String,
        shiftId: (m['shiftId'] as num?)?.toInt(),
        shiftCode: m['shiftCode'] as String?,
        startTime: m['startTime'] as String?,
        endTime: m['endTime'] as String?,
        note: m['note'] as String?,
        status: (m['status'] ?? 'PENDING') as String,
      );

  Map<String, dynamic> toJson() => {
        'workDate': _ymd(workDate),
        'kind': kind,
        if (shiftId != null) 'shiftId': shiftId,
        if (kind == 'CUSTOM') 'startTime': startTime,
        if (kind == 'CUSTOM') 'endTime': endTime,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

class RegShiftOption {
  final int id;
  final String code;
  final String name;
  final String startTime;
  final String endTime;
  final String? color;
  const RegShiftOption(this.id, this.code, this.name, this.startTime, this.endTime, this.color);

  factory RegShiftOption.fromJson(Map<String, dynamic> m) => RegShiftOption(
        (m['id'] as num).toInt(),
        (m['code'] ?? '').toString(),
        (m['name'] ?? '').toString(),
        (m['startTime'] ?? '').toString(),
        (m['endTime'] ?? '').toString(),
        m['color'] as String?,
      );
}

class MyRegRound {
  final RegRound round;
  final bool editable;
  final List<RegSlot> registrations;
  final List<RegShiftOption> shifts;
  const MyRegRound(this.round, this.editable, this.registrations, this.shifts);

  factory MyRegRound.fromJson(Map<String, dynamic> m) => MyRegRound(
        RegRound.fromJson(m['round'] as Map<String, dynamic>),
        m['editable'] == true,
        ((m['registrations'] as List?) ?? const []).map((e) => RegSlot.fromJson(e as Map<String, dynamic>)).toList(),
        ((m['shifts'] as List?) ?? const []).map((e) => RegShiftOption.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class RegBoardEmployee {
  final int id;
  final String code;
  final String name;
  final String? departmentName;
  final int days;
  final List<RegSlot> registrations;
  const RegBoardEmployee(this.id, this.code, this.name, this.departmentName, this.days, this.registrations);

  factory RegBoardEmployee.fromJson(Map<String, dynamic> m) => RegBoardEmployee(
        (m['id'] as num).toInt(),
        (m['code'] ?? '').toString(),
        (m['name'] ?? '').toString(),
        m['departmentName'] as String?,
        (m['days'] as num?)?.toInt() ?? 0,
        ((m['registrations'] as List?) ?? const []).map((e) => RegSlot.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class RegBoard {
  final RegRound round;
  final List<RegBoardEmployee> employees;
  final List<RegShiftOption> shifts;
  const RegBoard(this.round, this.employees, this.shifts);

  factory RegBoard.fromJson(Map<String, dynamic> m) => RegBoard(
        RegRound.fromJson(m['round'] as Map<String, dynamic>),
        ((m['employees'] as List?) ?? const []).map((e) => RegBoardEmployee.fromJson(e as Map<String, dynamic>)).toList(),
        ((m['shifts'] as List?) ?? const []).map((e) => RegShiftOption.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class RegDecideResult {
  final int approved;
  final List<({String employeeName, String reason})> skipped;
  const RegDecideResult(this.approved, this.skipped);

  factory RegDecideResult.fromJson(Map<String, dynamic> m) => RegDecideResult(
        (m['approved'] as num?)?.toInt() ?? 0,
        ((m['skipped'] as List?) ?? const [])
            .map((x) => (employeeName: (x['employeeName'] ?? '').toString(), reason: (x['reason'] ?? '').toString()))
            .toList(),
      );
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ShiftRegistrationRepository {
  final _api = ApiService.instance;

  // ── Quản lý ──
  Future<List<RegRound>> getRounds() => _api.get('/shift-registration-rounds',
      (d) => (d as List).map((e) => RegRound.fromJson(e as Map<String, dynamic>)).toList());

  Future<RegRound> saveRound({int? id, required Map<String, dynamic> body}) => id == null
      ? _api.post('/shift-registration-rounds', (d) => RegRound.fromJson(d as Map<String, dynamic>), body)
      : _api.put('/shift-registration-rounds/$id', (d) => RegRound.fromJson(d as Map<String, dynamic>), body);

  Future<void> deleteRound(int id) => _api.delete('/shift-registration-rounds/$id');

  Future<RegRound> open(int id) =>
      _api.post('/shift-registration-rounds/$id/open', (d) => RegRound.fromJson(d as Map<String, dynamic>), {});

  Future<RegRound> close(int id) =>
      _api.post('/shift-registration-rounds/$id/close', (d) => RegRound.fromJson(d as Map<String, dynamic>), {});

  Future<RegBoard> board(int id) =>
      _api.get('/shift-registration-rounds/$id/board', (d) => RegBoard.fromJson(d as Map<String, dynamic>));

  Future<RegDecideResult> approveDay(int roundId, DateTime date, {int? anyShiftId}) => _api.post(
        '/shift-registration-rounds/$roundId/days/${_ymd(date)}/approve',
        (d) => RegDecideResult.fromJson(d as Map<String, dynamic>),
        {if (anyShiftId != null) 'anyShiftId': anyShiftId},
      );

  Future<void> approveOne(int regId, {int? shiftId, String? startTime, String? endTime}) => _api.post(
        '/shift-registrations/$regId/approve',
        (_) {},
        {
          if (shiftId != null) 'shiftId': shiftId,
          if (startTime != null) 'startTime': startTime,
          if (endTime != null) 'endTime': endTime,
        },
      );

  Future<void> reject(int regId) => _api.post('/shift-registrations/$regId/reject', (_) {}, {});

  // ── Nhân viên ──
  Future<List<RegRound>> myRounds() => _api.get('/shift-registrations/self/rounds',
      (d) => (d as List).map((e) => RegRound.fromJson(e as Map<String, dynamic>)).toList());

  Future<MyRegRound> myRound(int id) =>
      _api.get('/shift-registrations/self/rounds/$id', (d) => MyRegRound.fromJson(d as Map<String, dynamic>));

  Future<MyRegRound> saveMine(int id, List<RegSlot> slots) => _api.put(
        '/shift-registrations/self/rounds/$id',
        (d) => MyRegRound.fromJson(d as Map<String, dynamic>),
        {'slots': slots.map((e) => e.toJson()).toList()},
      );
}

/// Ngày yyyy-MM-dd cho API.
String regYmd(DateTime d) => _ymd(d);
