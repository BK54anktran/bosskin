import '../models/dashboard.dart';
import '../services/api_service.dart';

class DashboardRepository {
  final _api = ApiService.instance;

  Future<DashboardData> get() async {
    return _api.get(
      '/dashboard',
      (data) => DashboardData.fromJson(data as Map<String, dynamic>),
    );
  }
}
