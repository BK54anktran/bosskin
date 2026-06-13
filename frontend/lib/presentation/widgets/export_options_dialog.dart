import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/department_model.dart';
import '../../data/repositories/universal_excel_repository.dart';
import 'department_picker_field.dart';

final _excelRepo = UniversalExcelRepository();

/// Dialog chọn cột + bộ lọc trước khi export.
///
/// Trả về [ExportOptions] khi user nhấn Xuất, null nếu Cancel.
class ExportOptionsDialog extends StatefulWidget {
  final Map<String, ExportMeta> meta;
  final List<String> selectedTypes;

  const ExportOptionsDialog({
    super.key,
    required this.meta,
    required this.selectedTypes,
  });

  @override
  State<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // moduleType → set of selected column keys (null = default visible)
  final Map<String, Set<String>> _selectedColumns = {};
  // moduleType → filter key → value
  final Map<String, Map<String, String>> _filters = {};
  // moduleType → selected department ids (for picker UI only)
  final Map<String, Set<int>> _deptIds = {};

  late final List<String> _types;

  @override
  void initState() {
    super.initState();
    _types = widget.selectedTypes.isEmpty
        ? widget.meta.keys.toList()
        : widget.selectedTypes.where((t) => widget.meta.containsKey(t)).toList();

    for (final type in _types) {
      final meta = widget.meta[type]!;
      _selectedColumns[type] = meta.columns
          .where((c) => c.defaultVisible)
          .map((c) => c.key)
          .toSet();
      _filters[type] = {};
      _deptIds[type] = {};
    }

    _tabs = TabController(length: _types.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.pop(context, ExportOptions(
      types: _types,
      selectedColumns: Map.fromEntries(_types.map((t) =>
          MapEntry(t, _selectedColumns[t]!.toList()))),
      filters: Map.fromEntries(_types.map((t) =>
          MapEntry(t, Map<String, String>.from(_filters[t]!)))),
    ));
  }

  void _onDeptChanged(String type, Set<int> ids) {
    final departments = widget.meta[type]?.departments ?? [];
    setState(() {
      _deptIds[type] = ids;
      if (ids.isEmpty) {
        _filters[type]!.remove('departmentCodes');
      } else {
        final codes = departments
            .where((d) => ids.contains(d.id))
            .map((d) => d.code)
            .join(',');
        _filters[type]!['departmentCodes'] = codes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 720,
        height: 560,
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(children: [
              const Icon(Icons.tune_outlined, color: AppTheme.primary),
              const SizedBox(width: 10),
              const Text('Tùy chọn xuất',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // ── Tabs ────────────────────────────────────────────────────────────
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            tabs: _types.map((t) => Tab(text: _typeLabel(t))).toList(),
          ),
          const Divider(height: 1),
          // ── Tab content ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: _types.map((type) {
                final meta = widget.meta[type]!;
                return _ModuleOptionsTab(
                  module: type,
                  meta: meta,
                  selectedColumns: _selectedColumns[type]!,
                  filters: _filters[type]!,
                  selectedDeptIds: _deptIds[type]!,
                  departments: meta.departments,
                  onColumnToggle: (key, on) => setState(() =>
                      on ? _selectedColumns[type]!.add(key)
                         : _selectedColumns[type]!.remove(key)),
                  onSelectAll: () => setState(() =>
                      _selectedColumns[type] = meta.columns.map((c) => c.key).toSet()),
                  onSelectDefault: () => setState(() =>
                      _selectedColumns[type] = meta.columns
                          .where((c) => c.defaultVisible)
                          .map((c) => c.key)
                          .toSet()),
                  onFilterChanged: (key, value) => setState(() {
                    if (value == null || value.isEmpty) {
                      _filters[type]!.remove(key);
                    } else {
                      _filters[type]![key] = value;
                    }
                  }),
                  onDeptChanged: (ids) => _onDeptChanged(type, ids),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // ── Actions ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: _types.map((t) => Text(
                    '${_selectedColumns[t]!.length} cột ${_typeLabel(t)}  ·',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  )).toList(),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Xuất'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _typeLabel(String type) => switch (type) {
        'employee'       => 'Nhân viên',
        'department'     => 'Phòng ban',
        'position'       => 'Chức vụ',
        'shift'          => 'Ca làm việc',
        'attendance'     => 'Chấm công',
        'payroll'        => 'Bảng lương',
        'salary_grade'     => 'Bậc lương',
        'salary_formula'   => 'Công thức lương',
        'formula_variable' => 'Biến công thức',
        _                  => type,
      };
}

// ── Per-module tab ────────────────────────────────────────────────────────────

class _ModuleOptionsTab extends StatelessWidget {
  final String module;
  final ExportMeta meta;
  final Set<String> selectedColumns;
  final Map<String, String> filters;
  final Set<int> selectedDeptIds;
  final List<ExcelDeptItem> departments;
  final void Function(String key, bool on) onColumnToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectDefault;
  final void Function(String key, String? value) onFilterChanged;
  final void Function(Set<int> ids) onDeptChanged;

  const _ModuleOptionsTab({
    required this.module,
    required this.meta,
    required this.selectedColumns,
    required this.filters,
    required this.selectedDeptIds,
    required this.departments,
    required this.onColumnToggle,
    required this.onSelectAll,
    required this.onSelectDefault,
    required this.onFilterChanged,
    required this.onDeptChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // ── Column selection (left 60%) ────────────────────────────────────────
      Expanded(
        flex: 6,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              const Text('Chọn cột xuất',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text('(${selectedColumns.length}/${meta.columns.length})',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const Spacer(),
              TextButton(onPressed: onSelectDefault, child: const Text('Mặc định', style: TextStyle(fontSize: 11))),
              TextButton(onPressed: onSelectAll, child: const Text('Tất cả', style: TextStyle(fontSize: 11))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: _ColumnList(
            columns: meta.columns,
            selected: selectedColumns,
            onToggle: onColumnToggle,
          )),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: Text('(*) Bắt buộc để import lại được',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ),
        ]),
      ),
      const VerticalDivider(width: 1),
      // ── Filters (right 40%) ────────────────────────────────────────────────
      Expanded(
        flex: 4,
        child: meta.filters.isEmpty
            ? const Center(
                child: Text('Không có bộ lọc',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Text('Bộ lọc',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: meta.filters.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: f.key == 'departmentCode' || f.key == 'departmentCodes'
                          ? _DeptFilterField(
                              departments: departments,
                              selectedIds: selectedDeptIds,
                              onChanged: onDeptChanged,
                            )
                          : _FilterField(
                              module: module,
                              filter: f,
                              value: filters[f.key],
                              valueFrom: filters['${f.key}From'],
                              valueTo:   filters['${f.key}To'],
                              onChange: onFilterChanged,
                            ),
                    )).toList(),
                  ),
                ),
              ]),
      ),
    ]);
  }
}

// ── Column list ───────────────────────────────────────────────────────────────

class _ColumnList extends StatelessWidget {
  final List<ExcelColumnMeta> columns;
  final Set<String> selected;
  final void Function(String, bool) onToggle;

