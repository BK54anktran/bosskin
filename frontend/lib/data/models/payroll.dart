import 'salary_formula.dart';

enum PayrollStatus { draft, approved, paid }

class CustomFormulaSnapshot {
  final String name;
  final String expressionGross;
  final String expressionNet;
  final Map<String, String> customVars;
  final Map<String, DeductionVarEntry> deductionVars;
  final Map<String, DeductionVarEntry> incomeVars;
  final Map<String, DeductionVarEntry> allowanceVars;

  const CustomFormulaSnapshot({
    required this.name,
    required this.expressionGross,
    required this.expressionNet,
    this.customVars = const {},
    this.deductionVars = const {},
    this.incomeVars = const {},
    this.allowanceVars = const {},
  });

  factory CustomFormulaSnapshot.fromJson(Map<String, dynamic> j) => CustomFormulaSnapshot(
    name: j['name'] as String? ?? '',
    expressionGross: j['expressionGross'] as String? ?? '',
    expressionNet: j['expressionNet'] as String? ?? '',
    customVars: (j['customVars'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, v as String)),
    deductionVars: (j['deductionVars'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, DeductionVarEntry.fromJson(v as Map<String, dynamic>))),
    incomeVars: (j['incomeVars'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, DeductionVarEntry.fromJson(v as Map<String, dynamic>))),
    allowanceVars: (j['allowanceVars'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, DeductionVarEntry.fromJson(v as Map<String, dynamic>))),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'expressionGross': expressionGross,
    'expressionNet': expressionNet,
    'customVars': customVars,
    'deductionVars': deductionVars.map((k, v) => MapEntry(k, v.toJson())),
    'incomeVars': incomeVars.map((k, v) => MapEntry(k, v.toJson())),
    'allowanceVars': allowanceVars.map((k, v) => MapEntry(k, v.toJson())),
  };
}

class PayrollDeductionEntry {
  final String label;
  final double amount;
  final int sortOrder;
  const PayrollDeductionEntry({required this.label, required this.amount, this.sortOrder = 0});

