import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../data/models/labor_contract.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/date_field.dart';
import '../../widgets/manager_dropdown.dart';
import 'allowance_editor.dart';
import 'contract_shared.dart';
import '../../../core/utils/company_currency_utils.dart';

final _iso = DateFormat('yyyy-MM-dd');
final _dmy = DateFormat('dd/MM/yyyy');

String? _isoOrNull(DateTime? d) => d == null ? null : _iso.format(d);

double? _money(String raw) {
  final v = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return v.isEmpty ? null : double.parse(v);
}

bool _can(String p) {
  final u = AuthService.instance.currentUser;
  return u != null && (u.isSystemAdmin || (u.can('CONTRACT_VIEW') && u.can(p)));
}

void _snack(BuildContext context, String msg, {bool error = false}) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppTheme.error : AppTheme.secondary));

// ── Chi tiết ───────────────────────────────────────────────────────────────

/// Xem một hợp đồng: thông tin, phụ cấp, phụ lục và các thao tác. Trả về true nếu đã thay đổi.
class ContractDetailDialog extends StatefulWidget {
  final LaborContract contract;
  final ContractRepository repo;

  const ContractDetailDialog({super.key, required this.contract, required this.repo});

  @override
  State<ContractDetailDialog> createState() => _ContractDetailDialogState();
}

class _ContractDetailDialogState extends State<ContractDetailDialog> {
  late LaborContract _c = widget.contract;
  bool _changed = false;
  bool _busy = false;

