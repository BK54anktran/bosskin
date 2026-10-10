import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../data/models/employee.dart';
import '../../../data/models/work_shift.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/shift_plan_repository.dart';
import '../../widgets/empty_state.dart';

/// Tab "Xoay ca": mẫu chu kỳ ca và sinh phân ca theo mẫu (Mốc 2b).
class ShiftRotationTab extends StatefulWidget {
  final List<WorkShift> shifts;
  final bool canManage;
  /// Gọi sau khi sinh phân ca để tab Phân ca tải lại.
  final VoidCallback? onGenerated;

  const ShiftRotationTab({super.key, required this.shifts, required this.canManage, this.onGenerated});

  @override
  State<ShiftRotationTab> createState() => _ShiftRotationTabState();
}

class _ShiftRotationTabState extends State<ShiftRotationTab> {
  final _repo = ShiftPlanRepository();
  List<ShiftRotation> _items = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _repo.getRotations();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {bool ok = true}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? AppTheme.secondary : AppTheme.error));

  Future<void> _onEdit([ShiftRotation? r]) async {
    final saved = await showInstantDialog<bool>(
        context, (ctx) => _RotationFormDialog(shifts: widget.shifts, initial: r));
    if (saved == true) _load();
  }

  Future<void> _onDelete(ShiftRotation r) async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        title: Text(s.rotationDeleteTitle),
        content: Text(s.rotationDeleteConfirm(r.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteRotation(r.id);
      _load();
    } catch (e) {
      _toast(serverMsg(e), ok: false);
    }
  }

  Future<void> _onGenerate(ShiftRotation r) async {
    final result = await showInstantDialog<RotationGenerateResult>(
        context, (ctx) => _GenerateDialog(rotation: r));
    if (result == null || !mounted) return;
    widget.onGenerated?.call();
    await showInstantDialog<void>(context, (ctx) => _GenerateResultDialog(result: result));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: const TextStyle(color: AppTheme.error)),
        TextButton(onPressed: _load, child: Text(s.retry)),
      ]));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        Row(children: [
          Expanded(
            child: Text(s.rotationIntro,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          if (widget.canManage)
            FilledButton.icon(
              onPressed: () => _onEdit(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(s.rotationAdd),
            ),
        ]),
        const SizedBox(height: 12),
        if (_items.isEmpty) EmptyState(message: s.rotationEmpty),
        for (final r in _items)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.autorenew, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(s.rotationCycleDays('${r.days.length}'),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  if (widget.canManage) ...[
                    IconButton(
                      tooltip: s.edit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _onEdit(r),
                    ),
                    IconButton(
                      tooltip: s.delete,
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                      onPressed: () => _onDelete(r),
                    ),
                  ],
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var i = 0; i < r.days.length; i++)
                    _DayChip(
                      index: i,
                      label: i < r.dayCodes.length && r.dayCodes[i].isNotEmpty ? r.dayCodes[i] : s.rotationDayOff,
                      off: r.days[i].isEmpty,
                    ),
                ]),
                if (widget.canManage) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _onGenerate(r),
                      icon: const Icon(Icons.event_repeat, size: 16),
                      label: Text(s.rotationApply),
                    ),
                  ),
                ],
              ]),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final int index;
  final String label;
  final bool off;
  const _DayChip({required this.index, required this.label, required this.off});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: off ? AppTheme.border.withValues(alpha: 0.4) : AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('${index + 1}. $label',
            style: TextStyle(fontSize: 12, color: off ? AppTheme.textSecondary : AppTheme.primary)),
      );
}

// ── Tạo / sửa mẫu ────────────────────────────────────────────────────────────

class _RotationFormDialog extends StatefulWidget {
  final List<WorkShift> shifts;
  final ShiftRotation? initial;
  const _RotationFormDialog({required this.shifts, this.initial});

  @override
  State<_RotationFormDialog> createState() => _RotationFormDialogState();
}

class _RotationFormDialogState extends State<_RotationFormDialog> {
  final _repo = ShiftPlanRepository();
  late final TextEditingController _nameCtrl;
  late List<Set<int>> _days;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _days = widget.initial != null
        ? widget.initial!.days.map((d) => d.toSet()).toList()
        : [<int>{}, <int>{}, <int>{}, <int>{}];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty || _days.every((d) => d.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.rotationNeedNameAndShift)));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _repo.saveRotation(
        id: widget.initial?.id,
        name: _nameCtrl.text.trim(),
        days: _days.map((d) => d.toList()).toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? s.rotationAdd : s.rotationEdit),
      content: SizedBox(
        width: 560,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: s.rotationName)),
          const SizedBox(height: 8),
          Text(s.rotationDaysHint, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _days.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 64,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(s.rotationDayN('${i + 1}'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Expanded(
                    child: Wrap(spacing: 4, runSpacing: 4, children: [
                      for (final sh in widget.shifts)
                        FilterChip(
                          label: Text(sh.code, style: const TextStyle(fontSize: 12)),
                          tooltip: '${sh.name} ${sh.timeLabel}',
                          selected: _days[i].contains(sh.id),
                          onSelected: (v) => setState(() => v ? _days[i].add(sh.id) : _days[i].remove(sh.id)),
                        ),
                      if (_days[i].isEmpty)
                        Chip(label: Text(s.rotationDayOff, style: const TextStyle(fontSize: 12))),
                    ]),
                  ),
                  IconButton(
                    tooltip: s.delete,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _days.length <= 1 ? null : () => setState(() => _days.removeAt(i)),
                  ),
                ]),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _days.add(<int>{})),
              icon: const Icon(Icons.add, size: 16),
              label: Text(s.rotationAddDay),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _isSaving ? null : _save, child: Text(s.save)),
      ],
    );
  }
}

