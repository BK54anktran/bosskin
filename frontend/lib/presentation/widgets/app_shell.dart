import 'dart:async';

import 'package:flutter/material.dart';
import 'notification_tile.dart';
import '../../core/navigation/nav_access.dart';
import '../../core/navigation/nav_menu.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/language_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/company_feature_service.dart';
import '../../data/services/team_approval_service.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import 'app_drawer.dart';
import '../../core/navigation/navigator_keys.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String location;

  const AppShell({required this.location, required this.child, super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _sidebarCtrl;
  late final Animation<double> _sidebarAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sidebarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _sidebarAnim = CurvedAnimation(
      parent: _sidebarCtrl,
      curve: Curves.easeInOut,
    );
    AuthService.instance.addListener(_onAuthChanged);
    LanguageService.instance.addListener(_onLocaleChanged);
    TeamApprovalService.instance.addListener(_onLocaleChanged);
    TeamApprovalService.instance.refresh();
    CompanyFeatureService.instance.addListener(_onLocaleChanged);
    CompanyFeatureService.instance.refresh();
    NotificationService.instance.refreshInbox();
    _inboxTimer = Timer.periodic(const Duration(minutes: 2), (_) => NotificationService.instance.refreshInbox());
  }

  Timer? _inboxTimer;

  @override
  void dispose() {
    _inboxTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AuthService.instance.removeListener(_onAuthChanged);
    LanguageService.instance.removeListener(_onLocaleChanged);
    TeamApprovalService.instance.removeListener(_onLocaleChanged);
    CompanyFeatureService.instance.removeListener(_onLocaleChanged);
    _sidebarCtrl.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
    TeamApprovalService.instance.refresh();
    CompanyFeatureService.instance.refresh();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      TeamApprovalService.instance.refresh();
      CompanyFeatureService.instance.refresh();
    }
  }

  PreferredSizeWidget _impersonationBanner(BuildContext context, AppLocalizations s) {
    final company = AuthService.instance.impersonatingUser?.companyName ?? '';
    return PreferredSize(
      preferredSize: const Size.fromHeight(36),
      child: Container(
        height: 36,
        color: AppTheme.warning.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 18, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.impersonationBanner(company),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              await AuthService.instance.logoutCompany();
              if (context.mounted) context.go(AppRoutes.adminDashboard);
            },
            child: Text(s.impersonationExit),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    final bottomItems = _bottomNavItems(s);
    final user = AuthService.instance.currentUser;
    final visibleBottomItems =
        bottomItems.where((item) => showInMenu(user, item.route)).toList();

    int? bottomIndex;
    if (!isWide) {
      for (var i = 0; i < visibleBottomItems.length; i++) {
        final item = visibleBottomItems[i];
        if (widget.location == item.route ||
            (item.route != AppRoutes.dashboard &&
                widget.location.startsWith('${item.route}/'))) {
          bottomIndex = i;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: s.menu,
            onPressed: isWide
                ? () => setState(() {
                      if (_sidebarCtrl.status == AnimationStatus.dismissed) {
                        _sidebarCtrl.forward();
                      } else {
                        _sidebarCtrl.reverse();
                      }
                    })
                : () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(_titleFor(widget.location, s)),
        actions: [
          const _NotificationBell(),
          const SizedBox(width: 4),
          const AppProfileMenu(),
          const SizedBox(width: 8),
        ],        // F5: luôn hiện rõ khi system admin đang xem với quyền một công ty
        bottom: AuthService.instance.isImpersonating ? _impersonationBanner(context, s) : null,
      ),
      drawer: isWide ? null : const AppDrawer(),
      bottomNavigationBar: isWide || visibleBottomItems.isEmpty
          ? null
          // Thanh dưới luôn cố định → giữ gọn: chữ nhãn không phóng quá 1.1 theo cỡ chữ hệ thống, để nhiều chỗ cho nội dung
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.of(context).textScaler.clamp(maxScaleFactor: 1.1)),
              child: BottomNavigationBar(
              currentIndex: bottomIndex ?? 0,
              onTap: (i) {
                final route = visibleBottomItems[i].route;
                if (widget.location != route) {
                  while (shellNavigatorKey.currentState?.canPop() == true) {
                    shellNavigatorKey.currentState!.pop();
                  }
                  context.go(route);
                }
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: AppTheme.textSecondary,
              selectedFontSize: 10.5,
              unselectedFontSize: 10.5,
              items: visibleBottomItems
                  .map((item) => BottomNavigationBarItem(
                        icon: Icon(item.icon),
                        label: item.label,
                      ))
                  .toList(),
              ),
            ),
      body: isWide
          ? Row(
              children: [
                SizeTransition(
                  sizeFactor: _sidebarAnim,
                  axis: Axis.horizontal,
                  axisAlignment: -1,
                  child: SizedBox(
                    width: 220,
                    child: _SideNav(location: widget.location),
                  ),
                ),
                SizeTransition(
                  sizeFactor: _sidebarAnim,
                  axis: Axis.horizontal,
                  child: const VerticalDivider(width: 1, thickness: 1),
                ),
                Expanded(child: widget.child),
              ],
            )
          : widget.child,
    );
  }

  static List<_NavItem> _bottomNavItems(AppLocalizations s) => [
        _NavItem(s.dashboard, Icons.dashboard_outlined, AppRoutes.dashboard,
            requiredPermission: 'DASHBOARD_VIEW'),
        _NavItem(s.navCheckInShort, Icons.login_outlined, AppRoutes.checkInOut,
            requiredPermission: 'ATTENDANCE_SELF'),
        _NavItem(s.navRequestsShort, Icons.note_add_outlined,
            AppRoutes.attendanceRequests,
            requiredPermission: 'ATTENDANCE_SELF'),
        _NavItem(s.leaves, Icons.beach_access_outlined, AppRoutes.leaves,
            requiredPermission: 'LEAVE_VIEW'),
        _NavItem(s.navProfileShort, Icons.person_outline, AppRoutes.profile),
      ];

  static String _titleFor(String path, AppLocalizations s) {
    if (path.startsWith(AppRoutes.editRequests)) return s.editRequests;
    if (path.startsWith(AppRoutes.attendanceRequests)) {
      return s.attendanceRequests;
    }
    return switch (path) {
      AppRoutes.dashboard => s.dashboard,
      AppRoutes.employees => s.employees,
      AppRoutes.shiftSwaps => s.swapMenu,
      AppRoutes.shiftRegistration => s.shiftRegMenu,
      AppRoutes.departments => s.departments,
      AppRoutes.shifts => s.shifts,
      AppRoutes.roles => s.roles,
      AppRoutes.attendance => s.attendance,
      AppRoutes.leaves => s.leaves,
      AppRoutes.companySettings => s.companySettings,
      AppRoutes.checkInOut => s.checkInOut,
      AppRoutes.payroll => s.payroll,
      AppRoutes.selfPayroll => s.selfPayroll,
      AppRoutes.profile => s.profile,
      AppRoutes.notifications => s.notifications,
      AppRoutes.excelImportExport => s.navImportExport,
      AppRoutes.reports => s.reportScreenTitle,
      AppRoutes.auditLogs => s.auditLogTitle,
      AppRoutes.orgChart => s.orgChartTitle,
      AppRoutes.contracts => s.contractsTitle,
      AppRoutes.documents => s.docScreenTitle,
      AppRoutes.teamApprovals => s.teamApprovalsTitle,
      _ => s.appName,
    };
  }
}


