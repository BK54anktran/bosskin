class FormulaVariable {
  final int id;
  final String name;
  final String label;
  final String expression;
  final String? category;
  final bool showInFormula;
  final DateTime? createdAt;

  const FormulaVariable({
    required this.id,
    required this.name,
    required this.label,
    required this.expression,
    this.category,
    this.showInFormula = true,
    this.createdAt,
  });

  factory FormulaVariable.fromJson(Map<String, dynamic> j) => FormulaVariable(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        label: j['label'] as String,
        expression: j['expression'] as String,
        category: j['category'] as String?,
        showInFormula: j['showInFormula'] as bool? ?? true,
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
      );
}

class FormulaVarValidationResult {
  final bool valid;
  final List<String> errors;

  const FormulaVarValidationResult({required this.valid, required this.errors});

  factory FormulaVarValidationResult.fromJson(Map<String, dynamic> j) =>
      FormulaVarValidationResult(
        valid: j['valid'] as bool,
        errors: (j['errors'] as List? ?? []).cast<String>(),
      );
}
