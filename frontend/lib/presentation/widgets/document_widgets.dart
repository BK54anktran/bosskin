import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../core/utils/file_picker_utils.dart';
import '../../core/utils/file_saver_utils.dart';
import '../../data/models/employee_document.dart';
import '../../data/models/labor_contract.dart';
import '../../data/repositories/document_repository.dart';
import 'app_dropdown.dart';
import 'date_field.dart';
import 'status_badge.dart';

/// Bước N — phần dùng chung giữa hộp tài liệu của NV (HR), màn Tài liệu nhân sự và thẻ "Tài liệu của tôi".

String documentStatusLabel(AppLocalizations s, String st) => switch (st) {
      'PENDING' => s.docStatusPending,
      'REJECTED' => s.docStatusRejected,
      _ => s.docStatusApproved,
    };

Color documentStatusColor(String st) => switch (st) {
      'PENDING' => AppTheme.warning,
      'REJECTED' => AppTheme.error,
      _ => AppTheme.secondary,
    };

/// Chip hạn dùng: đã hết hạn (đỏ) / còn ≤ 30 ngày (cam) / ngày hết hạn.
Widget documentExpiryBadge(AppLocalizations s, EmployeeDocument d) {
  if (d.expiresOn == null || d.daysToExpiry == null) return const SizedBox.shrink();
  final days = d.daysToExpiry!;
  if (days < 0) return StatusBadge(label: s.docExpired, color: AppTheme.error);
  if (days <= 30) return StatusBadge(label: s.docExpiresInDays(days), color: AppTheme.warning);
  return StatusBadge(label: '${s.docExpiresOn}: ${DateFormat('dd/MM/yyyy').format(d.expiresOn!)}',
      color: AppTheme.textSecondary);
}

/// Lấy link ký tạm rồi tải file về máy.
Future<void> downloadDocument(BuildContext context, Future<DocumentLink> Function() getLink) async {
  final s = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final link = await getLink();
    final bytes = await DocumentRepository().fetchLink(link);
    await saveFileToDevice(bytes, link.fileName);
    messenger.showSnackBar(SnackBar(content: Text(s.docDownloaded(link.fileName))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
  }
}

String _fileSize(int bytes) =>
    bytes >= 1024 * 1024 ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB' : '${(bytes / 1024).ceil()} KB';

/// Một dòng tài liệu: loại, tiêu đề, trạng thái, hạn, file.
class DocumentTile extends StatelessWidget {
  final EmployeeDocument doc;
  final bool showEmployee;
  final VoidCallback onDownload;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final List<Widget> extraActions;

  const DocumentTile({
    super.key,
    required this.doc,
    required this.onDownload,
    this.showEmployee = false,
    this.onEdit,
    this.onDelete,
    this.extraActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final d = doc;
    final dateFmt = DateFormat('dd/MM/yyyy');
    return ListTile(
      dense: true,
      onTap: onEdit,
      mouseCursor: onEdit != null ? SystemMouseCursors.click : null,
      leading: Icon(d.contentType == 'application/pdf' ? Icons.picture_as_pdf_outlined
          : d.contentType.startsWith('image/') ? Icons.image_outlined : Icons.description_outlined),
      title: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (showEmployee) Text('${d.employeeCode} ${d.employeeName}', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(d.typeName, style: TextStyle(fontWeight: showEmployee ? FontWeight.w400 : FontWeight.w700)),
        if (d.status != 'APPROVED') StatusBadge(label: documentStatusLabel(s, d.status), color: documentStatusColor(d.status)),
        documentExpiryBadge(s, d),
      ]),
      subtitle: Text([
        if ((d.title ?? '').isNotEmpty) d.title!,
        '${d.fileName} · ${_fileSize(d.fileSize)}',
        if (d.issuedOn != null) '${s.docIssuedOn}: ${dateFmt.format(d.issuedOn!)}',
        if (d.contractNo != null) '${s.docContract}: ${d.contractNo}',
        if ((d.note ?? '').isNotEmpty) d.note!,
        if ((d.reviewNote ?? '').isNotEmpty) '${s.docReviewNote}: ${d.reviewNote}',
      ].join('\n')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        ...extraActions,
        IconButton(tooltip: s.docDownload, icon: const Icon(Icons.download_outlined, size: 18), onPressed: onDownload),
        if (onDelete != null)
          IconButton(
            tooltip: s.delete,
            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
            onPressed: onDelete,
          ),
      ]),
    );
  }
}

