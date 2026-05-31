import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/navigation/navigator_keys.dart';
import '../../core/localization/language_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import 'package:bosskin/l10n/app_localizations.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final user = AuthService.instance.currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final location = GoRouterState.of(context).uri.path;
    final items = _items(s);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.business, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'BossKin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (user != null) ...[
                  Text(
                    user.fullName ?? user.email,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isAdmin ? s.admin : s.employee,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4),
              children: [
                ...items.where((item) {
                  if (item.requiredPermission == null) return true;
                  if (user == null) return false;
                  if (item.route == AppRoutes.attendanceRequests) {
                    return user.isSystemAdmin ||
                        user.can('ATTENDANCE_SELF') ||
                        user.can('ATTENDANCE_MANAGE') ||
                        user.can('ATTENDANCE_REQUEST_APPROVE');
                  }
                  if (item.route == AppRoutes.shifts) {
                    return user.isSystemAdmin ||
                        user.can('SHIFT_VIEW') ||
                        user.can('SHIFT_MANAGE');
                  }
                  return user.isSystemAdmin ||
                      user.can(item.requiredPermission!);
                }).map((item) {
                  bool isActive;
                  if (location == item.route) {
                    isActive = true;
                  } else if (item.route == AppRoutes.dashboard) {
                    isActive = false;
                  } else {
                    final exactMatch = items.any((other) =>
                        other.route != item.route && location == other.route);
                    isActive = !exactMatch && location.startsWith('${item.route}/');
                  }
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        item.icon,
                        color: isActive
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                        size: 20,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        while (shellNavigatorKey.currentState?.canPop() == true) {
                          shellNavigatorKey.currentState!.pop();
                        }
                        context.go(item.route);
                      },
                    ),
                  );
                }),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline,
                      color: AppTheme.textSecondary, size: 20),
                  title: Text(
                    s.personalInfo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    while (shellNavigatorKey.currentState?.canPop() == true) {
                      shellNavigatorKey.currentState!.pop();
                    }
                    context.go(AppRoutes.profile);
                  },
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.assignment_outlined,
                        color: AppTheme.warning, size: 20),
                    title: Text(
                      s.editRequests,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      while (shellNavigatorKey.currentState?.canPop() == true) {
                        shellNavigatorKey.currentState!.pop();
                      }
                      context.go(AppRoutes.editRequests);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_DrawerItem> _items(AppLocalizations s) => [
        _DrawerItem(s.dashboard, Icons.dashboard_outlined, AppRoutes.dashboard,
            requiredPermission: 'DASHBOARD_VIEW'),
        _DrawerItem(s.employees, Icons.people_outline, AppRoutes.employees,
            requiredPermission: 'EMPLOYEE_VIEW'),
        _DrawerItem(
            s.departments, Icons.account_tree_outlined, AppRoutes.departments,
            requiredPermission: 'DEPARTMENT_VIEW'),
        _DrawerItem(s.shifts, Icons.calendar_month_outlined, AppRoutes.shifts,
            requiredPermission: 'SHIFT_VIEW'),
        _DrawerItem(
            s.roles, Icons.admin_panel_settings_outlined, AppRoutes.roles,
            requiredPermission: 'ROLE_VIEW'),
        _DrawerItem(
            s.attendance, Icons.access_time_outlined, AppRoutes.attendance,
            requiredPermission: 'ATTENDANCE_VIEW'),
        _DrawerItem(s.checkInOut, Icons.login_outlined, AppRoutes.checkInOut,
            requiredPermission: 'ATTENDANCE_SELF'),
        _DrawerItem(
          s.attendanceRequests,
          Icons.note_add_outlined,
          AppRoutes.attendanceRequests,
          requiredPermission: 'ATTENDANCE_SELF',
        ),
        _DrawerItem(s.leaves, Icons.beach_access_outlined, AppRoutes.leaves,
            requiredPermission: 'LEAVE_VIEW'),
        _DrawerItem(
            s.companySettings, Icons.tune_outlined, AppRoutes.companySettings,
            requiredPermission: 'COMPANY_SETTING_VIEW'),
        _DrawerItem(s.payroll, Icons.payments_outlined, AppRoutes.payroll,
            requiredPermission: 'PAYROLL_VIEW'),
        _DrawerItem(s.selfPayroll, Icons.receipt_long_outlined, AppRoutes.selfPayroll,
            requiredPermission: 'ATTENDANCE_SELF'),
      ];
}

class _DrawerItem {
  final String label;
  final IconData icon;
  final String route;
  final String? requiredPermission;
  const _DrawerItem(this.label, this.icon, this.route,
      {this.requiredPermission});
}