  Future<void> _run(Future<LaborContract?> Function() action) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _c = updated;
          _changed = true;
        });
      }
    } catch (e) {
      if (mounted) _snack(context, serverMsg(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final updated = await showInstantDialog<LaborContract>(
        context, (ctx) => ContractFormDialog(repo: widget.repo, contract: _c));
    if (updated != null) setState(() { _c = updated; _changed = true; });
  }

  Future<bool> _confirm(String title, String message, {bool danger = false}) async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: AppTheme.error) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _activate() async {
    final s = AppLocalizations.of(context);
    if (!await _confirm(s.contractActivate, s.contractActivateConfirm(_c.contractNo))) return;
    await _run(() => widget.repo.activate(_c.id));
  }

  Future<void> _terminate() async {
    final updated = await showInstantDialog<LaborContract>(
        context, (ctx) => _TerminateDialog(contract: _c, repo: widget.repo));
    if (updated != null) setState(() { _c = updated; _changed = true; });
  }

  Future<void> _delete() async {
    final s = AppLocalizations.of(context);
    if (!await _confirm(s.delete, s.contractDeleteConfirm(_c.contractNo), danger: true)) return;
    setState(() => _busy = true);
    try {
      await widget.repo.delete(_c.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(context, serverMsg(e), error: true);
      }
    }
  }

  Future<void> _appendix([ContractAppendix? a]) async {
    final updated = await showInstantDialog<LaborContract>(
        context, (ctx) => AppendixFormDialog(repo: widget.repo, contract: _c, appendix: a));
    if (updated != null) setState(() { _c = updated; _changed = true; });
  }

  Future<void> _deleteAppendix(ContractAppendix a) async {
    final s = AppLocalizations.of(context);
    if (!await _confirm(s.delete, s.contractAppendixDeleteConfirm(a.appendixNo), danger: true)) return;
    await _run(() async {
      await widget.repo.deleteAppendix(a.id);
      final list = await widget.repo.getAll(employeeId: _c.employeeId);
      return list.firstWhere((x) => x.id == _c.id, orElse: () => _c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final c = _c;
    final canEdit = _can('CONTRACT_EDIT');
    final days = contractDaysText(s, c);
    return AlertDialog(
      title: Row(children: [
        Expanded(child: Text('${c.contractNo} · ${c.employeeName}', overflow: TextOverflow.ellipsis)),
        contractStatusBadge(s, c),
      ]),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 24, runSpacing: 8, children: [
              _info(s.employeeCode, c.employeeCode),
              _info(s.department, c.departmentName ?? '—'),
              _info(s.contractType, contractTypeLabel(s, c.contractType)),
              _info(s.contractSignDate, c.signDate == null ? '—' : _dmy.format(c.signDate!)),
              _info(s.contractStartDate, _dmy.format(c.startDate)),
              _info(s.contractEndDate, c.endDate == null ? s.contractNoEnd : _dmy.format(c.endDate!)),
              if (days != null) _info(s.status, days),
              _info(s.contractBaseSalary, formatMoney(c.baseSalary)),
              _info(s.contractCurrentSalary, formatMoney(c.currentBaseSalary)),
              _info(s.contractInsuranceSalary, formatMoney(c.currentInsuranceSalary)),
              if (c.positionTitle != null) _info(s.contractPositionTitle, c.positionTitle!),
              if (c.terminationDate != null) _info(s.contractTerminationDate, _dmy.format(c.terminationDate!)),
              if (c.terminationReason != null) _info(s.reason, c.terminationReason!),
              if (c.note != null) _info(s.note, c.note!),
            ]),
            const SizedBox(height: 16),
            Text(s.contractAllowances, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (c.allowances.isEmpty) const Text('—') else ...c.allowances.map((a) => _allowanceLine(s, a)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(s.contractAppendices, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (canEdit && !c.isTerminated)
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(s.contractAppendixAdd),
                  onPressed: _busy ? null : () => _appendix(),
                ),
            ]),
            if (c.appendices.isEmpty) const Text('—'),
            ...c.appendices.map((a) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    title: Text('${a.appendixNo} · ${s.contractEffectiveFrom(_dmy.format(a.effectiveFrom))}'),
                    subtitle: Text([
                      if (a.baseSalary != null) '${s.contractBaseSalary}: ${formatMoney(a.baseSalary)}',
                      if (a.insuranceSalary != null) '${s.contractInsuranceSalary}: ${formatMoney(a.insuranceSalary)}',
                      if (a.positionTitle != null) a.positionTitle!,
                      if (a.overridesAllowances)
                        '${s.contractAllowances}: ${a.allowances.map((x) => '${x.code} ${formatMoney(x.amount)}').join(', ')}',
                      if (a.note != null) a.note!,
                    ].join(' · ')),
                    trailing: canEdit && !c.isTerminated
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: s.edit,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: _busy ? null : () => _appendix(a),
                            ),
                            IconButton(
                              tooltip: s.delete,
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                              onPressed: _busy ? null : () => _deleteAppendix(a),
                            ),
                          ])
                        : null,
                  ),
                )),
          ]),
        ),
      ),
      actions: [
        if (_can('CONTRACT_DELETE'))
          TextButton(
            onPressed: _busy ? null : _delete,
            child: Text(s.delete, style: const TextStyle(color: AppTheme.error)),
          ),
        if (canEdit && c.isActive)
          TextButton(onPressed: _busy ? null : _terminate, child: Text(s.contractTerminate)),
        if (canEdit && c.isDraft)
          TextButton(onPressed: _busy ? null : _activate, child: Text(s.contractActivate)),
        if (canEdit) TextButton(onPressed: _busy ? null : _edit, child: Text(s.edit)),
        FilledButton(onPressed: () => Navigator.pop(context, _changed), child: Text(s.close)),
      ],
    );
  }

  Widget _info(String label, String value) => SizedBox(
        width: 190,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _allowanceLine(AppLocalizations s, ContractAllowance a) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text([
          '${a.code} · ${a.name}: ${formatMoney(a.amount)}',
          if (a.insurable) s.contractAllowanceInsurable,
          if (!a.taxable) s.contractAllowanceNonTaxable,
        ].join(' · ')),
      );
}

// ── Form hợp đồng ──────────────────────────────────────────────────────────

/// Tạo / sửa hợp đồng. Trả về hợp đồng sau khi lưu.
class ContractFormDialog extends StatefulWidget {
  final ContractRepository repo;
  final LaborContract? contract;

  const ContractFormDialog({super.key, required this.repo, this.contract});

  @override
  State<ContractFormDialog> createState() => _ContractFormDialogState();
}

class _ContractFormDialogState extends State<ContractFormDialog> {
  late final LaborContract? _c = widget.contract;
  late final _noCtrl = TextEditingController(text: _c?.contractNo ?? '');
  late final _salaryCtrl = TextEditingController(text: _c?.baseSalary.toStringAsFixed(0) ?? '');
  late final _insCtrl = TextEditingController(text: _c?.insuranceSalary?.toStringAsFixed(0) ?? '');
  late final _titleCtrl = TextEditingController(text: _c?.positionTitle ?? '');
  late final _noteCtrl = TextEditingController(text: _c?.note ?? '');
  late int? _employeeId = _c?.employeeId;
  late String _type = _c?.contractType ?? 'FIXED_TERM';
  late String _status = _c?.status ?? 'DRAFT';
  late DateTime? _sign = _c?.signDate;
  late DateTime? _start = _c?.startDate;
  late DateTime? _end = _c?.endDate;
  late List<ContractAllowance> _allowances = _c?.allowances ?? const [];
  bool _saving = false;

