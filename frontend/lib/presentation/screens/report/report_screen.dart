import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../data/services/auth_service.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/file_saver_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/services/department_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_dropdown.dart';

// ── Filter types và values ────────────────────────────────────────────────────

enum _FT { year, month, department, dateRange }

class _FilterValues {
  final int year;
  final int month;
  final int? deptId;
  final DateTime dateFrom;
  final DateTime dateTo;
  const _FilterValues({
    required this.year,
    required this.month,
    this.deptId,
    required this.dateFrom,
    required this.dateTo,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Route: /reports
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _repo = ReportRepository();
  List<DepartmentFlat> _depts = [];
  String? _exporting;

  @override
  void initState() {
    super.initState();
    _loadDepts();
  }

  Future<void> _loadDepts() async {
    try {
      final d = await DepartmentService.instance.getFlat();
      if (mounted) setState(() => _depts = d);
    } catch (_) {}
  }

  Future<void> _export(
    String key,
    AppLocalizations s,
    Future<({Uint8List bytes, String filename})> Function() call,
  ) async {
    if (_exporting != null) return;
    setState(() => _exporting = key);
    try {
      final result = await call();
      await saveFileToDevice(result.bytes, result.filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${s.reportExportSuccess}: ${result.filename}'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(serverMsg(e)),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _doExport(String key, _FilterValues v, AppLocalizations s) {
    switch (key) {
      case 'employee_headcount':
        _export(key, s, () => _repo.employeeHeadcount(deptId: v.deptId));
      case 'insured_employees':
        _export(key, s, () => _repo.insuredEmployees(deptId: v.deptId));
      case 'dependents':
        _export(key, s, () => _repo.dependents(deptId: v.deptId));
      case 'new_hires':
        _export(key, s, () => _repo.newHires(from: _fmt(v.dateFrom), to: _fmt(v.dateTo), deptId: v.deptId));
      case 'resigned':
        _export(key, s, () => _repo.resigned(from: _fmt(v.dateFrom), to: _fmt(v.dateTo), deptId: v.deptId));
      case 'attendance_summary':
        _export(key, s, () => _repo.attendanceSummary(year: v.year, month: v.month, deptId: v.deptId));
      case 'overtime_summary':
        _export(key, s, () => _repo.overtimeSummary(year: v.year, month: v.month, deptId: v.deptId));
      case 'payroll_summary':
        _export(key, s, () => _repo.payrollSummary(year: v.year, month: v.month, deptId: v.deptId));
      case 'yearly_overview':
        _export(key, s, () => _repo.yearlyOverview(year: v.year, deptId: v.deptId));
      case 'leave_balance':
        _export(key, s, () => _repo.leaveBalance(deptId: v.deptId));
      case 'leave_usage':
        _export(key, s, () => _repo.leaveUsage(from: _fmt(v.dateFrom), to: _fmt(v.dateTo), deptId: v.deptId));
    }
  }

  bool get _canViewYearly {
    final u = AuthService.instance.currentUser;
    if (u == null) return false;
    return u.isSystemAdmin || (u.can('PAYROLL_VIEW') && u.can('EMPLOYEE_VIEW') && u.can('LEAVE_VIEW'));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final now = DateTime.now();

    _ReportItem item(String key, String title, String desc, IconData icon, List<_FT> filters) =>
        _ReportItem(
          key_: key,
          title: title,
          desc: desc,
          icon: icon,
          filterTypes: filters,
          depts: _depts,
          initialYear: now.year,
          initialMonth: now.month,
          exporting: _exporting,
          onExport: (v) => _doExport(key, v, s),
          s: s,
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.reportScreenTitle), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReportGroup(
                  title: s.reportGroupEmployee,
                  color: AppTheme.primary,
                  icon: Icons.people_outline,
                  reports: [
                    item('employee_headcount', s.reportEmployee, s.reportEmployeeDesc,
                        Icons.bar_chart_outlined, [_FT.department]),
                    item('new_hires', s.reportNewHires, s.reportNewHiresDesc,
                        Icons.person_add_outlined, [_FT.dateRange, _FT.department]),
                    item('resigned', s.reportResigned, s.reportResignedDesc,
                        Icons.person_remove_outlined, [_FT.dateRange, _FT.department]),
                    item('insured_employees', s.reportInsured, s.reportInsuredDesc,
                        Icons.health_and_safety_outlined, [_FT.department]),
                    item('dependents', s.reportDependents, s.reportDependentsDesc,
                        Icons.family_restroom_outlined, [_FT.department]),
                  ],
                ),
                const SizedBox(height: 16),
                // Báo cáo tổng quan năm gồm cả số liệu lương, nhân sự và nghỉ phép: cần đủ quyền xem của cả ba
                if (_canViewYearly) ...[
                  _ReportGroup(
                    title: s.reportGroupYearly,
                    color: const Color(0xFF059669),
                    icon: Icons.analytics_outlined,
                    reports: [
                      item('yearly_overview', s.reportYearlyOverview, s.reportYearlyOverviewDesc,
                          Icons.auto_graph_outlined, [_FT.year, _FT.department]),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                _ReportGroup(
                  title: s.reportGroupAttendance,
                  color: AppTheme.secondary,
                  icon: Icons.fingerprint_outlined,
                  reports: [
                    item('attendance_summary', s.reportAttendanceSummary, s.reportAttendanceSummaryDesc,
                        Icons.calendar_month_outlined, [_FT.year, _FT.month, _FT.department]),
                    item('overtime_summary', s.reportOvertimeSummary, s.reportOvertimeSummaryDesc,
                        Icons.access_time_outlined, [_FT.year, _FT.month, _FT.department]),
                  ],
                ),
                const SizedBox(height: 16),
                _ReportGroup(
                  title: s.reportGroupPayroll,
                  color: const Color(0xFF7C3AED),
                  icon: Icons.payments_outlined,
                  reports: [
                    item('payroll_summary', s.reportPayrollSummary, s.reportPayrollSummaryDesc,
                        Icons.summarize_outlined, [_FT.year, _FT.month, _FT.department]),
                  ],
                ),
                const SizedBox(height: 16),
                _ReportGroup(
                  title: s.reportGroupLeave,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.beach_access_outlined,
                  reports: [
                    item('leave_balance', s.reportLeaveBalance, s.reportLeaveBalanceDesc,
                        Icons.account_balance_wallet_outlined, [_FT.department]),
                    item('leave_usage', s.reportLeaveUsage, s.reportLeaveUsageDesc,
                        Icons.event_note_outlined, [_FT.dateRange, _FT.department]),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter dialog ─────────────────────────────────────────────────────────────

class _FilterDialog extends StatefulWidget {
  final String reportTitle;
  final List<_FT> types;
  final List<DepartmentFlat> depts;
  final int initialYear;
  final int initialMonth;
  final AppLocalizations s;

  const _FilterDialog({
    required this.reportTitle,
    required this.types,
    required this.depts,
    required this.initialYear,
    required this.initialMonth,
    required this.s,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late int _year;
  late int _month;
  int? _deptId;
  late DateTime _dateFrom;
  late DateTime _dateTo;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = now;
  }

  String _fmtDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) { _dateFrom = picked; } else { _dateTo = picked; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final curYear = DateTime.now().year;
    final has = widget.types.contains;

    return AlertDialog(
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.reportExportOptions,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal)),
        const SizedBox(height: 2),
        Text(widget.reportTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: SizedBox(
        width: 380,
        child: Wrap(spacing: 12, runSpacing: 14, children: [
          if (has(_FT.year))
            SizedBox(
              width: 110,
              child: AppDropdown<int>(
                value: _year,
                label: s.reportFilterYear,
                items: [curYear - 2, curYear - 1, curYear, curYear + 1]
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (v) { if (v != null) setState(() => _year = v); },
              ),
            ),
          if (has(_FT.month))
            SizedBox(
              width: 100,
              child: AppDropdown<int>(
                value: _month,
                label: s.reportFilterMonth,
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(m.toString().padLeft(2, '0'))))
                    .toList(),
                onChanged: (v) { if (v != null) setState(() => _month = v); },
              ),
            ),
          if (has(_FT.dateRange)) ...[
            _DateBtn(
              label: s.dashDateFromLabel(_fmtDisplay(_dateFrom)),
              onTap: () => _pickDate(true),
            ),
            _DateBtn(
              label: s.dashDateToLabel(_fmtDisplay(_dateTo)),
              onTap: () => _pickDate(false),
            ),
          ],
          if (has(_FT.department))
            SizedBox(
              width: double.infinity,
              child: AppDropdown<int?>(
                value: _deptId,
                label: s.reportFilterDepartment,
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(s.reportFilterAllDepts)),
                  ...widget.depts.map((d) => DropdownMenuItem<int?>(
                      value: d.id,
                      child: Text(d.name, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => _deptId = v),
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            _FilterValues(
              year: _year,
              month: _month,
              deptId: _deptId,
              dateFrom: _dateFrom,
              dateTo: _dateTo,
            ),
          ),
          icon: const Icon(Icons.download_outlined, size: 16),
          label: Text(s.reportExportBtn),
        ),
      ],
    );
  }
}

class _DateBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
          ]),
        ),
      ),
    );
  }
}

// ── Report group ──────────────────────────────────────────────────────────────

class _ReportGroup extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<_ReportItem> reports;

  const _ReportGroup({
    required this.title,
    required this.color,
    required this.icon,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...reports,
        ]),
      ),
    );
  }
}

