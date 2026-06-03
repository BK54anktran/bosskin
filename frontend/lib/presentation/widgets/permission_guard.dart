import 'package:flutter/material.dart';
import '../../data/services/auth_service.dart';

class PermissionGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return fallback ?? const SizedBox.shrink();
    final normalized = permission.trim().toUpperCase().replaceAll('.', '_');
    if (user.isSystemAdmin || user.can(normalized)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