/// Hộp tải lên / sửa thông tin tài liệu. [employeeId] null = NV tự gửi (/self, chờ duyệt).
/// Sửa ([doc] khác null) không đổi file.
class DocumentUploadDialog extends StatefulWidget {
  final int? employeeId;
  final EmployeeDocument? doc;
  final List<DocumentType> types;
  final List<LaborContract> contracts;

  const DocumentUploadDialog({
    super.key,
    required this.types,
    this.employeeId,
    this.doc,
    this.contracts = const [],
  });

  @override
  State<DocumentUploadDialog> createState() => _DocumentUploadDialogState();
}

class _DocumentUploadDialogState extends State<DocumentUploadDialog> {
  final _repo = DocumentRepository();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int? _typeId;
  int? _contractId;
  DateTime? _issuedOn;
  DateTime? _expiresOn;
  ({Uint8List bytes, String filename})? _file;
  bool _saving = false;

  bool get _isEdit => widget.doc != null;
  DocumentType? get _type => widget.types.where((t) => t.id == _typeId).firstOrNull;

  @override
  void initState() {
    super.initState();
    final d = widget.doc;
    if (d != null) {
      _typeId = d.typeId;
      _contractId = d.contractId;
      _issuedOn = d.issuedOn;
      _expiresOn = d.expiresOn;
      _titleCtrl.text = d.title ?? '';
      _noteCtrl.text = d.note ?? '';
    } else if (widget.types.isNotEmpty) {
      _typeId = widget.types.first.id;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await pickDocumentFile();
    if (f != null && mounted) setState(() => _file = (bytes: f.bytes, filename: f.filename));
  }

  bool get _valid =>
      _typeId != null && (_isEdit || _file != null) && !((_type?.hasExpiry ?? false) && _expiresOn == null);

  Future<void> _save() async {
    setState(() => _saving = true);
    final fmt = DateFormat('yyyy-MM-dd');
    final fields = <String, dynamic>{
      'typeId': _typeId,
      'title': _titleCtrl.text.trim(),
      'issuedOn': _issuedOn != null ? fmt.format(_issuedOn!) : null,
      'expiresOn': _expiresOn != null ? fmt.format(_expiresOn!) : null,
      'note': _noteCtrl.text.trim(),
    };
    try {
      if (_isEdit) {
        await _repo.update(widget.doc!.id, {...fields, 'contractId': _contractId});
      } else if (widget.employeeId != null) {
        await _repo.upload({...fields, 'employeeId': widget.employeeId, 'contractId': _contractId},
            _file!.bytes, _file!.filename);
      } else {
        await _repo.uploadSelf(fields, _file!.bytes, _file!.filename);
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
    final hasExpiry = _type?.hasExpiry ?? false;
    return AlertDialog(
      title: Text(_isEdit ? s.docEdit : (widget.employeeId == null ? s.docSubmit : s.docUpload)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppDropdown<int>(
              value: _typeId,
              label: '${s.docType} *',
              items: widget.types
                  .map((t) => DropdownMenuItem(value: t.id, child: Text(t.required ? '${t.name} *' : t.name)))
                  .toList(),
              onChanged: (v) => setState(() => _typeId = v),
            ),
            const SizedBox(height: 12),
            if (!_isEdit) ...[
              Row(children: [
                Expanded(
                  child: Text(_file?.filename ?? s.docNoFile,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _file == null ? AppTheme.textSecondary : null)),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text(s.docChooseFile),
                  onPressed: _saving ? null : _pick,
                ),
              ]),
              const SizedBox(height: 4),
              Text(s.docFileHint, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _titleCtrl,
              maxLength: 200,
              decoration: InputDecoration(labelText: s.docTitle, isDense: true, counterText: ''),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DateField(
                  label: s.docIssuedOn,
                  value: _issuedOn,
                  clearable: true,
                  onChanged: (d) => setState(() => _issuedOn = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(
                  label: hasExpiry ? '${s.docExpiresOn} *' : s.docExpiresOn,
                  value: _expiresOn,
                  clearable: true,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  onChanged: (d) => setState(() => _expiresOn = d),
                ),
              ),
            ]),
            if (widget.contracts.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppDropdown<int?>(
                value: _contractId,
                label: s.docContract,
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(s.docNoContract)),
                  ...widget.contracts.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.contractNo))),
                ],
                onChanged: (v) => setState(() => _contractId = v),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLength: 500,
              decoration: InputDecoration(labelText: s.note, isDense: true),
            ),
            if (widget.employeeId == null && !_isEdit)
              Text(s.docSelfHint, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _saving || !_valid ? null : _save, child: Text(s.save)),
      ],
    );
  }
}
