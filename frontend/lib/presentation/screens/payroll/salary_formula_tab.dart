import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/all_variable.dart';
import '../../../data/models/formula_variable.dart';
import '../../../data/models/salary_formula.dart';
import '../../../data/models/salary_grade.dart';
import '../../../data/repositories/formula_variable_repository.dart';
import '../../../data/repositories/salary_formula_repository.dart';
import '../../../data/repositories/salary_grade_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/department_service.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/pagination_bar.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../core/utils/company_currency_utils.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');


class SalaryFormulaTab extends StatefulWidget {
  const SalaryFormulaTab({super.key});

  @override
  State<SalaryFormulaTab> createState() => _SalaryFormulaTabState();
}

class _SalaryFormulaTabState extends State<SalaryFormulaTab> {
  final _repo = SalaryFormulaRepository();
  final _gradeRepo = SalaryGradeRepository();

  bool _loading = true;
  String? _error;
  List<SalaryFormula> _formulas = [];
  List<SalaryGrade> _grades = [];
  List<DepartmentFlat> _depts = [];
  int? _filterDeptId;
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    _canEdit = (user?.isSystemAdmin ?? false) || (user?.can('PAYROLL_CREATE') ?? false);
    _loadDepts();
    _loadGrades();
    _load();
  }

  Future<void> _loadDepts() async {
    try {
      final depts = await DepartmentService.instance.getFlat();
      if (mounted) setState(() => _depts = depts);
    } catch (_) {}
  }

  Future<void> _loadGrades() async {
    try {
      final grades = await _gradeRepo.getAll();
      if (mounted) setState(() => _grades = grades);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final formulas = await _repo.getAll();
      if (mounted) setState(() => _formulas = formulas);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _page = 0;
  int _pageSize = 20;

  List<SalaryFormula> get _filtered => _filterDeptId == null
      ? _formulas
      : _formulas.where((f) => f.departmentId == _filterDeptId).toList();

  List<SalaryFormula> get _paged {
    final list = _filtered;
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, list.length);
    return start >= list.length ? [] : list.sublist(start, end);
  }

  void _openForm([SalaryFormula? existing, SalaryFormula? duplicateFrom]) async {
    final result = await showDialog<SalaryFormula>(
      context: context,
      builder: (_) => FormulaEditorDialog(
        grades: _grades,
        existing: existing,
        duplicateFrom: duplicateFrom,
        repo: _repo,
      ),
    );
    if (result != null) _load();
  }

  Future<void> _delete(SalaryFormula f) async {
    final s = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.payFormulaDeleteConfirm('${f.salaryGradeCode} — ${f.salaryGradeName}')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(f.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppTheme.background,
          child: Row(
            children: [
              Expanded(
                child: DepartmentPickerField(
                  departments: _depts,
                  value: _filterDeptId,
                  label: s.department,
                  allowAll: true,
                  compact: true,
                  onChanged: (v) => setState(() => _filterDeptId = v),
                ),
              ),
              const SizedBox(width: 12),
              if (_canEdit)
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(s.salaryFormula),
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
              : filtered.isEmpty
                  ? Center(child: Text(s.noResults))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _paged.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _FormulaCard(
                          formula: _paged[i],
                          canEdit: _canEdit,
                          onEdit: () => _openForm(_paged[i]),
                          onDelete: () => _delete(_paged[i]),
                          onDuplicate: () => _openForm(null, _paged[i]),
                        ),
                      ),
                    ),
        ),
        if (!_loading && _filtered.isNotEmpty)
          PaginationBar(
            total: _filtered.length,
            page: _page,
            pageSize: _pageSize,
            onPageSizeChanged: (v) => setState(() { _pageSize = v; _page = 0; }),
            onPrev: _page > 0 ? () => setState(() => _page--) : null,
            onNext: (_page + 1) * _pageSize < _filtered.length
                ? () => setState(() => _page++)
                : null,
          ),
      ],
    );
  }
}

class _FormulaCard extends StatelessWidget {
  final SalaryFormula formula;
  final bool canEdit;
  final VoidCallback onEdit, onDelete, onDuplicate;

  const _FormulaCard({
    required this.formula,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final f = formula;
    return Card(
      margin: EdgeInsets.zero,
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
                      Text(
                        f.name.isNotEmpty ? f.name : '${f.salaryGradeCode} — ${f.salaryGradeName}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Text(
                        '${f.salaryGradeCode} — ${f.salaryGradeName}  ·  ${f.departmentName ?? s.scopeCompanyLabel}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s.payFromDate(_dateFmt.format(f.effectiveDate)),
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                if (canEdit) ...[
                  IconButton(
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_outlined, size: 20),
                    color: AppTheme.textSecondary,
                    tooltip: s.payDuplicate,
                  ),
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20), color: AppTheme.textSecondary),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 20), color: AppTheme.error),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _FormulaPreview(label: 'Gross', expr: f.expressionGross),
            const SizedBox(height: 4),
            _FormulaPreview(label: 'Net', expr: f.expressionNet),
          ],
        ),
      ),
    );
  }
}

class _FormulaPreview extends StatelessWidget {
  final String label, expr;
  const _FormulaPreview({required this.label, required this.expr});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(4)),
            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(expr,
                style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.textSecondary),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}

// ─── Formula Editor Dialog ─────────────────────────────────────────────────────

