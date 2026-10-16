import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../core/utils/text_utils.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../auth/force_change_password_screen.dart' show isStrongPassword;
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/employee.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/services/department_service.dart';
import '../../widgets/date_field.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/search_text_field.dart';
import '../../widgets/permission_guard.dart';
import '../../widgets/reset_password_flow.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/payroll.dart';
import '../../../data/repositories/salary_history_repository.dart';
import '../../../data/repositories/payroll_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/repositories/salary_grade_repository.dart';
import '../../../data/models/salary_grade.dart';
import 'employee_form_screen.dart';
import 'dependents_dialog.dart';
import 'employee_documents_dialog.dart';
import 'job_history_dialog.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final _repo = EmployeeRepository();
  final _gradeRepo = SalaryGradeRepository();
  final _searchCtrl = TextEditingController();

  List<SalaryGrade> _cachedGrades = [];

  List<Employee> _employees = [];
  List<DepartmentFlat> _departments = [];
  bool _loading = true;
  String? _error;
  bool _syncing = false;

  int _page = 0;
  int _pageSize = 20;
  int _total = 0;

  int? _filterDept;
  EmployeeStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadDepts();
    _load(reset: true);
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    // Bậc lương thuộc gói Tính lương (PAYROLL_VIEW) — không có quyền / gói tắt thì không gọi API.
    if (AuthService.instance.currentUser?.can('PAYROLL_VIEW') != true) return;
    try {
      final grades = await _gradeRepo.getAll();
      if (mounted) setState(() => _cachedGrades = grades);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepts() async {
    try {
      final depts =
          await DepartmentService.instance.getFlat(permission: 'EMPLOYEE_VIEW');
      if (mounted) setState(() => _departments = depts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 0;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _repo.getAll(
        page: _page,
        size: _pageSize,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        departmentId: _filterDept?.toInt(),
        status: _filterStatus,
      );
      setState(() {
        _employees = res.items;
        _total = res.total;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = serverMsg(e); _loading = false; });
    }
  }


  void _openForm({Employee? emp}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeFormScreen(
          employee: emp,
          departments: _departments,
          initialGrades: _cachedGrades,
        ),
      ),
    );
    if (saved == true) _load(reset: true);
  }

  /// Nghỉ việc: chọn ngày làm việc cuối; hồ sơ không bị xoá (xem lại ở lọc "Nghỉ việc", cho đi làm lại được).
  Future<void> _resign(Employee emp) async {
    final s = AppLocalizations.of(context);
    final today = DateTime.now();
    DateTime lastDay = DateTime(today.year, today.month, today.day);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.employeeDeleteTitle),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.employeeDeletePrompt(emp.fullName)),
                const SizedBox(height: 16),
                DateField(
                  label: s.employeeResignLastDay,
                  value: lastDay,
                  firstDate: emp.joinDate.isAfter(today) ? today : emp.joinDate,
                  lastDate: today,
                  onChanged: (d) {
                    if (d != null) setDialogState(() => lastDay = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.confirm),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _repo.resign(emp.id, lastDay);
      _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reinstate(Employee emp) async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        title: Text(s.employeeReinstateTitle),
        content: Text(s.employeeReinstatePrompt(emp.fullName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.reinstate(emp.id);
      _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _syncUserAccounts() async {
    final s = AppLocalizations.of(context);
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showInstantDialog<bool>(
      context,
      (dialogContext) => AlertDialog(
        title: Text(s.syncEmployeeAccounts),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.syncEmployeeAccountsDesc),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: s.initialPassword,
                      hintText: s.passwordPolicyHint,
                    ),
                    validator: (v) {
                      if (v == null || !isStrongPassword(v.trim())) {
                        return s.passwordPolicyHint;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: s.confirmPasswordLabel,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return s.requiredField;
                      if (v != passwordCtrl.text) return s.passwordMismatch;
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(s.sync),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      passwordCtrl.dispose();
      confirmCtrl.dispose();
      return;
    }

    setState(() => _syncing = true);
    try {
      final res = await _repo.syncMissingUsers(passwordCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.syncEmployeeAccountsSuccess(
                res['createdCount'] ?? 0,
                res['linkedCount'] ?? 0,
                res['skippedCount'] ?? 0,
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      passwordCtrl.dispose();
      confirmCtrl.dispose();
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openJobHistory(Employee emp) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => JobHistoryDialog(employee: emp, departments: _departments, grades: _cachedGrades),
    );
    if (changed == true) _load();
  }

  void _openDependents(Employee emp) {
    showDialog(
      context: context,
      builder: (_) => DependentsDialog(employee: emp),
    );
  }

  void _openDocuments(Employee emp) {
    showDialog(
      context: context,
      builder: (_) => EmployeeDocumentsDialog(employee: emp),
    );
  }

  void _openSalaryHistory(Employee emp) {
    showDialog(
      context: context,
      builder: (_) => _SalaryHistoryDialog(employee: emp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  PermissionGuard(
                    permission: 'USER_MANAGE',
                    child: OutlinedButton.icon(
                      onPressed: _syncing ? null : _syncUserAccounts,
                      icon: _syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, size: 18),
                      label: Text(s.syncEmployeeAccounts),
                    ),
                  ),
                  PermissionGuard(
                    permission: 'EMPLOYEE_CREATE',
                    child: FilledButton.icon(
                      onPressed: _openForm,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: Text(s.addEmployee),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildFilters(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildFilters() {
    final s = AppLocalizations.of(context);
    final isWide = MediaQuery.of(context).size.width > 600;
    final search = SearchTextField(
      controller: _searchCtrl,
      hint: s.employeeSearchHint,
      onChanged: (_) => _load(reset: true),
      onClear: () => _load(reset: true),
    );
    final deptFilter = DepartmentPickerField(
      departments: _departments,
      value: _filterDept,
      label: s.department,
      allowAll: true,
      compact: true,
      onChanged: (v) {
        setState(() => _filterDept = v);
        _load(reset: true);
      },
    );
    final statusFilter = DropdownButtonFormField<EmployeeStatus?>(
      initialValue: _filterStatus,
      borderRadius: BorderRadius.circular(12),
      decoration: InputDecoration(labelText: s.status, isDense: true),
      items: [
        DropdownMenuItem(value: null, child: Text(s.all)),
        DropdownMenuItem(
            value: EmployeeStatus.active, child: Text(s.employeeStatusActive)),
        DropdownMenuItem(
            value: EmployeeStatus.inactive,
            child: Text(s.employeeStatusInactive)),
        DropdownMenuItem(
            value: EmployeeStatus.onLeave,
            child: Text(s.employeeStatusOnLeave)),
      ],
      onChanged: (v) {
        setState(() => _filterStatus = v);
        _load(reset: true);
      },
    );
    final refresh = IconButton(
      tooltip: s.refresh,
      icon: const Icon(Icons.refresh),
      onPressed: () => _load(reset: true),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Theme.of(context).colorScheme.surface,
      child: isWide
          ? Row(children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: deptFilter),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: statusFilter),
              const SizedBox(width: 4),
              refresh,
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              search,
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: deptFilter),
                const SizedBox(width: 8),
                Expanded(child: statusFilter),
                refresh,
              ]),
            ]),
    );
  }

  Widget _buildBody() {
    final s = AppLocalizations.of(context);
    if (_loading && _employees.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _employees.isEmpty) {
      return Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: () => _load(reset: true), child: Text(s.retry)),
        ],
      ));
    }
    if (_employees.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(s.noEmployeesFound, style: TextStyle(color: AppTheme.textSecondary)),
        ]),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _employees.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _EmployeeCard(
                employee: _employees[i],
                onEdit: () => _openForm(emp: _employees[i]),
                onDelete: () => _employees[i].status == EmployeeStatus.inactive
                    ? _reinstate(_employees[i])
                    : _resign(_employees[i]),
                onSalaryHistory: () => _openSalaryHistory(_employees[i]),
                onJobHistory: () => _openJobHistory(_employees[i]),
                onDependents: () => _openDependents(_employees[i]),
                onDocuments: () => _openDocuments(_employees[i]),
              ),
            ),
          ),
        ),
        PaginationBar(
          total: _total,
          page: _page,
          pageSize: _pageSize,
          onPageSizeChanged: (v) { _pageSize = v; _load(reset: true); },
          onPrev: _page > 0 ? () { setState(() => _page--); _load(); } : null,
          onNext: (_page + 1) * _pageSize < _total ? () { setState(() => _page++); _load(); } : null,
        ),
      ],
    );
  }
}

