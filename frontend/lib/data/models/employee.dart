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
