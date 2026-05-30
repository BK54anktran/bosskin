class Department {
  final int id;
  final String name;
  final String code;
  final String? description;
  final int? managerId;
  final String? managerName;
  final int employeeCount;

  const Department({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.managerId,
    this.managerName,
    required this.employeeCount,
  });

  factory Department.fromJson(Map<String, dynamic> j) => Department(
        id: j['id'],
        name: j['name'] ?? '',
        code: j['code'] ?? '',
        description: j['description'],
        managerId: j['managerId'],
        managerName: j['managerName'],
        employeeCount: j['employeeCount'] ?? 0,
      );
}

class Position {
  final int id;
  final String name;
  final String code;
  final int departmentId;
  final String? description;

  const Position({
    required this.id,
    required this.name,
    required this.code,
    required this.departmentId,
    this.description,
  });

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        id: j['id'],
        name: j['name'] ?? '',
        code: j['code'] ?? '',
        departmentId: j['departmentId'],
        description: j['description'],
      );
}
