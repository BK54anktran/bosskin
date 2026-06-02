import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/file_saver_utils.dart';
import '../../../core/utils/file_picker_excel_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/services/department_service.dart';
import '../../../data/services/position_service.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/location_picker_field.dart';
import '../../widgets/permission_guard.dart';
import '../../widgets/import_preview_dialog.dart';
import '../../../data/services/auth_service.dart';

class DepartmentScreen extends StatefulWidget {
  const DepartmentScreen({super.key});

  @override
  State<DepartmentScreen> createState() => _DepartmentScreenState();
}

class _DepartmentScreenState extends State<DepartmentScreen> {
  List<DepartmentNode> _tree = [];
  List<DepartmentFlat> _flat = [];
  bool _allowRootCreate = true;
  bool _loading = true;
  bool _exporting = false;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _import() async {
    final picked = await pickExcelFile();
    if (picked == null) return;
    setState(() => _importing = true);
    try {
      // Preview song song cả 2 sheet
      final results = await Future.wait([
        DepartmentService.instance.previewImport(picked.bytes, picked.filename),
        DepartmentService.instance.previewImportPositions(picked.bytes, picked.filename),
      ]);
      if (!mounted) return;

      final deptDiffs  = results[0] as List<DepartmentImportDiff>;
      final posDiffs   = results[1] as List<PositionImportDiff>;

      final deptRows = deptDiffs.map((d) => ImportDiffRow(
            action: d.action, code: d.code, name: d.name,
            parentCode: d.parentCode,
            changes: d.changes.map((c) => ImportFieldChange(
                  field: c.field, oldValue: c.oldValue, newValue: c.newValue)).toList(),
            warnings: d.warnings,
            details: _buildDeptDetails(d),
          )).toList();

      final posRows = posDiffs.map((d) => ImportDiffRow(
            action: d.action, code: d.code, name: d.name,
            parentCode: d.departmentCode,
            changes: d.changes.map((c) => ImportFieldChange(
                  field: c.field, oldValue: c.oldValue, newValue: c.newValue)).toList(),
            warnings: d.warnings,
            details: {
              if (d.departmentCode != null && d.departmentCode!.isNotEmpty)
                'Phòng ban': d.departmentCode!,
              if (d.description != null && d.description!.isNotEmpty)
                'Mô tả': d.description!,
            },
          )).toList();

      final confirmed = await showInstantDialog<bool>(
        context,
        (_) => ImportPreviewDialog(
          diffs: [...deptRows, ...posRows],
          sectionLabels: const ['Phòng ban', 'Chức vụ'],
          sectionCounts: [deptRows.length, posRows.length],
          onConfirm: () async {
            await Future.wait([
              DepartmentService.instance.importExcel(picked.bytes, picked.filename),
              DepartmentService.instance.importPositions(picked.bytes, picked.filename),
            ]);
          },
        ),
      );
      if (confirmed == true && mounted) {
        final s = AppLocalizations.of(context);
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.importSuccess)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Map<String, String> _buildDeptDetails(DepartmentImportDiff d) {
    final map = <String, String>{};
    if (d.parentCode != null && d.parentCode!.isNotEmpty) map['PB cha'] = d.parentCode!;
    if (d.description != null && d.description!.isNotEmpty) map['Mô tả'] = d.description!;
    if (d.latitude != null && d.latitude!.isNotEmpty) map['Vĩ độ'] = d.latitude!;
    if (d.longitude != null && d.longitude!.isNotEmpty) map['Kinh độ'] = d.longitude!;
    if (d.radiusMeters != null && d.radiusMeters!.isNotEmpty && d.radiusMeters != '0') {
      map['Bán kính'] = '${d.radiusMeters} m';
    }
    return map;
  }

  Future<void> _export() async {
    final s = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      final result = await DepartmentService.instance.exportExcel();
      await saveFileToDevice(result.bytes, result.filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.exportSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        DepartmentService.instance.getTree(),
        DepartmentService.instance.getFlat(),
        DepartmentService.instance.getFlat(permission: 'ROLE_MANAGE'),
      ]);
      final scoped = results[1] as List<DepartmentFlat>;
      final full = results[2] as List<DepartmentFlat>;
      setState(() {
        _tree = results[0] as List<DepartmentNode>;
        _flat = scoped;
        _allowRootCreate = scoped.length >= full.length;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = serverMsg(e);
        _loading = false;
      });
    }
  }

