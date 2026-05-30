import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/all_variable.dart';
import '../../../data/models/formula_variable.dart';
import '../../../data/repositories/formula_variable_repository.dart';
import 'salary_formula_tab.dart' show buildGroupedGlobalChips, buildSystemVarChips;

class CustomVarDialog extends StatefulWidget {
  final FormulaVariableRepository repo;
  final FormulaVariable? existing;

  const CustomVarDialog({super.key, required this.repo, this.existing});

  @override
  State<CustomVarDialog> createState() => _CustomVarDialogState();
}

class _CustomVarDialogState extends State<CustomVarDialog> {
  final _nameCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _exprCtrl = TextEditingController();
  final _exprFocus = FocusNode();
  TextSelection _exprLastSel = const TextSelection.collapsed(offset: 0);
  bool _saving = false;
  bool _validating = false;
  bool _validated = false;
  String? _error;
  List<String> _errors = [];
  List<FormulaVariable> _visibleGlobals = [];
  List<AllVariable> _systemVars = [];
  List<String> _existingCategories = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _labelCtrl.text = e.label;
      _categoryCtrl.text = e.category ?? '';
      _exprCtrl.text = e.expression;
    }
    _exprFocus.addListener(() {
      if (!_exprFocus.hasFocus) _exprLastSel = _exprCtrl.selection;
    });
    _loadGlobals();
    _loadCategories();
  }

  Future<void> _loadGlobals() async {
    try {
      final results = await Future.wait([
        widget.repo.getAll(),
        widget.repo.getAllVariables(),
      ]);
      if (mounted) setState(() {
        _visibleGlobals = (results[0] as List<FormulaVariable>)
            .where((v) => v.showInFormula && v.name != widget.existing?.name)
            .toList();
        _systemVars = (results[1] as List<AllVariable>)
            .where((v) => v.scope == VariableScope.system)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await widget.repo.getCategories();
      if (mounted) setState(() => _existingCategories = cats);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _labelCtrl.dispose();
    _categoryCtrl.dispose();
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
      setState(() => _error = 'Vui lòng điền đầy đủ');
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
    final category = _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim();
    setState(() { _saving = true; _error = null; });
    try {
      FormulaVariable result;
      if (widget.existing == null) {
        result = await widget.repo.create(name: name, label: label, expression: expr, category: category);
      } else {
        result = await widget.repo.update(
            widget.existing!.id, name: name, label: label, expression: expr, category: category ?? '');
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = serverMsg(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Sửa biến Global' : 'Thêm biến Global'),
      content: SizedBox(
        width: 420,
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
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên biến (A-Z, 0-9, _)',
                hintText: 'VD: THUONG_LE',
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() => _validated = false),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _labelCtrl,
              decoration: const InputDecoration(labelText: 'Mô tả (tuỳ chọn)'),
            ),
            const SizedBox(height: 10),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _categoryCtrl.text),
              optionsBuilder: (v) => _existingCategories
                  .where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
              fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                _categoryCtrl.text = ctrl.text;
                return TextFormField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: const InputDecoration(
                    labelText: 'Nhóm / Module (tuỳ chọn)',
                    hintText: 'VD: Bảo hiểm, Phụ cấp, Thuế...',
                  ),
                  onChanged: (v) => _categoryCtrl.text = v,
                );
              },
              onSelected: (v) => _categoryCtrl.text = v,
              optionsViewBuilder: (ctx, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160, maxWidth: 380),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final opt = options.elementAt(i);
                        return ListTile(
                          dense: true,
                          title: Text(opt, style: const TextStyle(fontSize: 13)),
                          onTap: () => onSelected(opt),
                        );
                      },
                    ),
                  ),
                ),
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
                  const Text('Nhấn chip để chèn vào biểu thức',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  ...buildSystemVarChips(_systemVars, _insertVar, compact: true),
                  ...buildGroupedGlobalChips(_visibleGlobals, _insertVar),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _exprCtrl,
              focusNode: _exprFocus,
              decoration: InputDecoration(
                labelText: 'Biểu thức',
                hintText: 'VD: BASE_RATE * 0.5',
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
                child: Row(children: const [
                  Icon(Icons.check_circle, color: AppTheme.secondary, size: 16),
                  SizedBox(width: 6),
                  Text('Biểu thức hợp lệ',
                      style: TextStyle(color: AppTheme.secondary, fontSize: 13)),
                ]),
              ),
          ],
        ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        OutlinedButton.icon(
          onPressed: _validating ? null : _validate,
          icon: _validating
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check, size: 16),
          label: const Text('Kiểm tra'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
