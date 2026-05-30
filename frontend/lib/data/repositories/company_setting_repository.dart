import '../services/api_service.dart';

class CompanySettingRepository {
  final _api = ApiService.instance;

  Future<Map<String, dynamic>> get() async {
    return _api.get('/company-settings', (data) => Map<String, dynamic>.from(data));
  }

  Future<Map<String, dynamic>> update(Map<String, dynamic> body) async {
    return _api.put('/company-settings', (data) => Map<String, dynamic>.from(data), body);
  }
}
