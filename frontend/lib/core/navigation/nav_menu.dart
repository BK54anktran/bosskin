import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bosskin/l10n/app_localizations.dart';
import '../../data/services/auth_service.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import 'nav_access.dart';

/// Menu trái (màn rộng) và drawer (điện thoại) dùng CHUNG danh sách nhóm này.
/// Quyền hiển thị vẫn do [showInMenu] trong nav_access.dart quyết định;
/// nhóm không còn mục nào hiển thị sẽ bị ẩn cả tiêu đề.
class NavEntry {
  final String label;
  final IconData icon;
  final String route;
  final Color? activeColor;
  const NavEntry(this.label, this.icon, this.route, {this.activeColor});
}

class NavGroup {
  /// Khoá lưu trạng thái thu gọn — không đổi khi đổi ngôn ngữ.
  final String id;

  /// null = nhóm đầu, không có tiêu đề, không thu gọn được.
  final String? title;
  final List<NavEntry> entries;
  const NavGroup(this.id, this.title, this.entries);
}

List<NavGroup> navGroups(AppLocalizations s) => [
      NavGroup('home', null, [
        NavEntry(s.dashboard, Icons.dashboard_outlined, AppRoutes.dashboard),
      ]),
      NavGroup('self', s.navGroupSelf, [
        NavEntry(s.checkInOut, Icons.login_outlined, AppRoutes.checkInOut),
        NavEntry(s.shiftRegMenu, Icons.edit_calendar_outlined, AppRoutes.shiftRegistration),
        NavEntry(s.selfPayroll, Icons.receipt_long_outlined, AppRoutes.selfPayroll),
        NavEntry(s.personalInfo, Icons.person_outline, AppRoutes.profile),
      ]),
      NavGroup('requests', s.navGroupRequests, [
        NavEntry(s.attendanceRequests, Icons.note_add_outlined, AppRoutes.attendanceRequests),
        NavEntry(s.leaves, Icons.beach_access_outlined, AppRoutes.leaves),
        NavEntry(s.swapMenu, Icons.swap_horiz, AppRoutes.shiftSwaps),
        NavEntry(s.teamApprovalsTitle, Icons.how_to_reg_outlined, AppRoutes.teamApprovals),
        NavEntry(s.editRequests, Icons.assignment_outlined, AppRoutes.editRequests,
            activeColor: AppTheme.warning),
      ]),
      NavGroup('hr', s.navGroupHr, [
        NavEntry(s.employees, Icons.people_outline, AppRoutes.employees),
        NavEntry(s.orgChartTitle, Icons.lan_outlined, AppRoutes.orgChart),
        NavEntry(s.departments, Icons.account_tree_outlined, AppRoutes.departments),
        NavEntry(s.contractsTitle, Icons.description_outlined, AppRoutes.contracts),
        NavEntry(s.docScreenTitle, Icons.folder_shared_outlined, AppRoutes.documents),
      ]),
      NavGroup('time', s.navGroupTime, [
        NavEntry(s.shifts, Icons.calendar_month_outlined, AppRoutes.shifts),
        NavEntry(s.attendance, Icons.access_time_outlined, AppRoutes.attendance),
      ]),
      NavGroup('pay', s.navGroupPayReports, [
        NavEntry(s.payroll, Icons.payments_outlined, AppRoutes.payroll),
        NavEntry(s.reportScreenTitle, Icons.analytics_outlined, AppRoutes.reports),
        NavEntry(s.navImportExport, Icons.import_export_outlined, AppRoutes.excelImportExport),
      ]),
      NavGroup('system', s.navGroupSystem, [
        NavEntry(s.companySettings, Icons.tune_outlined, AppRoutes.companySettings),
        NavEntry(s.roles, Icons.admin_panel_settings_outlined, AppRoutes.roles),
        NavEntry(s.auditLogTitle, Icons.history_outlined, AppRoutes.auditLogs),
      ]),
    ];

/// Route đang mở khớp mục nào: khớp đúng, hoặc tiền tố dài nhất
/// (vd. /profile/edit-requests thuộc "Yêu cầu chỉnh sửa", không phải "Thông tin cá nhân").
String? activeNavRoute(String location, Iterable<String> routes) {
  String? best;
  for (final r in routes) {
    if (location == r) return r;
    if (location.startsWith('$r/') && (best == null || r.length > best.length)) best = r;
  }
  return best;
}

/// Nhóm nào đang thu gọn — nhớ giữa các lần mở app.
class NavCollapseState extends ChangeNotifier {
  NavCollapseState._();
  static final NavCollapseState instance = NavCollapseState._();
  static const _key = 'nav_collapsed_groups';

  final Set<String> _collapsed = {};
  bool _loaded = false;

  bool isCollapsed(String id) => _collapsed.contains(id);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _collapsed.addAll(prefs.getStringList(_key) ?? const []);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle(String id) async {
    if (!_collapsed.remove(id)) _collapsed.add(id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _collapsed.toList());
    } catch (_) {}
  }
}

/// Danh sách menu có nhóm. [onNavigate] chạy trước khi chuyển màn (vd. đóng drawer).
class GroupedNavList extends StatefulWidget {
  final String location;
  final VoidCallback? onNavigate;
  final void Function(String route) go;
  final double fontSize;

  const GroupedNavList({
    required this.location,
    required this.go,
    this.onNavigate,
    this.fontSize = 13,
    super.key,
  });

  @override
  State<GroupedNavList> createState() => _GroupedNavListState();
}

class _GroupedNavListState extends State<GroupedNavList> {
  @override
  void initState() {
    super.initState();
    NavCollapseState.instance.addListener(_changed);
    NavCollapseState.instance.load();
  }

  @override
  void dispose() {
    NavCollapseState.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final user = AuthService.instance.currentUser;
    final groups = navGroups(s)
        .map((g) => NavGroup(g.id, g.title,
            g.entries.where((e) => showInMenu(user, e.route)).toList()))
        .where((g) => g.entries.isNotEmpty)
        .toList();
    final active = activeNavRoute(
        widget.location, groups.expand((g) => g.entries).map((e) => e.route));

    final children = <Widget>[];
    for (final g in groups) {
      final hasActive = g.entries.any((e) => e.route == active);
      // Nhóm chứa màn đang mở luôn mở ra, để người dùng thấy mình đang ở đâu.
      final collapsed = g.title != null && !hasActive && NavCollapseState.instance.isCollapsed(g.id);
      if (g.title != null) {
        children.add(_header(g, collapsed, hasActive));
      }
      if (!collapsed) {
        for (final e in g.entries) {
          children.add(_tile(e, e.route == active));
        }
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
      children: children,
    );
  }

  Widget _header(NavGroup g, bool collapsed, bool hasActive) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: hasActive ? null : () => NavCollapseState.instance.toggle(g.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(children: [
            Expanded(
              child: Text(
                g.title!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            if (!hasActive)
              Icon(collapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 16, color: AppTheme.textSecondary),
          ]),
        ),
      ),
    );
  }

  Widget _tile(NavEntry e, bool isActive) {
    final color = e.activeColor ?? AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isActive ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          minLeadingWidth: 20,
          horizontalTitleGap: 12,
          leading: Icon(e.icon, size: 20, color: isActive ? color : AppTheme.textSecondary),
          title: Text(
            e.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? color : AppTheme.textPrimary,
            ),
          ),
          onTap: () {
            widget.onNavigate?.call();
            widget.go(e.route);
          },
        ),
      ),
    );
  }
}