  const _ColumnList({
    required this.columns,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String?, List<ExcelColumnMeta>>{};
    for (final col in columns) {
      grouped.putIfAbsent(col.group, () => []).add(col);
    }

    final widgets = <Widget>[];
    grouped.forEach((group, cols) {
      if (group != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Text(_groupLabel(group),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary)),
        ));
      }
      for (final col in cols) {
        final isOn = selected.contains(col.key);
        widgets.add(InkWell(
          onTap: () => onToggle(col.key, !isOn),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              SizedBox(
                width: 20, height: 20,
                child: Checkbox(
                  value: isOn,
                  onChanged: (v) => onToggle(col.key, v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(col.label, style: const TextStyle(fontSize: 12)),
              ),
              if (!col.importable)
                const Tooltip(
                  message: 'Chỉ export, không import',
                  child: Icon(Icons.visibility_outlined, size: 12, color: AppTheme.textSecondary),
                ),
            ]),
          ),
        ));
      }
    });

    return ListView(padding: EdgeInsets.zero, children: widgets);
  }

  static String _groupLabel(String group) => switch (group) {
        'basic'          => 'Thông tin cơ bản',
        'contract'       => 'Hợp đồng & Lương',
        'personal'       => 'Thông tin cá nhân',
        'computed'       => 'Dữ liệu tổng hợp',
        'override'       => 'Ghi đè thủ công',
        'identification' => 'Định danh',
        'earnings'       => 'Thu nhập',
        'deductions'     => 'Khấu trừ & Net',
        'period'         => 'Kỳ lương & Giờ công',
        _                => group,
      };
}

