import '../services/api_service.dart';

/// Mẫu ca xoay vòng (Mốc 2b).
class ShiftRotation {
  final int id;
  final String name;
  /// Mỗi phần tử là một ngày trong chu kỳ: danh sách id ca (rỗng = nghỉ).
  final List<List<int>> days;
  /// Mã ca từng ngày ("" = nghỉ, "SANG+CHIEU" = 2 ca).
  final List<String> dayCodes;

  const ShiftRotation({required this.id, required this.name, required this.days, required this.dayCodes});

  factory ShiftRotation.fromJson(Map<String, dynamic> m) => ShiftRotation(
        id: m['id'] as int,
        name: m['name'] as String,
        days: (m['days'] as List)
            .map((d) => (d as List).map((e) => (e as num).toInt()).toList())
            .toList(),
        dayCodes: (m['dayCodes'] as List? ?? const []).map((e) => e.toString()).toList(),
      );
}

class RotationConflict {
  final String employeeName;
  final String date;
  final String reason;
  const RotationConflict(this.employeeName, this.date, this.reason);
}

class RotationGenerateResult {
  final int assignedDays;
  final int clearedDays;
  final int unchangedDays;
  final List<RotationConflict> conflicts;
  const RotationGenerateResult(this.assignedDays, this.clearedDays, this.unchangedDays, this.conflicts);

  factory RotationGenerateResult.fromJson(Map<String, dynamic> m) => RotationGenerateResult(
        (m['assignedDays'] as num?)?.toInt() ?? 0,
        (m['clearedDays'] as num?)?.toInt() ?? 0,
        (m['unchangedDays'] as num?)?.toInt() ?? 0,
        ((m['conflicts'] as List?) ?? const [])
            .map((c) => RotationConflict(
                  (c['employeeName'] ?? '').toString(),
                  (c['date'] ?? '').toString(),
                  (c['reason'] ?? '').toString(),
                ))
            .toList(),
      );
}

/// Yêu cầu đổi ca / nhường ca.
class ShiftSwap {
  final int id;
  final String status;
  final String kind; // SWAP | GIVE
  final int requesterId;
  final String requesterName;
  final String requesterDate;
  final String requesterShift;
  final int targetEmployeeId;
  final String targetEmployeeName;
  final String? targetDate;
  final String? targetShift;
  final String? reason;
  final String? adminNote;
  final String? processedByName;
  /// Bước K: bước quản lý trực tiếp.
  final String? managerApprovedByName;
  final String? awaitingManagerName;

  const ShiftSwap({
    required this.id,
    required this.status,
    required this.kind,
    required this.requesterId,
    required this.requesterName,
    required this.requesterDate,
    required this.requesterShift,
    required this.targetEmployeeId,
    required this.targetEmployeeName,
    this.targetDate,
    this.targetShift,
    this.reason,
    this.adminNote,
    this.processedByName,
    this.managerApprovedByName,
    this.awaitingManagerName,
  });

  factory ShiftSwap.fromJson(Map<String, dynamic> m) => ShiftSwap(
        id: m['id'] as int,
        status: m['status'] as String,
        kind: (m['kind'] as String?) ?? 'SWAP',
        requesterId: m['requesterId'] as int,
        requesterName: (m['requesterName'] ?? '').toString(),
        requesterDate: (m['requesterDate'] ?? '').toString(),
        requesterShift: (m['requesterShift'] ?? '').toString(),
        targetEmployeeId: m['targetEmployeeId'] as int,
        targetEmployeeName: (m['targetEmployeeName'] ?? '').toString(),
        targetDate: m['targetDate'] as String?,
        targetShift: m['targetShift'] as String?,
        reason: m['reason'] as String?,
        adminNote: m['adminNote'] as String?,
        processedByName: m['processedByName'] as String?,
        managerApprovedByName: m['managerApprovedByName'] as String?,
        awaitingManagerName: m['awaitingManagerName'] as String?,
      );
}

