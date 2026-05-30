import 'role.dart';

class AppUser {
  final int id;
  final String email;
  final String? fullName;
  final String? avatar;
  final bool enabled;
  final List<AppRole> roles;
  final List<String> directPermissions;

  const AppUser({
    required this.id,
    required this.email,
    this.fullName,
    this.avatar,
    required this.enabled,
    required this.roles,
    this.directPermissions = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        email: json['email'] as String,
        fullName: json['fullName'] as String?,
        avatar: json['avatar'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        roles: (json['roles'] as List<dynamic>? ?? [])
            .map((e) => AppRole.fromJson(e as Map<String, dynamic>))
            .toList(),
        directPermissions: (json['directPermissions'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}