class FormulaEditorDialog extends StatefulWidget {
  final List<SalaryGrade> grades;
  final SalaryFormula? existing;
  final SalaryFormula? duplicateFrom;
  final SalaryFormulaRepository repo;
  /// Nếu có onSave, override hành vi lưu mặc định (create/update repo).
  /// Nhận các giá trị hiện tại của form và trả về Future<void>.
  final Future<dynamic> Function({
    required String name,
    required String expressionGross,
    required String expressionNet,
    required Map<String, String> customVars,
    required Map<String, DeductionVarEntry> deductionVars,
    required Map<String, DeductionVarEntry> incomeVars,
    required Map<String, DeductionVarEntry> allowanceVars,
  })? onSave;

  const FormulaEditorDialog({
    super.key,
    required this.grades,
    required this.repo,
    this.existing,
    this.duplicateFrom,
    this.onSave,
  });

  @override
  State<FormulaEditorDialog> createState() => _FormulaEditorDialogState();
}

class _FormulaEditorDialogState extends State<FormulaEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _grossCtrl = TextEditingController();
  final _netCtrl = TextEditingController();
  final _grossFocus = FocusNode();
  final _netFocus = FocusNode();
  final _varRepo = FormulaVariableRepository();

  TextSelection _grossLastSel = const TextSelection.collapsed(offset: 0);
  TextSelection _netLastSel = const TextSelection.collapsed(offset: 0);
  bool _netActive = false;

  SalaryGrade? _selectedGrade;
  DateTime _effectiveDate = companyNow();
  bool _saving = false;
  bool _validating = false;
  String? _error;
  List<String> _errPrivate = [];
  List<String> _errDeduction = [];
  List<String> _errGross = [];
  List<String> _errNet = [];
  bool _validated = false;

  // System vars từ BE (thay thế hardcode buildVarGroups)
  List<AllVariable> _systemVars = [];
  // Global vars (company-wide, read-only display)
  List<FormulaVariable> _globalVars = [];
  // Private vars (formula-specific): name -> expression
  final Map<String, String> _privateVars = {};
  // Deduction vars: name -> {label, expression}
  final Map<String, DeductionVarEntry> _deductionVars = {};
  // Income vars: thu nhập thêm
  final Map<String, DeductionVarEntry> _incomeVars = {};
  // Allowance vars: trợ cấp
  final Map<String, DeductionVarEntry> _allowanceVars = {};

  @override
  void initState() {
    super.initState();
    _loadCustomVars();
    final e = widget.existing;
    final dup = widget.duplicateFrom;
    if (e != null) {
      _nameCtrl.text = e.name;
      _grossCtrl.text = e.expressionGross;
      _netCtrl.text = e.expressionNet;
      _effectiveDate = e.effectiveDate;
      _privateVars.addAll(e.customVars);
      _deductionVars.addAll(e.deductionVars);
      _incomeVars.addAll(e.incomeVars);
      _allowanceVars.addAll(e.allowanceVars);
      try {
        _selectedGrade = widget.grades.firstWhere((g) => g.id == e.salaryGradeId);
      } catch (_) {}
    } else if (dup != null) {
      _grossCtrl.text = dup.expressionGross;
      _netCtrl.text = dup.expressionNet;
      _privateVars.addAll(dup.customVars);
      _deductionVars.addAll(dup.deductionVars);
      _incomeVars.addAll(dup.incomeVars);
      _allowanceVars.addAll(dup.allowanceVars);
    }

    _grossFocus.addListener(() {
      if (!_grossFocus.hasFocus) {
        _grossLastSel = _grossCtrl.selection;
      } else {
        setState(() => _netActive = false);
      }
    });
    _netFocus.addListener(() {
      if (!_netFocus.hasFocus) {
        _netLastSel = _netCtrl.selection;
      } else {
        setState(() => _netActive = true);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _grossCtrl.dispose(); _netCtrl.dispose();
    _grossFocus.dispose(); _netFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCustomVars() async {
    try {
      final results = await Future.wait([
        _varRepo.getAll(),
        _varRepo.getAllVariables(),
      ]);
      if (mounted) {
        setState(() {
        _globalVars = results[0] as List<FormulaVariable>;
        _systemVars = (results[1] as List<AllVariable>)
            .where((v) => v.scope == VariableScope.system)
            .toList();
      });
      }
    } catch (_) {}
  }

  List<Widget> _systemVarChipWidgets(void Function(String) onInsert) {
    if (_systemVars.isEmpty) return [];
    final grouped = <String, List<AllVariable>>{};
    final other = AppLocalizations.of(context).payVarCategoryOther;
    for (final v in _systemVars) {
      grouped.putIfAbsent(v.category ?? other, () => []).add(v);
    }
    return grouped.entries.map((entry) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.key,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6, runSpacing: 4,
          children: entry.value.map((v) => ActionChip(
            label: Text(v.name, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            tooltip: v.label,
            visualDensity: VisualDensity.compact,
            onPressed: () => onInsert(v.name),
          )).toList(),
        ),
        const SizedBox(height: 6),
      ],
    )).toList();
  }

  void _openCustomVarDialog([FormulaVariable? existing]) async {
    final result = await showDialog<_CustomVarResult>(
      context: context,
      builder: (_) => _CustomVarDialog(repo: _varRepo, existing: existing),
    );
    if (result == null) return;
    if (result.deleted) {
      try {
        await _varRepo.delete(existing!.id);
        _loadCustomVars();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
        }
      }
    } else {
      _loadCustomVars();
    }
  }

  static const _builtinFunctions = {'PIT_VN'};

  void _insertVar(String varName) {
    final isNet = _netActive;
    final ctrl = isNet ? _netCtrl : _grossCtrl;
    final lastSel = isNet ? _netLastSel : _grossLastSel;
    final text = ctrl.text;
    final sel = ctrl.selection.isValid ? ctrl.selection : lastSel;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(start, text.length);
    final String insert;
    final int cursorOffset;
    if (_builtinFunctions.contains(varName)) {
      // Insert function call với cursor đặt bên trong ngoặc
      insert = ' $varName()';
      cursorOffset = start + insert.length - 1; // trước ')'
    } else {
      insert = ' $varName ';
      cursorOffset = start + insert.length;
    }
    ctrl.value = TextEditingValue(
      text: text.substring(0, start) + insert + text.substring(end),
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
    setState(() => _validated = false);
  }

  Future<void> _validate() async {
    setState(() { _validating = true; _errPrivate = []; _errDeduction = []; _errGross = []; _errNet = []; _validated = false; });
    try {
      final result = await widget.repo.validate(
        _grossCtrl.text, _netCtrl.text, _privateVars,
        deductionVars: _deductionVars,
        incomeVars: _incomeVars,
        allowanceVars: _allowanceVars,
      );
      if (mounted) {
        setState(() {
        _errPrivate = result.errorsPrivate;
        _errDeduction = result.errorsDeduction;
        _errGross = result.errorsGross;
        _errNet = result.errorsNet;
        _validated = result.valid;
      });
      }
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _save() async {
    final s = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = s.payFormulaNameRequired);
      return;
    }
    if (_selectedGrade == null && widget.existing == null) {
      setState(() => _error = s.payGradeRequired);
      return;
    }
    if (_grossCtrl.text.trim().isEmpty || _netCtrl.text.trim().isEmpty) {
      setState(() => _error = s.payFormulaIncomplete);
      return;
    }
    if (!_validated) { await _validate(); if (!_validated) return; }
    setState(() { _saving = true; _error = null; });
    try {
      if (widget.onSave != null) {
        final result = await widget.onSave!(
          name: _nameCtrl.text.trim(),
          expressionGross: _grossCtrl.text.trim(),
          expressionNet: _netCtrl.text.trim(),
          customVars: Map.of(_privateVars),
          deductionVars: Map.of(_deductionVars),
          incomeVars: Map.of(_incomeVars),
          allowanceVars: Map.of(_allowanceVars),
        );
        if (mounted) Navigator.pop(context, result);
      } else {
        SalaryFormula result;
        if (widget.existing == null) {
          result = await widget.repo.create(
            salaryGradeId: _selectedGrade!.id,
            name: _nameCtrl.text.trim(),
            effectiveDate: _effectiveDate,
            expressionGross: _grossCtrl.text.trim(),
            expressionNet: _netCtrl.text.trim(),
            customVars: _privateVars,
            deductionVars: _deductionVars,
            incomeVars: _incomeVars,
            allowanceVars: _allowanceVars,
          );
        } else {
          result = await widget.repo.update(
            widget.existing!.id,
            name: _nameCtrl.text.trim(),
            effectiveDate: _effectiveDate,
            expressionGross: _grossCtrl.text.trim(),
            expressionNet: _netCtrl.text.trim(),
            customVars: _privateVars,
            deductionVars: _deductionVars,
            incomeVars: _incomeVars,
            allowanceVars: _allowanceVars,
          );
        }
        if (mounted) Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = serverMsg(e); });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() { _effectiveDate = picked; _validated = false; });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      clipBehavior: Clip.none,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 680, maxHeight: screenH * 0.88),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.onSave != null
                    ? s.payFormulaCustomizeTitle
                    : isEdit
                        ? s.payFormulaEditTitle
                        : widget.duplicateFrom != null
                            ? s.payFormulaDuplicateTitle
                            : s.payFormulaAddTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (widget.onSave != null) ...[
                const SizedBox(height: 4),
                Text(
                  s.payFormulaInlineNote,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                        ),

                      // Formula name
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: s.payFormulaNameLabel,
                          hintText: s.payFormulaNameHint,
                          hintStyle: const TextStyle(fontSize: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),

                      // Grade picker — ẩn khi inline mode
                      if (widget.onSave == null && !isEdit) ...[
                        DropdownButtonFormField<SalaryGrade>(
                          initialValue: _selectedGrade,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: s.salaryGrade),
                          items: widget.grades.map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(
                              '${g.code} — ${g.name}  ·  ${g.departmentName ?? s.scopeCompanyLabel}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          onChanged: (v) => setState(() { _selectedGrade = v; _validated = false; }),
                        ),
                        const SizedBox(height: 12),
                      ] else if (_selectedGrade != null || widget.existing != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.border.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.existing != null
                                ? '${widget.existing!.salaryGradeCode} — ${widget.existing!.salaryGradeName}  ·  ${widget.existing!.departmentName ?? s.scopeCompanyLabel}'
                                : '',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Effective date — ẩn khi inline mode
                      if (widget.onSave == null) ...[
                        InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: s.effectiveDate,
                              suffixIcon: const Icon(Icons.calendar_today, size: 18),
                            ),
                            child: Text(_dateFmt.format(_effectiveDate), style: const TextStyle(fontSize: 14)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Variable chips
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.border.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.payFormulaVarsChipHint(s.formulaVariables),
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            ...buildSystemVarChips(s, _systemVars, _insertVar),
                            // ── Biến Global (company-wide) ──────────────────
                            Row(
                              children: [
                                Text(s.varGlobalSection,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                                const Spacer(),
                                InkWell(
                                  onTap: () => _openCustomVarDialog(),
                                  child: const Icon(Icons.add_circle_outline, size: 16, color: AppTheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Builder(builder: (_) {
                              final visibleGlobals = _globalVars.where((v) => v.showInFormula).toList();
                              if (visibleGlobals.isEmpty) {
                                return Text(s.varNoGlobal,
                                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary,
                                        fontStyle: FontStyle.italic));
                              }
                              // Nhóm theo category
                              final other = s.payVarCategoryOther;
                              final Map<String, List<FormulaVariable>> grouped = {};
                              for (final v in visibleGlobals) {
                                final key = (v.category?.isNotEmpty ?? false) ? v.category! : other;
                                grouped.putIfAbsent(key, () => []).add(v);
                              }
                              final sortedKeys = grouped.keys.toList()
                                ..sort((a, b) => a == other ? 1 : b == other ? -1 : a.compareTo(b));
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final cat in sortedKeys) ...[
                                    Text(cat, style: const TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w600,
                                        color: AppTheme.primary)),
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 6, runSpacing: 4,
                                      children: grouped[cat]!.map((v) => _GlobalVarChip(
                                        name: v.name,
                                        tooltip: '${v.label}\n= ${v.expression}',
                                        onInsert: () => _insertVar(v.name),
                                        onEdit: () => _showCustomVarMenu(v),
                                      )).toList(),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                ],
                              );
                            }),
                            const SizedBox(height: 6),
                            // ── Biến Private (chỉ trong công thức này) ──────
                            Row(
                              children: [
                                Text(s.varPrivateSection,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                                const Spacer(),
                                InkWell(
                                  onTap: () => _openPrivateVarDialog(),
                                  child: const Icon(Icons.add_circle_outline, size: 16, color: AppTheme.secondary),
                                ),
                              ],
                            ),
                            if (_errPrivate.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _errPrivate.map((e) => Text('⚠ $e',
                                        style: const TextStyle(color: AppTheme.error, fontSize: 11))).toList()),
                              ),
                            const SizedBox(height: 4),
                            if (_privateVars.isEmpty)
                              Text(s.varNoPrivate,
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary,
                                      fontStyle: FontStyle.italic))
                            else
                              Wrap(
                                spacing: 6, runSpacing: 4,
                                children: _privateVars.entries.map((entry) => _VarChip(
                                  name: entry.key,
                                  tooltip: '= ${entry.value}',
                                  color: AppTheme.secondary,
                                  onInsert: () => _insertVar(entry.key),
                                  onEdit: () => _editPrivateVar(entry.key, entry.value),
                                )).toList(),
                              ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),

                            // ── Thu nhập ──────────────────────────────────
                            _varGroupSection(
                              icon: Icons.add_circle_outline,
                              color: AppTheme.secondary,
                              title: s.incomeSection,
                              subtitle: s.payGrossVarsHint,
                              vars: _incomeVars,
                              onAdd: () => _openVarGroupDialog(_incomeVars, s.incomeSection),
                              onEdit: (k, v) => _openVarGroupDialog(_incomeVars, s.incomeSection, k, v),
                              onInsert: _insertVar,
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),

                            // ── Trợ cấp ───────────────────────────────────
                            _varGroupSection(
                              icon: Icons.card_giftcard_outlined,
                              color: const Color(0xFF9C27B0),
                              title: s.allowanceSection,
                              subtitle: s.payGrossVarsHint,
                              vars: _allowanceVars,
                              onAdd: () => _openVarGroupDialog(_allowanceVars, s.allowanceSection),
                              onEdit: (k, v) => _openVarGroupDialog(_allowanceVars, s.allowanceSection, k, v),
                              onInsert: _insertVar,
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            // ── Khoản khấu trừ ──────────────────────────────
                            _varGroupSection(
                              icon: Icons.remove_circle_outline,
                              color: AppTheme.error,
                              title: s.payDeductionItemsTitle,
                              subtitle: s.payNetVarsHint,
                              vars: _deductionVars,
                              onAdd: () => _openDeductionDialog(),
                              onEdit: (k, v) => _openDeductionDialog(k, v),
                              onInsert: _insertVar,
                            ),
                            if (_errDeduction.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _errDeduction.map((e) => Text('⚠ $e',
                                        style: const TextStyle(color: AppTheme.error, fontSize: 11))).toList()),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Gross
                      TextField(
                        controller: _grossCtrl, focusNode: _grossFocus, maxLines: 3,
                        decoration: InputDecoration(
                          labelText: '${s.formulaGross} (Gross)',
                          hintText: s.payGrossFormulaHint,
                          hintStyle: const TextStyle(fontSize: 12),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(borderSide: BorderSide(color: _errGross.isNotEmpty ? AppTheme.error : AppTheme.border)),
                        ),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        onChanged: (_) => setState(() => _validated = false),
                      ),
                      if (_errGross.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 4),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: _errGross.map((e) => Text('⚠ $e', style: const TextStyle(color: AppTheme.error, fontSize: 12))).toList())),
                      const SizedBox(height: 12),

                      // Net
                      TextField(
                        controller: _netCtrl, focusNode: _netFocus, maxLines: 3,
                        decoration: InputDecoration(
                          labelText: '${s.formulaNet} (Net)',
                          hintText: s.payNetFormulaHint,
                          hintStyle: const TextStyle(fontSize: 12),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(borderSide: BorderSide(color: _errNet.isNotEmpty ? AppTheme.error : AppTheme.border)),
                        ),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        onChanged: (_) => setState(() => _validated = false),
                      ),
                      if (_errNet.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 4),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: _errNet.map((e) => Text('⚠ $e', style: const TextStyle(color: AppTheme.error, fontSize: 12))).toList())),
                      if (_validated && _errGross.isEmpty && _errNet.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(children: [
                            const Icon(Icons.check_circle, color: AppTheme.secondary, size: 16),
                            const SizedBox(width: 6),
                            Text(s.formulaValid, style: const TextStyle(color: AppTheme.secondary, fontSize: 13)),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _validating ? null : _validate,
                    icon: _validating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check, size: 16),
                    label: Text(s.formulaValidate),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(s.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPrivateVarDialog([String? existingName, String? existingExpr]) async {
    final nameCtrl = TextEditingController(text: existingName ?? '');
    final exprCtrl = TextEditingController(text: existingExpr ?? '');
    final result = await showDialog<MapEntry<String, String>>(
      context: context,
      builder: (_) => _PrivateVarDialog(
        nameCtrl: nameCtrl,
        exprCtrl: exprCtrl,
        isEdit: existingName != null,
        existingNames: _privateVars.keys.where((k) => k != existingName).toSet(),
        globalVars: _globalVars,
        systemVars: _systemVars,
      ),
    );
    if (result != null) {
      setState(() {
        if (existingName != null && existingName != result.key) {
          _privateVars.remove(existingName);
        }
        _privateVars[result.key] = result.value;
        _validated = false;
      });
    }
  }

  void _editPrivateVar(String name, String expr) {
    final s = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(s.payEditNamed(name)),
              onTap: () { Navigator.pop(sheetCtx); _openPrivateVarDialog(name, expr); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.error),
              title: Text(s.payDeleteNamed(name), style: const TextStyle(color: AppTheme.error)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    content: Text(s.payVarDeleteConfirm(name)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(s.delete),
                      ),
                    ],
                  ),
                );
                if (ok == true) setState(() { _privateVars.remove(name); _validated = false; });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomVarMenu(FormulaVariable v) {
    _openCustomVarDialog(v);
  }

  Widget _varGroupSection({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Map<String, DeductionVarEntry> vars,
    required VoidCallback onAdd,
    required void Function(String, DeductionVarEntry) onEdit,
    required void Function(String) onInsert,
  }) {
    final s = AppLocalizations.of(context);
    final entries = vars.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          const Spacer(),
          InkWell(onTap: onAdd, child: Icon(Icons.add_circle_outline, size: 16, color: color)),
        ]),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
        const SizedBox(height: 4),
        if (vars.isEmpty)
          Text(s.payNoItems, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic))
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final item = entries.removeAt(oldIdx);
                entries.insert(newIdx, item);
                vars
                  ..clear()
                  ..addEntries(entries);
                _validated = false;
              });
            },
            children: [
              for (int i = 0; i < entries.length; i++)
                ListTile(
                  key: ValueKey(entries[i].key),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  minTileHeight: 36,
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle, size: 16, color: Colors.grey),
                  ),
                  title: Text(
                    entries[i].value.label.isNotEmpty ? entries[i].value.label : entries[i].key,
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    entries[i].key,
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontFamily: 'monospace'),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => onInsert(entries[i].key),
                        child: Icon(Icons.add_circle_outline, size: 16, color: color),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => onEdit(entries[i].key, entries[i].value),
                        child: Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  void _openVarGroupDialog(Map<String, DeductionVarEntry> target, String title,
      [String? existingKey, DeductionVarEntry? existing]) async {
    final keyCtrl = TextEditingController(text: existingKey ?? '');
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final exprCtrl = TextEditingController(text: existing?.expression ?? '');
    final result = await showDialog<MapEntry<String, DeductionVarEntry>>(
      context: context,
      builder: (_) => _DeductionVarDialog(
        title: title,
        keyCtrl: keyCtrl,
        labelCtrl: labelCtrl,
        exprCtrl: exprCtrl,
        isEdit: existingKey != null,
        existingKeys: target.keys.where((k) => k != existingKey).toSet(),
        globalVars: _globalVars,
        systemVars: _systemVars,
      ),
    );
    if (result != null) {
      setState(() {
        if (result.key == '__delete__') {
          target.remove(existingKey);
        } else {
          if (existingKey != null && existingKey != result.key) target.remove(existingKey);
          target[result.key] = result.value;
        }
        _validated = false;
      });
    }
  }

  void _openDeductionDialog([String? existingKey, DeductionVarEntry? existing]) async {
    final keyCtrl = TextEditingController(text: existingKey ?? '');
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final exprCtrl = TextEditingController(text: existing?.expression ?? '');
    final result = await showDialog<MapEntry<String, DeductionVarEntry>>(
      context: context,
      builder: (_) => _DeductionVarDialog(
        title: AppLocalizations.of(context).deductionSection,
        keyCtrl: keyCtrl,
        labelCtrl: labelCtrl,
        exprCtrl: exprCtrl,
        isEdit: existingKey != null,
        existingKeys: _deductionVars.keys.where((k) => k != existingKey).toSet(),
        globalVars: _globalVars,
        systemVars: _systemVars,
      ),
    );
    if (result != null) {
      setState(() {
        if (result.key == '__delete__') {
          _deductionVars.remove(existingKey);
        } else {
          if (existingKey != null && existingKey != result.key) {
            _deductionVars.remove(existingKey);
          }
          _deductionVars[result.key] = result.value;
        }
        _validated = false;
      });
    }
  }
}