// ── Employee Card ───────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSalaryHistory;
  final VoidCallback onJobHistory;
  final VoidCallback onDependents;
  final VoidCallback onDocuments;

  const _EmployeeCard({
    required this.employee,
    required this.onEdit,
    required this.onDelete,
    required this.onSalaryHistory,
    required this.onJobHistory,
    required this.onDependents,
    required this.onDocuments,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final e = employee;
    final resigned = e.status == EmployeeStatus.inactive;

    final user = AuthService.instance.currentUser;
    final canSalary = user != null && (user.isSystemAdmin || user.can('PAYROLL_CREATE'));
    // V26: nút của tính năng công ty đã tắt không hiện (bấm vào chỉ gặp 403)
    final canJobHistory = user?.hasFeature('HR_JOBHISTORY') ?? true;
    final canDependents = user?.hasFeature('PAY_DEPENDENT') ?? true;
    final canDocuments = user != null && (user.isSystemAdmin || user.can('EMPLOYEE_DOCUMENT_VIEW'));
    final canEdit = user != null && (user.isSystemAdmin || user.can('EMPLOYEE_UPDATE'));
    // Người đang làm: nút Nghỉ việc; người đã nghỉ: nút Đi làm lại (cùng quyền EMPLOYEE_DELETE)
    final canDelete = user != null && (user.isSystemAdmin || user.can('EMPLOYEE_DELETE'));
    // Đặt lại mật khẩu: người đã nghỉ bị khoá tài khoản nên không cần
    final canResetPassword = !resigned && user != null && (user.isSystemAdmin || user.can('USER_MANAGE'));

    final desktopActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canJobHistory)
          Tooltip(
            message: s.jobHistoryTitle,
            child: IconButton(
              icon: const Icon(Icons.timeline, size: 20),
              onPressed: onJobHistory,
            ),
          ),
        if (canDependents)
          Tooltip(
            message: s.dependentsTitle,
            child: IconButton(
              icon: const Icon(Icons.family_restroom_outlined, size: 20),
              onPressed: onDependents,
            ),
          ),
        if (canDocuments)
          Tooltip(
            message: s.docTitleDialog,
            child: IconButton(
              icon: const Icon(Icons.folder_shared_outlined, size: 20),
              onPressed: onDocuments,
            ),
          ),
        if (canSalary)
          Tooltip(
            message: s.salaryHistory,
            child: IconButton(
              icon: const Icon(Icons.payments_outlined, size: 20),
              onPressed: onSalaryHistory,
            ),
          ),
        if (canResetPassword)
          Tooltip(
            message: s.userResetPasswordTitle,
            child: IconButton(
              icon: const Icon(Icons.key_outlined, size: 20),
              onPressed: () => resetPasswordFlow(context,
                  name: e.fullName, endpoint: '/users/by-employee/${e.id}/reset-password'),
            ),
          ),
        if (canEdit)
          Tooltip(
            message: s.edit,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
          ),
        if (canDelete)
          Tooltip(
            message: resigned ? s.employeeReinstateTitle : s.employeeDeleteTitle,
            child: IconButton(
              icon: resigned
                  ? const Icon(Icons.person_add_alt_1_outlined, size: 20, color: AppTheme.primary)
                  : const Icon(Icons.person_off_outlined, size: 20, color: Colors.red),
              onPressed: onDelete,
            ),
          ),
      ],
    );

    final actionsMenu = PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      itemBuilder: (_) => [
        if (canJobHistory)
          PopupMenuItem(
            value: 'job',
            child: Row(children: [
              const Icon(Icons.timeline, size: 18),
              const SizedBox(width: 10),
              Text(s.jobHistoryTitle),
            ]),
          ),
        if (canDependents)
          PopupMenuItem(
            value: 'dependents',
            child: Row(children: [
              const Icon(Icons.family_restroom_outlined, size: 18),
              const SizedBox(width: 10),
              Text(s.dependentsTitle),
            ]),
          ),
        if (canDocuments)
          PopupMenuItem(
            value: 'documents',
            child: Row(children: [
              const Icon(Icons.folder_shared_outlined, size: 18),
              const SizedBox(width: 10),
              Text(s.docTitleDialog),
            ]),
          ),
        if (canSalary)
          PopupMenuItem(
            value: 'salary',
            child: Row(children: [
              const Icon(Icons.payments_outlined, size: 18),
              const SizedBox(width: 10),
              Text(s.salaryHistory),
            ]),
          ),
        if (canResetPassword)
          PopupMenuItem(
            value: 'password',
            child: Row(children: [
              const Icon(Icons.key_outlined, size: 18),
              const SizedBox(width: 10),
              Text(s.userResetPasswordTitle),
            ]),
          ),
        if (canEdit)
          PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 10),
              Text(s.edit),
            ]),
          ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: Row(children: resigned
                ? [
                    const Icon(Icons.person_add_alt_1_outlined, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Text(s.employeeReinstateTitle),
                  ]
                : [
                    const Icon(Icons.person_off_outlined, size: 18, color: Colors.red),
                    const SizedBox(width: 10),
                    Text(s.employeeDeleteTitle, style: const TextStyle(color: Colors.red)),
                  ]),
          ),
      ],
      onSelected: (v) {
        if (v == 'job') onJobHistory();
        if (v == 'dependents') onDependents();
        if (v == 'documents') onDocuments();
        if (v == 'salary') onSalaryHistory();
        if (v == 'edit') onEdit();
        if (v == 'password') {
          resetPasswordFlow(context, name: e.fullName, endpoint: '/users/by-employee/${e.id}/reset-password');
        }
        if (v == 'delete') onDelete();
      },
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(e.fullName,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(e.employeeCode,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
            _StatusChip(e.status),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            _InfoChip(Icons.email_outlined, e.email),
            _InfoChip(Icons.account_tree_outlined, e.departmentName),
            _InfoChip(Icons.work_outline, e.positionName ?? '—'),
            if (e.managerName != null) _InfoChip(Icons.supervisor_account_outlined, e.managerName!),
          ],
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: e.avatar != null && e.avatar!.isNotEmpty
                  ? NetworkImage(e.avatar!)
                  : null,
              child: e.avatar == null || e.avatar!.isEmpty
                  ? Text(
                      e.fullName.isNotEmpty ? e.fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: info),
            LayoutBuilder(
              builder: (context, constraints) =>
                  MediaQuery.of(context).size.width >= 600
                      ? desktopActions
                      : actionsMenu,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      );
}

