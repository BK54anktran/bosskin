import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/text_utils.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/role.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/department_service.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/permission_guard.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/search_text_field.dart';

Future<T?> _showInstantDialog<T>(BuildContext context, WidgetBuilder builder,
    {bool dismissible = true}) {
  return showGeneralDialog<T>(
    context: context,
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionDuration: Duration.zero,
    barrierDismissible: dismissible,
    barrierLabel: '',
    barrierColor: Colors.black54,
  );
}

Future<T?> _showInstantSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: builder,
  );
}

// Only VIEW permissions support per-department scoping;
// write/manage permissions are bounded by their corresponding VIEW scope
const _deptScopeablePerms = {
  'EMPLOYEE_VIEW',
  'DEPARTMENT_VIEW',
  'ATTENDANCE_VIEW',
  'SHIFT_VIEW',
  'PAYROLL_VIEW',
  'LEAVE_VIEW',
  'ROLE_VIEW',
  'USER_MANAGE',
};

const _selfScopePerms = {
  'ATTENDANCE_VIEW',
  'PAYROLL_VIEW',
  'SHIFT_VIEW',
  'EMPLOYEE_VIEW',
  'LEAVE_VIEW',
};

const int _scopeSelfOnlyMarker = -1;
const int _scopeMyDeptOnlyMarker = -2;
const int _scopeMyDeptAndDescMarker = -3;

