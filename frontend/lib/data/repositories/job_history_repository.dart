import '../models/job_history.dart';
import '../services/api_service.dart';

/// Bước K — quá trình công tác và sơ đồ tổ chức.
class JobHistoryRepository {
  final _api = ApiService.instance;

  Future<List<JobHistory>> getAll(int employeeId) => _api.get('/employees/$employeeId/job-histories',
      (d) => (d as List).map((e) => JobHistory.fromJson(e as Map<String, dynamic>)).toList());

  Future<void> create(int employeeId, Map<String, dynamic> body) =>
      _api.post('/employees/$employeeId/job-histories', (_) {}, body);

  Future<void> delete(int historyId) => _api.delete('/employees/job-histories/$historyId');

  Future<List<OrgNode>> orgChart() => _api.get('/org-chart',
      (d) => (d as List).map((e) => OrgNode.fromJson(e as Map<String, dynamic>)).toList());
}
