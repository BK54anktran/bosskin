import 'package:flutter/material.dart';
import '../../core/navigation/nav_menu.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/navigator_keys.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/team_approval_service.dart';
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
    TeamApprovalService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    TeamApprovalService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final user = AuthService.instance.currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final location = GoRouterState.of(context).uri.path;

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
            child: GroupedNavList(
              location: location,
              fontSize: 14,
              onNavigate: () => Navigator.pop(context),
              go: (route) {
                while (shellNavigatorKey.currentState?.canPop() == true) {
                  shellNavigatorKey.currentState!.pop();
                }
                context.go(route);
              },
            ),
          ),
        ],
      ),
    );
  }
}