  bool get _employeeLocked => !(_c?.isDraft ?? true);

  @override
  void dispose() {
    for (final c in [_noCtrl, _salaryCtrl, _insCtrl, _titleCtrl, _noteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppLocalizations.of(context);
    final salary = _money(_salaryCtrl.text);
    if (_employeeId == null || _noCtrl.text.trim().isEmpty || _start == null || salary == null) {
      _snack(context, s.contractRequiredFields, error: true);
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'employeeId': _employeeId,
      'contractNo': _noCtrl.text.trim(),
      'contractType': _type,
      if (_c?.isDraft ?? true) 'status': _status,
      'signDate': _isoOrNull(_sign),
      'startDate': _isoOrNull(_start),
      'endDate': _type == 'INDEFINITE' ? null : _isoOrNull(_end),
      'baseSalary': salary,
      'insuranceSalary': _money(_insCtrl.text),
      'positionTitle': _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      'allowances': _allowances.map((a) => a.toJson()).toList(),
    };
    try {
      final saved = _c == null ? await widget.repo.create(body) : await widget.repo.update(_c!.id, body);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(context, serverMsg(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    const gap = SizedBox(height: 12);
    return AlertDialog(
      title: Text(_c == null ? s.contractAdd : s.contractEdit),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_employeeLocked)
              InputDecorator(
                decoration: InputDecoration(labelText: s.employee, isDense: true, enabled: false),
                child: Text('${_c!.employeeName} · ${_c!.employeeCode}'),
              )
            else
              ManagerDropdown(
                value: _employeeId,
                label: '${s.employee} *',
                allowNone: false,
                onChanged: (v) => setState(() => _employeeId = v),
              ),
            gap,
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _noCtrl,
                  maxLength: 50,
                  decoration: InputDecoration(labelText: '${s.contractNo} *', isDense: true, counterText: ''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDropdown<String>(
                  value: _type,
                  label: s.contractType,
                  items: contractTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(contractTypeLabel(s, t))))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _type = v ?? 'FIXED_TERM';
                    if (_type == 'INDEFINITE') _end = null;
                  }),
                ),
              ),
            ]),
            gap,
            if (_c?.isDraft ?? true) ...[
              AppDropdown<String>(
                value: _status,
                label: s.status,
                items: [
                  DropdownMenuItem(value: 'DRAFT', child: Text(s.contractStatusDraft)),
                  DropdownMenuItem(value: 'ACTIVE', child: Text(s.contractStatusActive)),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'DRAFT'),
              ),
              gap,
            ],
            Row(children: [
              Expanded(
                child: DateField(
                  label: s.contractSignDate,
                  value: _sign,
                  clearable: true,
                  onChanged: (d) => setState(() => _sign = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(
                  label: '${s.contractStartDate} *',
                  value: _start,
                  onChanged: (d) => setState(() => _start = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(
                  label: s.contractEndDate,
                  value: _end,
                  clearable: true,
                  firstDate: _start,
                  onChanged: _type == 'INDEFINITE' ? null : (d) => setState(() => _end = d),
                ),
              ),
            ]),
            gap,
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _salaryCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: '${s.contractBaseSalary} *', isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _insCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: s.contractInsuranceSalary,
                    helperText: s.contractInsuranceSalaryHint,
                    isDense: true,
                  ),
                ),
              ),
            ]),
            gap,
            TextField(
              controller: _titleCtrl,
              maxLength: 150,
              decoration: InputDecoration(labelText: s.contractPositionTitle, isDense: true, counterText: ''),
            ),
            gap,
            TextField(
              controller: _noteCtrl,
              maxLength: 1000,
              maxLines: 2,
              decoration: InputDecoration(labelText: s.note, isDense: true, counterText: ''),
            ),
            const SizedBox(height: 16),
            Text(s.contractAllowances, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            AllowanceEditor(initial: _allowances, onChanged: (v) => _allowances = v),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _saving ? null : _save, child: Text(s.save)),
      ],
    );
  }
}

// ── Phụ lục ────────────────────────────────────────────────────────────────

/// Thêm / sửa phụ lục: trường trống = giữ giá trị trước đó.
class AppendixFormDialog extends StatefulWidget {
  final ContractRepository repo;
  final LaborContract contract;
  final ContractAppendix? appendix;

  const AppendixFormDialog({super.key, required this.repo, required this.contract, this.appendix});

  @override
  State<AppendixFormDialog> createState() => _AppendixFormDialogState();
}