  void _showForm({DepartmentNode? node, int? parentId}) {
    showInstantDialog(
      context,
      (_) => _DepartmentFormDialog(
        node: node,
        defaultParentId: parentId,
        flatList: _flat,
        allowRootCreate: _allowRootCreate,
        onSaved: _load,
      ),
    );
  }

  Future<void> _delete(DepartmentNode node) async {
    final s = AppLocalizations.of(context)!;
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        title: Text(s.deleteDepartmentTitle),
        content: Text(s.deleteDepartmentPrompt(node.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DepartmentService.instance.delete(node.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Spacer(),
              PermissionGuard(
                permission: 'DEPARTMENT_VIEW',
                child: OutlinedButton.icon(
                  onPressed: _exporting ? null : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_outlined, size: 18),
                  label: Text(s.exportExcel),
                ),
              ),
              const SizedBox(width: 8),
              PermissionGuard(
                permission: 'DEPARTMENT_MANAGE',
                child: OutlinedButton.icon(
                  onPressed: _importing ? null : _import,
                  icon: _importing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  label: Text(s.importExcel),
                ),
              ),
              const SizedBox(width: 8),
              PermissionGuard(
                permission: 'DEPARTMENT_MANAGE',
                child: FilledButton.icon(
                  onPressed: () => _showForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(s.addDepartment),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: Text(s.retry)),
                      ],
                    ))
                  : _tree.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: _tree
                                .map((n) => _DepartmentTile(
                                      node: n,
                                      onAdd: (parentId) =>
                                          _showForm(parentId: parentId),
                                      onEdit: (n) => _showForm(node: n),
                                      onDelete: _delete,
                                    ))
                                .toList(),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    final s = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(s.noDepartmentsYet,
              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _showForm(),
            icon: const Icon(Icons.add),
            label: Text(s.createFirstDepartment),
          ),
        ],
      ),
    );
  }
}

// ── Tree tile (đệ quy) ──────────────────────────────────────────────────────

class _DepartmentTile extends StatefulWidget {
  final DepartmentNode node;
  final void Function(int parentId) onAdd;
  final void Function(DepartmentNode) onEdit;
  final void Function(DepartmentNode) onDelete;

  const _DepartmentTile({
    required this.node,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DepartmentTile> createState() => _DepartmentTileState();
}

class _DepartmentTileState extends State<_DepartmentTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final indent = node.level * 24.0;
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: hasChildren
                            ? InkWell(
                                onTap: () =>
                                    setState(() => _expanded = !_expanded),
                                child: Icon(
                                  _expanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 18,
                                ),
                              )
                            : Icon(Icons.circle,
                                size: 6, color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        node.level == 0
                            ? Icons.corporate_fare
                            : Icons.account_tree,
                        size: 18,
                        color: _levelColor(node.level),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    node.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(node.code,
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.grey)),
                                ),
                              ],
                            ),
                            if (node.managerName != null ||
                                node.employeeCount > 0)
                              Row(
                                children: [
                                  if (node.managerName != null) ...[
                                    Icon(Icons.person_outline,
                                        size: 12, color: Colors.grey[500]),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        node.managerName!,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600]),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Icon(Icons.people_outline,
                                      size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 2),
                                  Text(
                                    s.employeeCountLabel(node.employeeCount),
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (isDesktop) ...[
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: s.managePositions,
                            icon: const Icon(Icons.work_outline,
                                size: 16, color: Color(0xFF3B82F6)),
                            onPressed: () => _showPositions(context, node),
                          ),
                        ),
                        PermissionGuard(
                          permission: 'DEPARTMENT_MANAGE',
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: s.addSubDepartment,
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: () => widget.onAdd(node.id),
                            ),
                          ),
                        ),
                        PermissionGuard(
                          permission: 'DEPARTMENT_MANAGE',
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: s.edit,
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              onPressed: () => widget.onEdit(node),
                            ),
                          ),
                        ),
                        PermissionGuard(
                          permission: 'DEPARTMENT_MANAGE',
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: s.delete,
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.red),
                              onPressed: () => widget.onDelete(node),
                            ),
                          ),
                        ),
                      ],
                      if (!isDesktop)
                        _ActionsMenu(
                          s: s,
                          onPositions: () => _showPositions(context, node),
                          onAdd: () => widget.onAdd(node.id),
                          onEdit: () => widget.onEdit(node),
                          onDelete: () => widget.onDelete(node),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasChildren && _expanded)
          ...node.children.map((child) => _DepartmentTile(
                node: child,
                onAdd: widget.onAdd,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
              )),
      ],
    );
  }

  void _showPositions(BuildContext context, DepartmentNode node) {
    showInstantDialog(
      context,
      (_) => _PositionManagerDialog(department: node),
    );
  }

  Color _levelColor(int level) {
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6)
    ];
    return colors[level % colors.length];
  }
}