// ── Áp dụng mẫu cho nhân viên ─────────────────────────────────────────────────

class _GenerateDialog extends StatefulWidget {
  final ShiftRotation rotation;
  const _GenerateDialog({required this.rotation});

  @override
  State<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends State<_GenerateDialog> {
  final _repo = ShiftPlanRepository();
  final _searchCtrl = TextEditingController();
  List<Employee> _employees = const [];
  final List<int> _selected = [];
  late DateTime _from;
  late DateTime _to;
  int _startOffset = 0;
  int _stagger = 0;
  bool _skipHolidays = true;
  bool _isLoading = true;
  bool _isRunning = false;

  static final _fmt = DateFormat('yyyy-MM-dd');
  static final _show = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day + 1);
    _to = DateTime(_from.year, _from.month + 1, _from.day - 1);
    EmployeeRepository().getAllForPicker(status: EmployeeStatus.active).then((list) {
      if (mounted) setState(() { _employees = list; _isLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isFrom) async {
    final d = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => isFrom ? _from = d : _to = d);
  }

  Future<void> _run() async {
    if (_selected.isEmpty) return;
    setState(() => _isRunning = true);
    try {
      final res = await _repo.generate(widget.rotation.id,
          employeeIds: _selected,
          from: _fmt.format(_from),
          to: _fmt.format(_to),
          startOffset: _startOffset,
          staggerPerEmployee: _stagger,
          skipHolidays: _skipHolidays);
      if (mounted) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
        setState(() => _isRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final q = foldSearchText(_searchCtrl.text);
    final visible = _employees
        .where((e) => q.isEmpty || foldSearchText('${e.fullName} ${e.employeeCode}').contains(q))
        .toList();
    final n = widget.rotation.days.length;
    return AlertDialog(
      title: Text(s.rotationApplyTitle(widget.rotation.name)),
      content: SizedBox(
        width: 560,
        height: 520,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pick(true),
                child: Text('${s.fromDate}: ${_show.format(_from)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pick(false),
                child: Text('${s.toDate}: ${_show.format(_to)}'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _startOffset,
                decoration: InputDecoration(labelText: s.rotationStartAt),
                items: [
                  for (var i = 0; i < n; i++)
                    DropdownMenuItem(value: i, child: Text(s.rotationDayN('${i + 1}'))),
                ],
                onChanged: (v) => setState(() => _startOffset = v ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _stagger,
                decoration: InputDecoration(labelText: s.rotationStagger),
                items: [
                  for (var i = 0; i < n; i++)
                    DropdownMenuItem(value: i, child: Text(i == 0 ? s.rotationStaggerNone : s.rotationStaggerDays('$i'))),
                ],
                onChanged: (v) => setState(() => _stagger = v ?? 0),
              ),
            ),
          ]),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _skipHolidays,
            onChanged: (v) => setState(() => _skipHolidays = v ?? false),
            title: Text(s.rotationSkipHolidays),
          ),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: s.search, isDense: true),
          ),
          Row(children: [
            Text(s.rotationSelectedCount('${_selected.length}'),
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                for (final e in visible) {
                  if (!_selected.contains(e.id)) _selected.add(e.id);
                }
              }),
              child: Text(s.all),
            ),
            TextButton(onPressed: () => setState(_selected.clear), child: Text(s.quickFillClearSelection)),
          ]),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(children: [
                    for (final e in visible)
                      CheckboxListTile(
                        dense: true,
                        value: _selected.contains(e.id),
                        title: Text(e.fullName),
                        subtitle: Text([e.employeeCode, e.departmentName].where((x) => x.isNotEmpty).join(' · ')),
                        secondary: _selected.contains(e.id)
                            ? CircleAvatar(radius: 12, child: Text('${_selected.indexOf(e.id) + 1}', style: const TextStyle(fontSize: 11)))
                            : null,
                        onChanged: (v) => setState(() => v == true ? _selected.add(e.id) : _selected.remove(e.id)),
                      ),
                  ]),
          ),
          Text(s.rotationOrderHint, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _isRunning || _selected.isEmpty ? null : _run,
          child: _isRunning
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(s.rotationApply),
        ),
      ],
    );
  }
}

class _GenerateResultDialog extends StatelessWidget {
  final RotationGenerateResult result;
  const _GenerateResultDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.rotationResultTitle),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.rotationResultSummary('${result.assignedDays}', '${result.clearedDays}', '${result.unchangedDays}')),
          if (result.conflicts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.rotationResultConflicts('${result.conflicts.length}'),
                style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final c in result.conflicts)
                  Text('• ${c.employeeName} — ${c.date}: ${serverKeyMsg(c.reason)}', style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ],
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(s.close))],
    );
  }
}
