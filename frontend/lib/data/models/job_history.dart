/// Bước K — một mốc trong quá trình công tác (phòng ban / chức vụ / bậc lương / quản lý từ ngày hiệu lực).
class JobHistory {
  final int id;
  final DateTime effectiveFrom;
  final String changeType; // HIRE | TRANSFER | PROMOTION | SALARY_CHANGE | MANAGER_CHANGE | OTHER
  final int departmentId;
  final String? departmentName;
  final int? positionId;
  final String? positionName;
  final int? salaryGradeId;
  final String? salaryGradeCode;
  final String? salaryGradeName;
  final int? managerId;
  final String? managerName;
  final String? note;
  final bool applied;
  final bool current;
  final String? createdByName;

  const JobHistory({
    required this.id,
    required this.effectiveFrom,
    required this.changeType,
    required this.departmentId,
    this.departmentName,
    this.positionId,
    this.positionName,
    this.salaryGradeId,
    this.salaryGradeCode,
    this.salaryGradeName,
    this.managerId,
    this.managerName,
    this.note,
    this.applied = false,
    this.current = false,
    this.createdByName,
  });

  /// Mốc chưa tới ngày — xoá được.
  bool get isFuture => !applied && !current;

  factory JobHistory.fromJson(Map<String, dynamic> j) => JobHistory(
        id: (j['id'] as num).toInt(),
        effectiveFrom: DateTime.parse(j['effectiveFrom'] as String),
        changeType: (j['changeType'] ?? 'OTHER').toString(),
        departmentId: (j['departmentId'] as num).toInt(),
        departmentName: j['departmentName'] as String?,
        positionId: (j['positionId'] as num?)?.toInt(),
        positionName: j['positionName'] as String?,
        salaryGradeId: (j['salaryGradeId'] as num?)?.toInt(),
        salaryGradeCode: j['salaryGradeCode'] as String?,
        salaryGradeName: j['salaryGradeName'] as String?,
        managerId: (j['managerId'] as num?)?.toInt(),
        managerName: j['managerName'] as String?,
        note: j['note'] as String?,
        applied: j['applied'] == true,
        current: j['current'] == true,
        createdByName: j['createdByName'] as String?,
      );
}

/// Một người trên sơ đồ tổ chức.
class OrgNode {
  final int id;
  final String employeeCode;
  final String fullName;
  final String? avatar;
  final int departmentId;
  final String departmentName;
  final String? positionName;
  final int? managerId;
  final bool departmentHead;

  const OrgNode({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    this.avatar,
    required this.departmentId,
    required this.departmentName,
    this.positionName,
    this.managerId,
    this.departmentHead = false,
  });

  factory OrgNode.fromJson(Map<String, dynamic> j) => OrgNode(
        id: (j['id'] as num).toInt(),
        employeeCode: (j['employeeCode'] ?? '').toString(),
        fullName: (j['fullName'] ?? '').toString(),
        avatar: j['avatar'] as String?,
        departmentId: (j['departmentId'] as num).toInt(),
        departmentName: (j['departmentName'] ?? '').toString(),
        positionName: j['positionName'] as String?,
        managerId: (j['managerId'] as num?)?.toInt(),
        departmentHead: j['departmentHead'] == true,
      );
}