// ─── Custom Variable Dialog ────────────────────────────────────────────────────

class _CustomVarResult {
  final bool deleted;
  const _CustomVarResult({this.deleted = false});
}

class _CustomVarDialog extends StatefulWidget {
  final FormulaVariableRepository repo;
  final FormulaVariable? existing;

  const _CustomVarDialog({required this.repo, this.existing});

  @override
  State<_CustomVarDialog> createState() => _CustomVarDialogState();
}

class _CustomVarDialogState extends State<_CustomVarDialog> {
  final _nameCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _exprCtrl = TextEditingController();
  final _exprFocus = FocusNode();
  TextSelection _exprLastSel = const TextSelection.collapsed(offset: 0);
  bool _saving = false;
  bool _validating = false;
  bool _validated = false;
  String? _error;
  List<String> _errors = [];
  List<FormulaVariable> _globalVars = [];
  List<AllVariable> _systemVars = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _labelCtrl.text = e.label;
      _exprCtrl.text = e.expression;
    }
    _exprFocus.addListener(() {
      if (!_exprFocus.hasFocus) _exprLastSel = _exprCtrl.selection;
    });
    _loadGlobals();
  }

  Future<void> _loadGlobals() async {
    try {
      final results = await Future.wait([
        widget.repo.getAll(),
        widget.repo.getAllVariables(),
      ]);
      if (mounted) {
        setState(() {
        _globalVars = (results[0] as List<FormulaVariable>)
            .where((v) => v.name != widget.existing?.name)
            .toList();
        _systemVars = (results[1] as List<AllVariable>)
            .where((v) => v.scope == VariableScope.system)
            .toList();
      });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _labelCtrl.dispose();
    _exprCtrl.dispose();
    _exprFocus.dispose();
    super.dispose();
  }

  void _insertVar(String varName) {
    final text = _exprCtrl.text;
    final sel = _exprCtrl.selection.isValid ? _exprCtrl.selection : _exprLastSel;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(start, text.length);
    final insert = ' $varName ';
    _exprCtrl.value = TextEditingValue(
      text: text.substring(0, start) + insert + text.substring(end),
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    setState(() => _validated = false);
  }

  Future<void> _validate() async {
    final name = _nameCtrl.text.trim().toUpperCase();
    final expr = _exprCtrl.text.trim();
    if (name.isEmpty || expr.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).payFillAllFields);
      return;
    }
    setState(() { _validating = true; _errors = []; _validated = false; _error = null; });
    try {
      final result = await widget.repo.validate(name, expr);
      if (mounted) setState(() { _errors = result.errors; _validated = result.valid; });
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _save() async {
    if (!_validated) { await _validate(); if (!_validated) return; }
    final name = _nameCtrl.text.trim().toUpperCase();
    final label = _labelCtrl.text.trim().isEmpty ? name : _labelCtrl.text.trim();
    final expr = _exprCtrl.text.trim();
    setState(() { _saving = true; _error = null; });
    try {
      if (widget.existing == null) {
        await widget.repo.create(name: name, label: label, expression: expr);
      } else {
        await widget.repo.update(widget.existing!.id, name: name, label: label, expression: expr);
      }
      if (mounted) Navigator.pop(context, const _CustomVarResult());
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = serverMsg(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? s.payCustomVarEditTitle : s.payCustomVarAddTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: s.varNameLabel,
                hintText: s.varNameHint,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() => _validated = false),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _labelCtrl,
              decoration: InputDecoration(labelText: s.varDescLabel),
            ),
            const SizedBox(height: 10),
            // Chip palette biến hệ thống
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.varChipInsertHint,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  ...buildSystemVarChips(s, _systemVars, _insertVar, compact: true),
                  ...buildGroupedGlobalChips(s, _globalVars, _insertVar),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _exprCtrl,
              focusNode: _exprFocus,
              decoration: InputDecoration(
                labelText: s.varExprLabel,
                hintText: s.varExprHint,
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: _errors.isNotEmpty ? AppTheme.error : AppTheme.border),
                ),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              maxLines: 2,
              onChanged: (_) => setState(() => _validated = false),
            ),
            if (_errors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _errors
                      .map((e) => Text('⚠ $e',
                          style: const TextStyle(color: AppTheme.error, fontSize: 12)))
                      .toList(),
                ),
              ),
            if (_validated && _errors.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: AppTheme.secondary, size: 16),
                  const SizedBox(width: 6),
                  Text(s.varExprValid,
                      style: const TextStyle(color: AppTheme.secondary, fontSize: 13)),
                ]),
              ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (isEdit)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    content: Text(s.payVarDeleteConfirm(widget.existing!.name)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(s.delete),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  Navigator.pop(context, const _CustomVarResult(deleted: true));
                }
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
              label: Text(s.delete, style: const TextStyle(color: AppTheme.error)),
            ),
          )
        else
          const SizedBox.shrink(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
            OutlinedButton.icon(
              onPressed: _validating ? null : _validate,
              icon: _validating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check, size: 16),
              label: Text(s.formulaValidate),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(s.save),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Deduction Var Dialog ─────────────────────────────────────────────────────

class _DeductionVarDialog extends StatefulWidget {
  final String title;
  final TextEditingController keyCtrl;
  final TextEditingController labelCtrl;
  final TextEditingController exprCtrl;
  final bool isEdit;
  final Set<String> existingKeys;
  final List<FormulaVariable> globalVars;
  final List<AllVariable> systemVars;

  const _DeductionVarDialog({
    required this.title,
    required this.keyCtrl,
    required this.labelCtrl,
    required this.exprCtrl,
    required this.isEdit,
    required this.existingKeys,
    this.globalVars = const [],
    this.systemVars = const [],
  });

  @override
  State<_DeductionVarDialog> createState() => _DeductionVarDialogState();
}

class _DeductionVarDialogState extends State<_DeductionVarDialog> {
  final _exprFocus = FocusNode();
  TextSelection _exprLastSel = const TextSelection.collapsed(offset: 0);
  String? _error;

  @override
  void initState() {
    super.initState();
    _exprFocus.addListener(() {
      if (!_exprFocus.hasFocus) _exprLastSel = widget.exprCtrl.selection;
    });
  }

  @override
  void dispose() {
    _exprFocus.dispose();
    super.dispose();
  }

  void _insertVar(String varName) {
    final ctrl = widget.exprCtrl;
    final text = ctrl.text;
    final sel = ctrl.selection.isValid ? ctrl.selection : _exprLastSel;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(start, text.length);
    final insert = ' $varName ';
    ctrl.value = TextEditingValue(
      text: text.substring(0, start) + insert + text.substring(end),
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    setState(() => _error = null);
  }

  void _submit() {
    final key = widget.keyCtrl.text.trim().toUpperCase();
    final label = widget.labelCtrl.text.trim();
    final expr = widget.exprCtrl.text.trim();
    final s = AppLocalizations.of(context);
    if (key.isEmpty) { setState(() => _error = s.payVarNameRequired); return; }
    if (!RegExp(r'^[A-Z][A-Z0-9_]{0,49}$').hasMatch(key)) {
      setState(() => _error = s.payVarNameFormatError);
      return;
    }
    if (widget.existingKeys.contains(key)) {
      setState(() => _error = s.payVarNameExists(key));
      return;
    }
    if (expr.isEmpty) { setState(() => _error = s.payExprRequired); return; }
    Navigator.pop(context, MapEntry(key, DeductionVarEntry(
      label: label.isEmpty ? key : label,
      expression: expr,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.isEdit ? s.payEditItemTitle(widget.title.toLowerCase()) : s.payAddItemTitle(widget.title.toLowerCase())),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            TextFormField(
              controller: widget.keyCtrl,
              decoration: InputDecoration(
                labelText: s.varNameLabel,
                hintText: s.payDeductionKeyHint,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: widget.labelCtrl,
              decoration: InputDecoration(
                labelText: s.payPayslipLabel,
                hintText: s.payPayslipLabelHint,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.varChipInsertHint,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  ...buildSystemVarChips(s, widget.systemVars, _insertVar, compact: true),
                  ...buildGroupedGlobalChips(s, widget.globalVars, _insertVar),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: widget.exprCtrl,
              focusNode: _exprFocus,
              decoration: InputDecoration(
                labelText: s.payAmountExprLabel,
                hintText: s.payAmountExprHint,
                hintStyle: const TextStyle(fontSize: 12),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              maxLines: 2,
              onChanged: (_) => setState(() => _error = null),
            ),
          ],
        ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (widget.isEdit)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    content: Text(s.payDeductionDeleteConfirm(widget.keyCtrl.text)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(s.delete),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) Navigator.pop(context, const MapEntry('__delete__', DeductionVarEntry(label: '', expression: '')));
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
              label: Text(s.delete, style: const TextStyle(color: AppTheme.error)),
            ),
          )
        else
          const SizedBox.shrink(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: _submit,
              child: Text(widget.isEdit ? s.payUpdateAction : s.add),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Shared helper: system var chips từ BE (thay thế hardcode buildVarGroups) ──

List<Widget> buildSystemVarChips(
  AppLocalizations s,
  List<AllVariable> systemVars,
  void Function(String) onInsert, {
  bool compact = false,
}) {
  if (systemVars.isEmpty) return [];
  final grouped = <String, List<AllVariable>>{};
  for (final v in systemVars) {
    grouped.putIfAbsent(v.category ?? s.payVarCategoryOther, () => []).add(v);
  }
  final labelSize = compact ? 10.0 : 11.0;
  final chipSpacing = compact ? 4.0 : 6.0;
  final chipRunSpacing = compact ? 3.0 : 4.0;
  final sectionSpacing = compact ? 4.0 : 6.0;
  return grouped.entries.map((entry) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(entry.key,
          style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
      SizedBox(height: compact ? 3 : 4),
      Wrap(
        spacing: chipSpacing, runSpacing: chipRunSpacing,
        children: entry.value.map((v) => ActionChip(
          label: Text(v.name, style: TextStyle(fontSize: labelSize, fontFamily: 'monospace')),
          tooltip: v.label,
          visualDensity: VisualDensity.compact,
          padding: compact ? EdgeInsets.zero : null,
          onPressed: () => onInsert(v.name),
        )).toList(),
      ),
      SizedBox(height: sectionSpacing),
    ],
  )).toList();
}

// ─── Shared helper: grouped global var chips (insert only, no edit) ────────────

List<Widget> buildGroupedGlobalChips(
    AppLocalizations s, List<FormulaVariable> vars, void Function(String) onInsert) {
  if (vars.isEmpty) return [];
  final globalLabel = s.payGlobalVarGroup;
  final Map<String, List<FormulaVariable>> grouped = {};
  for (final v in vars) {
    final key = (v.category?.isNotEmpty ?? false) ? v.category! : globalLabel;
    grouped.putIfAbsent(key, () => []).add(v);
  }
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) => a == globalLabel ? 1 : b == globalLabel ? -1 : a.compareTo(b));
  return sortedKeys.map((cat) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(cat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary)),
      const SizedBox(height: 3),
      Wrap(
        spacing: 4, runSpacing: 3,
        children: grouped[cat]!.map((v) => ActionChip(
          label: Text(v.name,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace',
                  color: AppTheme.warning)),
          tooltip: '${v.label}\n= ${v.expression}',
          visualDensity: VisualDensity.compact,
          backgroundColor: AppTheme.warning.withValues(alpha: 0.1),
          side: BorderSide(color: AppTheme.warning.withValues(alpha: 0.4)),
          onPressed: () => onInsert(v.name),
        )).toList(),
      ),
      const SizedBox(height: 4),
    ],
  )).toList();
}