// ── Department multi-picker filter ────────────────────────────────────────────

class _DeptFilterField extends StatelessWidget {
  final List<ExcelDeptItem> departments;
  final Set<int> selectedIds;
  final void Function(Set<int>) onChanged;

  const _DeptFilterField({
    required this.departments,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final flat = departments.map((d) => DepartmentFlat(
      id: d.id,
      name: d.name,
      code: d.code,
      parentId: d.parentId,
      level: d.level,
      employeeCount: 0,
    )).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Phòng ban',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      DepartmentMultiPickerField(
        departments: flat,
        values: selectedIds,
        onChanged: onChanged,
        label: '',
      ),
    ]);
  }
}

// ── Generic filter field ──────────────────────────────────────────────────────

class _FilterField extends StatelessWidget {
  final String module;
  final ExcelFilterDef filter;
  final String? value;
  final String? valueFrom;
  final String? valueTo;
  final void Function(String key, String? value) onChange;

  const _FilterField({
    required this.module,
    required this.filter,
    required this.onChange,
    this.value,
    this.valueFrom,
    this.valueTo,
  });

  String _label() => _knownLabels[filter.labelKey] ?? filter.labelKey;

  static const _knownLabels = {
    'filter.search':               'Tìm kiếm',
    'filter.department':           'Phòng ban',
    'filter.department.parent':    'Phòng ban cha',
    'filter.status':               'Trạng thái',
    'filter.salaryGrade':          'Bậc lương',
    'filter.joinDate':             'Ngày vào làm',
    'filter.year':                 'Năm',
    'filter.month':                'Tháng',
    'filter.shift.group':          'Nhóm ca',
    'filter.status.all':           'Tất cả',
    'filter.status.active':        'Đang làm',
    'filter.status.inactive':      'Đã nghỉ',
    'filter.attendance.present':   'Có mặt',
    'filter.attendance.absent':    'Vắng mặt',
    'filter.attendance.late':      'Đi trễ',
    'filter.attendance.halfDay':   'Nửa ngày',
    'filter.attendance.leave':     'Nghỉ phép',
    'filter.payroll.draft':        'Nháp',
    'filter.payroll.approved':     'Đã duyệt',
    'filter.payroll.paid':         'Đã trả',
    'filter.grade':                'Bậc lương',
    'filter.grade.payType':        'Loại tính lương',
    'filter.grade.payType.daily':  'Theo ngày',
    'filter.grade.payType.hourly': 'Theo giờ',
    'filter.variable.category':    'Nhóm biến',
  };

  static String _optLabel(FilterOption opt) =>
      _knownLabels[opt.labelKey] ?? opt.labelKey;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (filter.type != 'TEXT') ...[
        Text(_label(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
      ],
      if (filter.type == 'TEXT')
        _MultiPickField(
          module: module,
          filterKey: filter.key,
          selectedCodes: value == null || value!.isEmpty
              ? const []
              : value!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          onChange: (codes) => onChange(filter.key, codes.isEmpty ? null : codes.join(',')),
        )
      else if (filter.type == 'SELECT' || filter.type == 'MULTI_SELECT')
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('— Tất cả —',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
            ...filter.options.map((o) => DropdownMenuItem(
              value: o.value,
              child: Text(_optLabel(o), style: const TextStyle(fontSize: 12)),
            )),
          ],
          onChanged: (v) => onChange(filter.key, v),
        )
      else if (filter.type == 'DATE_RANGE')
        Row(children: [
          Expanded(child: _DateInput(
            hint: 'Từ ngày',
            value: valueFrom,
            onChange: (v) => onChange('${filter.key}From', v),
          )),
          const SizedBox(width: 6),
          Expanded(child: _DateInput(
            hint: 'Đến ngày',
            value: valueTo,
            onChange: (v) => onChange('${filter.key}To', v),
          )),
        ])
      else
        TextFormField(
          initialValue: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: (v) => onChange(filter.key, v.isEmpty ? null : v),
        ),
    ]);
  }
}

