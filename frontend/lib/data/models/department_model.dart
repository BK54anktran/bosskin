class DepartmentNode {
  final int id;
  final String name;
  final String code;
  final String? description;
  final int? parentId;
  final String? parentName;
  final int level;
  final int employeeCount;
  final int? managerId;
  final String? managerName;
  final List<DepartmentNode> children;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final int checkInRadiusMeters;

  const DepartmentNode({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.parentId,
    this.parentName,
    required this.level,
    required this.employeeCount,
    this.managerId,
    this.managerName,
    required this.children,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkInRadiusMeters = 100,
  });

  factory DepartmentNode.fromJson(Map<String, dynamic> j) => DepartmentNode(
        id: j['id'],
        name: j['name'],
        code: j['code'],
        description: j['description'],
        parentId: j['parentId'],
        parentName: j['parentName'],
        level: j['level'] ?? 0,
        employeeCount: j['employeeCount'] ?? 0,
        managerId: j['managerId'],
        managerName: j['managerName'],
        children: (j['children'] as List? ?? [])
            .map((e) => DepartmentNode.fromJson(e))
            .toList(),
        checkInLatitude: (j['checkInLatitude'] as num?)?.toDouble(),
        checkInLongitude: (j['checkInLongitude'] as num?)?.toDouble(),
        checkInRadiusMeters: (j['checkInRadiusMeters'] as num?)?.toInt() ?? 100,
      );
}

class DepartmentFlat {
  final int id;
  final String name;
  final String code;
  final int? parentId;
  final int level;
  final int employeeCount;

  const DepartmentFlat({
    required this.id,
    required this.name,
    required this.code,
    this.parentId,
    required this.level,
    required this.employeeCount,
  });

  factory DepartmentFlat.fromJson(Map<String, dynamic> j) => DepartmentFlat(
        id: j['id'],
        name: j['name'],
        code: j['code'],
        parentId: j['parentId'],
        level: j['level'] ?? 0,
        employeeCount: j['employeeCount'] ?? 0,
      );
}
