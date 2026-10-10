/// Bước L — hợp đồng lao động, phụ lục, phụ cấp.
library;

const contractTypes = ['PROBATION', 'FIXED_TERM', 'INDEFINITE', 'SEASONAL', 'SERVICE'];

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String);

class ContractAllowance {
  final int? id;
  final String code;
  final String name;
  final double amount;
  final bool insurable;
  final bool taxable;

  const ContractAllowance({
    this.id,
    required this.code,
    required this.name,
    required this.amount,
    this.insurable = false,
    this.taxable = true,
  });

  factory ContractAllowance.fromJson(Map<String, dynamic> j) => ContractAllowance(
        id: (j['id'] as num?)?.toInt(),
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        amount: _d(j['amount']) ?? 0,
        insurable: j['insurable'] == true,
        taxable: j['taxable'] != false,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'amount': amount,
        'insurable': insurable,
        'taxable': taxable,
      };
}

class ContractAppendix {
  final int id;
  final String appendixNo;
  final DateTime effectiveFrom;
  final double? baseSalary;
  final double? insuranceSalary;
  final String? positionTitle;
  final bool overridesAllowances;
  final String? note;
  final List<ContractAllowance> allowances;

  const ContractAppendix({
    required this.id,
    required this.appendixNo,
    required this.effectiveFrom,
    this.baseSalary,
    this.insuranceSalary,
    this.positionTitle,
    this.overridesAllowances = false,
    this.note,
    this.allowances = const [],
  });

  factory ContractAppendix.fromJson(Map<String, dynamic> j) => ContractAppendix(
        id: (j['id'] as num).toInt(),
        appendixNo: (j['appendixNo'] ?? '').toString(),
        effectiveFrom: DateTime.parse(j['effectiveFrom'] as String),
        baseSalary: _d(j['baseSalary']),
        insuranceSalary: _d(j['insuranceSalary']),
        positionTitle: j['positionTitle'] as String?,
        overridesAllowances: j['overridesAllowances'] == true,
        note: j['note'] as String?,
        allowances: ((j['allowances'] as List?) ?? const [])
            .map((e) => ContractAllowance.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LaborContract {
  final int id;
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final int? departmentId;
  final String? departmentName;
  final String contractNo;
  final String contractType;
  /// Trạng thái lưu: DRAFT | ACTIVE | TERMINATED
  final String status;
  /// Hiển thị: DRAFT | ACTIVE | EXPIRED | TERMINATED
  final String displayStatus;
  final DateTime? signDate;
  final DateTime startDate;
  final DateTime? endDate;
  final double baseSalary;
  final double? insuranceSalary;
  final String? positionTitle;
  final String? note;
  final DateTime? terminationDate;
  final String? terminationReason;
  final double currentBaseSalary;
  final double currentInsuranceSalary;
  final double currentAllowanceTotal;
  final int? daysToEnd;
  final bool renewed;
  final List<ContractAllowance> allowances;
  final List<ContractAppendix> appendices;

  const LaborContract({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentId,
    this.departmentName,
    required this.contractNo,
    required this.contractType,
    required this.status,
    required this.displayStatus,
    this.signDate,
    required this.startDate,
    this.endDate,
    required this.baseSalary,
    this.insuranceSalary,
    this.positionTitle,
    this.note,
    this.terminationDate,
    this.terminationReason,
    required this.currentBaseSalary,
    required this.currentInsuranceSalary,
    required this.currentAllowanceTotal,
    this.daysToEnd,
    this.renewed = false,
    this.allowances = const [],
    this.appendices = const [],
  });

  bool get isDraft => status == 'DRAFT';
  bool get isActive => status == 'ACTIVE';
  bool get isTerminated => status == 'TERMINATED';

  /// Đang hiệu lực / đã hết hạn mà chưa có hợp đồng nối tiếp và còn trong ngưỡng báo trước.
  bool needsRenewal(int warningDays) =>
      isActive && !renewed && daysToEnd != null && daysToEnd! <= warningDays;

  factory LaborContract.fromJson(Map<String, dynamic> j) => LaborContract(
        id: (j['id'] as num).toInt(),
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: (j['employeeCode'] ?? '').toString(),
        employeeName: (j['employeeName'] ?? '').toString(),
        departmentId: (j['departmentId'] as num?)?.toInt(),
        departmentName: j['departmentName'] as String?,
        contractNo: (j['contractNo'] ?? '').toString(),
        contractType: (j['contractType'] ?? 'INDEFINITE').toString(),
        status: (j['status'] ?? 'DRAFT').toString(),
        displayStatus: (j['displayStatus'] ?? j['status'] ?? 'DRAFT').toString(),
        signDate: _date(j['signDate']),
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: _date(j['endDate']),
        baseSalary: _d(j['baseSalary']) ?? 0,
        insuranceSalary: _d(j['insuranceSalary']),
        positionTitle: j['positionTitle'] as String?,
        note: j['note'] as String?,
        terminationDate: _date(j['terminationDate']),
        terminationReason: j['terminationReason'] as String?,
        currentBaseSalary: _d(j['currentBaseSalary']) ?? 0,
        currentInsuranceSalary: _d(j['currentInsuranceSalary']) ?? 0,
        currentAllowanceTotal: _d(j['currentAllowanceTotal']) ?? 0,
        daysToEnd: (j['daysToEnd'] as num?)?.toInt(),
        renewed: j['renewed'] == true,
        allowances: ((j['allowances'] as List?) ?? const [])
            .map((e) => ContractAllowance.fromJson(e as Map<String, dynamic>))
            .toList(),
        appendices: ((j['appendices'] as List?) ?? const [])
            .map((e) => ContractAppendix.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
