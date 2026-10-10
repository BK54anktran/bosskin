import '../models/attendance.dart';
import '../services/api_service.dart';
import 'shift_plan_repository.dart';

/// Bước K — đơn của cấp dưới trực tiếp chờ quản lý duyệt.
class TeamApprovals {
  final bool enabled;
  final int reportCount;
  final List<Map<String, dynamic>> leaves;
  final List<AttendanceChangeRequest> attendances;
  final List<ShiftSwap> swaps;

  const TeamApprovals({
    required this.enabled,
    required this.reportCount,
    this.leaves = const [],
    this.attendances = const [],
    this.swaps = const [],
  });

  int get total => leaves.length + attendances.length + swaps.length;

  factory TeamApprovals.fromJson(Map<String, dynamic> j) => TeamApprovals(
        enabled: j['enabled'] == true,
        reportCount: (j['reportCount'] as num?)?.toInt() ?? 0,
        leaves: ((j['leaves'] as List?) ?? const []).cast<Map<String, dynamic>>(),
        attendances: ((j['attendances'] as List?) ?? const [])
            .map((e) => AttendanceChangeRequest.fromJson(e as Map<String, dynamic>))
            .toList(),
        swaps: ((j['swaps'] as List?) ?? const [])
            .map((e) => ShiftSwap.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TeamApprovalRepository {
  final _api = ApiService.instance;

  Future<TeamApprovals> getAll() =>
      _api.get('/team-approvals', (d) => TeamApprovals.fromJson(d as Map<String, dynamic>));

  Future<({bool enabled, int reportCount, int count})> count() => _api.get('/team-approvals/count', (d) {
        final m = d as Map<String, dynamic>;
        return (
          enabled: m['enabled'] == true,
          reportCount: (m['reportCount'] as num?)?.toInt() ?? 0,
          count: (m['count'] as num?)?.toInt() ?? 0,
        );
      });

  /// [kind] = LEAVE | ATTENDANCE | SWAP
  Future<void> approve(String kind, int id, {String? note}) =>
      _api.post('/team-approvals/$kind/$id/approve', (_) {}, {'note': note});

  Future<void> reject(String kind, int id, {String? note}) =>
      _api.post('/team-approvals/$kind/$id/reject', (_) {}, {'note': note});
}