Widget _deptOptionLabel(DepartmentFlat d) {
  return Padding(
    padding: EdgeInsets.only(left: d.level > 0 ? d.level * 18.0 : 0),
    child: Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        if (d.level > 0) ...[
          Text(
            '+',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            '${d.name} (${d.code})',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Set<int> _expandedDepartmentScopeIds(
  List<DepartmentFlat> departments,
  int? rootDeptId,
) {
  if (rootDeptId == null) return <int>{};
  final childrenByParent = <int, List<int>>{};
  for (final d in departments) {
    final parentId = d.parentId;
    if (parentId == null) continue;
    childrenByParent.putIfAbsent(parentId, () => <int>[]).add(d.id);
  }
  final result = <int>{rootDeptId};
  final queue = <int>[rootDeptId];
  var index = 0;
  while (index < queue.length) {
    final current = queue[index++];
    for (final child in childrenByParent[current] ?? const <int>[]) {
      if (result.add(child)) queue.add(child);
    }
  }
  return result;
}

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, animationDuration: Duration.zero);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(text: s.roles),
              Tab(text: s.user),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              _RolesTab(),
              _UsersTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Roles Tab ─────────────────────────────────────────────────────────────────

class _RolesTab extends StatefulWidget {
  const _RolesTab();

  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  List<AppRole> _roles = [];
  List<AppPermission> _allPermissions = [];
  List<DepartmentFlat> _allDepts = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  int? _deptFilterId;
  bool _loading = true;
  String? _error;
  int _page = 0;
  int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      final q = foldSearchText(_searchCtrl.text);
      if (q != _query) {
        setState(() => _query = q);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.get<List<AppRole>>(
          '/roles',
          (data) => (data as List)
              .map((e) => AppRole.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        ApiService.instance.get<List<AppPermission>>(
          '/roles/permissions',
          (data) => (data as List)
              .map((e) => AppPermission.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      ]);
      if (mounted) {
        setState(() {
          _roles = results[0] as List<AppRole>;
          _allPermissions = results[1] as List<AppPermission>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = serverMsg(e);
          _loading = false;
        });
    }
    // Load departments separately — failure does not block role list
    try {
      final depts =
          await DepartmentService.instance.getFlat(permission: 'ROLE_MANAGE');
      if (mounted) setState(() => _allDepts = depts);
    } catch (_) {}
  }

  Future<void> _openEditDialog({AppRole? role}) async {
    final saved = await _showInstantDialog<bool>(
      context,
      (_) => _RoleEditDialog(
        role: role,
        allPermissions: _allPermissions,
        allDepartments: _allDepts,
      ),
    );
    if (saved == true) _load();
  }

  String _moduleLabel(AppLocalizations s, String module) => switch (module) {
        'EMPLOYEE' => s.employees,
        'DEPARTMENT' => s.departments,
        'ATTENDANCE' => s.attendance,
        'SHIFT' => s.shifts,
        'PAYROLL' => s.payroll,
        'ROLE' => s.roles,
        'USER' => s.user,
        'COMPANY' => s.company,
        _ => module,
      };

  String? _permUiHint(AppLocalizations s, String code) => switch (code) {
        'DASHBOARD_VIEW' => s.permUiDashboardView,
        'EMPLOYEE_VIEW' => s.permUiEmployeeView,
        'EMPLOYEE_CREATE' => s.permUiEmployeeCreate,
        'EMPLOYEE_UPDATE' => s.permUiEmployeeUpdate,
        'EMPLOYEE_DELETE' => s.permUiEmployeeDelete,
        'DEPARTMENT_VIEW' => s.permUiDepartmentView,
        'DEPARTMENT_MANAGE' => s.permUiDepartmentManage,
        'POSITION_MANAGE' => s.permUiPositionManage,
        'ATTENDANCE_VIEW' => s.permUiAttendanceView,
        'ATTENDANCE_MANAGE' => s.permUiAttendanceManage,
        'ATTENDANCE_SELF' => s.permUiAttendanceSelf,
        'ATTENDANCE_REQUEST_APPROVE' => s.permUiAttendanceApprove,
        'SHIFT_VIEW' => s.permUiShiftView,
        'SHIFT_MANAGE' => s.permUiShiftManage,
        'PAYROLL_VIEW' => s.permUiPayrollView,
        'PAYROLL_CREATE' => s.permUiPayrollCreate,
        'PAYROLL_APPROVE' => s.permUiPayrollApprove,
        'PAYROLL_PAY' => s.permUiPayrollPay,
        'ROLE_VIEW' => s.permUiRoleView,
        'ROLE_MANAGE' => s.permUiRoleManage,
        'USER_MANAGE' => s.permUiUserManage,
        'COMPANY_MANAGE' => s.permUiCompanyManage,
        'LEAVE_VIEW' => s.permUiLeaveView,
        'LEAVE_REQUEST_CREATE' => s.permUiLeaveRequestCreate,
        'LEAVE_REQUEST_APPROVE' => s.permUiLeaveRequestApprove,
        'LEAVE_GRANT_MANUAL' => s.permUiLeaveGrantManual,
        'LEAVE_TYPE_VIEW' => s.permUiLeaveTypeView,
        'LEAVE_TYPE_MANAGE' => s.permUiLeaveTypeManage,
        'LEAVE_ACCRUAL_VIEW' => s.permUiLeaveAccrualView,
        'LEAVE_ACCRUAL_MANAGE' => s.permUiLeaveAccrualManage,
        'COMPANY_SETTING_VIEW' => s.permUiCompanySettingView,
        'COMPANY_SETTING_MANAGE' => s.permUiCompanySettingManage,
        'LEAVE_REQUEST_CREATE_FOR_OTHERS' => s.permUiLeaveCreateForOthers,
        _ => null,
      };

  String _permissionDescription(
    AppLocalizations s,
    AppPermission perm,
  ) =>
      switch (perm.code) {
        'EMPLOYEE_VIEW' => s.permDescEmployeeView,
        'EMPLOYEE_CREATE' => s.permDescEmployeeCreate,
        'EMPLOYEE_UPDATE' => s.permDescEmployeeUpdate,
        'EMPLOYEE_DELETE' => s.permDescEmployeeDelete,
        'DEPARTMENT_VIEW' => s.permDescDepartmentView,
        'DEPARTMENT_MANAGE' => s.permDescDepartmentManage,
        'POSITION_MANAGE' => s.permDescPositionManage,
        'ATTENDANCE_VIEW' => s.permDescAttendanceView,
        'ATTENDANCE_MANAGE' => s.permDescAttendanceManage,
        'ATTENDANCE_SELF' => s.permDescAttendanceSelf,
        'ATTENDANCE_REQUEST_APPROVE' => s.permDescAttendanceApprove,
        'SHIFT_VIEW' => s.permDescShiftView,
        'SHIFT_MANAGE' => s.permDescShiftManage,
        'PAYROLL_VIEW' => s.permDescPayrollView,
        'PAYROLL_CREATE' => s.permDescPayrollCreate,
        'PAYROLL_APPROVE' => s.permDescPayrollApprove,
        'PAYROLL_PAY' => s.permDescPayrollPay,
        'ROLE_VIEW' => s.permDescRoleView,
        'ROLE_MANAGE' => s.permDescRoleManage,
        'USER_MANAGE' => s.permDescUserManage,
        'COMPANY_MANAGE' => s.permDescCompanyManage,
        'LEAVE_VIEW' => s.permDescLeaveView,
        'LEAVE_REQUEST_CREATE' => s.permDescLeaveRequestCreate,
        'LEAVE_REQUEST_APPROVE' => s.permDescLeaveRequestApprove,
        'LEAVE_GRANT_MANUAL' => s.permDescLeaveGrantManual,
        'LEAVE_TYPE_VIEW' => s.permDescLeaveTypeView,
        'LEAVE_TYPE_MANAGE' => s.permDescLeaveTypeManage,
        'LEAVE_ACCRUAL_VIEW' => s.permDescLeaveAccrualView,
        'LEAVE_ACCRUAL_MANAGE' => s.permDescLeaveAccrualManage,
        'COMPANY_SETTING_VIEW' => s.permDescCompanySettingView,
        'COMPANY_SETTING_MANAGE' => s.permDescCompanySettingManage,
        'LEAVE_REQUEST_CREATE_FOR_OTHERS' => s.permDescLeaveCreateForOthers,
        'DASHBOARD_VIEW' => s.permDescDashboardView,
        _ => perm.description,
      };

  Future<void> _delete(AppRole role) async {
    final s = AppLocalizations.of(context)!;
    final ok = await _showInstantDialog<bool>(
      context,
      (_) => AlertDialog(
        title: Text(s.deleteRoleTitle),
        content: Text(s.deleteRolePrompt(role.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.delete('/roles/${role.id}');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final deptScopeIds = _expandedDepartmentScopeIds(_allDepts, _deptFilterId);
    final filtered = _roles.where((r) {
      final matchesDept = _deptFilterId == null
          ? true
          : (_deptFilterId == 0
              ? r.roleViewAllCompany
              : (!r.roleViewAllCompany &&
                  r.roleViewDepartmentId != null &&
                  deptScopeIds.contains(r.roleViewDepartmentId!)));
      if (!matchesDept) return false;
      if (_query.isEmpty) return true;
      final byName = foldSearchText(r.name).contains(_query);
      final byDesc = foldSearchText(r.description ?? '').contains(_query);
      final byPerm =
          r.permissions.any((p) => foldSearchText(p.code).contains(_query));
      return byName || byDesc || byPerm;
    }).toList();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: Text(s.retry)),
        ]),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final searchField = SearchTextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                onClear: () => setState(() {}),
              );
              final deptField = DepartmentPickerField(
                departments: _allDepts,
                value: _deptFilterId == 0 ? null : _deptFilterId,
                allowAll: true,
                allLabel: _deptFilterId == 0 ? s.scopeCompanyLabel : s.all,
                label: s.department,
                compact: true,
                onChanged: (v) => setState(() => _deptFilterId = v),
              );
              final addBtn = PermissionGuard(
                permission: 'ROLE_MANAGE',
                child: FilledButton.icon(
                  onPressed: () => _openEditDialog(),
                  icon: const Icon(Icons.add),
                  label: Text(s.addRole),
                ),
              );
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: deptField),
                        const SizedBox(width: 8),
                        addBtn,
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 8),
                  deptField,
                  const SizedBox(width: 8),
                  addBtn,
                ],
              );
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.admin_panel_settings_outlined,
                  message: _roles.isEmpty ? s.noRolesYet : s.noResults,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _pageSize.clamp(0, filtered.length - _page * _pageSize),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = filtered[_page * _pageSize + i];
                      return _RoleCard(
                        role: r,
                        onTap: () => _openEditDialog(role: r),
                        onDelete: () => _delete(r),
                      );
                    },
                  ),
                ),
        ),
        PaginationBar(
          total: filtered.length,
          page: _page,
          pageSize: _pageSize,
          onPageSizeChanged: (v) => setState(() { _pageSize = v; _page = 0; }),
          onPrev: _page > 0 ? () => setState(() => _page--) : null,
          onNext: (_page + 1) * _pageSize < filtered.length ? () => setState(() => _page++) : null,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final AppRole role;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RoleCard({
    required this.role,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          role.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        if (role.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.defaultLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (role.description != null &&
                        role.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        role.description!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${role.permissions.length} ${s.permissionsLabel}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              PermissionGuard(
                permission: 'ROLE_MANAGE',
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: AppLocalizations.of(context)!.edit,
                  onPressed: onTap,
                ),
              ),
              PermissionGuard(
                permission: 'ROLE_MANAGE',
                child: role.isDefault
                    ? const SizedBox(width: 40)
                    : IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppTheme.error),
                        tooltip: AppLocalizations.of(context)!.delete,
                        onPressed: onDelete,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role Edit Dialog ──────────────────────────────────────────────────────────

class _RoleEditDialog extends StatefulWidget {
  final AppRole? role;
  final List<AppPermission> allPermissions;
  final List<DepartmentFlat> allDepartments;

  const _RoleEditDialog({
    this.role,
    required this.allPermissions,
    required this.allDepartments,
  });

  @override
  State<_RoleEditDialog> createState() => _RoleEditDialogState();
}

class _RoleEditDialogState extends State<_RoleEditDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<String> _selected = {};
  bool _roleViewAllCompany = true;
  int? _roleViewDepartmentId;
  // permCode → set of deptIds (empty = unrestricted / all company)
  Map<String, Set<int>> _deptScopes = {};
  bool _saving = false;

  void _togglePermission(AppPermission perm, bool enabled) {
    if (enabled) {
      _selected.add(perm.code);
      var reqCode = perm.requiredRule;
      while (reqCode != null) {
        _selected.add(reqCode);
        final reqPerm = widget.allPermissions.where((p) => p.code == reqCode).firstOrNull;
        reqCode = reqPerm?.requiredRule;
      }
      return;
    }
    _selected.remove(perm.code);
    _deptScopes.remove(perm.code);
    _disableDependents(perm.code);
  }

  void _disableDependents(String code) {
    for (final p in widget.allPermissions) {
      if (p.requiredRule == code && _selected.contains(p.code)) {
        _selected.remove(p.code);
        _deptScopes.remove(p.code);
        _disableDependents(p.code);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.role != null) {
      _nameCtrl.text = widget.role!.name;
      _descCtrl.text = widget.role!.description ?? '';
      _roleViewAllCompany = widget.role!.roleViewAllCompany;
      _roleViewDepartmentId = widget.role!.roleViewDepartmentId;
      _selected.addAll(widget.role!.permissions.map((p) => p.code));
      _loadDeptScopes();
    }
  }

  Future<void> _loadDeptScopes() async {
    try {
      final raw = await ApiService.instance.get<Map<String, dynamic>>(
        '/roles/${widget.role!.id}/dept-scopes',
        (d) => d as Map<String, dynamic>,
      );
      if (mounted) {
        setState(() {
          _deptScopes = raw.map((k, v) => MapEntry(
                k,
                (v as List).map((e) => (e as num).toInt()).toSet(),
              ));
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _moduleLabel(AppLocalizations s, String module) => switch (module) {
        'EMPLOYEE' => s.employees,
        'DEPARTMENT' => s.departments,
        'ATTENDANCE' => s.attendance,
        'SHIFT' => s.shifts,
        'PAYROLL' => s.payroll,
        'ROLE' => s.roles,
        'USER' => s.user,
        'COMPANY' => s.company,
        _ => module,
      };

  String? _permUiHint(AppLocalizations s, String code) => switch (code) {
        'DASHBOARD_VIEW' => s.permUiDashboardView,
        'EMPLOYEE_VIEW' => s.permUiEmployeeView,
        'EMPLOYEE_CREATE' => s.permUiEmployeeCreate,
        'EMPLOYEE_UPDATE' => s.permUiEmployeeUpdate,
        'EMPLOYEE_DELETE' => s.permUiEmployeeDelete,
        'DEPARTMENT_VIEW' => s.permUiDepartmentView,
        'DEPARTMENT_MANAGE' => s.permUiDepartmentManage,
        'POSITION_MANAGE' => s.permUiPositionManage,
        'ATTENDANCE_VIEW' => s.permUiAttendanceView,
        'ATTENDANCE_MANAGE' => s.permUiAttendanceManage,
        'ATTENDANCE_SELF' => s.permUiAttendanceSelf,
        'ATTENDANCE_REQUEST_APPROVE' => s.permUiAttendanceApprove,
        'SHIFT_VIEW' => s.permUiShiftView,
        'SHIFT_MANAGE' => s.permUiShiftManage,
        'PAYROLL_VIEW' => s.permUiPayrollView,
        'PAYROLL_CREATE' => s.permUiPayrollCreate,
        'PAYROLL_APPROVE' => s.permUiPayrollApprove,
        'PAYROLL_PAY' => s.permUiPayrollPay,
        'ROLE_VIEW' => s.permUiRoleView,
        'ROLE_MANAGE' => s.permUiRoleManage,
        'USER_MANAGE' => s.permUiUserManage,
        'COMPANY_MANAGE' => s.permUiCompanyManage,
        'LEAVE_VIEW' => s.permUiLeaveView,
        'LEAVE_REQUEST_CREATE' => s.permUiLeaveRequestCreate,
        'LEAVE_REQUEST_APPROVE' => s.permUiLeaveRequestApprove,
        'LEAVE_GRANT_MANUAL' => s.permUiLeaveGrantManual,
        'LEAVE_TYPE_VIEW' => s.permUiLeaveTypeView,
        'LEAVE_TYPE_MANAGE' => s.permUiLeaveTypeManage,
        'LEAVE_ACCRUAL_VIEW' => s.permUiLeaveAccrualView,
        'LEAVE_ACCRUAL_MANAGE' => s.permUiLeaveAccrualManage,
        'COMPANY_SETTING_VIEW' => s.permUiCompanySettingView,
        'COMPANY_SETTING_MANAGE' => s.permUiCompanySettingManage,
        'LEAVE_REQUEST_CREATE_FOR_OTHERS' => s.permUiLeaveCreateForOthers,
        _ => null,
      };

  String _permissionDescription(
    AppLocalizations s,
    AppPermission perm,
  ) =>
      switch (perm.code) {
        'EMPLOYEE_VIEW' => s.permDescEmployeeView,
        'EMPLOYEE_CREATE' => s.permDescEmployeeCreate,
        'EMPLOYEE_UPDATE' => s.permDescEmployeeUpdate,
        'EMPLOYEE_DELETE' => s.permDescEmployeeDelete,
        'DEPARTMENT_VIEW' => s.permDescDepartmentView,
        'DEPARTMENT_MANAGE' => s.permDescDepartmentManage,
        'POSITION_MANAGE' => s.permDescPositionManage,
        'ATTENDANCE_VIEW' => s.permDescAttendanceView,
        'ATTENDANCE_MANAGE' => s.permDescAttendanceManage,
        'ATTENDANCE_SELF' => s.permDescAttendanceSelf,
        'ATTENDANCE_REQUEST_APPROVE' => s.permDescAttendanceApprove,
        'SHIFT_VIEW' => s.permDescShiftView,
        'SHIFT_MANAGE' => s.permDescShiftManage,
        'PAYROLL_VIEW' => s.permDescPayrollView,
        'PAYROLL_CREATE' => s.permDescPayrollCreate,
        'PAYROLL_APPROVE' => s.permDescPayrollApprove,
        'PAYROLL_PAY' => s.permDescPayrollPay,
        'ROLE_VIEW' => s.permDescRoleView,
        'ROLE_MANAGE' => s.permDescRoleManage,
        'USER_MANAGE' => s.permDescUserManage,
        'COMPANY_MANAGE' => s.permDescCompanyManage,
        'LEAVE_VIEW' => s.permDescLeaveView,
        'LEAVE_REQUEST_CREATE' => s.permDescLeaveRequestCreate,
        'LEAVE_REQUEST_APPROVE' => s.permDescLeaveRequestApprove,
        'LEAVE_GRANT_MANUAL' => s.permDescLeaveGrantManual,
        'LEAVE_TYPE_VIEW' => s.permDescLeaveTypeView,
        'LEAVE_TYPE_MANAGE' => s.permDescLeaveTypeManage,
        'LEAVE_ACCRUAL_VIEW' => s.permDescLeaveAccrualView,
        'LEAVE_ACCRUAL_MANAGE' => s.permDescLeaveAccrualManage,
        'COMPANY_SETTING_VIEW' => s.permDescCompanySettingView,
        'COMPANY_SETTING_MANAGE' => s.permDescCompanySettingManage,
        'LEAVE_REQUEST_CREATE_FOR_OTHERS' => s.permDescLeaveCreateForOthers,
        'DASHBOARD_VIEW' => s.permDescDashboardView,
        _ => perm.description,
      };

  String _scopeLabel(AppLocalizations s, String permCode) {
    final ids = _deptScopes[permCode];
    if (ids == null || ids.isEmpty) return s.scopeCompanyLabel;
    if (ids.length == 1 && ids.contains(_scopeSelfOnlyMarker)) {
      return s.scopeSelfLabel;
    }
    if (ids.length == 1 && ids.contains(_scopeMyDeptOnlyMarker)) {
      return s.scopeMyDepartmentLabel;
    }
    if (ids.length == 1 && ids.contains(_scopeMyDeptAndDescMarker)) {
      return s.scopeMyDepartmentAndBelowLabel;
    }
    if (ids.contains(_scopeSelfOnlyMarker)) {
      return s.scopeSelfPlusDepartments(ids.length - 1);
    }
    if (ids.length == 1) {
      final dept =
          widget.allDepartments.where((d) => d.id == ids.first).firstOrNull;
      return dept?.name ?? s.scopeOneDepartment;
    }
    return s.scopeDepartments(ids.length);
  }

  Future<void> _showDeptPicker(
    String permCode,
    String permDesc, {
    bool allowSelfOnly = false,
  }) async {
    final initial = Set<int>.from(_deptScopes[permCode] ?? {});
    final result = await _showInstantDialog<Set<int>>(
      context,
      (_) => _DeptScopeDialog(
        permDescription: permDesc,
        departments: widget.allDepartments,
        initial: initial,
        allowSelfOnly: allowSelfOnly,
        allowMyDepartmentPresets:
            AuthService.instance.currentUser?.employeeId != null,
      ),
    );
    if (result != null) {
      setState(() {
        if (result.isEmpty) {
          _deptScopes.remove(permCode);
        } else {
          _deptScopes[permCode] = result;
        }
      });
    }
  }

  Future<void> _save() async {
    final s = AppLocalizations.of(context)!;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(s.roleNameRequired), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (!_roleViewAllCompany && _roleViewDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(s.pleaseChooseDepartment),
            backgroundColor: AppTheme.error),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // Build dept scopes: only include checked, scopeable permissions
      final scopeBody = <String, List<int>>{};
      for (final code in _deptScopeablePerms) {
        if (_selected.contains(code)) {
          scopeBody[code] = (_deptScopes[code] ?? {}).toList();
        }
      }

      final body = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'roleViewAllCompany': _roleViewAllCompany,
        'roleViewDepartmentId':
            _roleViewAllCompany ? null : _roleViewDepartmentId,
        'permissions': _selected.toList(),
        'deptScopes': scopeBody,
      };
      if (widget.role != null) {
        await ApiService.instance.put<Map<String, dynamic>>(
          '/roles/${widget.role!.id}',
          (data) => data as Map<String, dynamic>,
          body,
        );
      } else {
        await ApiService.instance.post<Map<String, dynamic>>(
          '/roles',
          (data) => data as Map<String, dynamic>,
          body,
        );
      }
      if (!mounted) return;
      final router = GoRouter.of(context);
      final oldPerms = AuthService.instance.currentUser?.permissions ?? {};
      Navigator.pop(context, true);

      // Refresh token to pick up role changes for the current user
      final refreshed = await AuthService.instance.refreshToken();
      if (refreshed) {
        final newPerms = AuthService.instance.currentUser?.permissions ?? {};
        if (!oldPerms.containsAll(newPerms) ||
            !newPerms.containsAll(oldPerms)) {
          router.go(AppRoutes.dashboard);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  List<Widget> _buildPermTree(
    AppLocalizations s,
    Map<String, List<AppPermission>> childrenMap,
    AppPermission perm,
    int depth,
  ) {
    final isChecked = _selected.contains(perm.code);
    final canEnable = perm.requiredRule == null || _selected.contains(perm.requiredRule);
    final isScopeable = _deptScopeablePerms.contains(perm.code);
    final indent = depth * 20.0;
    final result = <Widget>[];

    result.add(Padding(
      padding: EdgeInsets.only(left: indent),
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(_permissionDescription(s, perm),
            style: const TextStyle(fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(perm.code,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
            if (_permUiHint(s, perm.code) != null)
              Row(children: [
                const Icon(Icons.visibility_outlined,
                    size: 10, color: AppTheme.primary),
                const SizedBox(width: 3),
                Text(_permUiHint(s, perm.code)!,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.primary)),
              ]),
          ],
        ),
        value: isChecked,
        onChanged: (!canEnable && !isChecked)
            ? null
            : (v) {
                if (v == null) return;
                setState(() => _togglePermission(perm, v));
              },
      ),
    ));

    if (isChecked && isScopeable) {
      result.add(Padding(
        padding: EdgeInsets.only(left: indent + 12, bottom: 6),
        child: ActionChip(
          avatar: Icon(
            Icons.domain_outlined,
            size: 14,
            color: (_deptScopes[perm.code]?.isNotEmpty ?? false)
                ? Colors.orange[700]
                : AppTheme.primary,
          ),
          label: Text(
            _scopeLabel(s, perm.code),
            style: TextStyle(
              fontSize: 11,
              color: (_deptScopes[perm.code]?.isNotEmpty ?? false)
                  ? Colors.orange[700]
                  : AppTheme.primary,
            ),
          ),
          backgroundColor: (_deptScopes[perm.code]?.isNotEmpty ?? false)
              ? Colors.orange.withValues(alpha: 0.08)
              : AppTheme.primary.withValues(alpha: 0.08),
          side: BorderSide(
            color: (_deptScopes[perm.code]?.isNotEmpty ?? false)
                ? Colors.orange.withValues(alpha: 0.4)
                : AppTheme.primary.withValues(alpha: 0.3),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () => _showDeptPicker(
            perm.code,
            perm.description,
            allowSelfOnly: _selfScopePerms.contains(perm.code),
          ),
        ),
      ));
    }

    for (final child in (childrenMap[perm.code] ?? [])) {
      result.addAll(_buildPermTree(s, childrenMap, child, depth + 1));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final dialogHeight = MediaQuery.of(context).size.height * 0.95;
    final grouped = <String, List<AppPermission>>{};
    for (final p in widget.allPermissions) {
      grouped.putIfAbsent(p.module, () => []).add(p);
    }
    return AlertDialog(
      title: Text(widget.role != null ? s.editRole : s.addRole),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration:
                    InputDecoration(labelText: s.roleNameLabel, isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: InputDecoration(
                    labelText: s.descriptionLabel, isDense: true),
              ),
              const SizedBox(height: 16),
              DepartmentPickerField(
                departments: widget.allDepartments,
                value: _roleViewDepartmentId,
                label: s.department,
                allowAll: true,
                onChanged: (v) => setState(() {
                  _roleViewDepartmentId = v;
                  _roleViewAllCompany = v == null;
                }),
              ),
              const SizedBox(height: 8),
              Text(s.permissionsLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              ...grouped.entries.toList().asMap().entries.map((groupEntry) {
                final index = groupEntry.key;
                final entry = groupEntry.value;
                final moduleName = _moduleLabel(s, entry.key);
                final permsInModule = entry.value;
                final moduleCodesSet =
                    permsInModule.map((p) => p.code).toSet();
                final childrenMap = <String, List<AppPermission>>{};
                for (final p in permsInModule) {
                  if (p.requiredRule != null &&
                      moduleCodesSet.contains(p.requiredRule)) {
                    childrenMap.putIfAbsent(p.requiredRule!, () => []).add(p);
                  }
                }
                final roots = permsInModule
                    .where((p) =>
                        p.requiredRule == null ||
                        !moduleCodesSet.contains(p.requiredRule))
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Container(
                          height: 1,
                          color: AppTheme.textSecondary.withValues(alpha: 0.28),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        moduleName,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary),
                      ),
                    ),
                    ...roots.expand(
                        (perm) => _buildPermTree(s, childrenMap, perm, 0)),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(s.save),
        ),
      ],
    );
  }
}

// ── Users Tab ─────────────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<AppUser> _users = [];
  List<AppRole> _roles = [];
  List<AppPermission> _allPermissions = [];
  List<DepartmentFlat> _allDepts = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;
  int _page = 0;
  int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      final q = foldSearchText(_searchCtrl.text);
      if (q != _query) {
        setState(() => _query = q);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.get<List<AppUser>>(
          '/users',
          (data) => (data as List)
              .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        ApiService.instance.get<List<AppRole>>(
          '/roles',
          (data) => (data as List)
              .map((e) => AppRole.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        ApiService.instance.get<List<AppPermission>>(
          '/roles/permissions',
          (data) => (data as List)
              .map((e) => AppPermission.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<AppUser>;
          _roles = results[1] as List<AppRole>;
          _allPermissions = results[2] as List<AppPermission>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = serverMsg(e);
          _loading = false;
        });
    }
    // Load departments separately — failure does not break the user list
    try {
      final depts =
          await DepartmentService.instance.getFlat(permission: 'ROLE_MANAGE');
      if (mounted) setState(() => _allDepts = depts);
    } catch (_) {}
  }

  Future<void> _openRoleDialog(AppUser user) async {
    final saved = await _showInstantDialog<bool>(
      context,
      (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: _UserRoleDialog(
          user: user,
          allRoles: _roles,
          allPermissions: _allPermissions,
          allDepartments: _allDepts,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _toggleEnabled(AppUser user) async {
    final s = AppLocalizations.of(context)!;
    if (user.enabled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.disableUserTitle),
          content: Text(s.disableUserPrompt(user.fullName ?? user.email)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.disable),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ApiService.instance.patch<Map<String, dynamic>>(
        '/users/${user.id}/enabled',
        (data) => data as Map<String, dynamic>,
        {'enabled': !user.enabled},
      );
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final filtered = _query.isEmpty
        ? _users
        : _users.where((u) {
            final byName = foldSearchText(u.fullName ?? '').contains(_query);
            final byEmail = foldSearchText(u.email).contains(_query);
            final byRole =
                u.roles.any((r) => foldSearchText(r.name).contains(_query));
            return byName || byEmail || byRole;
          }).toList();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: Text(s.retry)),
        ]),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SearchTextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            onClear: () => setState(() {}),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  message: _users.isEmpty ? s.noUsersYet : s.noResults,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pageSize.clamp(0, filtered.length - _page * _pageSize),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final u = filtered[_page * _pageSize + i];
                      return _UserCard(
                        user: u,
                        onTap: () => _openRoleDialog(u),
                        onToggleEnabled: () => _toggleEnabled(u),
                      );
                    },
                  ),
                ),
        ),
        PaginationBar(
          total: filtered.length,
          page: _page,
          pageSize: _pageSize,
          onPageSizeChanged: (v) => setState(() { _pageSize = v; _page = 0; }),
          onPrev: _page > 0 ? () => setState(() => _page--) : null,
          onNext: (_page + 1) * _pageSize < filtered.length ? () => setState(() => _page++) : null,
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  final VoidCallback onToggleEnabled;

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onToggleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final initials = (user.fullName ?? user.email)[0].toUpperCase();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: user.enabled
                    ? AppTheme.primary.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.15),
                backgroundImage:
                    user.avatar != null ? NetworkImage(user.avatar!) : null,
                child: user.avatar == null
                    ? Text(initials,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: user.enabled
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          fontSize: 14,
                        ))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          user.fullName ?? user.email,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: user.enabled
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: user.enabled
                              ? AppTheme.success.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.enabled
                              ? s.employeeStatusActive
                              : s.employeeStatusInactive,
                          style: TextStyle(
                              fontSize: 10,
                              color: user.enabled
                                  ? AppTheme.success
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                    if (user.fullName != null) ...[
                      const SizedBox(height: 1),
                      Text(user.email,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                    if (user.roles.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: user.roles
                            .map((r) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.25)),
                                  ),
                                  child: Text(r.name,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.primary)),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              PermissionGuard(
                permission: 'USER_MANAGE',
                child: Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: user.enabled,
                    onChanged: (_) => onToggleEnabled(),
                    activeThumbColor: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── User Role Dialog ──────────────────────────────────────────────────────────

class _UserRoleDialog extends StatefulWidget {
  final AppUser user;
  final List<AppRole> allRoles;
  final List<AppPermission> allPermissions;
  final List<DepartmentFlat> allDepartments;

  const _UserRoleDialog({
    required this.user,
    required this.allRoles,
    required this.allPermissions,
    required this.allDepartments,
  });

  @override
  State<_UserRoleDialog> createState() => _UserRoleDialogState();
}

class _UserRoleDialogState extends State<_UserRoleDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final Set<int> _selectedRoles;
  late final Set<String> _selectedPerms;
  // permCode → set of deptIds (empty = unrestricted / all company)
  Map<String, Set<int>> _deptScopes = {};
  bool _saving = false;

  String? _viewCodeForModule(String module) {
    for (final p in widget.allPermissions) {
      if (p.module == module && p.code.endsWith('_VIEW')) {
        return p.code;
      }
    }
    return null;
  }

  void _togglePermission(AppPermission perm, bool enabled) {
    final viewCode = _viewCodeForModule(perm.module);
    final isViewPermission = viewCode != null && perm.code == viewCode;

    if (enabled) {
      _selectedPerms.add(perm.code);
      if (viewCode != null) _selectedPerms.add(viewCode);
      return;
    }

    _selectedPerms.remove(perm.code);
    _deptScopes.remove(perm.code);

    if (isViewPermission) {
      final moduleCodes = widget.allPermissions
          .where((p) => p.module == perm.module)
          .map((p) => p.code)
          .toSet();
      _selectedPerms.removeAll(moduleCodes);
      _deptScopes.removeWhere((k, _) => moduleCodes.contains(k));
    }
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, animationDuration: Duration.zero);
    _selectedRoles = widget.user.roles.map((r) => r.id).toSet();
    _selectedPerms = widget.user.directPermissions.toSet();
    _loadDeptScopes();
  }

  Future<void> _loadDeptScopes() async {
    try {
      final raw = await ApiService.instance.get<Map<String, dynamic>>(
        '/users/${widget.user.id}/dept-scopes',
        (d) => d as Map<String, dynamic>,
      );
      if (mounted) {
        setState(() {
          _deptScopes = raw.map((k, v) => MapEntry(
                k,
                (v as List).map((e) => (e as num).toInt()).toSet(),
              ));
        });
      }
    } catch (_) {
      // Silently ignore — defaults to empty (all company)
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _moduleLabel(AppLocalizations s, String module) => switch (module) {
        'EMPLOYEE' => s.employees,
        'DEPARTMENT' => s.departments,
        'ATTENDANCE' => s.attendance,
        'SHIFT' => s.shifts,
        'PAYROLL' => s.payroll,
        'ROLE' => s.roles,
        'USER' => s.user,
        'COMPANY' => s.company,
        _ => module,
      };

  String? _permUiHint(AppLocalizations s, String code) => switch (code) {
        'DASHBOARD_VIEW' => s.permUiDashboardView,
        'EMPLOYEE_VIEW' => s.permUiEmployeeView,
        'EMPLOYEE_CREATE' => s.permUiEmployeeCreate,
        'EMPLOYEE_UPDATE' => s.permUiEmployeeUpdate,
        'EMPLOYEE_DELETE' => s.permUiEmployeeDelete,
        'DEPARTMENT_VIEW' => s.permUiDepartmentView,
        'DEPARTMENT_MANAGE' => s.permUiDepartmentManage,
        'POSITION_MANAGE' => s.permUiPositionManage,
        'ATTENDANCE_VIEW' => s.permUiAttendanceView,
        'ATTENDANCE_MANAGE' => s.permUiAttendanceManage,
        'ATTENDANCE_SELF' => s.permUiAttendanceSelf,
        'ATTENDANCE_REQUEST_APPROVE' => s.permUiAttendanceApprove,
        'SHIFT_VIEW' => s.permUiShiftView,
        'SHIFT_MANAGE' => s.permUiShiftManage,
        'PAYROLL_VIEW' => s.permUiPayrollView,
        'PAYROLL_CREATE' => s.permUiPayrollCreate,
        'PAYROLL_APPROVE' => s.permUiPayrollApprove,
        'PAYROLL_PAY' => s.permUiPayrollPay,
        'ROLE_VIEW' => s.permUiRoleView,
        'ROLE_MANAGE' => s.permUiRoleManage,
        'USER_MANAGE' => s.permUiUserManage,
        'COMPANY_MANAGE' => s.permUiCompanyManage,
        'LEAVE_VIEW' => s.permUiLeaveView,
        'LEAVE_REQUEST_CREATE' => s.permUiLeaveRequestCreate,
        'LEAVE_REQUEST_APPROVE' => s.permUiLeaveRequestApprove,
        'LEAVE_GRANT_MANUAL' => s.permUiLeaveGrantManual,
        'LEAVE_TYPE_VIEW' => s.permUiLeaveTypeView,
        'LEAVE_TYPE_MANAGE' => s.permUiLeaveTypeManage,
        'LEAVE_ACCRUAL_VIEW' => s.permUiLeaveAccrualView,
        'LEAVE_ACCRUAL_MANAGE' => s.permUiLeaveAccrualManage,
        'COMPANY_SETTING_VIEW' => s.permUiCompanySettingView,
        'COMPANY_SETTING_MANAGE' => s.permUiCompanySettingManage,
        'LEAVE_REQUEST_CREATE_FOR_OTHERS' => s.permUiLeaveCreateForOthers,
        _ => null,
      };

  String _permissionDescription(
    AppLocalizations s,
    AppPermission perm,
  ) =>
      switch (perm.code) {
        'EMPLOYEE_VIEW' => s.permDescEmployeeView,
        'EMPLOYEE_CREATE' => s.permDescEmployeeCreate,
        'EMPLOYEE_UPDATE' => s.permDescEmployeeUpdate,
        'EMPLOYEE_DELETE' => s.permDescEmployeeDelete,
        'DEPARTMENT_VIEW' => s.permDescDepartmentView,
        'DEPARTMENT_MANAGE' => s.permDescDepartmentManage,
        'POSITION_MANAGE' => s.permDescPositionManage,
        'ATTENDANCE_VIEW' => s.permDescAttendanceView,
        'ATTENDANCE_MANAGE' => s.permDescAttendanceManage,
        'ATTENDANCE_SELF' => s.permDescAttendanceSelf,
        'ATTENDANCE_REQUEST_APPROVE' => s.permDescAttendanceApprove,
        'SHIFT_VIEW' => s.permDescShiftView,
        'SHIFT_MANAGE' => s.permDescShiftManage,
        'PAYROLL_VIEW' => s.permDescPayrollView,
        'PAYROLL_CREATE' => s.permDescPayrollCreate,
        'PAYROLL_APPROVE' => s.permDescPayrollApprove,
        'PAYROLL_PAY' => s.permDescPayrollPay,
        'ROLE_VIEW' => s.permDescRoleView,
        'ROLE_MANAGE' => s.permDescRoleManage,
        'USER_MANAGE' => s.permDescUserManage,
        'COMPANY_MANAGE' => s.permDescCompanyManage,
        'LEAVE_VIEW' => s.permDescLeaveView,
        'LEAVE_REQUEST_CREATE' => s.permDescLeaveRequestCreate,
        'LEAVE_REQUEST_APPROVE' => s.permDescLeaveRequestApprove,
        'LEAVE_GRANT_MANUAL' => s.permDescLeaveGrantManual,
        'LEAVE_TYPE_VIEW' => s.permDescLeaveTypeView,
        'LEAVE_TYPE_MANAGE' => s.permDescLeaveTypeManage,
        'LEAVE_ACCRUAL_VIEW' => s.permDescLeaveAccrualView,
        'LEAVE_ACCRUAL_MANAGE' => s.permDescLeaveAccrualManage,
        'COMPANY_SETTING_VIEW' => s.permDescCompanySettingView,
        'COMPANY_SETTING_MANAGE' => s.permDescCompanySettingManage,
        'LEAVE_REQUEST_CREATE_FOR_OTHERS' => s.permDescLeaveCreateForOthers,
        'DASHBOARD_VIEW' => s.permDescDashboardView,
        _ => perm.description,
      };

  String _scopeLabel(AppLocalizations s, String permCode) {
    final ids = _deptScopes[permCode];
    if (ids == null || ids.isEmpty) return s.scopeCompanyLabel;
    if (ids.length == 1 && ids.contains(_scopeSelfOnlyMarker)) {
      return s.scopeSelfLabel;
    }
    if (ids.length == 1 && ids.contains(_scopeMyDeptOnlyMarker)) {
      return s.scopeMyDepartmentLabel;
    }
    if (ids.length == 1 && ids.contains(_scopeMyDeptAndDescMarker)) {
      return s.scopeMyDepartmentAndBelowLabel;
    }
    if (ids.contains(_scopeSelfOnlyMarker)) {
      return s.scopeSelfPlusDepartments(ids.length - 1);
    }
    if (ids.length == 1) {
      final dept =
          widget.allDepartments.where((d) => d.id == ids.first).firstOrNull;
      return dept?.name ?? s.scopeOneDepartment;
    }
    return s.scopeDepartments(ids.length);
  }

  Future<void> _showDeptPicker(
    String permCode,
    String permDesc, {
    bool allowSelfOnly = false,
  }) async {
    final initial = Set<int>.from(_deptScopes[permCode] ?? {});
    final result = await _showInstantDialog<Set<int>>(
      context,
      (_) => _DeptScopeDialog(
        permDescription: permDesc,
        departments: widget.allDepartments,
        initial: initial,
        allowSelfOnly: allowSelfOnly,
        allowMyDepartmentPresets:
            AuthService.instance.currentUser?.employeeId != null,
      ),
    );
    if (result != null) {
      setState(() {
        if (result.isEmpty) {
          _deptScopes.remove(permCode);
        } else {
          _deptScopes[permCode] = result;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Build dept scopes: only include checked, scopeable permissions
      final scopeBody = <String, List<int>>{};
      for (final code in _deptScopeablePerms) {
        if (_selectedPerms.contains(code)) {
          scopeBody[code] = (_deptScopes[code] ?? {}).toList();
        }
      }

      await Future.wait([
        ApiService.instance.put<Map<String, dynamic>>(
          '/users/${widget.user.id}/roles',
          (d) => d as Map<String, dynamic>,
          {'roleIds': _selectedRoles.toList()},
        ),
        ApiService.instance.put<Map<String, dynamic>>(
          '/users/${widget.user.id}/permissions',
          (d) => d as Map<String, dynamic>,
          {'permissionCodes': _selectedPerms.toList()},
        ),
        ApiService.instance.put<void>(
          '/users/${widget.user.id}/dept-scopes',
          (_) {},
          scopeBody,
        ),
      ]);

      if (!mounted) return;

      final currentUser = AuthService.instance.currentUser;
      final isSelf =
          currentUser != null && currentUser.email == widget.user.email;

      final router = GoRouter.of(context);
      Navigator.pop(context, true);

      if (isSelf) {
        final permByCode = {
          for (final p in widget.allPermissions) p.code: p,
        };
        final directModules = _selectedPerms
            .map((code) => permByCode[code]?.module)
            .whereType<String>()
            .toSet();
        final rolePerms = widget.allRoles
            .where((r) => _selectedRoles.contains(r.id))
            .expand((r) => r.permissions)
            .where((p) => !directModules.contains(p.module))
            .map((p) => p.code)
            .toSet();
        final effective = {...rolePerms, ..._selectedPerms};
        // Convert deptScopes: Set<int> → List<int>
        final scopesForAuth = _deptScopes.map(
          (k, v) => MapEntry(k, v.toList()),
        );
        AuthService.instance
            .applyPermissions(effective, deptScopes: scopesForAuth);
        router.go(AppRoutes.dashboard);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final dialogHeight = MediaQuery.of(context).size.height * 0.85;
    final grouped = <String, List<AppPermission>>{};
    for (final p in widget.allPermissions) {
      grouped.putIfAbsent(p.module, () => []).add(p);
    }

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        width: 640,
        height: dialogHeight,
        constraints: BoxConstraints(maxHeight: dialogHeight),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                child: Text(
                  (widget.user.fullName ?? widget.user.email)[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.fullName ?? widget.user.email,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    if (widget.user.fullName != null)
                      Text(widget.user.email,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false)),
            ]),
            const SizedBox(height: 8),
            TabBar(
              controller: _tab,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: [
                Tab(text: s.roleGroupsTab),
                Tab(text: s.directPermissionsTab)
              ],
            ),
            Flexible(
              child: TabBarView(
                controller: _tab,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Tab 1: Roles
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.allRoles.map((role) {
                        return CheckboxListTile(
                          dense: true,
                          title: Text(role.name,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: role.description != null
                              ? Text(role.description!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary))
                              : null,
                          value: _selectedRoles.contains(role.id),
                          onChanged: (v) => setState(() => v == true
                              ? _selectedRoles.add(role.id)
                              : _selectedRoles.remove(role.id)),
                        );
                      }).toList(),
                    ),
                  ),
                  // Tab 2: Direct permissions grouped by module
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: grouped.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((groupEntry) {
                        final index = groupEntry.key;
                        final entry = groupEntry.value;
                        final moduleName = _moduleLabel(s, entry.key);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index > 0)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 8),
                                child: Container(
                                  height: 1,
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.28),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Text(
                                moduleName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary),
                              ),
                            ),
                            ...entry.value.map((p) {
                              final isChecked = _selectedPerms.contains(p.code);
                              final isScopeable =
                                  _deptScopeablePerms.contains(p.code);
                              final viewCode = _viewCodeForModule(p.module);
                              final requiresView =
                                  viewCode != null && p.code != viewCode;
                              final canEnable = !requiresView ||
                                  _selectedPerms.contains(viewCode);
                              final hasScope =
                                  _deptScopes[p.code]?.isNotEmpty ?? false;
                              final showScopeChip =
                                  isScopeable && (isChecked || hasScope);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(_permissionDescription(s, p),
                                        style: const TextStyle(fontSize: 13)),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p.code,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary)),
                                        if (_permUiHint(s, p.code) != null)
                                          Row(children: [
                                            const Icon(
                                                Icons.visibility_outlined,
                                                size: 10,
                                                color: AppTheme.primary),
                                            const SizedBox(width: 3),
                                            Text(_permUiHint(s, p.code)!,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppTheme.primary)),
                                          ]),
                                      ],
                                    ),
                                    value: isChecked,
                                    onChanged: (!canEnable && !isChecked)
                                        ? null
                                        : (v) {
                                            if (v == null) return;
                                            setState(
                                                () => _togglePermission(p, v));
                                          },
                                  ),
                                  // Dept scope chip — shown when checked and scopeable
                                  if (showScopeChip)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 12, bottom: 6, right: 0),
                                      child: ActionChip(
                                        avatar: Icon(
                                          Icons.domain_outlined,
                                          size: 14,
                                          color: (_deptScopes[p.code]
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? Colors.orange[700]
                                              : AppTheme.primary,
                                        ),
                                        label: Text(
                                          _scopeLabel(s, p.code),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: (_deptScopes[p.code]
                                                        ?.isNotEmpty ??
                                                    false)
                                                ? Colors.orange[700]
                                                : AppTheme.primary,
                                          ),
                                        ),
                                        backgroundColor:
                                            (_deptScopes[p.code]?.isNotEmpty ??
                                                    false)
                                                ? Colors.orange
                                                    .withValues(alpha: 0.08)
                                                : AppTheme.primary
                                                    .withValues(alpha: 0.08),
                                        side: BorderSide(
                                          color: (_deptScopes[p.code]
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? Colors.orange
                                                  .withValues(alpha: 0.4)
                                              : AppTheme.primary
                                                  .withValues(alpha: 0.3),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onPressed: () => _showDeptPicker(
                                          p.code,
                                          p.description,
                                          allowSelfOnly:
                                              _selfScopePerms.contains(p.code),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(AppLocalizations.of(context)!.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dept Scope Dialog ─────────────────────────────────────────────────────────

class _DeptScopeDialog extends StatefulWidget {
  final String permDescription;
  final List<DepartmentFlat> departments;
  final Set<int> initial;
  final bool allowSelfOnly;
  final bool allowMyDepartmentPresets;

  const _DeptScopeDialog({
    required this.permDescription,
    required this.departments,
    required this.initial,
    required this.allowSelfOnly,
    required this.allowMyDepartmentPresets,
  });

  @override
  State<_DeptScopeDialog> createState() => _DeptScopeDialogState();
}

class _DeptScopeDialogState extends State<_DeptScopeDialog> {
  late Set<int> _selected;
  late bool _allCompany;
  late bool _selfOnly;
  late bool _myDeptOnly;
  late bool _myDeptAndDesc;
  late List<DepartmentFlat> _allDepts;
  late Map<int?, List<DepartmentFlat>> _childrenByParent;
  late Set<int> _expanded;
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initial.where(
      (id) =>
          id != _scopeSelfOnlyMarker &&
          id != _scopeMyDeptOnlyMarker &&
          id != _scopeMyDeptAndDescMarker,
    ));
    _selfOnly =
        widget.allowSelfOnly && widget.initial.contains(_scopeSelfOnlyMarker);
    _myDeptOnly = widget.allowMyDepartmentPresets &&
        widget.initial.contains(_scopeMyDeptOnlyMarker);
    _myDeptAndDesc = widget.allowMyDepartmentPresets &&
        widget.initial.contains(_scopeMyDeptAndDescMarker);
    _allCompany = widget.initial.isEmpty;
    _allDepts = List<DepartmentFlat>.from(widget.departments);
    _childrenByParent = <int?, List<DepartmentFlat>>{};
    for (final d in _allDepts) {
      _childrenByParent.putIfAbsent(d.parentId, () => []).add(d);
    }
    for (final list in _childrenByParent.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    _expanded = _allDepts.map((d) => d.id).toSet();
  }

  bool _hasChildren(int deptId) =>
      (_childrenByParent[deptId] ?? const []).isNotEmpty;

  List<DepartmentFlat> _visibleNodes() {
    final result = <DepartmentFlat>[];
    void walk(int? parentId) {
      final children = _childrenByParent[parentId] ?? const [];
      for (final d in children) {
        result.add(d);
        if (_expanded.contains(d.id)) {
          walk(d.id);
        }
      }
    }

    walk(null);
    return result;
  }

  void _toggleExpand(int deptId) {
    setState(() {
      if (_expanded.contains(deptId)) {
        _expanded.remove(deptId);
      } else {
        _expanded.add(deptId);
      }
    });
  }

  void _toggleAllCompany(bool? v) {
    if (v != true) return;
    setState(() {
      _allCompany = true;
      _selfOnly = false;
      _myDeptOnly = false;
      _myDeptAndDesc = false;
      _selected.clear();
    });
  }

  void _toggleSelfOnly(bool? v) {
    if (!widget.allowSelfOnly) return;
    setState(() {
      if (v == true) {
        _selfOnly = true;
        _allCompany = false;
        _myDeptOnly = false;
        _myDeptAndDesc = false;
        _selected.clear();
      } else {
        _selfOnly = false;
        if (_selected.isEmpty) {
          _allCompany = true;
        }
      }
    });
  }

  void _toggleMyDeptOnly(bool? v) {
    if (!widget.allowMyDepartmentPresets) return;
    setState(() {
      if (v == true) {
        _myDeptOnly = true;
        _myDeptAndDesc = false;
        _selfOnly = false;
        _allCompany = false;
        _selected.clear();
      } else {
        _myDeptOnly = false;
        if (_selected.isEmpty && !_selfOnly && !_myDeptAndDesc) {
          _allCompany = true;
        }
      }
    });
  }

  void _toggleMyDeptAndDesc(bool? v) {
    if (!widget.allowMyDepartmentPresets) return;
    setState(() {
      if (v == true) {
        _myDeptAndDesc = true;
        _myDeptOnly = false;
        _selfOnly = false;
        _allCompany = false;
        _selected.clear();
      } else {
        _myDeptAndDesc = false;
        if (_selected.isEmpty && !_selfOnly && !_myDeptOnly) {
          _allCompany = true;
        }
      }
    });
  }

  void _toggleDept(int id, bool? v) {
    setState(() {
      if (v == true) {
        _selected.add(id);
        _allCompany = false;
        _selfOnly = false;
        _myDeptOnly = false;
        _myDeptAndDesc = false;
      } else {
        _selected.remove(id);
        if (_selected.isEmpty) _allCompany = true;
      }
    });
  }

  double _treeContentWidth() {
    final maxLevel =
        _allDepts.fold<int>(0, (m, d) => d.level > m ? d.level : m);
    return 380 + (maxLevel * 28);
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.scopeDepartmentLabel,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(
            widget.permDescription,
            style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "All company" option
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(s.scopeCompanyLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(s.scopeCompanyDesc,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              value: _allCompany,
              onChanged: _toggleAllCompany,
              activeColor: AppTheme.primary,
            ),
            if (widget.allowSelfOnly)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.scopeSelfLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(s.scopeSelfDesc,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                value: _selfOnly,
                onChanged: _toggleSelfOnly,
                activeColor: AppTheme.primary,
              ),
            if (widget.allowMyDepartmentPresets)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.scopeMyDepartmentLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(s.scopeMyDepartmentDesc,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                value: _myDeptOnly,
                onChanged: _toggleMyDeptOnly,
                activeColor: AppTheme.primary,
              ),
            if (widget.allowMyDepartmentPresets)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.scopeMyDepartmentAndBelowLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(s.scopeMyDepartmentAndBelowDesc,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                value: _myDeptAndDesc,
                onChanged: _toggleMyDeptAndDesc,
                activeColor: AppTheme.primary,
              ),
            const Divider(height: 12),
            Text(s.orSelectSpecificDepartment,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Expanded(
              child: Scrollbar(
                controller: _hScroll,
                thumbVisibility: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _treeContentWidth(),
                    child: ListView.builder(
                      controller: _vScroll,
                      itemCount: _visibleNodes().length,
                      itemBuilder: (_, i) {
                        final dept = _visibleNodes()[i];
                        final hasChildren = _hasChildren(dept.id);
                        final isExpanded = _expanded.contains(dept.id);

                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              SizedBox(width: dept.level * 18.0),
                              SizedBox(
                                width: 18,
                                child: hasChildren
                                    ? InkWell(
                                        onTap: () => _toggleExpand(dept.id),
                                        child: Text(
                                          isExpanded ? '-' : '+',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 6),
                              if (dept.level > 0) ...[
                                Icon(Icons.subdirectory_arrow_right,
                                    size: 16, color: Colors.grey[500]),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  '${dept.name} (${dept.code})',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          value: _selected.contains(dept.id),
                          onChanged: (v) => _toggleDept(dept.id, v),
                          activeColor: AppTheme.primary,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _selfOnly
                ? <int>{_scopeSelfOnlyMarker}
                : _myDeptOnly
                    ? <int>{_scopeMyDeptOnlyMarker}
                    : _myDeptAndDesc
                        ? <int>{_scopeMyDeptAndDescMarker}
                        : _selected,
          ),
          child: Text(s.confirm),
        ),
      ],
    );
  }
}
