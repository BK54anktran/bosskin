enum VariableScope { system, global, private }

class AllVariable {
  final int? id;
  final String name;
  final String label;
  final String? expression;
  final VariableScope scope;
  final String scopeLabel;
  final int? formulaId;
  final String? category;
  final bool showInFormula;

  const AllVariable({
    this.id,
    required this.name,
    required this.label,
    this.expression,
    required this.scope,
    required this.scopeLabel,
    this.formulaId,
    this.category,
    this.showInFormula = true,
  });

  factory AllVariable.fromJson(Map<String, dynamic> j) => AllVariable(
        id: j['id'] != null ? (j['id'] as num).toInt() : null,
        name: j['name'] as String,
        label: j['label'] as String? ?? '',
        expression: j['expression'] as String?,
        scope: switch (j['scope'] as String) {
          'GLOBAL' => VariableScope.global,
          'PRIVATE' => VariableScope.private,
          _ => VariableScope.system,
        },
        scopeLabel: j['scopeLabel'] as String,
        formulaId: j['formulaId'] != null ? (j['formulaId'] as num).toInt() : null,
        category: j['category'] as String?,
        showInFormula: j['showInFormula'] as bool? ?? true,
      );
}

class VariableUsage {
  final int formulaId;
  final String formulaLabel;
  final String effectiveDate;

  const VariableUsage({
    required this.formulaId,
    required this.formulaLabel,
    required this.effectiveDate,
  });

  factory VariableUsage.fromJson(Map<String, dynamic> j) => VariableUsage(
        formulaId: (j['formulaId'] as num).toInt(),
        formulaLabel: j['formulaLabel'] as String,
        effectiveDate: j['effectiveDate'] as String,
      );
}
