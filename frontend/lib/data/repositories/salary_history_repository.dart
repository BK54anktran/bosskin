import '../models/payroll.dart';
import '../services/api_service.dart';

class SalaryHistoryRepository {
  final _api = ApiService.instance;

  Future<List<SalaryHistory>> getByEmployee(int employeeId) async {
    return _api.get(
      '/salary-histories',
      (data) => (data as List)
          .map((e) => SalaryHistory.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: {'employeeId': employeeId},
    );
  }

  Future<SalaryHistory> create({
    required int employeeId,
    required double baseSalary,
    required DateTime effectiveDate,
    String? note,
  }) async {
    return _api.post(
      '/salary-histories',
      (data) => SalaryHistory.fromJson(data as Map<String, dynamic>),
      {
        'employeeId': employeeId,
        'baseSalary': baseSalary,
        'effectiveDate':
            '${effectiveDate.year.toString().padLeft(4, '0')}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}',
        if (note != null) 'note': note,
      },
    );
  }

  Future<SalaryHistory> update(
    int id, {
    required double baseSalary,
    required DateTime effectiveDate,
    String? note,
  }) async {
    return _api.put(
      '/salary-histories/$id',
      (data) => SalaryHistory.fromJson(data as Map<String, dynamic>),
      {
        'baseSalary': baseSalary,
        'effectiveDate':
            '${effectiveDate.year.toString().padLeft(4, '0')}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}',
        'note': note,
      },
    );
  }

  Future<void> delete(int id) async {
    await _api.delete('/salary-histories/$id');
  }
}
