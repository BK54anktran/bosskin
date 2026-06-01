import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/salary_grade.dart';
import '../../../data/repositories/salary_grade_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/department_service.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/pagination_bar.dart';
import 'package:bosskin/l10n/app_localizations.dart';

final _currFmt = NumberFormat('#,###', 'vi_VN');

class SalaryGradeTab extends StatefulWidget {
  const SalaryGradeTab({super.key});

  @override
  State<SalaryGradeTab> createState() => _SalaryGradeTabState();
}

class _SalaryGradeTabState extends State<SalaryGradeTab> {
  final _repo = SalaryGradeRepository();

  bool _loading = true;
  String? _error;
  List<SalaryGrade> _grades = [];
  List<DepartmentFlat> _depts = [];
  int? _filterDeptId;
  int _page = 0;
  int _pageSize = 20;

  List<SalaryGrade> get _pagedGrades {
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, _grades.length);
    return start >= _grades.length ? [] : _grades.sublist(start, end);
  }
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    _canEdit = AuthService.instance.currentUser?.can('PAYROLL_CREATE') ?? false;
    _loadDepts();
    _load();
  }

  Future<void> _loadDepts() async {
    try {
      final depts = await DepartmentService.instance.getFlat();
      if (mounted) setState(() => _depts = depts);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final grades = await _repo.getAll(departmentId: _filterDeptId);
      if (mounted) setState(() => _grades = grades);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForm([SalaryGrade? existing]) async {
    final result = await showDialog<SalaryGrade>(
      context: context,
      builder: (_) => _SalaryGradeDialog(
        existing: existing,
        repo: _repo,
      ),
    );
    if (result != null) _load();
  }

  Future<void> _delete(SalaryGrade g) async {
    final s = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('Xoá bậc lương "${g.code} - ${g.name}"?'),
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
      await _repo.delete(g.id);
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
    final s = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter bar
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
                  onChanged: (v) {
                    setState(() => _filterDeptId = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              if (_canEdit)
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(s.salaryGradeAdd),
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
              : _grades.isEmpty
                  ? Center(child: Text(s.noResults))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pagedGrades.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _GradeCard(
                          grade: _pagedGrades[i],
                          canEdit: _canEdit,
                          onEdit: () => _openForm(_pagedGrades[i]),
                          onDelete: () => _delete(_pagedGrades[i]),
                        ),
                      ),
                    ),
        ),
        if (!_loading && _grades.isNotEmpty)
          PaginationBar(
            total: _grades.length,
            page: _page,
            pageSize: _pageSize,
            onPageSizeChanged: (v) => setState(() { _pageSize = v; _page = 0; }),
            onPrev: _page > 0 ? () => setState(() => _page--) : null,
            onNext: (_page + 1) * _pageSize < _grades.length
                ? () => setState(() => _page++)
                : null,
          ),
      ],
    );
  }
}

class _GradeCard extends StatelessWidget {
  final SalaryGrade grade;
  final bool canEdit;
  final VoidCallback onEdit, onDelete;

  const _GradeCard({
    required this.grade,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final g = grade;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        g.code,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (g.payType == PayType.hourly ? AppTheme.warning : AppTheme.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          g.payType == PayType.hourly ? 'Giờ' : 'Ngày',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: g.payType == PayType.hourly ? AppTheme.warning : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(g.name, style: const TextStyle(fontSize: 13)),
                  Text(
                    g.departmentName ?? 'Toàn công ty',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_currFmt.format(g.baseRate)}đ / ${g.payType == PayType.hourly ? "giờ" : "ngày"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (canEdit) ...[
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppTheme.textSecondary,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppTheme.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SalaryGradeDialog extends StatefulWidget {
  final SalaryGrade? existing;
  final SalaryGradeRepository repo;

  const _SalaryGradeDialog({
    required this.repo,
    this.existing,
  });

  @override
  State<_SalaryGradeDialog> createState() => _SalaryGradeDialogState();
}

class _SalaryGradeDialogState extends State<_SalaryGradeDialog> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  String _payType = 'DAILY';
  bool _saving = false;
  String? _error;

  List<DepartmentFlat> _depts = [];
  int? _deptId;

  @override
  void initState() {
    super.initState();
    _loadDepts();
    final e = widget.existing;
    if (e != null) {
      _codeCtrl.text = e.code;
      _nameCtrl.text = e.name;
      _rateCtrl.text = e.baseRate.toStringAsFixed(0);
      _payType = e.payType == PayType.hourly ? 'HOURLY' : 'DAILY';
      _deptId = e.departmentId;
    }
  }

  Future<void> _loadDepts() async {
    try {
      final depts = await DepartmentService.instance.getFlat();
      if (mounted) setState(() => _depts = depts);
    } catch (_) {}
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_codeCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
      setState(() => _error = 'Vui lòng điền đầy đủ thông tin');
      return;
    }
    final rate = double.tryParse(_rateCtrl.text.replaceAll(',', ''));
    if (rate == null || rate <= 0) {
      setState(() => _error = 'Đơn giá không hợp lệ');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      SalaryGrade result;
      if (widget.existing == null) {
        result = await widget.repo.create(
          departmentId: _deptId,
          code: _codeCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          payType: _payType,
          baseRate: rate,
        );
      } else {
        result = await widget.repo.update(
          widget.existing!.id,
          name: _nameCtrl.text.trim(),
          payType: _payType,
          baseRate: rate,
        );
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = serverMsg(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? s.salaryGradeEdit : s.salaryGradeAdd),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            if (!isEdit) ...[
              DepartmentPickerField(
                departments: _depts,
                value: _deptId,
                label: s.department,
                allowAll: true,
                allLabel: 'Toàn công ty',
                compact: true,
                onChanged: (v) => setState(() => _deptId = v),
              ),
              const SizedBox(height: 12),
            ],
            if (!isEdit)
              TextFormField(
                controller: _codeCtrl,
                decoration: InputDecoration(labelText: s.salaryGradeCode),
              ),
            if (!isEdit) const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: s.salaryGradeName),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.payTypeDaily, style: const TextStyle(fontSize: 13)),
                    value: 'DAILY',
                    groupValue: _payType,
                    onChanged: (v) => setState(() => _payType = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.payTypeHourly, style: const TextStyle(fontSize: 13)),
                    value: 'HOURLY',
                    groupValue: _payType,
                    onChanged: (v) => setState(() => _payType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _rateCtrl,
              decoration: InputDecoration(
                labelText: s.baseRate,
                suffixText: 'đ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(s.save),
        ),
      ],
    );
  }
}
