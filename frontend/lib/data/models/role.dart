import '../../core/utils/default_text_utils.dart';
class AppPermission {
  final int id;
  final String code;
  final String description;
  final String module;
  final String? requiredRule;

  const AppPermission({
    required this.id,
    required this.code,
    required this.description,
    required this.module,
    this.requiredRule,
  });

  factory AppPermission.fromJson(Map<String, dynamic> json) => AppPermission(
        id: json['id'] as int,
        code: json['code'] as String,
        description: json['description'] as String,
        module: json['module'] as String,
        requiredRule: json['requiredRule'] as String?,
      );
}

class AppRole {
  final int id;
  final String name;
  final String? description;
  final bool isDefault;
  final bool roleViewAllCompany;
  final int? roleViewDepartmentId;
  final List<AppPermission> permissions;

  const AppRole({
    required this.id,
    required this.name,
    this.description,
    required this.isDefault,
    required this.roleViewAllCompany,
    this.roleViewDepartmentId,
    required this.permissions,
  });

  factory AppRole.fromJson(Map<String, dynamic> json) => AppRole(
        id: json['id'] as int,
        name: localizeDefaultRoleName(json['name'] as String,
            isDefault: (json['default'] ?? json['isDefault']) as bool? ?? false),
        description: localizeDefaultTextOrNull(json['description'] as String?),
        isDefault: (json['default'] ?? json['isDefault']) as bool? ?? false,
        roleViewAllCompany: json['roleViewAllCompany'] as bool? ?? true,
        roleViewDepartmentId: (json['roleViewDepartmentId'] as num?)?.toInt(),
        permissions: (json['permissions'] as List<dynamic>? ?? [])
            .map((e) => AppPermission.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