// ── Mobile actions menu ──────────────────────────────────────────────────────

class _ActionsMenu extends StatelessWidget {
  final AppLocalizations s;
  final VoidCallback onPositions;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionsMenu({
    required this.s,
    required this.onPositions,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final canManage = user != null &&
        (user.isSystemAdmin || user.can('DEPARTMENT_MANAGE'));

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'positions',
          child: Row(children: [
            const Icon(Icons.work_outline, size: 18, color: Color(0xFF3B82F6)),
            const SizedBox(width: 10),
            Text(s.managePositions),
          ]),
        ),
        if (canManage) ...[
          PopupMenuItem(
            value: 'add',
            child: Row(children: [
              const Icon(Icons.add, size: 18),
              const SizedBox(width: 10),
              Text(s.addSubDepartment),
            ]),
          ),
          PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 10),
              Text(s.edit),
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              const SizedBox(width: 10),
              Text(s.delete, style: const TextStyle(color: Colors.red)),
            ]),
          ),
        ],
      ],
      onSelected: (v) {
        if (v == 'positions') onPositions();
        if (v == 'add') onAdd();
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
    );
  }
}

// ── Form dialog ─────────────────────────────────────────────────────────────

class _DepartmentFormDialog extends StatefulWidget {
  final DepartmentNode? node;
  final int? defaultParentId;
  final List<DepartmentFlat> flatList;
  final bool allowRootCreate;
  final VoidCallback onSaved;

  const _DepartmentFormDialog({
    this.node,
    this.defaultParentId,
    required this.flatList,
    required this.allowRootCreate,
    required this.onSaved,
  });

  @override
  State<_DepartmentFormDialog> createState() => _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends State<_DepartmentFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _desc;
  int? _parentId;
  bool _saving = false;
  double? _checkInLat;
  double? _checkInLng;
  int _checkInRadius = 100;

  @override
  void initState() {
    super.initState();
    final n = widget.node;
    _name = TextEditingController(text: n?.name ?? '');
    _code = TextEditingController(text: n?.code ?? '');
    _desc = TextEditingController(text: n?.description ?? '');
    _parentId = n?.parentId ?? widget.defaultParentId;
    _checkInLat = n?.checkInLatitude;
    _checkInLng = n?.checkInLongitude;
    _checkInRadius = n?.checkInRadiusMeters ?? 100;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _desc.dispose();
    super.dispose();
  }

