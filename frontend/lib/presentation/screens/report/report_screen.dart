import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/file_saver_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/services/department_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_dropdown.dart';

/// Route: /reports
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _repo = ReportRepository();

  List<DepartmentFlat> _depts = [];
  int? _selectedDeptId;

  final now = DateTime.now();
  late int _year;
  late int _month;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  String? _exporting; // report key being exported

  @override
  void initState() {
    super.initState();
    _year  = now.year;
    _month = now.month;
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo   = now;
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

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDateDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) { _dateFrom = picked; } else { _dateTo = picked; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
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
                _FilterBar(
                  depts: _depts,
                  selectedDeptId: _selectedDeptId,
                  year: _year,
                  month: _month,
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  onDeptChanged: (v) => setState(() => _selectedDeptId = v),
                  onYearChanged: (v) => setState(() => _year = v),
                  onMonthChanged: (v) => setState(() => _month = v),
                  onPickFrom: () => _pickDate(true),
                  onPickTo: () => _pickDate(false),
                  fmtDate: _fmtDateDisplay,
                  s: s,
                ),
                const SizedBox(height: 20),
                _ReportGroup(
                  title: s.reportGroupEmployee,
                  color: AppTheme.primary,
                  icon: Icons.people_outline,
                  reports: [
                    _ReportItem(
                      key_: 'employee_headcount',
                      title: s.reportEmployee,
                      desc: s.reportEmployeeDesc,
                      icon: Icons.bar_chart_outlined,
                      exporting: _exporting,
                      onExport: () => _export('employee_headcount', s,
                          () => _repo.employeeHeadcount(deptId: _selectedDeptId)),
                      s: s,
                    ),
                    _ReportItem(
                      key_: 'new_hires',
                      title: s.reportNewHires,
                      desc: s.reportNewHiresDesc,
                      icon: Icons.person_add_outlined,
                      exporting: _exporting,
                      onExport: () => _export('new_hires', s, () => _repo.newHires(
                        from: _fmtDate(_dateFrom ?? DateTime(now.year, now.month, 1)),
                        to:   _fmtDate(_dateTo   ?? now),
                        deptId: _selectedDeptId,
                      )),
                      s: s,
                    ),
                    _ReportItem(
                      key_: 'resigned',
                      title: s.reportResigned,
                      desc: s.reportResignedDesc,
                      icon: Icons.person_remove_outlined,
                      exporting: _exporting,
                      onExport: () => _export('resigned', s, () => _repo.resigned(
                        from: _fmtDate(_dateFrom ?? DateTime(now.year, now.month, 1)),
                        to:   _fmtDate(_dateTo   ?? now),
                        deptId: _selectedDeptId,
                      )),
                      s: s,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ReportGroup(
                  title: s.reportGroupAttendance,
                  color: AppTheme.secondary,
                  icon: Icons.fingerprint_outlined,
                  reports: [
                    _ReportItem(
                      key_: 'attendance_summary',
                      title: s.reportAttendanceSummary,
                      desc: s.reportAttendanceSummaryDesc,
                      icon: Icons.calendar_month_outlined,
                      exporting: _exporting,
                      onExport: () => _export('attendance_summary', s,
                          () => _repo.attendanceSummary(year: _year, month: _month,
                              deptId: _selectedDeptId)),
                      s: s,
                    ),
                    _ReportItem(
                      key_: 'overtime_summary',
                      title: s.reportOvertimeSummary,
                      desc: s.reportOvertimeSummaryDesc,
                      icon: Icons.access_time_outlined,
                      exporting: _exporting,
                      onExport: () => _export('overtime_summary', s,
                          () => _repo.overtimeSummary(year: _year, month: _month,
                              deptId: _selectedDeptId)),
                      s: s,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ReportGroup(
                  title: s.reportGroupPayroll,
                  color: const Color(0xFF7C3AED),
                  icon: Icons.payments_outlined,
                  reports: [
                    _ReportItem(
                      key_: 'payroll_summary',
                      title: s.reportPayrollSummary,
                      desc: s.reportPayrollSummaryDesc,
                      icon: Icons.summarize_outlined,
                      exporting: _exporting,
                      onExport: () => _export('payroll_summary', s,
                          () => _repo.payrollSummary(year: _year, month: _month,
                              deptId: _selectedDeptId)),
                      s: s,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ReportGroup(
                  title: s.reportGroupLeave,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.beach_access_outlined,
                  reports: [
                    _ReportItem(
                      key_: 'leave_balance',
                      title: s.reportLeaveBalance,
                      desc: s.reportLeaveBalanceDesc,
                      icon: Icons.account_balance_wallet_outlined,
                      exporting: _exporting,
                      onExport: () => _export('leave_balance', s,
                          () => _repo.leaveBalance(deptId: _selectedDeptId)),
                      s: s,
                    ),
                    _ReportItem(
                      key_: 'leave_usage',
                      title: s.reportLeaveUsage,
                      desc: s.reportLeaveUsageDesc,
                      icon: Icons.event_note_outlined,
                      exporting: _exporting,
                      onExport: () => _export('leave_usage', s, () => _repo.leaveUsage(
                        from: _fmtDate(_dateFrom ?? DateTime(now.year, now.month, 1)),
                        to:   _fmtDate(_dateTo   ?? now),
                        deptId: _selectedDeptId,
                      )),
                      s: s,
                    ),
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

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final List<DepartmentFlat> depts;
  final int? selectedDeptId;
  final int year;
  final int month;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ValueChanged<int?> onDeptChanged;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final String Function(DateTime) fmtDate;
  final AppLocalizations s;

  const _FilterBar({
    required this.depts,
    required this.selectedDeptId,
    required this.year,
    required this.month,
    required this.dateFrom,
    required this.dateTo,
    required this.onDeptChanged,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.fmtDate,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final curYear = DateTime.now().year;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.reportScreenSubtitle,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 10, children: [
            // Year
            SizedBox(
              width: 110,
              child: AppDropdown<int>(
                value: year,
                label: s.reportFilterYear,
                items: [curYear - 1, curYear, curYear + 1]
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (v) { if (v != null) { onYearChanged(v); } },
              ),
            ),
            // Month
            SizedBox(
              width: 100,
              child: AppDropdown<int>(
                value: month,
                label: s.reportFilterMonth,
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(m.toString().padLeft(2, '0'))))
                    .toList(),
                onChanged: (v) { if (v != null) { onMonthChanged(v); } },
              ),
            ),
            // Department
            SizedBox(
              width: 200,
              child: AppDropdown<int?>(
                value: selectedDeptId,
                label: s.reportFilterDepartment,
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(s.reportFilterAllDepts)),
                  ...depts.map((d) => DropdownMenuItem<int?>(
                      value: d.id,
                      child: Text(d.name, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: onDeptChanged,
              ),
            ),
            // Date range
            _DateBtn(
              label: dateFrom != null ? fmtDate(dateFrom!) : 'From',
              icon: Icons.calendar_today_outlined,
              onTap: onPickFrom,
            ),
            const Text('→', style: TextStyle(color: AppTheme.textSecondary)),
            _DateBtn(
              label: dateTo != null ? fmtDate(dateTo!) : 'To',
              icon: Icons.calendar_today_outlined,
              onTap: onPickTo,
            ),
          ]),
        ]),
      ),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DateBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
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
        side: const BorderSide(color: AppTheme.border),
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
  final String? exporting;
  final VoidCallback onExport;
  final AppLocalizations s;

  const _ReportItem({
    required this.key_,
    required this.title,
    required this.desc,
    required this.icon,
    required this.exporting,
    required this.onExport,
    required this.s,
  });

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
          Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ])),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: isBusy ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : onExport,
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
