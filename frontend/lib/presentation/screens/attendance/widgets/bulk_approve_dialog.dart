import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../data/models/department_model.dart';
import '../../../../data/repositories/attendance_repository.dart';
import '../../../../data/services/department_service.dart';
import '../../../widgets/department_picker_field.dart';

/// Duyệt công cả phòng × cả kỳ một lần (bước A sau thử nghiệm nội bộ).
/// Backend `/attendances/approve-bulk` tự bỏ qua dòng đã duyệt, kỳ đã khoá, công của chính mình.
/// Trả về true khi đã duyệt được ít nhất một dòng (màn gọi tải lại dữ liệu).
Future<bool?> showBulkApproveDialog(BuildContext context) =>
    showInstantDialog<bool>(context, (ctx) => const _BulkApproveDialog());

class _BulkApproveDialog extends StatefulWidget {
  const _BulkApproveDialog();

  @override
  State<_BulkApproveDialog> createState() => _BulkApproveDialogState();
}

class _BulkApproveDialogState extends State<_BulkApproveDialog> {
  final _repo = AttendanceRepository();
  static final _dayFmt = DateFormat('dd/MM/yyyy');

  List<AttendancePeriod> _periods = const [];
  List<DepartmentFlat> _departments = const [];
  AttendancePeriod? _period;
  int? _departmentId;
  bool _loading = true;
  bool _running = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        _repo.getPeriods(now.year),
        if (now.month == 1) _repo.getPeriods(now.year - 1),
        DepartmentService.instance.getFlat(permission: 'ATTENDANCE_VIEW'),
      ]);
      final periods = <AttendancePeriod>[
        ...results[0] as List<AttendancePeriod>,
        if (now.month == 1) ...results[1] as List<AttendancePeriod>,
      ].where((p) => !p.from.isAfter(now)).toList()
        ..sort((a, b) => b.from.compareTo(a.from));
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _departments = results.last as List<DepartmentFlat>;
        // Mặc định: kỳ gần nhất chưa khoá
        _period = periods.where((p) => !p.locked).firstOrNull ?? periods.firstOrNull;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = serverMsg(e); _loading = false; });
    }
  }

  Future<void> _run() async {
    final p = _period;
    if (p == null) return;
    setState(() { _running = true; _error = null; _result = null; });
    try {
      final r = await _repo.approveBulk(from: p.from, to: p.to, departmentId: _departmentId);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final r = _result;
    final errors = (r?['errors'] as List?) ?? const [];
    return AlertDialog(
      title: Text(s.bulkApproveMonthTitle),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.bulkApproveMonthDesc,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AttendancePeriod>(
                      initialValue: _period,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: s.bulkApprovePeriod),
                      items: _periods
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  '${p.month}/${p.year} · ${_dayFmt.format(p.from)} – ${_dayFmt.format(p.to)}'
                                  '${p.locked ? ' 🔒' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: _running ? null : (v) => setState(() { _period = v; _result = null; }),
                    ),
                    const SizedBox(height: 12),
                    DepartmentPickerField(
                      departments: _departments,
                      value: _departmentId,
                      label: s.departments,
                      allowAll: true,
                      allLabel: s.bulkApproveAllDepartments,
                      onChanged: (v) => setState(() { _departmentId = v; _result = null; }),
                    ),
                    if (_running) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 6),
                      Text(s.bulkApproveRunning, style: const TextStyle(fontSize: 12)),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppTheme.error)),
                    ],
                    if (r != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        s.bulkApproveResult('${r['approved'] ?? 0}', '${r['alreadyApproved'] ?? 0}',
                            '${r['locked'] ?? 0}', '${r['failed'] ?? 0}'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (errors.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(s.bulkApproveErrors, style: const TextStyle(fontSize: 12, color: AppTheme.error)),
                        ...errors.map((e) {
                          final m = Map<String, dynamic>.from(e as Map);
                          return Text('• ${m['employeeName']} · ${m['date']}: ${serverKeyMsg('${m['reason']}')}',
                              style: const TextStyle(fontSize: 12));
                        }),
                      ],
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.pop(context, ((r?['approved'] as num?) ?? 0) > 0),
          child: Text(s.close),
        ),
        FilledButton(
          onPressed: _running || _period == null || _loading ? null : _run,
          child: Text(s.bulkApproveRun),
        ),
      ],
    );
  }
}
