import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/job_history.dart';
import '../../../data/repositories/job_history_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_text_field.dart';
import '../../widgets/status_badge.dart';

/// Bước K — sơ đồ tổ chức: theo người (cây quản lý trực tiếp) hoặc theo phòng ban.
class OrgChartScreen extends StatefulWidget {
  const OrgChartScreen({super.key});

  @override
  State<OrgChartScreen> createState() => _OrgChartScreenState();
}

class _OrgChartScreenState extends State<OrgChartScreen> {
  final _repo = JobHistoryRepository();
  final _searchCtrl = TextEditingController();
  List<OrgNode> _nodes = [];
  bool _loading = true;
  String? _error;
  bool _byDepartment = false;
  final Set<int> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final nodes = await _repo.orgChart();
      if (mounted) setState(() { _nodes = nodes; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = serverMsg(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final query = _searchCtrl.text.trim().toLowerCase();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(s.orgChartByPerson), icon: const Icon(Icons.lan_outlined)),
                  ButtonSegment(value: true, label: Text(s.orgChartByDepartment),
                      icon: const Icon(Icons.account_tree_outlined)),
                ],
                selected: {_byDepartment},
                onSelectionChanged: (v) => setState(() => _byDepartment = v.first),
              ),
              SizedBox(
                width: 260,
                child: SearchTextField(
                  controller: _searchCtrl,
                  hint: s.orgChartSearch,
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(() {}),
                ),
              ),
              IconButton(tooltip: s.refresh, onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(child: _body(s, query)),
      ],
    );
  }

  Widget _body(AppLocalizations s, String query) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)));
    }
    if (_nodes.isEmpty) return EmptyState(icon: Icons.lan_outlined, message: s.noResults);
    if (query.isNotEmpty) return _searchResults(s, query);
    return _byDepartment ? _departmentView(s) : _personView(s);
  }

  Map<int, OrgNode> get _byId => {for (final n in _nodes) n.id: n};

  Widget _searchResults(AppLocalizations s, String query) {
    final byId = _byId;
    final hits = _nodes
        .where((n) => n.fullName.toLowerCase().contains(query) || n.employeeCode.toLowerCase().contains(query))
        .toList();
    if (hits.isEmpty) return EmptyState(icon: Icons.search_off, message: s.noResults);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: hits.map((n) => _PersonTile(node: n, manager: byId[n.managerId], showManager: true)).toList(),
    );
  }

  /// Cây theo quản lý trực tiếp. Gốc = người không có quản lý (hoặc quản lý ngoài phạm vi xem).
  Widget _personView(AppLocalizations s) {
    final byId = _byId;
    final children = <int, List<OrgNode>>{};
    final roots = <OrgNode>[];
    for (final n in _nodes) {
      if (n.managerId != null && byId.containsKey(n.managerId)) {
        children.putIfAbsent(n.managerId!, () => []).add(n);
      } else {
        roots.add(n);
      }
    }
    // Người có cấp dưới lên trước
    roots.sort((a, b) {
      final ca = children[a.id]?.length ?? 0;
      final cb = children[b.id]?.length ?? 0;
      return ca != cb ? cb.compareTo(ca) : a.fullName.compareTo(b.fullName);
    });
    final rows = <Widget>[];
    void add(OrgNode n, int depth) {
      final kids = children[n.id] ?? const [];
      final collapsed = _collapsed.contains(n.id);
      rows.add(Padding(
        padding: EdgeInsets.only(left: depth * 24.0),
        child: _PersonTile(
          node: n,
          reportCount: kids.length,
          expanded: kids.isEmpty ? null : !collapsed,
          onToggle: kids.isEmpty
              ? null
              : () => setState(() => collapsed ? _collapsed.remove(n.id) : _collapsed.add(n.id)),
        ),
      ));
      if (!collapsed) {
        for (final k in kids) {
          add(k, depth + 1);
        }
      }
    }

    for (final r in roots) {
      add(r, 0);
    }
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: rows);
  }

  Widget _departmentView(AppLocalizations s) {
    final byId = _byId;
    final groups = <String, List<OrgNode>>{};
    for (final n in _nodes) {
      groups.putIfAbsent(n.departmentName, () => []).add(n);
    }
    final names = groups.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: names.map((name) {
        final people = groups[name]!
          ..sort((a, b) => a.departmentHead != b.departmentHead
              ? (a.departmentHead ? -1 : 1)
              : a.fullName.compareTo(b.fullName));
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.account_tree_outlined, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  Text(s.orgChartPeopleCount(people.length),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ]),
                const Divider(),
                ...people.map((n) => _PersonTile(node: n, manager: byId[n.managerId], showManager: true)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final OrgNode node;
  final OrgNode? manager;
  final bool showManager;
  final int reportCount;
  final bool? expanded;
  final VoidCallback? onToggle;

  const _PersonTile({
    required this.node,
    this.manager,
    this.showManager = false,
    this.reportCount = 0,
    this.expanded,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final subtitle = [
      if (node.positionName != null && node.positionName!.isNotEmpty) node.positionName!,
      node.departmentName,
      if (showManager && manager != null) s.orgChartManagerOf(manager!.fullName),
      if (reportCount > 0) s.orgChartReports(reportCount),
    ].join(' · ');
    final tile = ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        radius: 16,
        backgroundImage: node.avatar != null && node.avatar!.isNotEmpty ? NetworkImage(node.avatar!) : null,
        child: node.avatar == null || node.avatar!.isEmpty
            ? Text(node.fullName.isNotEmpty ? node.fullName[0].toUpperCase() : '?')
            : null,
      ),
      title: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(node.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(node.employeeCode, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        if (node.departmentHead) StatusBadge(label: s.orgChartDepartmentHead, color: AppTheme.primary, fontSize: 10),
      ]),
      subtitle: Text(subtitle),
      trailing: expanded == null ? null : Icon(expanded! ? Icons.expand_less : Icons.expand_more),
      onTap: onToggle,
    );
    return onToggle == null ? tile : MouseRegion(cursor: SystemMouseCursors.click, child: tile);
  }
}