class _AppendixFormDialogState extends State<AppendixFormDialog> {
  late final ContractAppendix? _a = widget.appendix;
  late final _noCtrl = TextEditingController(text: _a?.appendixNo ?? '');
  late final _salaryCtrl = TextEditingController(text: _a?.baseSalary?.toStringAsFixed(0) ?? '');
  late final _insCtrl = TextEditingController(text: _a?.insuranceSalary?.toStringAsFixed(0) ?? '');
  late final _titleCtrl = TextEditingController(text: _a?.positionTitle ?? '');
  late final _noteCtrl = TextEditingController(text: _a?.note ?? '');
  late DateTime? _from = _a?.effectiveFrom;
  late bool _overrides = _a?.overridesAllowances ?? false;
  late List<ContractAllowance> _allowances =
      (_a?.overridesAllowances ?? false) ? _a!.allowances : widget.contract.allowances;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_noCtrl, _salaryCtrl, _insCtrl, _titleCtrl, _noteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppLocalizations.of(context);
    if (_noCtrl.text.trim().isEmpty || _from == null) {
      _snack(context, s.contractRequiredFields, error: true);
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'appendixNo': _noCtrl.text.trim(),
      'effectiveFrom': _isoOrNull(_from),
      'baseSalary': _money(_salaryCtrl.text),
      'insuranceSalary': _money(_insCtrl.text),
      'positionTitle': _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      'overridesAllowances': _overrides,
      'allowances': _overrides ? _allowances.map((a) => a.toJson()).toList() : null,
    };
    try {
      final saved = _a == null
          ? await widget.repo.addAppendix(widget.contract.id, body)
          : await widget.repo.updateAppendix(_a!.id, body);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(context, serverMsg(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final c = widget.contract;
    const gap = SizedBox(height: 12);
    return AlertDialog(
      title: Text(_a == null ? s.contractAppendixAdd : s.contractAppendixEdit),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.contractAppendixKeepHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            gap,
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _noCtrl,
                  maxLength: 50,
                  decoration: InputDecoration(labelText: '${s.contractAppendixNo} *', isDense: true, counterText: ''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(
                  label: '${s.effectiveDate} *',
                  value: _from,
                  firstDate: c.startDate.add(const Duration(days: 1)),
                  lastDate: c.endDate,
                  onChanged: (d) => setState(() => _from = d),
                ),
              ),
            ]),
            gap,
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _salaryCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: s.contractBaseSalary,
                    hintText: formatMoney(c.currentBaseSalary),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _insCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: s.contractInsuranceSalary, isDense: true),
                ),
              ),
            ]),
            gap,
            TextField(
              controller: _titleCtrl,
              maxLength: 150,
              decoration: InputDecoration(labelText: s.contractPositionTitle, isDense: true, counterText: ''),
            ),
            gap,
            TextField(
              controller: _noteCtrl,
              maxLength: 1000,
              decoration: InputDecoration(labelText: s.note, isDense: true, counterText: ''),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.contractAppendixOverridesAllowances),
              value: _overrides,
              onChanged: (v) => setState(() => _overrides = v),
            ),
            if (_overrides) AllowanceEditor(initial: _allowances, onChanged: (v) => _allowances = v),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _saving ? null : _save, child: Text(s.save)),
      ],
    );
  }
}

// ── Chấm dứt ───────────────────────────────────────────────────────────────

class _TerminateDialog extends StatefulWidget {
  final LaborContract contract;
  final ContractRepository repo;

  const _TerminateDialog({required this.contract, required this.repo});

  @override
  State<_TerminateDialog> createState() => _TerminateDialogState();
}

class _TerminateDialogState extends State<_TerminateDialog> {
  final _reasonCtrl = TextEditingController();
  DateTime? _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    final today = DateUtils.dateOnly(companyNow());
    _date = c.endDate != null && c.endDate!.isBefore(today) ? c.endDate : today;
    if (_date!.isBefore(c.startDate)) _date = c.startDate;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_date == null) return;
    setState(() => _saving = true);
    try {
      final reason = _reasonCtrl.text.trim();
      final saved = await widget.repo.terminate(widget.contract.id, _iso.format(_date!), reason.isEmpty ? null : reason);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(context, serverMsg(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final c = widget.contract;
    return AlertDialog(
      title: Text(s.contractTerminateTitle(c.contractNo)),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DateField(
            label: s.contractTerminationDate,
            value: _date,
            firstDate: c.startDate,
            lastDate: c.endDate,
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLength: 500,
            decoration: InputDecoration(labelText: s.reason, isDense: true),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: _saving ? null : _save,
          child: Text(s.contractTerminate),
        ),
      ],
    );
  }
}