// ─── Global Var Chip (same style as system chips, with small edit button) ──────

class _GlobalVarChip extends StatelessWidget {
  final String name;
  final String tooltip;
  final VoidCallback onInsert;
  final VoidCallback onEdit;

  const _GlobalVarChip({
    required this.name,
    required this.tooltip,
    required this.onInsert,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InputChip(
          label: Text(name, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          visualDensity: VisualDensity.compact,
          onPressed: onInsert,
          deleteIcon: Icon(Icons.edit, size: 12, color: AppTheme.textSecondary),
          onDeleted: onEdit,
        ),
      );
}

// ─── Var Chip with insert + edit buttons ──────────────────────────────────────

class _VarChip extends StatelessWidget {
  final String name;
  final String tooltip;
  final Color color;
  final VoidCallback onInsert;
  final VoidCallback onEdit;

  const _VarChip({
    required this.name,
    required this.tooltip,
    required this.color,
    required this.onInsert,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                onTap: onInsert,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(name,
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace',
                          color: color, fontWeight: FontWeight.w600)),
                ),
              ),
              Container(width: 1, height: 18, color: color.withValues(alpha: 0.3)),
              InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(Icons.edit, size: 11, color: color),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Private Variable Dialog ───────────────────────────────────────────────────

class _PrivateVarDialog extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController exprCtrl;
  final bool isEdit;
  final Set<String> existingNames;
  final List<FormulaVariable> globalVars;
  final List<AllVariable> systemVars;

  const _PrivateVarDialog({
    required this.nameCtrl,
    required this.exprCtrl,
    required this.isEdit,
    required this.existingNames,
    this.globalVars = const [],
    this.systemVars = const [],
  });

  @override
  State<_PrivateVarDialog> createState() => _PrivateVarDialogState();
}

class _PrivateVarDialogState extends State<_PrivateVarDialog> {
  final _exprFocus = FocusNode();
  TextSelection _exprLastSel = const TextSelection.collapsed(offset: 0);
  String? _error;