  factory PayrollDeductionEntry.fromJson(Map<String, dynamic> j) =>
      PayrollDeductionEntry(
        label: j['label'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

class Payroll {
  final int id;
  final int employeeId;
  final String employeeName;
  final String? departmentName;
  final String? positionName;
  final int year;
  final int month;
  final double baseSalary;
  final double allowance;
  final double bonus;
  final double overtimePay;
  final double grossSalary;
  final double socialInsurance;
  final double healthInsurance;
  final double unemploymentInsurance;
  final double personalIncomeTax;
  /// Giảm trừ gia cảnh đã dùng (bản thân + người phụ thuộc); null với phiếu tạo trước V13.
  final double? familyDeduction;
  /// Lương đóng BHXH/BHYT sau trần; null với phiếu tạo trước V13.
  final double? insuranceBase;
  /// Bước M (V17): số người phụ thuộc được giảm trừ, phần BH công ty đóng; null với phiếu cũ.
  final int? dependents;
  final double? employerSocialIns;
  final double? employerHealthIns;
  final double? employerUnemploymentIns;
  final double otherDeductions;
  final Map<String, PayrollDeductionEntry> customDeductions;
  final Map<String, PayrollDeductionEntry> incomeEntries;
  final Map<String, PayrollDeductionEntry> allowanceEntries;
  final double netSalary;

  /// Tổng khấu trừ thống nhất (khớp backend Payroll.totalDeduction, Excel, báo cáo): GROSS − NET.
  double get totalDeduction => grossSalary - netSalary;

  /// Phần khấu trừ công thức NET tự trừ (bảo hiểm, thuế…) ngoài các khoản liệt kê riêng.
  double get formulaDeductionRemainder =>
      totalDeduction -
      customDeductions.values.fold(0.0, (s, e) => s + e.amount) -
      otherDeductions;
  final int? salaryGradeId;
  final String? salaryGradeCode;
  final String? salaryGradeName;
  final int? presentDays;
  final double? totalOvertimeHours;
  final double? dayHours;
  final double? nightHours;
  final double? dayOt;
  final double? nightOt;
  final PayrollStatus status;
  final String? note;
  final CustomFormulaSnapshot? customFormula;
  final DateTime? paidAt;
  final DateTime? approvedAt;
  final String? payType;
  /// Công chuẩn kỳ — có thể lẻ nửa ngày khi tính theo lịch làm việc (bước J).
  final num? standardWorkDays;
  final DateTime? periodFrom;
  final DateTime? periodTo;

  const Payroll({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.departmentName,
    this.positionName,
    required this.year,
    required this.month,
    required this.baseSalary,
    required this.allowance,
    required this.bonus,
    required this.overtimePay,
    required this.grossSalary,
    required this.socialInsurance,
    required this.healthInsurance,
    required this.unemploymentInsurance,
    required this.personalIncomeTax,
    this.familyDeduction,
    this.insuranceBase,
    this.dependents,
    this.employerSocialIns,
    this.employerHealthIns,
    this.employerUnemploymentIns,
    required this.otherDeductions,
    this.customDeductions = const {},
    this.incomeEntries = const {},
    this.allowanceEntries = const {},
    required this.netSalary,
    this.salaryGradeId,
    this.salaryGradeCode,
    this.salaryGradeName,
    this.presentDays,
    this.totalOvertimeHours,
    this.dayHours,
    this.nightHours,
    this.dayOt,
    this.nightOt,
    required this.status,
    this.note,
    this.customFormula,
    this.paidAt,
    this.approvedAt,
    this.payType,
    this.standardWorkDays,
    this.periodFrom,
    this.periodTo,
  });

  factory Payroll.fromJson(Map<String, dynamic> j) => Payroll(
        id: (j['id'] as num).toInt(),
        employeeId: (j['employeeId'] as num).toInt(),
        employeeName: j['employeeName'] as String? ?? '',
        departmentName: j['departmentName'] as String?,
        positionName: j['positionName'] as String?,
        year: (j['year'] as num).toInt(),
        month: (j['month'] as num).toInt(),
        baseSalary: (j['baseSalary'] as num).toDouble(),
        allowance: (j['allowance'] as num?)?.toDouble() ?? 0,
        bonus: (j['bonus'] as num?)?.toDouble() ?? 0,
        overtimePay: (j['overtimePay'] as num?)?.toDouble() ?? 0,
        grossSalary: (j['grossSalary'] as num).toDouble(),
        socialInsurance: (j['socialInsurance'] as num?)?.toDouble() ?? 0,
        healthInsurance: (j['healthInsurance'] as num?)?.toDouble() ?? 0,
        unemploymentInsurance: (j['unemploymentInsurance'] as num?)?.toDouble() ?? 0,
        personalIncomeTax: (j['personalIncomeTax'] as num?)?.toDouble() ?? 0,
        familyDeduction: (j['familyDeduction'] as num?)?.toDouble(),
        insuranceBase: (j['insuranceBase'] as num?)?.toDouble(),
        dependents: (j['dependents'] as num?)?.toInt(),
        employerSocialIns: (j['employerSocialIns'] as num?)?.toDouble(),
        employerHealthIns: (j['employerHealthIns'] as num?)?.toDouble(),
        employerUnemploymentIns: (j['employerUnemploymentIns'] as num?)?.toDouble(),
        otherDeductions: (j['otherDeductions'] as num?)?.toDouble() ?? 0,
        customDeductions: (j['customDeductions'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, PayrollDeductionEntry.fromJson(v as Map<String, dynamic>))),
        incomeEntries: (j['incomeEntries'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, PayrollDeductionEntry.fromJson(v as Map<String, dynamic>))),
        allowanceEntries: (j['allowanceEntries'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, PayrollDeductionEntry.fromJson(v as Map<String, dynamic>))),
        netSalary: (j['netSalary'] as num).toDouble(),
        salaryGradeId: (j['salaryGradeId'] as num?)?.toInt(),
        salaryGradeCode: j['salaryGradeCode'] as String?,
        salaryGradeName: j['salaryGradeName'] as String?,
        presentDays: (j['presentDays'] as num?)?.toInt(),
        totalOvertimeHours: (j['totalOvertimeHours'] as num?)?.toDouble(),
        dayHours: (j['dayHours'] as num?)?.toDouble(),
        nightHours: (j['nightHours'] as num?)?.toDouble(),
        dayOt: (j['dayOt'] as num?)?.toDouble(),
        nightOt: (j['nightOt'] as num?)?.toDouble(),
        status: _status(j['status'] as String?),
        note: j['note'] as String?,
        customFormula: j['customFormula'] != null
            ? CustomFormulaSnapshot.fromJson(j['customFormula'] as Map<String, dynamic>)
            : null,
        paidAt: j['paidAt'] != null ? DateTime.tryParse(j['paidAt'] as String) : null,
        approvedAt: j['approvedAt'] != null ? DateTime.tryParse(j['approvedAt'] as String) : null,
        payType: j['payType'] as String?,
        standardWorkDays: j['standardWorkDays'] as num?,
        periodFrom: j['periodFrom'] != null ? DateTime.tryParse(j['periodFrom'] as String) : null,
        periodTo: j['periodTo'] != null ? DateTime.tryParse(j['periodTo'] as String) : null,
      );

  static PayrollStatus _status(String? s) => switch (s?.toUpperCase()) {
        'APPROVED' => PayrollStatus.approved,
        'PAID'     => PayrollStatus.paid,
        _          => PayrollStatus.draft,
      };
}

class SalaryHistory {
  final int id;
  final int employeeId;
  final String employeeName;
  final double baseSalary;
  final DateTime effectiveDate;
  final String? note;
  final DateTime? createdAt;

  const SalaryHistory({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.baseSalary,
    required this.effectiveDate,
    this.note,
    this.createdAt,
  });

  factory SalaryHistory.fromJson(Map<String, dynamic> j) => SalaryHistory(
        id: (j['id'] as num).toInt(),
        employeeId: (j['employeeId'] as num).toInt(),
        employeeName: j['employeeName'] as String? ?? '',
        baseSalary: (j['baseSalary'] as num).toDouble(),
        effectiveDate: DateTime.parse(j['effectiveDate'] as String),
        note: j['note'] as String?,
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
      );
}
