import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../data/models/payroll.dart';
import '../../../data/repositories/payroll_repository.dart';
import '../../../data/services/auth_service.dart';
import 'package:bosskin/l10n/app_localizations.dart';

final _currFmt2 = NumberFormat('#,###', 'vi_VN');
String _fmt2(double v) => '${_currFmt2.format(v)}đ';

class SelfPayrollScreen extends StatefulWidget {
  const SelfPayrollScreen({super.key});

  @override
  State<SelfPayrollScreen> createState() => _SelfPayrollScreenState();
}

class _SelfPayrollScreenState extends State<SelfPayrollScreen> {
  final _repo = PayrollRepository();
  int _year = DateTime.now().year;
  bool _loading = true;
  String? _error;
  List<Payroll> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _repo.getSelf(year: _year);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPayslip(Payroll p) {
    showDialog(context: context, builder: (_) => _SelfPayslipDialog(payroll: p));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (AuthService.instance.isImpersonating) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(s.impersonatingCompanyNotice,
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Column(
      children: [
        // Year picker
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text(s.selfPayroll,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () { setState(() => _year--); _load(); },
              ),
              Text('$_year', style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _year < DateTime.now().year
                    ? () { setState(() => _year++); _load(); }
                    : null,
              ),
            ],
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
              : _items.isEmpty
                  ? Center(child: Text(s.noResults))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _SelfPayrollCard(
                        payroll: _items[i],
                        onTap: () => _openPayslip(_items[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _SelfPayrollCard extends StatelessWidget {
  final Payroll payroll;
  final VoidCallback onTap;
  const _SelfPayrollCard({required this.payroll, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final p = payroll;
    final monthNames = ['', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4',
      'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8', 'Tháng 9',
      'Tháng 10', 'Tháng 11', 'Tháng 12'];
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: Text('${p.month}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary)),
        ),
        title: Text(monthNames[p.month],
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${s.presentDays}: ${p.presentDays ?? '-'}/${p.standardWorkDays ?? 22}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_fmt2(p.netSalary),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppTheme.secondary)),
            _StatusChip(p.status),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PayrollStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      PayrollStatus.approved => (s.payrollStatusApproved, AppTheme.primary),
      PayrollStatus.paid     => (s.payrollStatusPaid, AppTheme.secondary),
      _                      => (s.payrollStatusDraft, AppTheme.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _SelfPayslipDialog extends StatelessWidget {
  final Payroll payroll;
  const _SelfPayslipDialog({required this.payroll});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final p = payroll;
    final totalDed = p.customDeductions.values.fold(0.0, (s, e) => s + e.amount)
        + p.otherDeductions;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.payslip,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(formatPayrollPeriod(p.periodFrom, p.periodTo, p.month, p.year),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const Divider(height: 24),
              _Row(s.presentDays, '${p.presentDays ?? '-'} / ${p.standardWorkDays ?? 22}'),
              _Row(s.dayShiftHours,  '${(p.dayHours ?? 0).toStringAsFixed(1)} giờ'),
              _Row(s.nightShiftHours,'${(p.nightHours ?? 0).toStringAsFixed(1)} giờ'),
              _Row(s.otDayShift,     '${(p.dayOt ?? 0).toStringAsFixed(1)} giờ'),
              _Row(s.otNightShift,   '${(p.nightOt ?? 0).toStringAsFixed(1)} giờ'),
              _Row(s.overtimeHours, '${(p.totalOvertimeHours ?? 0).toStringAsFixed(1)} giờ'),
              const Divider(height: 20),
              // ── Mức lương cơ bản ──
              if (p.payType == 'HOURLY') ...[
                _Row(s.baseSalary, '${_fmt2(p.baseSalary)}/giờ'),
              ] else ...[
                _Row(s.baseSalaryMonthly, _fmt2(p.baseSalary)),
                _Row(s.actualWorkDays,
                    '${p.presentDays ?? 0} / ${p.standardWorkDays ?? 22} ngày'),
              ],
              const SizedBox(height: 4),
              // ── Thu nhập (chỉ hiện nếu có) ──
              if (p.incomeEntries.isNotEmpty) ...[
                const _SectionHeader('Thu nhập', AppTheme.primary),
                ...(p.incomeEntries.values.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))).map((e) => _Row(e.label, _fmt2(e.amount))),
                const SizedBox(height: 4),
              ],
              // ── Trợ cấp (chỉ hiện nếu có) ──
              if (p.allowanceEntries.isNotEmpty) ...[
                const _SectionHeader('Trợ cấp', Color(0xFF9C27B0)),
                ...(p.allowanceEntries.values.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))).map((e) => _Row(e.label, _fmt2(e.amount))),
                const SizedBox(height: 4),
              ],
              if (p.allowance > 0)   _Row(s.allowance, _fmt2(p.allowance)),
              if (p.bonus > 0)       _Row(s.bonus, _fmt2(p.bonus)),
              // ── Gross riêng ──
              const Divider(height: 16),
              _Row(s.grossSalary, _fmt2(p.grossSalary), bold: true, color: AppTheme.primary),
              const SizedBox(height: 8),
              // ── Khấu trừ ──
              const _SectionHeader('Khấu trừ', AppTheme.error),
              ...p.customDeductions.values.map((d) =>
                _Row(d.label, '-${_fmt2(d.amount)}', color: AppTheme.error)),
              if (p.otherDeductions > 0)
                _Row(s.otherDeductions, '-${_fmt2(p.otherDeductions)}', color: AppTheme.error),
              _Row(s.totalDeductions, '-${_fmt2(totalDed)}', bold: true, color: AppTheme.error),
              const Divider(height: 20),
              _Row(s.netSalary, _fmt2(p.netSalary),
                  bold: true, large: true,
                  color: p.netSalary < 0 ? AppTheme.error : AppTheme.secondary),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(s.close)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader(this.title, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(children: [
          Container(width: 3, height: 14, color: color,
              margin: const EdgeInsets.only(right: 6)),
          Text(title, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          const Expanded(child: Divider(indent: 8)),
        ]),
      );
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
                      fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
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