  @override
  void initState() {
    super.initState();
    _exprFocus.addListener(() {
      if (!_exprFocus.hasFocus) _exprLastSel = widget.exprCtrl.selection;
    });
  }

  @override
  void dispose() {
    _exprFocus.dispose();
    super.dispose();
  }

  void _insertVar(String varName) {
    final ctrl = widget.exprCtrl;
    final text = ctrl.text;
    final sel = ctrl.selection.isValid ? ctrl.selection : _exprLastSel;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(start, text.length);
    final insert = ' $varName ';
    ctrl.value = TextEditingValue(
      text: text.substring(0, start) + insert + text.substring(end),
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
  }

  void _submit() {
    final name = widget.nameCtrl.text.trim().toUpperCase();
    final expr = widget.exprCtrl.text.trim();
    final s = AppLocalizations.of(context);
    if (name.isEmpty) {
      setState(() => _error = s.payVarNameRequired);
      return;
    }
    if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(name)) {
      setState(() => _error = s.payNameFormatError);
      return;
    }
    if (widget.existingNames.contains(name)) {
      setState(() => _error = s.payVarNameExistsPlain);
      return;
    }
    if (expr.isEmpty) {
      setState(() => _error = s.payExprRequired);
      return;
    }
    Navigator.pop(context, MapEntry(name, expr));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.isEdit ? s.varEditPrivate : s.varAddPrivate),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            TextFormField(
              controller: widget.nameCtrl,
              enabled: !widget.isEdit,
              decoration: InputDecoration(
                labelText: s.varNameLabel,
                hintText: s.payPrivateVarNameHint,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 10),
            // Chip palette
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.varChipInsertHint,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  ...buildSystemVarChips(s, widget.systemVars, _insertVar, compact: true),
                  ...buildGroupedGlobalChips(s, widget.globalVars, _insertVar),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: widget.exprCtrl,
              focusNode: _exprFocus,
              decoration: InputDecoration(
                labelText: s.varExprLabel,
                hintText: s.payPrivateVarExprHint,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              maxLines: 2,
              onChanged: (_) => setState(() => _error = null),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _submit, child: Text(s.add)),
      ],
    );
  }
}
