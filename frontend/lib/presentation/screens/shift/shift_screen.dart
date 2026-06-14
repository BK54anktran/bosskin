import 'dart:typed_data';
import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/utils/file_saver_utils.dart';
import '../../../core/utils/file_picker_excel_utils.dart';
import '../../../data/models/work_shift.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/department_service.dart';
import '../../../data/models/department_model.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/import_preview_dialog.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/search_text_field.dart';
import 'shift_assign_tab.dart';
import 'shift_form_dialog.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _assignTabKey = const ShiftAssignTabKey();
  List<WorkShift> _shifts = [];
  List<DepartmentFlat> _allDepartments = [];
  bool _loading = true;
  String? _error;
  bool _exporting = false;
  bool _importing = false;
  final _searchCtrl = TextEditingController();
  int? _deptFilterId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, animationDuration: Duration.zero);
    _loadShifts();
    _loadDepartments();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final list = await DepartmentService.instance.getFlat();
      if (mounted) {
        setState(() => _allDepartments = list);
      }
    } catch (_) {}
  }

  List<WorkShift> get _filteredShifts {
    final q = foldSearchText(_searchCtrl.text);
    final deptScopeIds = _expandedDepartmentScopeIds(_deptFilterId);
    return _shifts.where((s) {
      final byDept = _deptFilterId == null ||
          s.departments.any((d) => deptScopeIds.contains(d.id));
      if (!byDept) return false;
      if (q.isEmpty) return true;
      return foldSearchText(s.name).contains(q) ||
          foldSearchText(s.code).contains(q) ||
          s.departments.any((d) => foldSearchText(d.name).contains(q));
    }).toList();
  }

  Set<int> _expandedDepartmentScopeIds(int? rootDeptId) {
    if (rootDeptId == null) return <int>{};
    final childrenByParent = <int, List<int>>{};
    for (final d in _allDepartments) {
      final p = d.parentId;
      if (p == null) continue;
      childrenByParent.putIfAbsent(p, () => <int>[]).add(d.id);
    }

    final result = <int>{rootDeptId};
    final queue = <int>[rootDeptId];
    var idx = 0;
    while (idx < queue.length) {
      final cur = queue[idx++];
      for (final child in childrenByParent[cur] ?? const <int>[]) {
        if (result.add(child)) queue.add(child);
      }
    }
    return result;
  }

  Future<void> _loadShifts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.instance.get<List<WorkShift>>(
        '/shifts',
        (data) => (data as List)
            .map((e) => WorkShift.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      if (mounted) {
        setState(() {
          _shifts = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = serverMsg(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final range = _assignTabKey.currentRange;
      final fmt = DateFormat('yyyy-MM-dd');
      final deptScopeIds = _expandedDepartmentScopeIds(_deptFilterId);
      final deptQuery = deptScopeIds.isNotEmpty
          ? '&${deptScopeIds.map((id) => 'departmentIds=$id').join('&')}'
          : '';
      final query = range != null
          ? 'from=${fmt.format(range.start)}&to=${fmt.format(range.end)}$deptQuery'
          : 'year=${DateTime.now().year}&month=${DateTime.now().month}$deptQuery';
      final res = await ApiService.instance.dio.get<List<int>>(
        '/shifts/export?$query',
        options: Options(responseType: ResponseType.bytes),
      );
      final disposition = res.headers.value('content-disposition') ?? '';
      final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
      final filename = match?.group(1) ?? 'danh_sach_ca_lam.xlsx';
      await saveFileToDevice(Uint8List.fromList(res.data!), filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
      );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importAssignments() async {
    final picked = await pickExcelFile();
    if (picked == null) return;
    setState(() => _importing = true);
    try {
      final previewForm = FormData.fromMap({
        'file': MultipartFile.fromBytes(picked.bytes, filename: picked.filename),
      });
      final previewRes = await ApiService.instance.dio.post('/shifts/preview-import-assignments', data: previewForm);
      if (!mounted) return;

      final data = previewRes.data as Map<String, dynamic>;
      final diffs = ((data['diffs'] as List?) ?? const []).map((d) {
        final changes = (d['changes'] as List? ?? []).map((c) => ImportFieldChange(
          field: c['field'] ?? '',
          oldValue: c['oldValue'] ?? '',
          newValue: c['newValue'] ?? '',
        )).toList();
        return ImportDiffRow(
          action: d['action'] ?? 'CREATE',
          code: d['code'] ?? '',
          name: d['name'] ?? '',
          changes: changes,
          warnings: (d['warnings'] as List? ?? []).map((w) => w.toString()).toList(),
        );
      }).toList();
      final sectionLabels = ((data['sectionLabels'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      final sectionCounts = ((data['sectionCounts'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList();

      final confirmed = await showInstantDialog<bool>(
        context,
        (_) => ImportPreviewDialog(
          diffs: diffs,
          sectionLabels: sectionLabels,
          sectionCounts: sectionCounts,
          onConfirm: () async {
            final importForm = FormData.fromMap({
              'file': MultipartFile.fromBytes(picked.bytes, filename: picked.filename),
            });
            await ApiService.instance.dio.post('/shifts/import-assignments', data: importForm);
          },
        ),
      );

      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).importSuccess)),
        );
        _loadShifts();
        _assignTabKey.reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
      );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openForm([WorkShift? shift]) async {
    final groups = _shifts
        .map((s) => s.groupName?.trim())
        .where((g) => g != null && g.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
    final result = await showInstantDialog<bool>(
      context,
      (_) => ShiftFormDialog(shift: shift, existingGroups: groups),
    );
    if (result == true) _loadShifts();
  }

  Future<void> _deleteShift(WorkShift shift) async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        title: Text(s.deleteShiftTitle),
        content: Text(s.deleteShiftPrompt(shift.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(s.delete, style: const TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.delete('/shifts/${shift.id}');
      _loadShifts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isSysAdmin = AuthService.instance.currentUser?.isSystemAdmin ?? false;
    final canView   = isSysAdmin || (AuthService.instance.currentUser?.can('SHIFT_VIEW')   ?? false);
    final canManage = isSysAdmin || (AuthService.instance.currentUser?.can('SHIFT_MANAGE') ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(text: s.shiftAssignmentsTab),
                  Tab(text: s.shiftListTab),
                ],
                onTap: (_) => setState(() {}),
              ),
            ),
            if (_tab.index == 0 && (canView || canManage)) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exporting ? null : _export,
                      icon: _exporting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_outlined, size: 16),
                      label: Text(s.exportExcel),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _importing ? null : _importAssignments,
                        icon: _importing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_outlined, size: 16),
                        label: Text(s.importExcel),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_tab.index == 1 && canManage) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(s.createShift),
                    ),
                  ],
                ),
              ),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: SearchTextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              DepartmentPickerField(
                departments: _allDepartments,
                value: _deptFilterId,
                allowAll: true,
                allLabel: s.all,
                label: s.department,
                compact: true,
                onChanged: (v) => setState(() => _deptFilterId = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab.index,
            sizing: StackFit.expand,
            children: [
              ShiftAssignTab(
                key: _assignTabKey,
                shifts: _shifts,
                canManage: canManage,
                searchQuery: _searchCtrl.text,
                departmentFilterId: _deptFilterId,
                departmentFilterScopeIds:
                    _expandedDepartmentScopeIds(_deptFilterId),
              ),
              _ShiftListTab(
                loading: _loading,
                error: _error,
                shifts: _filteredShifts,
                canManage: canManage,
                onEdit: _openForm,
                onDelete: _deleteShift,
                onRetry: _loadShifts,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShiftListTab extends StatefulWidget {
  final bool loading;
  final String? error;
  final List<WorkShift> shifts;
  final bool canManage;
  final void Function(WorkShift) onEdit;
  final void Function(WorkShift) onDelete;
  final VoidCallback onRetry;

  const _ShiftListTab({
    required this.loading,
    required this.error,
    required this.shifts,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onRetry,
  });

  @override
  State<_ShiftListTab> createState() => _ShiftListTabState();
}

class _ShiftListTabState extends State<_ShiftListTab> {
  int _page = 0;
  int _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (widget.loading) return const Center(child: CircularProgressIndicator());
    if (widget.error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.error!, style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 8),
          TextButton(onPressed: widget.onRetry, child: Text(s.retry)),
        ]),
      );
    }
    if (widget.shifts.isEmpty) {
      return Center(
        child: Text(s.noShiftsYet,
            style: const TextStyle(color: AppTheme.textSecondary)),
      );
    }
    // Group shifts: named groups first (sorted), then ungrouped
    final grouped = <String, List<WorkShift>>{};
    for (final shift in widget.shifts) {
      final key = shift.groupName?.trim().isNotEmpty == true
          ? shift.groupName!.trim()
          : '';
      grouped.putIfAbsent(key, () => []).add(shift);
    }
    final namedKeys = grouped.keys.where((k) => k.isNotEmpty).toList()..sort();
    final allKeys = [...namedKeys, if (grouped.containsKey('')) ''];

    // Build flat list with section headers for pagination
    final items = <Object>[];
    for (final key in allKeys) {
      if (allKeys.length > 1 || key.isNotEmpty) {
        items.add(_GroupHeader(key.isEmpty ? s.shiftGroupUngrouped : key));
      }
      items.addAll(grouped[key]!);
    }
    final paged = items.skip(_page * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            itemCount: paged.length,
            itemBuilder: (_, i) {
              final item = paged[i];
              if (item is _GroupHeader) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                  child: Text(item.label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5)),
                );
              }
              final shift = item as WorkShift;
              return _ShiftCard(
                shift: shift,
                canManage: widget.canManage,
                onEdit: () => widget.onEdit(shift),
                onDelete: () => widget.onDelete(shift),
              );
            },
          ),
        ),
        PaginationBar(
          total: items.length,
          page: _page,
          pageSize: _pageSize,
          onPageSizeChanged: (v) => setState(() { _pageSize = v; _page = 0; }),
          onPrev: _page > 0 ? () => setState(() => _page--) : null,
          onNext: (_page + 1) * _pageSize < items.length ? () => setState(() => _page++) : null,
        ),
      ],
    );
  }
}

class _GroupHeader {
  final String label;
  const _GroupHeader(this.label);
}

class _ShiftCard extends StatelessWidget {
  final WorkShift shift;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShiftCard({
    required this.shift,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final color = _parseColor(shift.color);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              shift.code,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        title: Text(
          shift.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shift.timeLabel,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (shift.workMinutes != null)
              Text(
                '${s.workingHours}: ${shift.workHoursLabel}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            if (shift.departments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children:
                      shift.departments.map((d) => _DeptChip(d.name)).toList(),
                ),
              ),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (canManage) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.textSecondary),
              onPressed: onEdit,
              tooltip: s.edit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppTheme.error),
              onPressed: onDelete,
              tooltip: s.delete,
            ),
          ],
        ]),
        isThreeLine: shift.departments.isNotEmpty,
      ),
    );
  }
}

class _DeptChip extends StatelessWidget {
  final String name;
  const _DeptChip(this.name);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          name,
          style: const TextStyle(fontSize: 10, color: AppTheme.primary),
        ),
      );
}
