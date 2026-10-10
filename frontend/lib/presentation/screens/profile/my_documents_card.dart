import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/employee_document.dart';
import '../../../data/repositories/document_repository.dart';
import '../../widgets/document_widgets.dart';

/// Bước N — "Tài liệu của tôi" ở Hồ sơ: xem / tải tài liệu của mình, gửi bổ sung (chờ HR duyệt),
/// rút bản còn chờ duyệt. Không tải được (vd. tài khoản không gắn NV) thì ẩn.
class MyDocumentsCard extends StatefulWidget {
  const MyDocumentsCard({super.key});

  @override
  State<MyDocumentsCard> createState() => _MyDocumentsCardState();
}

class _MyDocumentsCardState extends State<MyDocumentsCard> {
  final _repo = DocumentRepository();
  List<EmployeeDocument> _items = const [];
  List<DocumentType> _types = const [];
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([_repo.getSelf(), _repo.getTypes()]);
      if (mounted) {
        setState(() {
          _items = r[0] as List<EmployeeDocument>;
          _types = r[1] as List<DocumentType>;
          _available = true;
        });
      }
    } catch (_) {
      // Không tải được thì ẩn thẻ, không chặn Hồ sơ
    }
  }

  Future<void> _submit() async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(context, (ctx) => DocumentUploadDialog(types: _types));
    if (ok == true) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.docSubmitted)));
      _load();
    }
  }

  Future<void> _withdraw(EmployeeDocument d) async {
    try {
      await _repo.deleteSelf(d.id);
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
    if (!_available) return const SizedBox.shrink();
    final s = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(s.docMyTitle,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),
              if (_types.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(s.docSubmit),
                  onPressed: _submit,
                ),
            ]),
            const SizedBox(height: 4),
            Text(s.docSelfHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Text(s.docEmpty, style: TextStyle(color: AppTheme.textSecondary))
            else
              for (final d in _items)
                DocumentTile(
                  doc: d,
                  onDownload: () => downloadDocument(context, () => _repo.getSelfLink(d.id)),
                  onDelete: d.isPending ? () => _withdraw(d) : null,
                ),
          ]),
        ),
      ),
    );
  }
}
