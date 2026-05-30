import '../models/salary_formula.dart';
import '../services/api_service.dart';

class SalaryFormulaRepository {
  final _api = ApiService.instance;

  Future<List<SalaryFormula>> getAll({int? gradeId}) async {
    return _api.get(
      '/salary-formulas',
      (data) => (data as List)
          .map((e) => SalaryFormula.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: gradeId != null ? {'gradeId': gradeId} : {},
    );
  }

  Future<FormulaValidationResult> validate(
      String gross, String net, Map<String, String> privateVars, {
      Map<String, DeductionVarEntry> deductionVars = const {},
      Map<String, DeductionVarEntry> incomeVars = const {},
      Map<String, DeductionVarEntry> allowanceVars = const {},
  }) async {
    return _api.post(
      '/salary-formulas/validate',
      (data) => FormulaValidationResult.fromJson(data as Map<String, dynamic>),
      {
        'expressionGross': gross,
        'expressionNet': net,
        'customVars': privateVars,
        'deductionVars': deductionVars.map((k, v) => MapEntry(k, v.toJson())),
        'incomeVars': incomeVars.map((k, v) => MapEntry(k, v.toJson())),
        'allowanceVars': allowanceVars.map((k, v) => MapEntry(k, v.toJson())),
      },
    );
  }

  Future<SalaryFormula> create({
    required int salaryGradeId,
    required String name,
    required DateTime effectiveDate,
    required String expressionGross,
    required String expressionNet,
    Map<String, String> customVars = const {},
    Map<String, DeductionVarEntry> deductionVars = const {},
    Map<String, DeductionVarEntry> incomeVars = const {},
    Map<String, DeductionVarEntry> allowanceVars = const {},
  }) async {
    return _api.post(
      '/salary-formulas',
      (data) => SalaryFormula.fromJson(data as Map<String, dynamic>),
      {
        'salaryGradeId': salaryGradeId,
        'name': name,
        'effectiveDate': effectiveDate.toIso8601String().substring(0, 10),
        'expressionGross': expressionGross,
        'expressionNet': expressionNet,
        'customVars': customVars,
        'deductionVars': deductionVars.map((k, v) => MapEntry(k, v.toJson())),
        'incomeVars': incomeVars.map((k, v) => MapEntry(k, v.toJson())),
        'allowanceVars': allowanceVars.map((k, v) => MapEntry(k, v.toJson())),
      },
    );
  }

  Future<SalaryFormula> update(
    int id, {
    required String name,
    DateTime? effectiveDate,
    required String expressionGross,
    required String expressionNet,
    Map<String, String> customVars = const {},
    Map<String, DeductionVarEntry> deductionVars = const {},
    Map<String, DeductionVarEntry> incomeVars = const {},
    Map<String, DeductionVarEntry> allowanceVars = const {},
  }) async {
    return _api.put(
      '/salary-formulas/$id',
      (data) => SalaryFormula.fromJson(data as Map<String, dynamic>),
      {
        'name': name,
        if (effectiveDate != null)
          'effectiveDate': effectiveDate.toIso8601String().substring(0, 10),
        'expressionGross': expressionGross,
        'expressionNet': expressionNet,
        'customVars': customVars,
        'deductionVars': deductionVars.map((k, v) => MapEntry(k, v.toJson())),
        'incomeVars': incomeVars.map((k, v) => MapEntry(k, v.toJson())),
        'allowanceVars': allowanceVars.map((k, v) => MapEntry(k, v.toJson())),
      },
    );
  }

  Future<void> delete(int id) async {
    await _api.delete('/salary-formulas/$id');
  }
}
