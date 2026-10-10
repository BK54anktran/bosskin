import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/employee.dart';
import '../../../data/models/job_history.dart';
import '../../../data/models/salary_grade.dart';
import '../../../data/repositories/job_history_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/position_service.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/manager_dropdown.dart';
import '../../widgets/status_badge.dart';

const jobChangeTypes = ['TRANSFER', 'PROMOTION', 'SALARY_CHANGE', 'MANAGER_CHANGE', 'OTHER'];

String jobChangeTypeLabel(AppLocalizations s, String type) => switch (type) {
      'HIRE' => s.jobChangeHire,
      'TRANSFER' => s.jobChangeTransfer,
      'PROMOTION' => s.jobChangePromotion,
      'SALARY_CHANGE' => s.jobChangeSalary,
      'MANAGER_CHANGE' => s.jobChangeManager,
      _ => s.jobChangeOther,
    };

/// Bước K — quá trình công tác của một nhân viên: các mốc phòng ban / chức vụ / bậc lương / quản lý
/// theo ngày hiệu lực. Mốc tương lai tự áp dụng khi tới ngày; chỉ mốc chưa tới ngày mới xoá được.
class JobHistoryDialog extends StatefulWidget {
  final Employee employee;
  final List<DepartmentFlat> departments;
  final List<SalaryGrade> grades;

  const JobHistoryDialog({super.key, required this.employee, required this.departments, required this.grades});

  @override
  State<JobHistoryDialog> createState() => _JobHistoryDialogState();
}

class _JobHistoryDialogState extends State<JobHistoryDialog> {
  final _repo = JobHistoryRepository();
  List<JobHistory> _items = [];
  bool _loading = true;
  String? _error;
  bool _changed = false;

  bool get _canEdit {
    final u = AuthService.instance.currentUser;
    return u != null && (u.isSystemAdmin || u.can('EMPLOYEE_UPDATE'));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _repo.getAll(widget.employee.id);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = serverMsg(e); _loading = false; });
    }
  }

  Future<void> _add() async {
    final current = _items.where((h) => h.current).firstOrNull;
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => _JobHistoryFormDialog(
        employee: widget.employee,
        departments: widget.departments,
        grades: widget.grades,
        current: current,
        repo: _repo,
      ),
    );
    if (ok == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _delete(JobHistory h) async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        content: Text(s.jobHistoryDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(h.id);
      _changed = true;
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text('${s.jobHistoryTitle} — ${widget.employee.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                if (_canEdit)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(s.jobHistoryAdd),
                    onPressed: _add,
                  ),
              ]),
              const SizedBox(height: 4),
              Text(s.jobHistoryHint, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
                        : _items.isEmpty
                            ? EmptyState(icon: Icons.timeline, message: s.noResults)
                            : ListView.separated(
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final h = _items[i];
                                  final lines = [
                                    h.departmentName ?? '',
                                    if (h.positionName != null) h.positionName!,
                                    if (h.salaryGradeCode != null) '${s.salaryGrade}: ${h.salaryGradeCode}',
                                    if (h.managerName != null) s.orgChartManagerOf(h.managerName!),
                                  ].join(' · ');
                                  return ListTile(
                                    dense: true,
                                    title: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                      Text(dateFmt.format(h.effectiveFrom),
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(jobChangeTypeLabel(s, h.changeType)),
                                      if (h.current)
                                        StatusBadge(label: s.jobHistoryCurrent, color: AppTheme.secondary),
                                      if (h.isFuture)
                                        StatusBadge(label: s.jobHistoryUpcoming, color: AppTheme.warning),
                                    ]),
                                    subtitle: Text([
                                      lines,
                                      if ((h.note ?? '').isNotEmpty) h.note!,
                                      if (h.createdByName != null) s.jobHistoryBy(h.createdByName!),
                                    ].join('\n')),
                                    trailing: _canEdit && h.isFuture
                                        ? IconButton(
                                            tooltip: s.delete,
                                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                            onPressed: () => _delete(h),
                                          )
                                        : null,
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context, _changed), child: Text(s.close)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobHistoryFormDialog extends StatefulWidget {
  final Employee employee;
  final List<DepartmentFlat> departments;
  final List<SalaryGrade> grades;
  final JobHistory? current;
  final JobHistoryRepository repo;

  const _JobHistoryFormDialog({
    required this.employee,
    required this.departments,
    required this.grades,
    required this.current,
    required this.repo,
  });

  @override
  State<_JobHistoryFormDialog> createState() => _JobHistoryFormDialogState();
}

class _JobHistoryFormDialogState extends State<_JobHistoryFormDialog> {
  final _noteCtrl = TextEditingController();
  DateTime _from = DateTime.now();
  String _type = 'TRANSFER';
  int? _deptId;
  int? _positionId;
  int? _gradeId;
  int? _managerId;
  List<PositionModel> _positions = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    final c = widget.current;
    _deptId = c?.departmentId ?? e.departmentId;
    _positionId = c?.positionId ?? e.positionId;
    _gradeId = c?.salaryGradeId ?? e.salaryGradeId;
    _managerId = c?.managerId ?? e.managerId;
    if (_deptId != null) _loadPositions(_deptId!);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPositions(int deptId) async {
    try {
      final list = await PositionService.instance.getByDepartment(deptId);
      if (mounted) {
        setState(() {
          _positions = list;
          if (!_positions.any((p) => p.id == _positionId)) _positionId = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _positions = []);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: widget.employee.joinDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _save() async {
    if (_deptId == null) return;
    setState(() => _saving = true);
    try {
      await widget.repo.create(widget.employee.id, {
        'effectiveFrom': DateFormat('yyyy-MM-dd').format(_from),
        'changeType': _type,
        'departmentId': _deptId,
        'positionId': _positionId,
        'salaryGradeId': _gradeId,
        'managerId': _managerId,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.jobHistoryAdd),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(labelText: s.effectiveDate, isDense: true),
                  child: Text(DateFormat('dd/MM/yyyy').format(_from)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppDropdown<String>(
              value: _type,
              label: s.jobHistoryChangeType,
              items: jobChangeTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(jobChangeTypeLabel(s, t))))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? 'OTHER'),
            ),
            const SizedBox(height: 12),
            DepartmentPickerField(
              departments: widget.departments,
              value: _deptId,
              label: '${s.department} *',
              onChanged: (v) {
                setState(() { _deptId = v; _positionId = null; _positions = []; });
                if (v != null) _loadPositions(v);
              },
            ),
            const SizedBox(height: 12),
            AppDropdown<int?>(
              key: ValueKey('pos-$_deptId-${_positions.length}'),
              value: _positions.any((p) => p.id == _positionId) ? _positionId : null,
              label: s.position,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                ..._positions.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _positionId = v),
            ),
            const SizedBox(height: 12),
            AppDropdown<int?>(
              value: widget.grades.any((g) => g.id == _gradeId) ? _gradeId : null,
              label: s.salaryGrade,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                ...widget.grades.map((g) => DropdownMenuItem<int?>(value: g.id, child: Text('${g.code} · ${g.name}'))),
              ],
              onChanged: (v) => setState(() => _gradeId = v),
            ),
            const SizedBox(height: 12),
            ManagerDropdown(
              value: _managerId,
              excludeEmployeeId: widget.employee.id,
              onChanged: (v) => setState(() => _managerId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLength: 500,
              decoration: InputDecoration(labelText: s.note, isDense: true),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _saving || _deptId == null ? null : _save, child: Text(s.save)),
      ],
    );
  }
}
