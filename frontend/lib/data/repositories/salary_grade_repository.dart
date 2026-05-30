import '../models/salary_grade.dart';
import '../services/api_service.dart';

class SalaryGradeRepository {
  final _api = ApiService.instance;

  Future<List<SalaryGrade>> getAll({int? departmentId}) async {
    final params = <String, dynamic>{
      if (departmentId != null) 'departmentId': departmentId,
    };
    return _api.get(
      '/salary-grades',
      (data) => (data as List)
          .map((e) => SalaryGrade.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: params,
    );
  }

  Future<SalaryGrade> create({
    int? departmentId,
    required String code,
    required String name,
    required String payType,
    required double baseRate,
  }) async {
    return _api.post(
      '/salary-grades',
      (data) => SalaryGrade.fromJson(data as Map<String, dynamic>),
      {
        if (departmentId != null) 'departmentId': departmentId,
        'code': code,
        'name': name,
        'payType': payType,
        'baseRate': baseRate,
      },
    );
  }

  Future<SalaryGrade> update(
    int id, {
    String? name,
    String? payType,
    double? baseRate,
  }) async {
    return _api.put(
      '/salary-grades/$id',
      (data) => SalaryGrade.fromJson(data as Map<String, dynamic>),
      {
        if (name != null) 'name': name,
        if (payType != null) 'payType': payType,
        if (baseRate != null) 'baseRate': baseRate,
      },
    );
  }

  Future<void> delete(int id) async {
    await _api.delete('/salary-grades/$id');
  }
}