class _StatusChip extends StatelessWidget {
  final EmployeeStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      EmployeeStatus.active => (s.employeeStatusActive, Colors.green),
      EmployeeStatus.inactive => (s.employeeStatusInactive, Colors.red),
      EmployeeStatus.onLeave => (s.employeeStatusOnLeave, Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Salary History Dialog ───────────────────────────────────────────────────

class _SalaryHistoryDialog extends StatefulWidget {
  final Employee employee;
  const _SalaryHistoryDialog({required this.employee});

  @override
  State<_SalaryHistoryDialog> createState() => _SalaryHistoryDialogState();
}

class _SalaryHistoryDialogState extends State<_SalaryHistoryDialog>
    with SingleTickerProviderStateMixin {
  final _shRepo = SalaryHistoryRepository();
  final _payrollRepo = PayrollRepository();
  late final TabController _tab;

  bool _loadingSh = true;
  List<SalaryHistory> _shItems = [];
  String? _shError;

  bool _loadingPayroll = true;
  List<Payroll> _payrollItems = [];
  String? _payrollError;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadSh();
    _loadPayroll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadSh() async {
    setState(() { _loadingSh = true; _shError = null; });
    try {
      final items = await _shRepo.getByEmployee(widget.employee.id);
      if (mounted) setState(() => _shItems = items);
    } catch (e) {
      if (mounted) setState(() => _shError = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loadingSh = false);
    }
  }

  Future<void> _loadPayroll() async {
    setState(() { _loadingPayroll = true; _payrollError = null; });
    try {
      final items = await _payrollRepo.getByEmployee(widget.employee.id);
      if (mounted) setState(() => _payrollItems = items);
    } catch (e) {
      if (mounted) setState(() => _payrollError = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loadingPayroll = false);
    }
  }

  void _openAdd() async {
    final created = await showDialog<SalaryHistory>(
      context: context,
      builder: (_) => _SalaryHistoryFormDialog(employeeId: widget.employee.id, repo: _shRepo),
    );
    if (created != null) _loadSh();
  }

  void _openEdit(SalaryHistory sh) async {
    final updated = await showDialog<SalaryHistory>(
      context: context,
      builder: (_) => _SalaryHistoryFormDialog(employeeId: widget.employee.id, repo: _shRepo, existing: sh),
    );
    if (updated != null) _loadSh();
  }

  Future<void> _delete(SalaryHistory sh) async {
    final s = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.empDeleteSalaryConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _shRepo.delete(sh.id);
      _loadSh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final currFmt = moneyNumberFormat();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${s.salaryHistory} — ${widget.employee.fullName}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tab,
                tabs: [
                  Tab(text: s.payrollMonthlyHistory),
                  Tab(text: s.salaryGradeHistory),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildPayrollTab(s, currFmt),
                    _buildSalaryHistoryTab(s, currFmt),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(s.close)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayrollTab(AppLocalizations s, NumberFormat currFmt) {
    if (_loadingPayroll) return const Center(child: CircularProgressIndicator());
    if (_payrollError != null) return Center(child: Text(_payrollError!, style: const TextStyle(color: AppTheme.error)));
    if (_payrollItems.isEmpty) return Center(child: Text(s.noResults));
    return ListView.separated(
      itemCount: _payrollItems.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = _payrollItems[i];
        final statusColor = p.status == PayrollStatus.paid
            ? Colors.green
            : p.status == PayrollStatus.approved
                ? Colors.blue
                : Colors.grey;
        return ListTile(
          dense: true,
          title: Text(
            s.adminStatsMonth(p.month, p.year),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${s.baseSalary}: ${currFmt.format(p.baseSalary)}đ'
            '  •  ${s.netSalary}: ${currFmt.format(p.netSalary)}đ',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              payrollStatusLabel(s, p.status),
              style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSalaryHistoryTab(AppLocalizations s, NumberFormat currFmt) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text(s.salaryHistoryAdd),
            onPressed: _openAdd,
          ),
        ),
        if (_shError != null)
          Text(_shError!, style: const TextStyle(color: AppTheme.error)),
        Expanded(
          child: _loadingSh
              ? const Center(child: CircularProgressIndicator())
              : _shItems.isEmpty
                  ? Center(child: Text(s.noResults))
                  : ListView.separated(
                      itemCount: _shItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final sh = _shItems[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${currFmt.format(sh.baseSalary)}đ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${s.effectiveDate}: ${dateFmt.format(sh.effectiveDate)}'
                            '${sh.note != null ? '\n${sh.note}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                onPressed: () => _openEdit(sh),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                                onPressed: () => _delete(sh),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _SalaryHistoryFormDialog extends StatefulWidget {
  final int employeeId;
  final SalaryHistoryRepository repo;
  final SalaryHistory? existing;
  const _SalaryHistoryFormDialog({required this.employeeId, required this.repo, this.existing});

  @override
  State<_SalaryHistoryFormDialog> createState() => _SalaryHistoryFormDialogState();
}

class _SalaryHistoryFormDialogState extends State<_SalaryHistoryFormDialog> {
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _noteCtrl;
  DateTime _effectiveDate = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _salaryCtrl = TextEditingController(
        text: widget.existing != null ? widget.existing!.baseSalary.toStringAsFixed(0) : '');
    _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
    if (widget.existing != null) _effectiveDate = widget.existing!.effectiveDate;
  }

  @override
  void dispose() {
    _salaryCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _effectiveDate = picked);
  }

  Future<void> _save() async {
    final salary = double.tryParse(_salaryCtrl.text.replaceAll(',', ''));
    if (salary == null || salary <= 0) {
      setState(() => _error = AppLocalizations.of(context).empSalaryMustBePositive);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final SalaryHistory result;
      if (widget.existing != null) {
        result = await widget.repo.update(
          widget.existing!.id,
          baseSalary: salary,
          effectiveDate: _effectiveDate,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
      } else {
        result = await widget.repo.create(
          employeeId: widget.employeeId,
          baseSalary: salary,
          effectiveDate: _effectiveDate,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = serverMsg(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final dateFmt = DateFormat('dd/MM/yyyy');
    return AlertDialog(
      title: Text(widget.existing != null ? s.edit : s.salaryHistoryAdd),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            TextFormField(
              controller: _salaryCtrl,
              decoration: InputDecoration(labelText: s.baseSalary, suffixText: 'đ'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: s.effectiveDate),
                child: Text(dateFmt.format(_effectiveDate)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: InputDecoration(labelText: s.note),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(s.save),
        ),
      ],
    );
  }
}
