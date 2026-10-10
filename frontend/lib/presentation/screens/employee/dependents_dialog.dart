import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/dependent.dart';
import '../../../data/models/employee.dart';
import '../../../data/repositories/dependent_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/date_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

String dependentRelationshipLabel(AppLocalizations s, String r) => switch (r) {
      'CHILD' => s.dependentRelChild,
      'SPOUSE' => s.dependentRelSpouse,
      'PARENT' => s.dependentRelParent,
      _ => s.dependentRelOther,
    };

String dependentStatusLabel(AppLocalizations s, String st) => switch (st) {
      'NOT_REGISTERED' => s.dependentStatusNotRegistered,
      'REGISTERED' => s.dependentStatusRegistered,
      _ => s.dependentStatusPending,
    };

/// Bước M — người phụ thuộc của một nhân viên (giảm trừ gia cảnh theo tháng).
class DependentsDialog extends StatefulWidget {
  final Employee employee;

  const DependentsDialog({super.key, required this.employee});

  @override
  State<DependentsDialog> createState() => _DependentsDialogState();
}

class _DependentsDialogState extends State<DependentsDialog> {
  final _repo = DependentRepository();
  final _monthFmt = DateFormat('MM/yyyy');
  List<Dependent> _items = [];
  bool _loading = true;
  String? _error;

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

  Future<void> _openForm([Dependent? d]) async {
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => _DependentFormDialog(employee: widget.employee, dependent: d, repo: _repo),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(Dependent d) async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        content: Text(s.dependentDeleteConfirm(d.fullName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(d.id);
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
                  child: Text('${s.dependentsTitle} — ${widget.employee.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                if (_canEdit)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(s.dependentAdd),
                    onPressed: () => _openForm(),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(s.dependentsHint, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
                        : _items.isEmpty
                            ? EmptyState(icon: Icons.family_restroom_outlined, message: s.dependentEmpty)
                            : ListView.separated(
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final d = _items[i];
                                  final period = '${_monthFmt.format(d.deductionFrom)} – '
                                      '${d.deductionTo == null ? s.dependentNoEnd : _monthFmt.format(d.deductionTo!)}';
                                  return ListTile(
                                    dense: true,
                                    onTap: _canEdit ? () => _openForm(d) : null,
                                    mouseCursor: _canEdit ? SystemMouseCursors.click : null,
                                    title: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                      Text(d.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(dependentRelationshipLabel(s, d.relationship)),
                                      StatusBadge(
                                        label: dependentStatusLabel(s, d.registrationStatus),
                                        color: d.registrationStatus == 'NOT_REGISTERED'
                                            ? AppTheme.textSecondary
                                            : d.registrationStatus == 'REGISTERED'
                                                ? AppTheme.secondary
                                                : AppTheme.warning,
                                      ),
                                      if (d.activeNow)
                                        StatusBadge(label: s.dependentActiveNow, color: AppTheme.primary),
                                    ]),
                                    subtitle: Text([
                                      '${s.dependentPeriod}: $period',
                                      if (d.dateOfBirth != null) '${s.dateOfBirth}: ${dateFmt.format(d.dateOfBirth!)}',
                                      if ((d.taxCode ?? '').isNotEmpty) '${s.dependentTaxCode}: ${d.taxCode}',
                                      if ((d.identityNo ?? '').isNotEmpty) '${s.dependentIdentityNo}: ${d.identityNo}',
                                      if ((d.note ?? '').isNotEmpty) d.note!,
                                    ].join('\n')),
                                    trailing: _canEdit
                                        ? IconButton(
                                            tooltip: s.delete,
                                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                            onPressed: () => _delete(d),
                                          )
                                        : null,
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: Text(s.close)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DependentFormDialog extends StatefulWidget {
  final Employee employee;
  final Dependent? dependent;
  final DependentRepository repo;

  const _DependentFormDialog({required this.employee, required this.dependent, required this.repo});

  @override
  State<_DependentFormDialog> createState() => _DependentFormDialogState();
}

class _DependentFormDialogState extends State<_DependentFormDialog> {
  final _nameCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _relationship = 'CHILD';
  String _status = 'PENDING';
  DateTime? _dob;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _to;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dependent;
    if (d != null) {
      _nameCtrl.text = d.fullName;
      _taxCtrl.text = d.taxCode ?? '';
      _idCtrl.text = d.identityNo ?? '';
      _noteCtrl.text = d.note ?? '';
      _relationship = d.relationship;
      _status = d.registrationStatus;
      _dob = d.dateOfBirth;
      _from = d.deductionFrom;
      _to = d.deductionTo;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taxCtrl.dispose();
    _idCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final fmt = DateFormat('yyyy-MM-dd');
    final body = {
      'employeeId': widget.employee.id,
      'fullName': _nameCtrl.text.trim(),
      'relationship': _relationship,
      'dateOfBirth': _dob != null ? fmt.format(_dob!) : null,
      'taxCode': _taxCtrl.text.trim(),
      'identityNo': _idCtrl.text.trim(),
      'deductionFrom': fmt.format(DateTime(_from.year, _from.month)),
      'deductionTo': _to != null ? fmt.format(DateTime(_to!.year, _to!.month)) : null,
      'registrationStatus': _status,
      'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    };
    try {
      if (widget.dependent == null) {
        await widget.repo.create(body);
      } else {
        await widget.repo.update(widget.dependent!.id, body);
      }
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
      title: Text(widget.dependent == null ? s.dependentAdd : s.dependentEdit),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _nameCtrl,
              maxLength: 100,
              decoration: InputDecoration(labelText: '${s.dependentName} *', isDense: true, counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: AppDropdown<String>(
                  value: _relationship,
                  label: s.dependentRelationship,
                  items: dependentRelationships
                      .map((r) => DropdownMenuItem(value: r, child: Text(dependentRelationshipLabel(s, r))))
                      .toList(),
                  onChanged: (v) => setState(() => _relationship = v ?? 'OTHER'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(
                  label: s.dateOfBirth,
                  value: _dob,
                  lastDate: DateTime.now(),
                  firstDate: DateTime(1920),
                  clearable: true,
                  onChanged: (d) => setState(() => _dob = d),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _taxCtrl,
                  maxLength: 20,
                  decoration: InputDecoration(labelText: s.dependentTaxCode, isDense: true, counterText: ''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _idCtrl,
                  maxLength: 20,
                  decoration: InputDecoration(labelText: s.dependentIdentityNo, isDense: true, counterText: ''),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DateField(
                  label: '${s.dependentFrom} *',
                  value: _from,
                  onChanged: (d) => setState(() => _from = d ?? _from),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(
                  label: s.dependentTo,
                  value: _to,
                  clearable: true,
                  onChanged: (d) => setState(() => _to = d),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.dependentMonthHint, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 12),
            AppDropdown<String>(
              value: _status,
              label: s.dependentStatus,
              items: dependentStatuses
                  .map((st) => DropdownMenuItem(value: st, child: Text(dependentStatusLabel(s, st))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? 'PENDING'),
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
        FilledButton(
          onPressed: _saving || _nameCtrl.text.trim().isEmpty ? null : _save,
          child: Text(s.save),
        ),
      ],
    );
  }
}