class _SideNav extends StatelessWidget {
  final String location;

  const _SideNav({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppTheme.background,
      child: GroupedNavList(
        location: location,
        go: (route) {
          while (shellNavigatorKey.currentState?.canPop() == true) {
            shellNavigatorKey.currentState!.pop();
          }
          context.go(route);
        },
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  final String? requiredPermission;
  const _NavItem(this.label, this.icon, this.route, {this.requiredPermission});
}

// ── Notification Bell ────────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationService.instance.inbox,
      builder: (context, notifications, _) {
        final unread = notifications.where((n) => !n.isRead).length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: s.notifications,
              onPressed: () => _openPanel(context),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openPanel(BuildContext context) {
    NotificationService.instance.refreshInbox().then((_) => NotificationService.instance.markAllRead());
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
          child: const _NotificationSheet(),
        ),
      ),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationService.instance.inbox,
      builder: (context, notifications, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  s.notifications,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: NotificationService.instance.markAllRead,
                    child: Text(s.markAllAsRead,
                        style: const TextStyle(fontSize: 13)),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  tooltip: s.notificationsSettingsTab,
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.notifications);
                  },
                  color: AppTheme.textSecondary,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (notifications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      size: 48,
                      color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Text(
                    s.noNotificationsYet,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: notifications.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) => NotificationTile(notifications[i]),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class AppProfileMenu extends StatelessWidget {
  const AppProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([AuthService.instance, LanguageService.instance]),
      builder: (context, _) {
        final s = AppLocalizations.of(context);
        final user = AuthService.instance.currentUser;
        final displayName = user?.fullName ?? user?.email ?? s.user;
        final initials =
            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
        final avatarUrl =
            (user?.avatar?.isNotEmpty ?? false) ? user!.avatar : null;

        return PopupMenuButton<String>(
          offset: const Offset(0, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tooltip: '',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.primary,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
          ),
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              enabled: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? s.user,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (user?.email != null)
                    Text(
                      user!.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Text(s.personalInfo,
                      style: TextStyle(
                          fontSize: 14, color: AppTheme.textPrimary)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'language',
              child: Row(
                children: [
                  Icon(Icons.language_outlined,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.language,
                      style: TextStyle(
                          fontSize: 14, color: AppTheme.textPrimary),
                    ),
                  ),
                  Text(
                    LanguageService.instance.localeLabel,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 18, color: AppTheme.error),
                  const SizedBox(width: 10),
                  Text(s.logout,
                      style:
                          const TextStyle(color: AppTheme.error, fontSize: 14)),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'profile') {
              while (shellNavigatorKey.currentState?.canPop() == true) {
                shellNavigatorKey.currentState!.pop();
              }
              context.go(AppRoutes.profile);
            } else if (value == 'language') {
              await _showLanguageSheet(context);
            } else if (value == 'logout') {
              while (shellNavigatorKey.currentState?.canPop() == true) {
                shellNavigatorKey.currentState!.pop();
              }
              final hasAdminSession = await AuthService.instance.isAdminLoggedIn();
              if (hasAdminSession) {
                await AuthService.instance.logoutCompany();
                if (context.mounted) context.go(AppRoutes.adminDashboard);
              } else {
                await AuthService.instance.logout();
                if (context.mounted) context.go(AppRoutes.login);
              }
            }
          },
        );
      },
    );
  }
}

Future<void> _showLanguageSheet(BuildContext context) async {
  final current = LanguageService.instance.locale;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final s = AppLocalizations.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                s.chooseLanguage,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            RadioListTile<Locale>(
              value: LanguageService.vi,
              groupValue: current,
              onChanged: (value) async {
                if (value != null) {
                  await LanguageService.instance.setLocale(value);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                }
              },
              title: Text(s.vietnamese),
            ),
            RadioListTile<Locale>(
              value: LanguageService.en,
              groupValue: current,
              onChanged: (value) async {
                if (value != null) {
                  await LanguageService.instance.setLocale(value);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                }
              },
              title: Text(s.english),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
