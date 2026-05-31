import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/all_variable.dart';
import '../../../data/models/formula_variable.dart';
import '../../../data/repositories/formula_variable_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/pagination_bar.dart';
import 'custom_var_dialog.dart';
import 'package:bosskin/l10n/app_localizations.dart';

class VariablesTab extends StatefulWidget {
  const VariablesTab({super.key});

  @override
  State<VariablesTab> createState() => _VariablesTabState();
}

class _VariablesTabState extends State<VariablesTab> {
  final _repo = FormulaVariableRepository();

  bool _loading = true;
  String? _error;
  List<AllVariable> _vars = [];
  String _search = '';
  bool _canEdit = false;
  int _page = 0;
  int _pageSize = 20;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _canEdit = AuthService.instance.currentUser?.can('PAYROLL_CREATE') ?? false;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final vars = await _repo.getAllVariables();
      if (mounted) setState(() => _vars = vars);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AllVariable> get _filtered {
    var list = _vars;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((v) =>
          v.name.toLowerCase().contains(q) ||
          v.label.toLowerCase().contains(q) ||
          (v.expression?.toLowerCase().contains(q) ?? false) ||
          v.scopeLabel.toLowerCase().contains(q) ||
          (v.category?.toLowerCase().contains(q) ?? false)).toList();
    }
    if (_categoryFilter != null) {
      list = list.where((v) => v.category == _categoryFilter).toList();
    }
    // Sort: nhóm (global với category trước, không category sau, system/private cuối) → scope → tên
    list = [...list]..sort((a, b) {
      final aGroup = a.scope == VariableScope.global ? (a.category?.isNotEmpty == true ? 0 : 1) : 2;
      final bGroup = b.scope == VariableScope.global ? (b.category?.isNotEmpty == true ? 0 : 1) : 2;
      if (aGroup != bGroup) return aGroup.compareTo(bGroup);
      final aCat = a.category ?? '';
      final bCat = b.category ?? '';
      if (aCat != bCat) return aCat.compareTo(bCat);
      final aScope = a.scope.index;
      final bScope = b.scope.index;
      if (aScope != bScope) return aScope.compareTo(bScope);
      return a.name.compareTo(b.name);
    });
    return list;
  }

  List<String> get _categories => _vars
      .where((v) => v.scope == VariableScope.global && (v.category?.isNotEmpty ?? false))
      .map((v) => v.category!)
      .toSet()
      .toList()..sort();

  List<AllVariable> get _paged {
    final list = _filtered;
    final start = _page * _pageSize;
    if (start >= list.length) return [];
    final end = (start + _pageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  void _openAdd() async {
    final result = await showDialog<FormulaVariable>(
      context: context,
      builder: (_) => CustomVarDialog(repo: _repo),
    );
    if (result != null) _load();
  }

  void _openEdit(AllVariable v) async {
    final existing = FormulaVariable(
      id: v.id!,
      name: v.name,
      label: v.label,
      expression: v.expression ?? '',
      category: v.category,
    );
    final result = await showDialog<FormulaVariable>(
      context: context,
      builder: (_) => CustomVarDialog(repo: _repo, existing: existing),
    );
    if (result != null) _load();
  }

  Future<void> _toggleShow(AllVariable v) async {
    try {
      await _repo.toggleShowInFormula(v.id!, !v.showInFormula);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _delete(AllVariable v) async {
    final s = AppLocalizations.of(context)!;
    if (!mounted) return;

    // Check usages trước khi xoá
    List<VariableUsage> usages = [];
    try {
      usages = await _repo.getUsages(v.id!);
    } catch (_) {}
    if (!mounted) return;

    if (usages.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Không thể xoá'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Biến "${v.name}" đang được dùng trong ${usages.length} công thức:'),
              const SizedBox(height: 8),
              ...usages.map((u) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_right, size: 16, color: AppTheme.textSecondary),
                    Expanded(child: Text('${u.formulaLabel} (${u.effectiveDate})',
                        style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              const Text('Vui lòng xoá biến này khỏi các công thức trước.',
                  style: TextStyle(fontSize: 13, color: AppTheme.error)),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('Xoá biến "${v.name}"?'),
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
    if (!mounted) return;
    if (v.id == null) return;
    try {
      await _repo.delete(v.id!);
      if (!mounted) return;
      setState(() {
        if (_categoryFilter != null && _categoryFilter == v.category) _categoryFilter = null;
        _page = 0;
      });
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final filtered = _filtered;
    final paged = _paged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final searchField = TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm tên, mô tả, biểu thức...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onChanged: (v) => setState(() { _search = v; _page = 0; }),
            );
            final categoryDropdown = _categories.isEmpty
                ? null
                : DropdownButtonFormField<String?>(
                    value: _categoryFilter,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Nhóm',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tất cả')),
                      ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setState(() { _categoryFilter = v; _page = 0; }),
                  );
            final addButton = _canEdit
                ? FilledButton.icon(
                    onPressed: _openAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Thêm biến Global'),
                  )
                : null;

            if (isMobile) {
              return Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                color: AppTheme.background,
                child: Column(
                  children: [
                    searchField,
                    if (categoryDropdown != null || addButton != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (categoryDropdown != null)
                            Expanded(child: categoryDropdown),
                          if (categoryDropdown != null && addButton != null)
                            const SizedBox(width: 8),
                          if (addButton != null)
                            addButton,
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: AppTheme.background,
              child: Row(
                children: [
                  Expanded(child: searchField),
                  if (categoryDropdown != null) ...[
                    const SizedBox(width: 8),
                    SizedBox(width: 160, child: categoryDropdown),
                    const SizedBox(width: 12),
                  ],
                  if (addButton != null) ...[
                    const SizedBox(width: 12),
                    addButton,
                  ],
                ],
              ),
            );
          },
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        return Column(
                          children: [
                            if (!isMobile)
                              Container(
                                color: AppTheme.border.withValues(alpha: 0.3),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: const Row(
                                  children: [
                                    Expanded(flex: 2, child: Text('Tên biến',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                                    Expanded(flex: 3, child: Text('Mô tả',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                                    Expanded(flex: 3, child: Text('Biểu thức',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                                    Expanded(flex: 2, child: Text('Nhóm',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                                    Expanded(flex: 2, child: Text('Scope',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                                    SizedBox(width: 96, child: Text('Actions',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _load,
                                child: isMobile
                                    ? ListView.separated(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        itemCount: paged.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                                        itemBuilder: (_, i) => _VariableCard(
                                          variable: paged[i],
                                          canEdit: _canEdit,
                                          onEdit: () => _openEdit(paged[i]),
                                          onDelete: () => _delete(paged[i]),
                                          onToggleShow: () => _toggleShow(paged[i]),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: EdgeInsets.zero,
                                        itemCount: paged.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (_, i) {
                                          final v = paged[i];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            child: Row(
                                              children: [
                                                Expanded(flex: 2, child: Text(v.name,
                                                    style: const TextStyle(fontFamily: 'monospace',
                                                        fontWeight: FontWeight.w600, fontSize: 13))),
                                                Expanded(flex: 3, child: Text(v.label,
                                                    style: const TextStyle(fontSize: 13),
                                                    overflow: TextOverflow.ellipsis)),
                                                Expanded(flex: 3, child: Text(
                                                  v.expression ?? '—',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontFamily: v.expression != null ? 'monospace' : null,
                                                    color: v.expression != null
                                                        ? AppTheme.textPrimary
                                                        : AppTheme.textSecondary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                )),
                                                Expanded(flex: 2, child: Text(
                                                  v.scope == VariableScope.global ? (v.category ?? '—') : '—',
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                                  overflow: TextOverflow.ellipsis,
                                                )),
                                                Expanded(flex: 2, child: _ScopeChip(v.scope, v.scopeLabel)),
                                                SizedBox(
                                                  width: 96,
                                                  child: v.scope == VariableScope.global && _canEdit
                                                      ? Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Tooltip(
                                                              message: v.showInFormula ? 'Ẩn khỏi công thức' : 'Hiện trong công thức',
                                                              child: IconButton(
                                                                icon: Icon(
                                                                  v.showInFormula ? Icons.visibility : Icons.visibility_off_outlined,
                                                                  size: 16,
                                                                ),
                                                                color: v.showInFormula ? AppTheme.primary : AppTheme.textSecondary,
                                                                onPressed: () => _toggleShow(v),
                                                                visualDensity: VisualDensity.compact,
                                                                padding: EdgeInsets.zero,
                                                              ),
                                                            ),
                                                            Tooltip(
                                                              message: 'Sửa',
                                                              child: IconButton(
                                                                icon: const Icon(Icons.edit_outlined, size: 16),
                                                                color: AppTheme.textSecondary,
                                                                onPressed: () => _openEdit(v),
                                                                visualDensity: VisualDensity.compact,
                                                                padding: EdgeInsets.zero,
                                                              ),
                                                            ),
                                                            Tooltip(
                                                              message: 'Xoá',
                                                              child: IconButton(
                                                                icon: const Icon(Icons.delete_outline, size: 16),
                                                                color: AppTheme.error,
                                                                onPressed: () => _delete(v),
                                                                visualDensity: VisualDensity.compact,
                                                                padding: EdgeInsets.zero,
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      : const Text('—',
                                                          style: TextStyle(color: AppTheme.textSecondary)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ),
                            PaginationBar(
                              total: filtered.length,
                              page: _page,
                              pageSize: _pageSize,
                              onPageSizeChanged: (v) => setState(() { _pageSize = v; _page = 0; }),
                              onPrev: _page > 0 ? () => setState(() => _page--) : null,
                              onNext: (_page + 1) * _pageSize < filtered.length
                                  ? () => setState(() => _page++)
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _VariableCard extends StatelessWidget {
  final AllVariable variable;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleShow;

  const _VariableCard({
    required this.variable,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleShow,
  });

  @override
  Widget build(BuildContext context) {
    final v = variable;
    final isGlobalEditable = v.scope == VariableScope.global && canEdit;
    final (scopeColor, scopeIcon) = switch (v.scope) {
      VariableScope.system  => (AppTheme.textSecondary, Icons.lock_outline),
      VariableScope.global  => (AppTheme.warning, Icons.public),
      VariableScope.private => (AppTheme.secondary, Icons.lock_person_outlined),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên biến + scope chip
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          v.name,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(scopeIcon, size: 13, color: scopeColor),
                      const SizedBox(width: 3),
                      Text(
                        v.scopeLabel,
                        style: TextStyle(fontSize: 11, color: scopeColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Mô tả
                  Text(
                    v.label,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (v.expression != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.border.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        v.expression!,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (v.scope == VariableScope.global && (v.category?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 4),
                    Text(
                      v.category!,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            // Actions column
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isGlobalEditable)
                  Switch(
                    value: v.showInFormula,
                    onChanged: (_) => onToggleShow(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (isGlobalEditable)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppTheme.textSecondary,
                        onPressed: onEdit,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: AppTheme.error,
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final VariableScope scope;
  final String label;
  const _ScopeChip(this.scope, this.label);

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (scope) {
      VariableScope.system  => (AppTheme.textSecondary, Icons.lock_outline),
      VariableScope.global  => (AppTheme.warning, Icons.public),
      VariableScope.private => (AppTheme.secondary, Icons.lock_person_outlined),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
