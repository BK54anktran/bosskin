import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/file_saver_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/employee.dart';
import '../../../data/models/payroll.dart';
import '../../../data/models/salary_formula.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/payroll_repository.dart';
import '../../../data/repositories/salary_formula_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/department_service.dart';
import '../../widgets/payslip_tax_info.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/permission_guard.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import 'salary_formula_tab.dart' show FormulaEditorDialog;

final _currFmt = NumberFormat('#,###', 'vi_VN');
String _fmt(double v) => '${_currFmt.format(v)}đ';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final _repo = PayrollRepository();
  final _empRepo = EmployeeRepository();
  final _formulaRepo = SalaryFormulaRepository();

  bool _loading = true;
  bool _exportingPayslips = false;
  String? _error;
  List<Payroll> _items = [];
  int _total = 0;
  int _page = 0;
  String _search = '';
  int _pageSize = 20;
  int _localPage = 0;
  final Set<int> _selectedIds = {};

  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  int? _deptId;
  String? _status;
  List<DepartmentFlat> _depts = [];

  bool _canCreate = false;
  bool _canApprove = false;
  bool _canPay = false;

  @override
  void initState() {
    super.initState();
    _initPerms();
    _loadDepts();
    _load();
  }

  void _initPerms() {
    final user = AuthService.instance.currentUser;
    final isSysAdmin = user?.isSystemAdmin ?? false;
    _canCreate  = isSysAdmin || (user?.can('PAYROLL_CREATE')  ?? false);
    _canApprove = isSysAdmin || (user?.can('PAYROLL_APPROVE') ?? false);
    _canPay     = isSysAdmin || (user?.can('PAYROLL_PAY')     ?? false);
  }

  Future<void> _loadDepts() async {
    try {
      final depts =
          await DepartmentService.instance.getFlat(permission: 'PAYROLL_VIEW');
      if (mounted) setState(() => _depts = depts);
    } catch (_) {}
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.getByMonth(
        _year,
        _month,
        departmentId: _deptId,
        status: _status,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items = result.content;
        _total = result.totalElements;
      });
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPayslips({List<int>? ids}) async {
    final s = AppLocalizations.of(context);
    setState(() => _exportingPayslips = true);
    try {
      final result = await _repo.exportPayslips(
        year: _year,
        month: _month,
        ids: ids,
      );
      await saveFileToDevice(result.bytes, result.filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.exportPayslipsSuccess)),
        );
        if (ids != null) setState(() => _selectedIds.clear());
      }
    } catch (e) {
      if (mounted) _showError(serverMsg(e));
    } finally {
      if (mounted) setState(() => _exportingPayslips = false);
    }
  }

  Future<void> _approve(Payroll p) async {
    final s = AppLocalizations.of(context);
    final ok = await _confirm(s.payrollConfirmApprove);
    if (!ok) return;
    try {
      final updated = await _repo.approve(p.id);
      setState(() =>
          _items = _items.map((e) => e.id == p.id ? updated : e).toList());
    } catch (e) {
      if (mounted) _showError(serverMsg(e));
    }
  }

  Future<void> _pay(Payroll p) async {
    final s = AppLocalizations.of(context);
    final ok = await _confirm(s.payrollConfirmPay);
    if (!ok) return;
    try {
      final updated = await _repo.pay(p.id);
      setState(() =>
          _items = _items.map((e) => e.id == p.id ? updated : e).toList());
    } catch (e) {
      if (mounted) _showError(serverMsg(e));
    }
  }

  Future<void> _delete(Payroll p) async {
    final s = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.payrollDeleteConfirm(p.month, p.year, p.employeeName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.payrollDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(p.id);
      setState(() => _items = _items.where((e) => e.id != p.id).toList());
    } catch (e) {
      if (mounted) _showError(serverMsg(e));
    }
  }

  Future<void> _recalculate(Payroll p) async {
    final s = AppLocalizations.of(context);
    int? formulaId;
    CustomFormulaSnapshot? customFormula;

    if (p.salaryGradeId != null) {
      List<SalaryFormula> formulas = [];
      try {
        formulas = await _formulaRepo.getAll(gradeId: p.salaryGradeId);
      } catch (_) {}

      if (!mounted) return;

      final hasCustom = p.customFormula != null;
      if (formulas.length > 1 || hasCustom) {
        final cutoff = DateTime(p.year, p.month, 1);
        final eligible = formulas
            .where((f) => !f.effectiveDate.isAfter(cutoff))
            .toList()
          ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
        final defaultFormula = eligible.isNotEmpty
            ? eligible.first
            : (formulas.isNotEmpty ? formulas.first : null);

        final result = await showDialog<_FormulaPickResult>(
          context: context,
          builder: (ctx) => _PickFormulaDialog(
            formulas: formulas,
            initial: defaultFormula,
            customFormula: p.customFormula,
            year: p.year,
            month: p.month,
          ),
        );
        if (!mounted) return;
        if (result == null) return;
        if (result.isCustom) {
          customFormula = p.customFormula;
        } else {
          formulaId = result.formula?.id;
        }
      }
    }

    try {
      Payroll updated;
      if (customFormula != null) {
        updated = await _repo.updateDraft(p.id, customFormula: customFormula);
      } else {
        updated = await _repo.recalculate(p.id, formulaId: formulaId);
      }
      setState(() =>
          _items = _items.map((e) => e.id == p.id ? updated : e).toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.payrollRecalculateDone)),
        );
      }
    } catch (e) {
      if (mounted) _showError(serverMsg(e));
    }
  }

  Future<bool> _confirm(String msg) async {
    final s = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(msg),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(s.confirm)),
            ],
          ),
        ) ==
        true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
  }

  void _openGenerate() async {
    final created = await showDialog<Payroll>(
      context: context,
      builder: (_) => _GenerateDialog(empRepo: _empRepo, repo: _repo),
    );
    if (created != null) _load(reset: true);
  }

  void _openEdit(Payroll p) async {
    // Load công thức hiện tại (customFormula nếu có, không thì load từ grade)
    SalaryFormula? baseFormula;
    if (p.salaryGradeId != null) {
      try {
        final formulas = await _formulaRepo.getAll(gradeId: p.salaryGradeId);
        if (formulas.isNotEmpty) {
          final cutoff = DateTime(p.year, p.month, 1);
          final eligible = formulas
              .where((f) => !f.effectiveDate.isAfter(cutoff))
              .toList()
            ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
          baseFormula = eligible.isNotEmpty ? eligible.first : formulas.first;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final updated = await showDialog<Payroll>(
      context: context,
      builder: (_) => _InlineFormulaEditDialog(
        payroll: p,
        repo: _repo,
        baseFormula: baseFormula,
      ),
    );
    if (updated != null) {
      setState(() =>
          _items = _items.map((e) => e.id == p.id ? updated : e).toList());
    }
  }

  void _openPayslip(Payroll p) async {
    final reloaded = await showDialog<bool>(
      context: context,
      builder: (_) => _PayslipDialog(payroll: p),
    );
    if (reloaded == true && mounted) _load();
  }

  List<Payroll> get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items
        .where((p) =>
            p.employeeName.toLowerCase().contains(q) ||
            (p.departmentName?.toLowerCase().contains(q) ?? false) ||
            (p.salaryGradeCode?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<Payroll> get _paged {
    final list = _filtered;
    final start = _localPage * _pageSize;
    if (start >= list.length) return list;
    final end = (start + _pageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final filtered = _filtered;
    final paged = _paged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(
          year: _year,
          month: _month,
          depts: _depts,
          deptId: _deptId,
          status: _status,
          canCreate: _canCreate,
          exportingPayslips: _exportingPayslips,
          selectedCount: _selectedIds.length,
          onChanged: (y, m, d, st) {
            setState(() {
              _year = y;
              _month = m;
              _deptId = d;
              _status = st;
              _selectedIds.clear();
            });
            _load(reset: true);
          },
          onGenerate: _openGenerate,
          onExportPayslips: () => _exportPayslips(ids: _selectedIds.toList()),
          onClearSelection: () => setState(() => _selectedIds.clear()),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: s.employeeSearchHint,
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
            onChanged: (v) => setState(() {
              _search = v;
              _localPage = 0;
            }),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(child: Text(s.noResults))
                  : Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () => _load(),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              itemCount: paged.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) => _PayrollCard(
                                payroll: paged[i],
                                canApprove: _canApprove,
                                canPay: _canPay,
                                canEdit: _canCreate,
                                selected: _selectedIds.contains(paged[i].id),
                                onView: () => _openPayslip(paged[i]),
                                onEdit: () => _openEdit(paged[i]),
                                onApprove: () => _approve(paged[i]),
                                onPay: () => _pay(paged[i]),
                                onDelete: () => _delete(paged[i]),
                                onRecalculate: () => _recalculate(paged[i]),
                                onToggleSelect: () => setState(() {
                                  if (_selectedIds.contains(paged[i].id)) {
                                    _selectedIds.remove(paged[i].id);
                                  } else {
                                    _selectedIds.add(paged[i].id);
                                  }
                                }),
                              ),
                            ),
                          ),
                        ),
                        PaginationBar(
                          total: filtered.length,
                          page: _localPage,
                          pageSize: _pageSize,
                          onPageSizeChanged: (v) => setState(() {
                            _pageSize = v;
                            _localPage = 0;
                          }),
                          onPrev: _localPage > 0
                              ? () => setState(() => _localPage--)
                              : null,
                          onNext: (_localPage + 1) * _pageSize < filtered.length
                              ? () => setState(() => _localPage++)
                              : null,
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

// ─── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final int year, month;
  final List<DepartmentFlat> depts;
  final int? deptId;
  final String? status;
  final bool canCreate;
  final bool exportingPayslips;
  final int selectedCount;
  final void Function(int y, int m, int? d, String? st) onChanged;
  final VoidCallback onGenerate;
  final VoidCallback onExportPayslips;
  final VoidCallback onClearSelection;

  const _FilterBar({
    required this.year,
    required this.month,
    required this.depts,
    this.deptId,
    this.status,
    required this.canCreate,
    required this.exportingPayslips,
    required this.selectedCount,
    required this.onChanged,
    required this.onGenerate,
    required this.onExportPayslips,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final monthField = SizedBox(
      width: 130,
      child: DropdownButtonFormField<int>(
        initialValue: month,
        decoration: InputDecoration(labelText: s.month, isDense: true),
        items: List.generate(
            12,
            (i) => DropdownMenuItem(
                value: i + 1, child: Text(s.monthLabel(i + 1)))),
        onChanged: (v) => onChanged(year, v ?? month, deptId, status),
      ),
    );

    final yearField = SizedBox(
      width: 90,
      child: TextFormField(
        initialValue: year.toString(),
        decoration: InputDecoration(labelText: s.year, isDense: true),
        keyboardType: TextInputType.number,
        onFieldSubmitted: (v) {
          final y = int.tryParse(v);
          if (y != null && y > 2000) onChanged(y, month, deptId, status);
        },
      ),
    );

    final statusField = SizedBox(
      width: 140,
      child: DropdownButtonFormField<String?>(
        initialValue: status,
        isExpanded: true,
        decoration: InputDecoration(labelText: s.status, isDense: true),
        items: [
          DropdownMenuItem(value: null, child: Text(s.all)),
          DropdownMenuItem(value: 'DRAFT', child: Text(s.payrollStatusDraft)),
          DropdownMenuItem(
              value: 'APPROVED', child: Text(s.payrollStatusApproved)),
          DropdownMenuItem(value: 'PAID', child: Text(s.payrollStatusPaid)),
        ],
        onChanged: (v) => onChanged(year, month, deptId, v),
      ),
    );

    final deptField = depts.isNotEmpty
        ? SizedBox(
            width: isMobile ? double.infinity : 180,
            child: DepartmentPickerField(
              departments: depts,
              value: deptId,
              label: s.department,
              allowAll: true,
              compact: true,
              onChanged: (v) => onChanged(year, month, v, status),
            ),
          )
        : null;

    final generateBtn = canCreate
        ? FilledButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.add, size: 16),
            label: Text(s.payrollGenerateBtn),
          )
        : null;

    // Nút export phiếu: khi có selection thì "Xuất phiếu (N)", không thì "Xuất phiếu"
    final exportPayslipsBtn = PermissionGuard(
      permission: 'payroll.view',
      child: selectedCount > 0
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: exportingPayslips ? null : onExportPayslips,
                  icon: exportingPayslips
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text(s.exportPayslipsSelected(selectedCount)),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onClearSelection,
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: s.quickFillClearSelection,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            )
          : OutlinedButton.icon(
              onPressed: exportingPayslips ? null : onExportPayslips,
              icon: exportingPayslips
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(s.exportPayslips),
            ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppTheme.background,
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    monthField,
                    const SizedBox(width: 8),
                    yearField,
                    const SizedBox(width: 8),
                    statusField,
                  ],
                ),
                if (deptField != null) ...[
                  const SizedBox(height: 8),
                  deptField,
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    exportPayslipsBtn,
                    if (generateBtn != null) ...[
                      const SizedBox(width: 8),
                      generateBtn,
                    ],
                  ],
                ),
              ],
            )
          : Row(
              children: [
                monthField,
                const SizedBox(width: 8),
                yearField,
                if (deptField != null) ...[
                  const SizedBox(width: 8),
                  deptField,
                ],
                const SizedBox(width: 8),
                statusField,
                const Spacer(),
                exportPayslipsBtn,
                if (generateBtn != null) ...[
                  const SizedBox(width: 8),
                  generateBtn,
                ],
              ],
            ),
    );
  }
}