class ShiftOption {
  final int assignmentId;
  final String date;
  final String label;
  const ShiftOption(this.assignmentId, this.date, this.label);
  factory ShiftOption.fromJson(Map<String, dynamic> m) =>
      ShiftOption(m['assignmentId'] as int, (m['date'] ?? '').toString(), (m['label'] ?? '').toString());
}

class SwapColleague {
  final int employeeId;
  final String fullName;
  final String? departmentName;
  final List<ShiftOption> shifts;
  const SwapColleague(this.employeeId, this.fullName, this.departmentName, this.shifts);
  factory SwapColleague.fromJson(Map<String, dynamic> m) => SwapColleague(
        m['employeeId'] as int,
        (m['fullName'] ?? '').toString(),
        m['departmentName'] as String?,
        ((m['shifts'] as List?) ?? const [])
            .map((e) => ShiftOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ShiftPlanRepository {
  final _api = ApiService.instance;

  // ── Rotations ──
  Future<List<ShiftRotation>> getRotations() => _api.get('/shift-rotations',
      (d) => (d as List).map((e) => ShiftRotation.fromJson(e as Map<String, dynamic>)).toList());

  Future<void> saveRotation({int? id, required String name, required List<List<int>> days}) {
    final body = {'name': name, 'days': days};
    return id == null
        ? _api.post('/shift-rotations', (_) => null, body)
        : _api.put('/shift-rotations/$id', (_) => null, body);
  }

  Future<void> deleteRotation(int id) => _api.dio.delete('/shift-rotations/$id');

  Future<RotationGenerateResult> generate(int rotationId,
          {required List<int> employeeIds,
          required String from,
          required String to,
          int startOffset = 0,
          int staggerPerEmployee = 0,
          bool skipHolidays = false}) =>
      _api.post(
        '/shift-rotations/$rotationId/generate',
        (d) => RotationGenerateResult.fromJson(d as Map<String, dynamic>),
        {
          'employeeIds': employeeIds,
          'from': from,
          'to': to,
          'startOffset': startOffset,
          'staggerPerEmployee': staggerPerEmployee,
          'skipHolidays': skipHolidays,
        },
      );

  // ── Swaps ──
  Future<List<ShiftSwap>> getSwaps({String? status}) => _api.get(
        '/shift-swaps',
        (d) => (d as List).map((e) => ShiftSwap.fromJson(e as Map<String, dynamic>)).toList(),
        queryParams: {if (status != null) 'status': status},
      );

  Future<List<ShiftOption>> myShifts() => _api.get('/shift-swaps/my-shifts',
      (d) => (d as List).map((e) => ShiftOption.fromJson(e as Map<String, dynamic>)).toList());

  Future<List<SwapColleague>> colleagues(int assignmentId) => _api.get(
        '/shift-swaps/colleagues',
        (d) => (d as List).map((e) => SwapColleague.fromJson(e as Map<String, dynamic>)).toList(),
        queryParams: {'assignmentId': assignmentId},
      );

  Future<void> createSwap({
    required int requesterAssignmentId,
    required int targetEmployeeId,
    int? targetAssignmentId,
    String? reason,
  }) =>
      _api.post('/shift-swaps', (_) => null, {
        'requesterAssignmentId': requesterAssignmentId,
        'targetEmployeeId': targetEmployeeId,
        if (targetAssignmentId != null) 'targetAssignmentId': targetAssignmentId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<void> approveSwap(int id, {String? note}) =>
      _api.put('/shift-swaps/$id/approve', (_) => null, {if (note != null) 'adminNote': note});

  Future<void> rejectSwap(int id, {String? note}) =>
      _api.put('/shift-swaps/$id/reject', (_) => null, {if (note != null) 'adminNote': note});

  Future<void> cancelSwap(int id) => _api.put('/shift-swaps/$id/cancel', (_) => null, const {});
}
