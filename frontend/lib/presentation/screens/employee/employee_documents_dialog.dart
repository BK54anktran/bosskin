import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/employee.dart';
import '../../../data/models/employee_document.dart';
import '../../../data/models/labor_contract.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../../data/repositories/document_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/document_widgets.dart';
import '../../widgets/empty_state.dart';

/// Bước N — tài liệu nhân sự của một nhân viên (cần EMPLOYEE_DOCUMENT_VIEW; sửa cần EDIT).
class EmployeeDocumentsDialog extends StatefulWidget {
  final Employee employee;

  const EmployeeDocumentsDialog({super.key, required this.employee});

  @override
  State<EmployeeDocumentsDialog> createState() => _EmployeeDocumentsDialogState();
}

class _EmployeeDocumentsDialogState extends State<EmployeeDocumentsDialog> {
  final _repo = DocumentRepository();
  List<EmployeeDocument> _items = [];
  List<DocumentType> _types = [];
  List<LaborContract> _contracts = [];
  bool _loading = true;
  String? _error;

  bool get _canEdit {
    final u = AuthService.instance.currentUser;
    return u != null && (u.isSystemAdmin || u.can('EMPLOYEE_DOCUMENT_EDIT'));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final u = AuthService.instance.currentUser;
      final canContracts = u != null && (u.isSystemAdmin || u.can('CONTRACT_VIEW'));
      final results = await Future.wait([
        _repo.getAll(widget.employee.id),
        _repo.getTypes(),
        if (_canEdit && canContracts) ContractRepository().getAll(employeeId: widget.employee.id),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<EmployeeDocument>;
        _types = results[1] as List<DocumentType>;
        _contracts = results.length > 2 ? results[2] as List<LaborContract> : [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = serverMsg(e); _loading = false; });
    }
  }

  Future<void> _openForm([EmployeeDocument? d]) async {
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => DocumentUploadDialog(employeeId: widget.employee.id, doc: d, types: _types, contracts: _contracts),
    );
    if (ok == true) _load();
  }

  Future<void> _review(EmployeeDocument d, bool approve) async {
    try {
      approve ? await _repo.approve(d.id, null) : await _repo.reject(d.id, null);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _delete(EmployeeDocument d) async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        content: Text(s.docDeleteConfirm(d.typeName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(d.id);
      _load();
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
    final have = _items.where((d) => d.status == 'APPROVED' && !d.isExpired).map((d) => d.typeId).toSet();
    final missing = _types.where((t) => t.required && !have.contains(t.id)).map((t) => t.name).toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text('${s.docTitleDialog} — ${widget.employee.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                if (_canEdit && _types.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: Text(s.docUpload),
                    onPressed: () => _openForm(),
                  ),
              ]),
              if (!_loading && missing.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(s.docMissingRequired(missing.join(', ')),
                    style: const TextStyle(fontSize: 12, color: AppTheme.warning)),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
                        : _items.isEmpty
                            ? EmptyState(icon: Icons.folder_open_outlined, message: s.docEmpty)
                            : ListView.separated(
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final d = _items[i];
                                  return DocumentTile(
                                    doc: d,
                                    onDownload: () => downloadDocument(context, () => _repo.getLink(d.id)),
                                    onEdit: _canEdit ? () => _openForm(d) : null,
                                    onDelete: _canEdit ? () => _delete(d) : null,
                                    extraActions: [
                                      if (_canEdit && d.isPending) ...[
                                        IconButton(
                                          tooltip: s.approve,
                                          icon: const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.secondary),
                                          onPressed: () => _review(d, true),
                                        ),
                                        IconButton(
                                          tooltip: s.reject,
                                          icon: const Icon(Icons.cancel_outlined, size: 18, color: AppTheme.error),
                                          onPressed: () => _review(d, false),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: Text(s.close)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
