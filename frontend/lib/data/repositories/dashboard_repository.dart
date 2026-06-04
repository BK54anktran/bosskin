import '../models/dashboard.dart';
import '../services/api_service.dart';

class DashboardRepository {
  final _api = ApiService.instance;

  Future<DashboardData> get({int? departmentId, DateTime? date}) async {
    final params = <String, String>{};
    if (departmentId != null) params['departmentId'] = departmentId.toString();
    if (date != null) params['date'] = _fmt(date);
    final query = _buildQuery(params);
    return _api.get(
      '/dashboard$query',
      (data) => DashboardData.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<DashboardRangeData> getRange({
    required DateTime from,
    required DateTime to,
    int? departmentId,
  }) async {
    final params = <String, String>{
      'from': _fmt(from),
      'to': _fmt(to),
    };
    if (departmentId != null) params['departmentId'] = departmentId.toString();
    return _api.get(
      '/dashboard/range${_buildQuery(params)}',
      (data) => DashboardRangeData.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<DashboardAnalyticsData> getAnalytics({
    int? departmentId,
    int? year,
  }) async {
    final params = <String, String>{};
    if (departmentId != null) params['departmentId'] = departmentId.toString();
    if (year != null) params['year'] = year.toString();
    return _api.get(
      '/dashboard/analytics${_buildQuery(params)}',
      (data) => DashboardAnalyticsData.fromJson(data as Map<String, dynamic>),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _buildQuery(Map<String, String> params) => params.isEmpty
      ? ''
      : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
}
