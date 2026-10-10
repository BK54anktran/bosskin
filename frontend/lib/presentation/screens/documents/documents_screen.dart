import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/employee_document.dart';
import '../../../data/repositories/document_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/document_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

/// Bước N — tài liệu nhân sự toàn công ty (trong phạm vi): sắp hết hạn, thiếu bắt buộc, chờ duyệt, loại tài liệu.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final u = AuthService.instance.currentUser;
    final canEdit = u != null && (u.isSystemAdmin || u.can('EMPLOYEE_DOCUMENT_EDIT'));
    return DefaultTabController(
      length: 4,
      child: Column(children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: s.docTabExpiring),
              Tab(text: s.docTabMissing),
              Tab(text: s.docTabPending),
              Tab(text: s.docTabTypes),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            const _ExpiringTab(),
            const _MissingTab(),
            _PendingTab(canEdit: canEdit),
            _TypesTab(canEdit: canEdit),
          ]),
        ),
      ]),
    );
  }
}

/// Khung tải dữ liệu dùng chung cho các tab.
class _Loader<T> extends StatefulWidget {
  final Future<List<T>> Function() load;
  final Widget Function(BuildContext, List<T>, VoidCallback reload) builder;
  final IconData emptyIcon;
  final String Function(AppLocalizations) emptyMessage;
  final Widget? header;

  const _Loader({
    super.key,
    required this.load,
    required this.builder,
    required this.emptyIcon,
    required this.emptyMessage,
    this.header,
  });

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  List<T> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await widget.load();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = serverMsg(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final Widget body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
            : _items.isEmpty
                ? EmptyState(icon: widget.emptyIcon, message: widget.emptyMessage(s))
                : RefreshIndicator(onRefresh: _load, child: widget.builder(context, _items, _load));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.header != null) widget.header!,
      Expanded(child: body),
    ]);
  }
}

class _ExpiringTab extends StatelessWidget {
  const _ExpiringTab();

  @override
  Widget build(BuildContext context) {
    final repo = DocumentRepository();
    final s = AppLocalizations.of(context);
    return _Loader<EmployeeDocument>(
      load: () => repo.getExpiring(),
      emptyIcon: Icons.event_available_outlined,
      emptyMessage: (s) => s.docExpiringEmpty,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(s.docExpiringHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ),
      builder: (context, items, _) => ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => DocumentTile(
          doc: items[i],
          showEmployee: true,
          onDownload: () => downloadDocument(context, () => repo.getLink(items[i].id)),
        ),
      ),
    );
  }
}

class _MissingTab extends StatelessWidget {
  const _MissingTab();

