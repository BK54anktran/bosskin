enum PayType { daily, hourly }

class SalaryGrade {
  final int id;
  final int? departmentId;
  final String? departmentName;
  final String code;
  final String name;
  final PayType payType;
  final double baseRate;
  final DateTime? createdAt;

  const SalaryGrade({
    required this.id,
    this.departmentId,
    this.departmentName,
    required this.code,
    required this.name,
    required this.payType,
    required this.baseRate,
    this.createdAt,
  });

  factory SalaryGrade.fromJson(Map<String, dynamic> j) => SalaryGrade(
        id: (j['id'] as num).toInt(),
        departmentId: j['departmentId'] != null ? (j['departmentId'] as num).toInt() : null,
        departmentName: j['departmentName'] as String?,
        code: j['code'] as String,
        name: j['name'] as String,
        payType: (j['payType'] as String) == 'HOURLY' ? PayType.hourly : PayType.daily,
        baseRate: (j['baseRate'] as num).toDouble(),
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
      );
}