// ─── Payroll card ──────────────────────────────────────────────────────────────

class _PayrollCard extends StatelessWidget {
  final Payroll payroll;
  final bool canApprove, canPay, canEdit;
  final bool selected;
  final VoidCallback onView, onEdit, onApprove, onPay, onDelete, onRecalculate;
  final VoidCallback onToggleSelect;

  const _PayrollCard({
    required this.payroll,
    required this.canApprove,
    required this.canPay,
    required this.canEdit,
    required this.selected,
    required this.onView,
    required this.onEdit,
    required this.onApprove,
    required this.onPay,
    required this.onDelete,
    required this.onRecalculate,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final p = payroll;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.employeeName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        Row(
                          children: [
                            if (p.departmentName != null)
                              Text(p.departmentName!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                            if (p.salaryGradeCode != null) ...[
                              if (p.departmentName != null)
                                const Text(' · ',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary)),
                              Text(
                                  '${p.salaryGradeCode} — ${p.salaryGradeName}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.primary)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(p.status),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onToggleSelect,
                    borderRadius: BorderRadius.circular(4),
                    child: IgnorePointer(
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) {},
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoTile(label: s.baseSalary, value: _fmt(p.baseSalary)),
                  const SizedBox(width: 16),
                  _InfoTile(label: s.grossSalary, value: _fmt(p.grossSalary)),
                  const SizedBox(width: 16),
                  _InfoTile(
                      label: s.netSalary,
                      value: _fmt(p.netSalary),
                      valueStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: p.netSalary < 0
                              ? AppTheme.error
                              : AppTheme.secondary,
                          fontSize: 14)),
                ],
              ),
              if (p.presentDays != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${s.presentDays}: ${p.presentDays}/${formatDays(p.standardWorkDays ?? 22)}'
                  '   ${s.dayShiftHours}: ${(p.dayHours ?? 0).toStringAsFixed(1)}h'
                  '   ${s.nightShiftHours}: ${(p.nightHours ?? 0).toStringAsFixed(1)}h'
                  '   ${s.otDayShift}: ${(p.dayOt ?? 0).toStringAsFixed(1)}h'
                  '   ${s.otNightShift}: ${(p.nightOt ?? 0).toStringAsFixed(1)}h',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onView, child: Text(s.viewDetails)),
                  if (p.status == PayrollStatus.draft && canEdit) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppTheme.error,
                      tooltip: s.delete,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      onPressed: onRecalculate,
                      icon: const Icon(Icons.refresh, size: 18),
                      color: AppTheme.primary,
                      tooltip: s.payrollRecalculateTooltip,
                      visualDensity: VisualDensity.compact,
                    ),
                    TextButton(onPressed: onEdit, child: Text(s.payrollEdit)),
                    const SizedBox(width: 4),
                    FilledButton(
                        onPressed: canApprove ? onApprove : null,
                        child: Text(s.payrollApprove)),
                  ],
                  if (p.status == PayrollStatus.approved && canPay) ...[
                    const SizedBox(width: 4),
                    FilledButton(onPressed: onPay, child: Text(s.payrollPay)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final TextStyle? valueStyle;
  const _InfoTile({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Text(value,
              style:
                  valueStyle ?? const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
}

class _StatusChip extends StatelessWidget {
  final PayrollStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      PayrollStatus.approved => (s.payrollStatusApproved, AppTheme.primary),
      PayrollStatus.paid => (s.payrollStatusPaid, AppTheme.secondary),
      _ => (s.payrollStatusDraft, AppTheme.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Pick formula dialog ───────────────────────────────────────────────────────

class _FormulaPickResult {
  final SalaryFormula? formula;
  final bool isCustom;
  const _FormulaPickResult({this.formula, this.isCustom = false});
}

class _PickFormulaDialog extends StatefulWidget {
  final List<SalaryFormula> formulas;
  final SalaryFormula? initial;
  final CustomFormulaSnapshot? customFormula;
  final int year, month;
  const _PickFormulaDialog({
    required this.formulas,
    required this.initial,
    this.customFormula,
    required this.year,
    required this.month,
  });

  @override
  State<_PickFormulaDialog> createState() => _PickFormulaDialogState();
}

class _PickFormulaDialogState extends State<_PickFormulaDialog> {
  // null = custom formula selected
  SalaryFormula? _selected;
  bool _customSelected = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.payrollPickFormulaTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option công thức đã chỉnh sửa (inline)
            if (widget.customFormula != null)
              RadioListTile<bool>(
                value: true,
                groupValue: _customSelected,
                onChanged: (v) => setState(() {
                  _customSelected = true;
                  _selected = null;
                }),
                title: Text(
                  widget.customFormula!.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(s.payrollPickFormulaCustomSubtitle,
                    style: TextStyle(fontSize: 12, color: Colors.orange[700])),
                dense: true,
              ),
            // Các công thức gốc
            ...widget.formulas.map((f) {
              final isDefault = f == widget.initial;
              final effectiveDate = f.effectiveDate.toString().substring(0, 10);
              return RadioListTile<SalaryFormula?>(
                value: f,
                groupValue: _customSelected ? null : _selected,
                onChanged: (v) => setState(() {
                  _customSelected = false;
                  _selected = f;
                }),
                title: Text(
                  f.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _selected == f && !_customSelected
                        ? null
                        : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  isDefault
                      ? '${s.payrollPickFormulaDateSubtitle(effectiveDate)} · ${s.payrollPickFormulaRecentNote}'
                      : s.payrollPickFormulaDateSubtitle(effectiveDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDefault ? Colors.blue[700] : null,
                  ),
                ),
                secondary: _selected == f && !_customSelected
                    ? const Icon(Icons.check_circle,
                        color: AppTheme.primary, size: 18)
                    : null,
                dense: true,
              );
            }),
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
            _customSelected
                ? const _FormulaPickResult(isCustom: true)
                : _FormulaPickResult(formula: _selected),
          ),
          child: Text(s.payrollRecalculateAction),
        ),
      ],
    );
  }
}

// ─── Generate dialog ───────────────────────────────────────────────────────────

class _GenerateDialog extends StatefulWidget {
  final EmployeeRepository empRepo;
  final PayrollRepository repo;
  const _GenerateDialog({required this.empRepo, required this.repo});

  @override
  State<_GenerateDialog> createState() => _GenerateDialogState();
}

// Entry cho mỗi nhân viên đã chọn
class _EmpEntry {
  final Employee employee;
  List<SalaryFormula> formulas;
  SalaryFormula? selectedFormula;
  _EmpEntry(
      {required this.employee, this.formulas = const [], this.selectedFormula});
}

class _GenerateDialogState extends State<_GenerateDialog> {
  final _searchCtrl = TextEditingController();
  final _formulaRepo = SalaryFormulaRepository();
  List<Employee> _suggestions = [];
  final List<_EmpEntry> _entries = [];
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _searching = false;
  bool _saving = false;
  String? _error;

  // Cache formulas theo gradeId để tránh load lại
  final Map<int, List<SalaryFormula>> _formulaCache = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await widget.empRepo.getAll(search: q, size: 10);
      // Lọc bỏ nhân viên đã chọn
      final existing = _entries.map((e) => e.employee.id).toSet();
      if (mounted) {
        setState(() => _suggestions =
            res.items.where((e) => !existing.contains(e.id)).toList());
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addEmployee(Employee emp) async {
    setState(() {
      _suggestions = [];
      _searchCtrl.clear();
    });

    // Load formulas nếu có grade
    List<SalaryFormula> formulas = [];
    if (emp.salaryGradeId != null) {
      if (_formulaCache.containsKey(emp.salaryGradeId)) {
        formulas = _formulaCache[emp.salaryGradeId]!;
      } else {
        try {
          formulas = await _formulaRepo.getAll(gradeId: emp.salaryGradeId);
          _formulaCache[emp.salaryGradeId!] = formulas;
        } catch (_) {}
      }
    }

    // Ưu tiên công thức gần nhất (effectiveDate <= tháng được chọn)
    final cutoff = DateTime(_year, _month, 1);
    final eligible = formulas
        .where((f) => !f.effectiveDate.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    final selected = eligible.isNotEmpty
        ? eligible.first
        : (formulas.isNotEmpty ? formulas.first : null);

    if (mounted) {
      setState(() {
        _entries.add(_EmpEntry(
            employee: emp, formulas: formulas, selectedFormula: selected));
      });
    }
  }

  Future<void> _submit() async {
    if (_entries.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final errors = <String>[];
    final created = <Payroll>[];
    for (final entry in _entries) {
      try {
        final p = await widget.repo.generate(
          entry.employee.id,
          _year,
          _month,
          formulaId: entry.selectedFormula?.id,
        );
        created.add(p);
      } catch (e) {
        errors.add('${entry.employee.fullName}: ${serverMsg(e)}');
      }
    }
    if (!mounted) return;
    if (errors.isNotEmpty) {
      setState(() {
        _saving = false;
        _error = errors.join('\n');
      });
    } else {
      Navigator.pop(context, created.isNotEmpty ? created.last : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.payrollGenerate),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style:
                        const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration:
                        InputDecoration(labelText: s.month, isDense: true),
                    items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                            value: i + 1, child: Text(s.monthLabel(i + 1)))),
                    onChanged: (v) => setState(() => _month = v ?? _month),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _year.toString(),
                    decoration:
                        InputDecoration(labelText: s.year, isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final y = int.tryParse(v);
                      if (y != null && y > 2000) setState(() => _year = y);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: s.searchEmployeeHint,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
              ),
              onChanged: _search,
            ),
            if (_suggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: _suggestions
                      .map((e) => ListTile(
                            dense: true,
                            title: Text(e.fullName,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              '${e.employeeCode}${e.salaryGradeName != null ? ' · ${e.salaryGradeName}' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () => _addEmployee(e),
                          ))
                      .toList(),
                ),
              ),
            if (_entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final entry = _entries[i];
                    final emp = entry.employee;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 2),
                      child: Row(
                        children: [
                          // Mã NV
                          SizedBox(
                            width: 70,
                            child: Text(emp.employeeCode,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontFamily: 'monospace')),
                          ),
                          // Tên
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(emp.fullName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                if (emp.salaryGradeName != null)
                                  Text(emp.salaryGradeName!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.primary)),
                              ],
                            ),
                          ),
                          // Dropdown công thức (nếu > 1)
                          if (entry.formulas.length > 1) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<SalaryFormula>(
                                initialValue: entry.selectedFormula,
                                isDense: true,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: s.salaryFormula,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                ),
                                items: entry.formulas
                                    .map((f) => DropdownMenuItem(
                                          value: f,
                                          child: Text(
                                            '${f.name} · ${f.effectiveDate.toString().substring(0, 10)}',
                                            style:
                                                const TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => entry.selectedFormula = v),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () =>
                                setState(() => _entries.removeAt(i)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: (_entries.isEmpty || _saving) ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(_entries.isEmpty
                  ? s.create
                  : '${s.create} (${_entries.length})'),
        ),
      ],
    );
  }
}

// ─── Edit draft dialog ─────────────────────────────────────────────────────────

class _EditDraftDialog extends StatefulWidget {
  final Payroll payroll;
  final PayrollRepository repo;
  const _EditDraftDialog({required this.payroll, required this.repo});

  @override
  State<_EditDraftDialog> createState() => _EditDraftDialogState();
}

class _EditDraftDialogState extends State<_EditDraftDialog> {
  late final TextEditingController _allowanceCtrl;
  late final TextEditingController _bonusCtrl;
  late final TextEditingController _deductCtrl;
  late final TextEditingController _noteCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _allowanceCtrl =
        TextEditingController(text: widget.payroll.allowance.toString());
    _bonusCtrl = TextEditingController(text: widget.payroll.bonus.toString());
    _deductCtrl =
        TextEditingController(text: widget.payroll.otherDeductions.toString());
    _noteCtrl = TextEditingController(text: widget.payroll.note ?? '');
  }

  @override
  void dispose() {
    _allowanceCtrl.dispose();
    _bonusCtrl.dispose();
    _deductCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repo.updateDraft(
        widget.payroll.id,
        allowance: double.tryParse(_allowanceCtrl.text) ?? 0,
        bonus: double.tryParse(_bonusCtrl.text) ?? 0,
        otherDeductions: double.tryParse(_deductCtrl.text) ?? 0,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = serverMsg(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.payrollEdit),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style:
                        const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            TextFormField(
              controller: _allowanceCtrl,
              decoration:
                  InputDecoration(labelText: s.allowance, suffixText: 'đ'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bonusCtrl,
              decoration: InputDecoration(labelText: s.bonus, suffixText: 'đ'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _deductCtrl,
              decoration: InputDecoration(
                  labelText: s.otherDeductions, suffixText: 'đ'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration: InputDecoration(labelText: s.note),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(s.save),
        ),
      ],
    );
  }
}

// ─── Payslip dialog ────────────────────────────────────────────────────────────

class _PayslipDialog extends StatefulWidget {
  final Payroll payroll;
  const _PayslipDialog({required this.payroll});

  @override
  State<_PayslipDialog> createState() => _PayslipDialogState();
}

class _PayslipDialogState extends State<_PayslipDialog> {
  final _repo = PayrollRepository();
  final _formulaRepo = SalaryFormulaRepository();
  bool _exporting = false;
  bool _recalculating = false;

  Future<void> _recalculate() async {
    final s = AppLocalizations.of(context);
    final p = widget.payroll;
    int? formulaId;
    CustomFormulaSnapshot? customFormula;

    if (p.salaryGradeId != null) {
      List<SalaryFormula> formulas = [];
      try { formulas = await _formulaRepo.getAll(gradeId: p.salaryGradeId); } catch (_) {}
      if (!mounted) return;

      final hasCustom = p.customFormula != null;
      if (formulas.length > 1 || hasCustom) {
        final cutoff = DateTime(p.year, p.month, 1);
        final eligible = formulas
            .where((f) => !f.effectiveDate.isAfter(cutoff))
            .toList()
          ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
        final defaultFormula = eligible.isNotEmpty ? eligible.first : (formulas.isNotEmpty ? formulas.first : null);

        final result = await showDialog<_FormulaPickResult>(
          context: context,
          builder: (ctx) => _PickFormulaDialog(
            formulas: formulas,
            initial: defaultFormula,
            customFormula: p.customFormula,
            year: p.year,
            month: p.month,
          ),
        );
        if (!mounted) return;
        if (result == null) return;
        if (result.isCustom) {
          customFormula = p.customFormula;
        } else {
          formulaId = result.formula?.id;
        }
      }
    }

    setState(() => _recalculating = true);
    try {
      if (customFormula != null) {
        await _repo.updateDraft(p.id, customFormula: customFormula);
      } else {
        await _repo.recalculate(p.id, formulaId: formulaId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.payrollRecalculateDone)));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _recalculating = false);
    }
  }

  Future<void> _exportThis() async {
    final s = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final p = widget.payroll;
      final result = await _repo.exportPayslips(
        year: p.year,
        month: p.month,
        ids: [p.id],
      );
      await saveFileToDevice(result.bytes, result.filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.exportPayslipsSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final p = widget.payroll;
    final totalDed = p.totalDeduction;
    final formulaRest = p.formulaDeductionRemainder;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Stack(children: [
                Text(s.payslip,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                Positioned(top: 0, right: 0, child: _StatusChip(p.status)),
              ]),
              const SizedBox(height: 4),
              Text(
                '${p.employeeName} — ${formatPayrollPeriod(s, p.periodFrom, p.periodTo, p.month, p.year)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              if (p.departmentName != null)
                Text(
                  '${p.departmentName}${p.positionName != null ? ' · ${p.positionName}' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              const Divider(height: 24),
              // Attendance summary
              _Row(s.presentDays,
                  '${p.presentDays ?? '-'} / ${formatDays(p.standardWorkDays ?? 22)} ${s.daysSuffix}'),
              _Row(s.dayShiftHours,
                  '${(p.dayHours ?? 0).toStringAsFixed(1)} ${s.hourSuffix}'),
              _Row(s.nightShiftHours,
                  '${(p.nightHours ?? 0).toStringAsFixed(1)} ${s.hourSuffix}'),
              _Row(s.otDayShift, '${(p.dayOt ?? 0).toStringAsFixed(1)} ${s.hourSuffix}'),
              _Row(
                  s.otNightShift, '${(p.nightOt ?? 0).toStringAsFixed(1)} ${s.hourSuffix}'),
              const Divider(height: 20),
              // ── Mức lương cơ bản ──
              if (p.payType == 'HOURLY') ...[
                _Row(s.baseSalary, '${_fmt(p.baseSalary)}/${s.hourSuffix}'),
              ] else ...[
                _Row(s.baseSalaryMonthly, _fmt(p.baseSalary)),
                _Row(s.actualWorkDays,
                    '${p.presentDays ?? 0} / ${formatDays(p.standardWorkDays ?? 22)} ${s.daysSuffix}'),
              ],
              const SizedBox(height: 4),
              // ── Thu nhập (chỉ hiện nếu có) ──
              if (p.incomeEntries.isNotEmpty) ...[
                _PayslipSectionHeader(s.incomeSection, AppTheme.primary),
                ...(p.incomeEntries.values.toList()
                      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
                    .map((e) => _Row(e.label, _fmt(e.amount))),
                const SizedBox(height: 4),
              ],
              // ── Trợ cấp (chỉ hiện nếu có) ──
              if (p.allowanceEntries.isNotEmpty) ...[
                _PayslipSectionHeader(s.allowanceSection, const Color(0xFF9C27B0)),
                ...(p.allowanceEntries.values.toList()
                      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
                    .map((e) => _Row(e.label, _fmt(e.amount))),
                const SizedBox(height: 4),
              ],
              if (p.allowance > 0) _Row(s.allowance, _fmt(p.allowance)),
              if (p.bonus > 0) _Row(s.bonus, _fmt(p.bonus)),
              // ── Gross riêng ──
              const Divider(height: 16),
              _Row(s.grossSalary, _fmt(p.grossSalary),
                  bold: true, color: AppTheme.primary),
              const SizedBox(height: 8),
              // ── Khấu trừ ──
              _PayslipSectionHeader(s.deductionSection, AppTheme.error),
              ...p.customDeductions.values.map((d) =>
                  _Row(d.label, '-${_fmt(d.amount)}', color: AppTheme.error)),
              if (p.otherDeductions > 0)
                _Row(s.otherDeductions, '-${_fmt(p.otherDeductions)}',
                    color: AppTheme.error),
              if (formulaRest.abs() >= 1)
                _Row(s.formulaDeductionRest, '-${_fmt(formulaRest)}',
                    color: AppTheme.error),
              _Row(s.totalDeductions, '-${_fmt(totalDed)}',
                  bold: true, color: AppTheme.error),
              const Divider(height: 20),
              // Net
              _Row(s.netSalary, _fmt(p.netSalary),
                  bold: true,
                  large: true,
                  color: p.netSalary < 0 ? AppTheme.error : AppTheme.secondary),
              PayslipTaxInfo(payroll: p, showEmployerCost: true),
              const SizedBox(height: 8),
              if (p.note != null && p.note!.isNotEmpty)
                Text('${s.note}: ${p.note}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              const SizedBox(height: 16),
              // Actions
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (p.status == PayrollStatus.draft)
                    OutlinedButton.icon(
                      onPressed: _recalculating ? null : _recalculate,
                      icon: _recalculating
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 16),
                      label: Text(s.payrollRecalculateTooltip),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12)),
                    ),
                  OutlinedButton.icon(
                    onPressed: _exporting ? null : _exportThis,
                    icon: _exporting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_outlined, size: 16),
                    label: Text(s.exportPayslips),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayslipSectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _PayslipSectionHeader(this.title, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(children: [
          Container(
              width: 3,
              height: 14,
              color: color,
              margin: const EdgeInsets.only(right: 6)),
          Text(title,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          const Expanded(child: Divider(indent: 8)),
        ]),
      );
}

// ─── Inline formula edit dialog — wrapper dùng FormulaEditorDialog ────────────

class _InlineFormulaEditDialog extends StatelessWidget {
  final Payroll payroll;
  final PayrollRepository repo;
  final SalaryFormula? baseFormula;
  const _InlineFormulaEditDialog({
    required this.payroll,
    required this.repo,
    this.baseFormula,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final cf = payroll.customFormula;
    final bf = baseFormula;

    // Tạo SalaryFormula giả để truyền vào FormulaEditorDialog như "existing"
    // nhưng override onSave để lưu inline thay vì update repo
    final fakeExisting = bf != null
        ? SalaryFormula(
            id: bf.id,
            salaryGradeId: bf.salaryGradeId,
            salaryGradeCode: bf.salaryGradeCode,
            salaryGradeName: bf.salaryGradeName,
            name: cf?.name ?? s.payFormulaEditedName(bf.name),
            effectiveDate: bf.effectiveDate,
            expressionGross: cf?.expressionGross ?? bf.expressionGross,
            expressionNet: cf?.expressionNet ?? bf.expressionNet,
            customVars: cf?.customVars ?? bf.customVars,
            deductionVars: cf?.deductionVars ?? bf.deductionVars,
            incomeVars: cf?.incomeVars ?? bf.incomeVars,
            allowanceVars: cf?.allowanceVars ?? bf.allowanceVars,
          )
        : null;

    return FormulaEditorDialog(
      grades: const [],
      repo: SalaryFormulaRepository(),
      existing: fakeExisting,
      onSave: ({
        required name,
        required expressionGross,
        required expressionNet,
        required customVars,
        required deductionVars,
        required incomeVars,
        required allowanceVars,
      }) async {
        final snapshot = CustomFormulaSnapshot(
          name: name,
          expressionGross: expressionGross,
          expressionNet: expressionNet,
          customVars: customVars,
          deductionVars: deductionVars,
          incomeVars: incomeVars,
          allowanceVars: allowanceVars,
        );
        return await repo.updateDraft(payroll.id, customFormula: snapshot);
      },
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold, large;
  final Color? color;
  const _Row(this.label, this.value,
      {this.bold = false, this.large = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: large ? 15 : 13,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                      color: AppTheme.textPrimary)),
            ),
            Text(value,
                style: TextStyle(
                    fontSize: large ? 15 : 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: color ?? AppTheme.textPrimary)),
          ],
        ),
      );
}