  // Lọc bỏ chính nó và con cháu khỏi dropdown parent
  List<DepartmentFlat> get _parentOptions {
    if (widget.node == null) return widget.flatList;
    final selfId = widget.node!.id;
    return widget.flatList.where((d) => d.id != selfId).toList();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'name': _name.text.trim(),
      'code': _code.text.trim().toUpperCase(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'parentId': _parentId,
      'checkInLatitude': _checkInLat,
      'checkInLongitude': _checkInLng,
      'checkInRadiusMeters': _checkInRadius,
    };
    try {
      if (widget.node == null) {
        await DepartmentService.instance.create(data);
      } else {
        await DepartmentService.instance.update(widget.node!.id, data);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final isEdit = widget.node != null;
    return AlertDialog(
      title: Text(isEdit ? s.editDepartment : s.addDepartment),
      content: SizedBox(
        width: 480,
        height: 560,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: s.departmentNameLabel),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? s.requiredField : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  decoration: InputDecoration(
                      labelText: s.departmentCodeLabel,
                      hintText: s.departmentCodeHintAlt),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? s.requiredField : null,
                ),
                const SizedBox(height: 12),
                DepartmentPickerField(
                  departments: _parentOptions,
                  value: _parentId,
                  label: s.parentDepartment,
                  allowAll: widget.allowRootCreate,
                  allLabel: s.noParentDepartment,
                  onChanged: (v) => setState(() => _parentId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  decoration: InputDecoration(labelText: s.descriptionLabel),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(s.checkInRadius,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                LocationPickerField(
                  latitude: _checkInLat,
                  longitude: _checkInLng,
                  radiusMeters: _checkInRadius,
                  onChanged: (lat, lng, r) => setState(() {
                    _checkInLat = lat;
                    _checkInLng = lng;
                    _checkInRadius = r;
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? s.save : s.create),
        ),
      ],
    );
  }
}

// ── Position Manager Dialog ──────────────────────────────────────────────────

class _PositionManagerDialog extends StatefulWidget {
  final DepartmentNode department;
  const _PositionManagerDialog({required this.department});

  @override
  State<_PositionManagerDialog> createState() => _PositionManagerDialogState();
}

class _PositionManagerDialogState extends State<_PositionManagerDialog> {
  List<PositionModel> _positions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list =
          await PositionService.instance.getByDepartment(widget.department.id);
      if (mounted)
        setState(() {
          _positions = list;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showForm({PositionModel? pos}) async {
    await showInstantDialog(
      context,
      (_) => _PositionFormDialog(
        position: pos,
        departmentId: widget.department.id,
      ),
    );
    _load();
  }

  Future<void> _delete(PositionModel pos) async {
    final s = AppLocalizations.of(context)!;
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        title: Text(s.deletePositionTitle),
        content: Text(s.deletePositionPrompt(pos.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PositionService.instance.delete(pos.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.work_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(s.positionsOfDepartment(widget.department.name))),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: s.addPosition,
            onPressed: () => _showForm(),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _positions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.work_off_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(s.noPositionsYet,
                            style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _showForm(),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(s.addPosition),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _positions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final pos = _positions[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      pos.code,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF3B82F6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    pos.name,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                icon: const Icon(Icons.edit_outlined,
                                    color: Color(0xFF3B82F6)),
                                onPressed: () => _showForm(pos: pos),
                              ),
                            ),
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => _delete(pos),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.close)),
      ],
    );
  }
}

// ── Position Form Dialog ─────────────────────────────────────────────────────

class _PositionFormDialog extends StatefulWidget {
  final PositionModel? position;
  final int departmentId;
  const _PositionFormDialog({this.position, required this.departmentId});

  @override
  State<_PositionFormDialog> createState() => _PositionFormDialogState();
}

class _PositionFormDialogState extends State<_PositionFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _desc;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.position;
    _name = TextEditingController(text: p?.name ?? '');
    _code = TextEditingController(text: p?.code ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'name': _name.text.trim(),
      'code': _code.text.trim().toUpperCase(),
      'departmentId': widget.departmentId,
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
    };
    try {
      if (widget.position == null) {
        await PositionService.instance.create(data);
      } else {
        await PositionService.instance.update(widget.position!.id, data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final isEdit = widget.position != null;
    return AlertDialog(
      title: Text(isEdit ? s.editPosition : s.addPosition),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: s.positionNameLabel),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? s.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                decoration: InputDecoration(
                    labelText: s.positionCodeLabel,
                    hintText: s.positionCodeHintText),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? s.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                decoration: InputDecoration(labelText: s.descriptionLabel),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(s.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? s.save : s.create),
        ),
      ],
    );
  }
}
