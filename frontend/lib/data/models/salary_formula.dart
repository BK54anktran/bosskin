class DeductionVarEntry {
  final String label;
  final String expression;
  final int sortOrder;
  const DeductionVarEntry({required this.label, required this.expression, this.sortOrder = 0});

  factory DeductionVarEntry.fromJson(Map<String, dynamic> j) => DeductionVarEntry(
        label: j['label'] as String? ?? '',
        expression: j['expression'] as String? ?? '',
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'label': label, 'expression': expression, 'sortOrder': sortOrder};
}

class SalaryFormula {
  final int id;
  final int salaryGradeId;
  final String salaryGradeCode;
  final String salaryGradeName;
  final String name;
  final int? departmentId;
  final String? departmentName;
  final DateTime effectiveDate;
  final String expressionGross;
  final String expressionNet;
  final Map<String, String> customVars;
  final Map<String, DeductionVarEntry> deductionVars;
  final Map<String, DeductionVarEntry> incomeVars;
  final Map<String, DeductionVarEntry> allowanceVars;
  final DateTime? createdAt;

  const SalaryFormula({
    required this.id,
    required this.salaryGradeId,
    required this.salaryGradeCode,
    required this.salaryGradeName,
    required this.name,
    this.departmentId,
    this.departmentName,
    required this.effectiveDate,
    required this.expressionGross,
    required this.expressionNet,
    this.customVars = const {},
    this.deductionVars = const {},
    this.incomeVars = const {},
    this.allowanceVars = const {},
    this.createdAt,
  });

  factory SalaryFormula.fromJson(Map<String, dynamic> j) => SalaryFormula(
        id: (j['id'] as num).toInt(),
        salaryGradeId: (j['salaryGradeId'] as num).toInt(),
        salaryGradeCode: j['salaryGradeCode'] as String,
        salaryGradeName: j['salaryGradeName'] as String,
        name: j['name'] as String? ?? '',
        departmentId: j['departmentId'] != null ? (j['departmentId'] as num).toInt() : null,
        departmentName: j['departmentName'] as String?,
        effectiveDate: DateTime.parse(j['effectiveDate'] as String),
        expressionGross: j['expressionGross'] as String,
        expressionNet: j['expressionNet'] as String,
        customVars: (j['customVars'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as String)),
        deductionVars: (j['deductionVars'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, DeductionVarEntry.fromJson(v as Map<String, dynamic>))),
        incomeVars: (j['incomeVars'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, DeductionVarEntry.fromJson(v as Map<String, dynamic>))),
        allowanceVars: (j['allowanceVars'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, DeductionVarEntry.fromJson(v as Map<String, dynamic>))),
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
      );
}

class FormulaValidationResult {
  final bool valid;
  final List<String> errorsPrivate;
  final List<String> errorsDeduction;
  final List<String> errorsGross;
  final List<String> errorsNet;

  const FormulaValidationResult({
    required this.valid,
    this.errorsPrivate = const [],
    this.errorsDeduction = const [],
    required this.errorsGross,
    required this.errorsNet,
  });

  factory FormulaValidationResult.fromJson(Map<String, dynamic> j) =>
      FormulaValidationResult(
        valid: j['valid'] as bool,
        errorsPrivate: (j['errorsPrivate'] as List? ?? []).cast<String>(),
        errorsDeduction: (j['errorsDeduction'] as List? ?? []).cast<String>(),
        errorsGross: (j['errorsGross'] as List? ?? []).cast<String>(),
        errorsNet: (j['errorsNet'] as List? ?? []).cast<String>(),
      );
}
