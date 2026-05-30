import '../services/api_service.dart';

class LeaveRepository {
  final _api = ApiService.instance;

  Future<List<Map<String, dynamic>>> getTypes() async {
    return _api.get(
      '/leaves/types',
      (data) =>
          (data as List).map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<Map<String, dynamic>> createType(Map<String, dynamic> body) async {
    return _api.post(
        '/leaves/types', (data) => Map<String, dynamic>.from(data), body);
  }

  Future<Map<String, dynamic>> updateType(
      int id, Map<String, dynamic> body) async {
    return _api.put(
        '/leaves/types/$id', (data) => Map<String, dynamic>.from(data), body);
  }

  Future<void> deleteType(int id) async {
    await _api.delete('/leaves/types/$id');
  }

  Future<List<Map<String, dynamic>>> getRequests(
      {String? status, int? departmentId}) async {
    return _api.get(
      '/leaves/requests',
      (data) =>
          (data as List).map((e) => Map<String, dynamic>.from(e)).toList(),
      queryParams: {
        if (status != null) 'status': status,
        if (departmentId != null) 'departmentId': departmentId,
      },
    );
  }

  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> body) async {
    return _api.post(
        '/leaves/requests', (data) => Map<String, dynamic>.from(data), body);
  }

  Future<Map<String, dynamic>> approveRequest(int id,
      {String? adminNote}) async {
    return _api.put(
      '/leaves/requests/$id/approve',
      (data) => Map<String, dynamic>.from(data),
      {'adminNote': adminNote},
    );
  }

  Future<Map<String, dynamic>> rejectRequest(int id,
      {String? adminNote}) async {
    return _api.put(
      '/leaves/requests/$id/reject',
      (data) => Map<String, dynamic>.from(data),
      {'adminNote': adminNote},
    );
  }

  Future<Map<String, dynamic>> cancelRequest(int id) async {
    return _api.post(
      '/leaves/requests/$id/cancel',
      (data) => Map<String, dynamic>.from(data),
      {},
    );
  }

  Future<Map<String, dynamic>> setRequestApplied(int id, bool applied) async {
    return _api.put(
      '/leaves/requests/$id/applied',
      (data) => Map<String, dynamic>.from(data),
      {'applied': applied},
    );
  }

  Future<List<Map<String, dynamic>>> getGrants({
    int? employeeId,
    int? leaveTypeId,
    int? departmentId,
  }) async {
    return _api.get(
      '/leaves/grants',
      (data) =>
          (data as List).map((e) => Map<String, dynamic>.from(e)).toList(),
      queryParams: {
        if (employeeId != null) 'employeeId': employeeId,
        if (leaveTypeId != null) 'leaveTypeId': leaveTypeId,
        if (departmentId != null) 'departmentId': departmentId,
      },
    );
  }

  Future<Map<String, dynamic>> manualGrant(Map<String, dynamic> body) async {
    return _api.post('/leaves/grants/manual',
        (data) => Map<String, dynamic>.from(data), body);
  }

  Future<List<Map<String, dynamic>>> getAccrualRules() async {
    return _api.get(
      '/leaves/accrual-rules',
      (data) =>
          (data as List).map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<Map<String, dynamic>> createAccrualRule(
      Map<String, dynamic> body) async {
    return _api.post('/leaves/accrual-rules',
        (data) => Map<String, dynamic>.from(data), body);
  }

  Future<Map<String, dynamic>> updateAccrualRule(
      int id, Map<String, dynamic> body) async {
    return _api.put('/leaves/accrual-rules/$id',
        (data) => Map<String, dynamic>.from(data), body);
  }

  Future<void> deleteAccrualRule(int id) async {
    await _api.delete('/leaves/accrual-rules/$id');
  }

  Future<Map<String, dynamic>> runAccrual({String? date}) async {
    return _api.post(
      '/leaves/accrual-rules/run',
      (data) => Map<String, dynamic>.from(data),
      {},
    );
  }
}