// ── Multi-pick field (autocomplete + chips) ───────────────────────────────────

class _MultiPickField extends StatefulWidget {
  final String module;
  final String filterKey;
  final List<String> selectedCodes;
  final void Function(List<String> codes) onChange;

  const _MultiPickField({
    required this.module,
    required this.filterKey,
    required this.selectedCodes,
    required this.onChange,
  });

  @override
  State<_MultiPickField> createState() => _MultiPickFieldState();
}

class _MultiPickFieldState extends State<_MultiPickField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<ExcelPickItem> _suggestions = [];
  late List<String> _selected; // codes đang chọn
  // label cache: code → label
  final Map<String, String> _labelCache = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedCodes);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final items = await _excelRepo.searchForPick(widget.module, q.trim());
      if (mounted) {
        for (final i in items) { _labelCache[i.code] = i.label; }
        setState(() { _suggestions = items; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _suggestions = []; _loading = false; });
    }
  }

  void _pick(ExcelPickItem item) {
    if (_selected.contains(item.code)) return;
    _labelCache[item.code] = item.label;
    setState(() {
      _selected = [..._selected, item.code];
      _suggestions = [];
      _ctrl.clear();
    });
    widget.onChange(_selected);
    _focus.requestFocus();
  }

  void _remove(String code) {
    setState(() => _selected = _selected.where((c) => c != code).toList());
    widget.onChange(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Chips ──
      if (_selected.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _selected.map((code) {
              final label = _labelCache[code] ?? code;
              return Chip(
                label: Text(label, style: const TextStyle(fontSize: 11)),
                deleteIcon: const Icon(Icons.close, size: 12),
                onDeleted: () => _remove(code),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
      // ── Search input ──
      TextField(
        controller: _ctrl,
        focusNode: _focus,
        decoration: InputDecoration(
          hintText: 'Tìm tên hoặc mã...',
          hintStyle: const TextStyle(fontSize: 11),
          border: const OutlineInputBorder(),
          contentPadding: EdgeInsets.zero,
          prefixIcon: const Icon(Icons.search_outlined, size: 16),
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _suggestions = []);
                      },
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
        ),
        onChanged: _search,
      ),
      // ── Dropdown gợi ý ──
      if (_suggestions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6, offset: const Offset(0, 2))],
          ),
          constraints: const BoxConstraints(maxHeight: 160),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: _suggestions.map((item) {
              final picked = _selected.contains(item.code);
              return InkWell(
                onTap: picked ? null : () => _pick(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(item.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: picked ? AppTheme.textSecondary : AppTheme.textPrimary,
                          )),
                    ),
                    if (picked)
                      const Icon(Icons.check, size: 14, color: AppTheme.primary),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
    ]);
  }
}

class _DateInput extends StatefulWidget {
  final String hint;
  final String? value;
  final void Function(String?) onChange;
  const _DateInput({required this.hint, this.value, required this.onChange});

  @override
  State<_DateInput> createState() => _DateInputState();
}

class _DateInputState extends State<_DateInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_ctrl.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final iso = picked.toIso8601String().substring(0, 10);
      _ctrl.text = iso;
      widget.onChange(iso);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      readOnly: true,
      onTap: _pick,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(fontSize: 11),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        suffixIcon: _ctrl.text.isEmpty
            ? const Icon(Icons.calendar_today_outlined, size: 14)
            : IconButton(
                icon: const Icon(Icons.clear, size: 14),
                onPressed: () { _ctrl.clear(); widget.onChange(null); },
              ),
      ),
    );
  }
}

// ── Result model ──────────────────────────────────────────────────────────────

class ExportOptions {
  final List<String> types;
  final Map<String, List<String>> selectedColumns;
  final Map<String, Map<String, String>> filters;

  const ExportOptions({
    required this.types,
    required this.selectedColumns,
    required this.filters,
  });
}