  @override
  Widget build(BuildContext context) {
    final repo = DocumentRepository();
    return _Loader<MissingDocuments>(
      load: () => repo.getMissing(),
      emptyIcon: Icons.task_alt,
      emptyMessage: (s) => s.docMissingEmpty,
      builder: (context, items, _) => ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = items[i];
          return ListTile(
            dense: true,
            title: Text('${m.employeeCode} ${m.employeeName}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(m.departmentName ?? ''),
            trailing: Wrap(
              spacing: 4,
              children: m.missingTypes.map((t) => StatusBadge(label: t, color: AppTheme.warning)).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _PendingTab extends StatelessWidget {
  final bool canEdit;

  const _PendingTab({required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final repo = DocumentRepository();
    final s = AppLocalizations.of(context);
    return _Loader<EmployeeDocument>(
      load: () => repo.getPending(),
      emptyIcon: Icons.inbox_outlined,
      emptyMessage: (s) => s.docPendingEmpty,
      builder: (context, items, reload) => ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final d = items[i];
          Future<void> review(bool approve) async {
            try {
              approve ? await repo.approve(d.id, null) : await repo.reject(d.id, null);
              reload();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
              }
            }
          }

          return DocumentTile(
            doc: d,
            showEmployee: true,
            onDownload: () => downloadDocument(context, () => repo.getLink(d.id)),
            extraActions: [
              if (canEdit) ...[
                IconButton(
                  tooltip: s.approve,
                  icon: const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.secondary),
                  onPressed: () => review(true),
                ),
                IconButton(
                  tooltip: s.reject,
                  icon: const Icon(Icons.cancel_outlined, size: 18, color: AppTheme.error),
                  onPressed: () => review(false),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TypesTab extends StatefulWidget {
  final bool canEdit;

  const _TypesTab({required this.canEdit});

  @override
  State<_TypesTab> createState() => _TypesTabState();
}

class _TypesTabState extends State<_TypesTab> {
  final _repo = DocumentRepository();
  Key _key = UniqueKey();

  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _openForm([DocumentType? t]) async {
    final ok = await showInstantDialog<bool>(context, (ctx) => _TypeFormDialog(type: t, repo: _repo));
    if (ok == true) _reload();
  }

  Future<void> _delete(DocumentType t) async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        content: Text(s.docTypeDeleteConfirm(t.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteType(t.id);
      _reload();
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
    return _Loader<DocumentType>(
      key: _key,
      load: () => _repo.getTypes(),
      emptyIcon: Icons.category_outlined,
      emptyMessage: (s) => s.docTypeEmpty,
      header: widget.canEdit
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(s.docTypeAdd),
                  onPressed: () => _openForm(),
                ),
              ),
            )
          : null,
      builder: (context, items, _) => ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final t = items[i];
          return ListTile(
            dense: true,
            onTap: widget.canEdit ? () => _openForm(t) : null,
            mouseCursor: widget.canEdit ? SystemMouseCursors.click : null,
            title: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(t.code, style: TextStyle(color: AppTheme.textSecondary)),
              if (t.required) StatusBadge(label: s.docTypeRequired, color: AppTheme.primary),
              if (t.hasExpiry) StatusBadge(label: s.docTypeHasExpiry, color: AppTheme.warning),
            ]),
            trailing: widget.canEdit
                ? IconButton(
                    tooltip: s.delete,
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                    onPressed: () => _delete(t),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _TypeFormDialog extends StatefulWidget {
  final DocumentType? type;
  final DocumentRepository repo;

  const _TypeFormDialog({required this.type, required this.repo});

  @override
  State<_TypeFormDialog> createState() => _TypeFormDialogState();
}

class _TypeFormDialogState extends State<_TypeFormDialog> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();
  bool _required = false;
  bool _hasExpiry = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.type;
    if (t != null) {
      _codeCtrl.text = t.code;
      _nameCtrl.text = t.name;
      _orderCtrl.text = '${t.sortOrder}';
      _required = t.required;
      _hasExpiry = t.hasExpiry;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _codeCtrl.text.trim().isNotEmpty && _nameCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    final body = {
      'code': _codeCtrl.text.trim().toUpperCase(),
      'name': _nameCtrl.text.trim(),
      'required': _required,
      'hasExpiry': _hasExpiry,
      'sortOrder': int.tryParse(_orderCtrl.text.trim()),
    };
    try {
      if (widget.type == null) {
        await widget.repo.createType(body);
      } else {
        await widget.repo.updateType(widget.type!.id, body);
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
      title: Text(widget.type == null ? s.docTypeAdd : s.docTypeEdit),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _codeCtrl,
                maxLength: 30,
                decoration: InputDecoration(labelText: '${s.docTypeCode} *', isDense: true, counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _orderCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s.docTypeOrder, isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            maxLength: 150,
            decoration: InputDecoration(labelText: '${s.docTypeName} *', isDense: true, counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _required,
            title: Text(s.docTypeRequired),
            subtitle: Text(s.docTypeRequiredHint, style: const TextStyle(fontSize: 12)),
            onChanged: (v) => setState(() => _required = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _hasExpiry,
            title: Text(s.docTypeHasExpiry),
            subtitle: Text(s.docTypeHasExpiryHint, style: const TextStyle(fontSize: 12)),
            onChanged: (v) => setState(() => _hasExpiry = v),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _saving || !_valid ? null : _save, child: Text(s.save)),
      ],
    );
  }
}
