import '../models/all_variable.dart';
import '../models/formula_variable.dart';
import '../services/api_service.dart';

class FormulaVariableRepository {
  final _api = ApiService.instance;

  Future<List<FormulaVariable>> getAll() async {
    return _api.get(
      '/formula-variables',
      (data) => (data as List)
          .map((e) => FormulaVariable.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<FormulaVarValidationResult> validate(String name, String expression) async {
    return _api.post(
      '/formula-variables/validate',
      (data) => FormulaVarValidationResult.fromJson(data as Map<String, dynamic>),
      {'name': name, 'expression': expression},
    );
  }

  Future<List<String>> getCategories() async {
    return _api.get(
      '/formula-variables/categories',
      (data) => (data as List).cast<String>(),
    );
  }

  Future<FormulaVariable> create({
    required String name,
    required String label,
    required String expression,
    String? category,
  }) async {
    return _api.post(
      '/formula-variables',
      (data) => FormulaVariable.fromJson(data as Map<String, dynamic>),
      {
        'name': name,
        'label': label,
        'expression': expression,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
  }

  Future<FormulaVariable> update(int id,
      {String? name, String? label, String? expression, String? category}) async {
    return _api.put(
      '/formula-variables/$id',
      (data) => FormulaVariable.fromJson(data as Map<String, dynamic>),
      {
        if (name != null) 'name': name,
        if (label != null) 'label': label,
        if (expression != null) 'expression': expression,
        if (category != null) 'category': category,
      },
    );
  }

  Future<FormulaVariable> toggleShowInFormula(int id, bool show) async {
    return _api.patch(
      '/formula-variables/$id/show-in-formula',
      (data) => FormulaVariable.fromJson(data as Map<String, dynamic>),
      {'showInFormula': show},
    );
  }

  Future<void> delete(int id) async {
    await _api.delete('/formula-variables/$id');
  }

  Future<List<AllVariable>> getAllVariables() async {
    return _api.get(
      '/formula-variables/all',
      (data) => (data as List)
          .map((e) => AllVariable.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<VariableUsage>> getUsages(int id) async {
    return _api.get(
      '/formula-variables/$id/usages',
      (data) => (data as List)
          .map((e) => VariableUsage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