// ── Report item ───────────────────────────────────────────────────────────────

class _ReportItem extends StatelessWidget {
  final String key_;
  final String title;
  final String desc;
  final IconData icon;
  final List<_FT> filterTypes;
  final List<DepartmentFlat> depts;
  final int initialYear;
  final int initialMonth;
  final String? exporting;
  final void Function(_FilterValues) onExport;
  final AppLocalizations s;

  const _ReportItem({
    required this.key_,
    required this.title,
    required this.desc,
    required this.icon,
    required this.filterTypes,
    required this.depts,
    required this.initialYear,
    required this.initialMonth,
    required this.exporting,
    required this.onExport,
    required this.s,
  });

  Future<void> _showFilterDialog(BuildContext context) async {
    final result = await showDialog<_FilterValues>(
      context: context,
      builder: (ctx) => _FilterDialog(
        reportTitle: title,
        types: filterTypes,
        depts: depts,
        initialYear: initialYear,
        initialMonth: initialMonth,
        s: s,
      ),
    );
    if (result != null) onExport(result);
  }

  @override
  Widget build(BuildContext context) {
    final isMe = exporting == key_;
    final isBusy = exporting != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(desc, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ])),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: isBusy ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : () => _showFilterDialog(context),
            icon: isMe
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined, size: 15),
            label: Text(
              isMe ? s.reportExporting : s.reportExportBtn,
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ]),
    );
  }
}
