enum EmployeeStatus { active, inactive, onLeave }
enum Gender { male, female, other }

class Employee {
  final int id;
  final String employeeCode;
  final String fullName;
  final String email;
  final String? phone;
  final String? personalEmail;
  final String? avatar;
  final Gender gender;
  final DateTime? dateOfBirth;
  final DateTime joinDate;
  final DateTime? leaveDate;
  final EmployeeStatus status;
  final int departmentId;
  final String departmentName;
  final int? positionId;
  final String? positionName;
  final int? salaryGradeId;
  final String? salaryGradeCode;
  final String? salaryGradeName;
  final String? address;
  final String? identityCard;
  final String? bankAccount;
  final String? bankName;
  final double? contractSalary;
  /// Bước M: thuế / bảo hiểm. MST, sổ BHXH, CCCD, tài khoản trả về dạng che (****1234) khi thiếu quyền
  /// EMPLOYEE_SENSITIVE_VIEW; gửi lại nguyên bản che thì backend giữ giá trị cũ.
  final String? taxCode;
  final String? socialInsuranceNo;
  final String? healthInsurancePlace;
  final DateTime? insuranceJoinDate;
  /// Bước K: quản lý trực tiếp (bản hiện hành).
  final int? managerId;
  final String? managerName;
  /// Đã gắn thiết bị chấm công (công ty bật gắn thiết bị)
  final bool deviceBound;
  final DateTime? boundDeviceAt;

  const Employee({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.email,
    this.phone,
    this.personalEmail,
    this.avatar,
    required this.gender,
    this.dateOfBirth,
    required this.joinDate,
    this.leaveDate,
    required this.status,
    required this.departmentId,
    required this.departmentName,
    required this.positionId,
    required this.positionName,
    this.salaryGradeId,
    this.salaryGradeCode,
    this.salaryGradeName,
    this.address,
    this.identityCard,
    this.bankAccount,
    this.bankName,
    this.contractSalary,
    this.taxCode,
    this.socialInsuranceNo,
    this.healthInsurancePlace,
    this.insuranceJoinDate,
    this.managerId,
    this.managerName,
    this.deviceBound = false,
    this.boundDeviceAt,
  });

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'],
        employeeCode: j['employeeCode'] ?? '',
        fullName: j['fullName'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'],
        personalEmail: j['personalEmail'],
        avatar: j['avatar'],
        gender: _gender(j['gender']),
        dateOfBirth: j['dateOfBirth'] != null ? DateTime.tryParse(j['dateOfBirth']) : null,
        joinDate: DateTime.parse(j['joinDate']),
        leaveDate: j['leaveDate'] != null ? DateTime.tryParse(j['leaveDate']) : null,
        status: _status(j['status']),
        departmentId: j['departmentId'],
        departmentName: j['departmentName'] ?? '',
        positionId: j['positionId'],
        positionName: j['positionName'],
        salaryGradeId: j['salaryGradeId'],
        salaryGradeCode: j['salaryGradeCode'],
        salaryGradeName: j['salaryGradeName'],
        address: j['address'],
        identityCard: j['identityCard'],
        bankAccount: j['bankAccount'],
        bankName: j['bankName'],
        contractSalary: (j['contractSalary'] as num?)?.toDouble(),
        taxCode: j['taxCode'] as String?,
        socialInsuranceNo: j['socialInsuranceNo'] as String?,
        healthInsurancePlace: j['healthInsurancePlace'] as String?,
        insuranceJoinDate: j['insuranceJoinDate'] != null ? DateTime.tryParse(j['insuranceJoinDate']) : null,
        managerId: (j['managerId'] as num?)?.toInt(),
        managerName: j['managerName'] as String?,
        deviceBound: j['deviceBound'] == true,
        boundDeviceAt: j['boundDeviceAt'] != null ? DateTime.tryParse(j['boundDeviceAt']) : null,
      );

  static EmployeeStatus _status(String? s) => switch (s?.toUpperCase()) {
        'ACTIVE' => EmployeeStatus.active,
        'INACTIVE' => EmployeeStatus.inactive,
        'ON_LEAVE' => EmployeeStatus.onLeave,
        _ => EmployeeStatus.active,
      };

  static Gender _gender(String? g) => switch (g?.toUpperCase()) {
        'FEMALE' => Gender.female,
        'OTHER' => Gender.other,
        _ => Gender.male,
      };
}

class EmployeeImportDiff {
  final String action; // "CREATE" | "UPDATE" | "NO_CHANGE"
  final String? employeeCode;
  final String fullName;
  final String? email;
  final String? departmentCode;
  final List<EmployeeFieldChange> changes;
  final List<String> warnings;

  const EmployeeImportDiff({
    required this.action,
    this.employeeCode,
    required this.fullName,
    this.email,
    this.departmentCode,
    required this.changes,
    this.warnings = const [],
  });

  factory EmployeeImportDiff.fromJson(Map<String, dynamic> j) =>
      EmployeeImportDiff(
        action: j['action'],
        employeeCode: j['employeeCode'],
        fullName: j['fullName'] ?? '',
        email: j['email'],
        departmentCode: j['departmentCode'],
        changes: (j['changes'] as List? ?? [])
            .map((e) => EmployeeFieldChange.fromJson(e))
            .toList(),
        warnings: (j['warnings'] as List? ?? []).cast<String>(),
      );
}

class EmployeeFieldChange {
  final String field;
  final String oldValue;
  final String newValue;

  const EmployeeFieldChange(
      {required this.field, required this.oldValue, required this.newValue});

  factory EmployeeFieldChange.fromJson(Map<String, dynamic> j) =>
      EmployeeFieldChange(
        field: j['field'],
        oldValue: j['oldValue'] ?? '',
        newValue: j['newValue'] ?? '',
      );
}
