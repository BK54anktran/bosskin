import '../models/employee.dart';
import '../services/api_service.dart';

class EmployeeRepository {
  final _api = ApiService.instance;

  Future<({List<Employee> items, int total})> getAll({
    int page = 0,
    int size = 20,
    String? search,
    int? departmentId,
    EmployeeStatus? status,
  }) async {
    final params = {
      'page': page,
      'size': size,
      if (search != null) 'search': search,
      if (departmentId != null) 'departmentId': departmentId,
      if (status != null) 'status': status.name.toUpperCase(),
    };
    return _api.get(
      '/employees',
      (data) => (
        items: (data['content'] as List)
            .map((e) => Employee.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (data['totalElements'] as num?)?.toInt() ?? 0,
      ),
      queryParams: params,
    );
  }

  Future<Employee> getById(int id) async {
    return _api.get(
      '/employees/$id',
      (data) => Employee.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Employee> create(Map<String, dynamic> data) async {
    return _api.post(
      '/employees',
      (data) => Employee.fromJson(data as Map<String, dynamic>),
      data,
    );
  }

  Future<Employee> update(int id, Map<String, dynamic> data) async {
    return _api.put(
      '/employees/$id',
      (data) => Employee.fromJson(data as Map<String, dynamic>),
      data,
    );
  }

  Future<void> delete(int id) => _api.delete('/employees/$id');

  Future<Map<String, dynamic>> syncMissingUsers(String initialPassword) async {
    return _api.post(
      '/users/sync-from-employees',
      (data) => Map<String, dynamic>.from(data as Map),
      {'initialPassword': initialPassword},
    );
  }
}
