enum PayrollStatus { draft, approved, paid }

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
  final double otherDeductions;
  final Map<String, PayrollDeductionEntry> customDeductions;
  final Map<String, PayrollDeductionEntry> incomeEntries;
  final Map<String, PayrollDeductionEntry> allowanceEntries;
  final double netSalary;
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
  final DateTime? paidAt;
  final DateTime? approvedAt;
  final String? payType;
  final int? standardWorkDays;
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
        paidAt: j['paidAt'] != null ? DateTime.tryParse(j['paidAt'] as String) : null,
        approvedAt: j['approvedAt'] != null ? DateTime.tryParse(j['approvedAt'] as String) : null,
        payType: j['payType'] as String?,
        standardWorkDays: (j['standardWorkDays'] as num?)?.toInt(),
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
