import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Một dòng thay đổi của 1 field (field, oldValue, newValue).
class ImportFieldChange {
  final String field;
  final String oldValue;
  final String newValue;
  const ImportFieldChange({
    required this.field,
    required this.oldValue,
    required this.newValue,
  });
}

/// Một hàng diff: CREATE / UPDATE / NO_CHANGE / DELETE.
class ImportDiffRow {
  final String action; // "CREATE" | "UPDATE" | "NO_CHANGE" | "DELETE"
  final String code;
  final String name;
  final String? parentCode;
  final List<ImportFieldChange> changes;
  final List<String> warnings;
  /// Thông tin bổ sung hiển thị dưới tên — key: label, value: giá trị.
  /// Ví dụ: {'Mô tả': 'Hội đồng quản trị', 'Vĩ độ': '10.123'}
  final Map<String, String> details;
  const ImportDiffRow({
    required this.action,
    required this.code,
    required this.name,
    this.parentCode,
    this.changes = const [],
    this.warnings = const [],
    this.details = const {},
  });
}

/// Dialog review thay đổi trước khi import Excel.
///
/// Dùng chung cho mọi module:
/// ```dart
/// final ok = await showInstantDialog<bool>(
///   context,
///   (_) => ImportPreviewDialog(
///     diffs: diffs,
///     onConfirm: () async { await service.importExcel(...); },
///   ),
/// );
/// ```
class ImportPreviewDialog extends StatefulWidget {
  final List<ImportDiffRow> diffs;

  /// Callback async thực hiện import thật. Dialog tự đóng sau khi hoàn tất.
  final Future<void> Function() onConfirm;

  const ImportPreviewDialog({
    super.key,
    required this.diffs,
    required this.onConfirm,
  });

  @override
  State<ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<ImportPreviewDialog> {
  bool _saving = false;

  List<ImportDiffRow> get _creates   => widget.diffs.where((d) => d.action == 'CREATE').toList();
  List<ImportDiffRow> get _updates   => widget.diffs.where((d) => d.action == 'UPDATE').toList();
  List<ImportDiffRow> get _deletes   => widget.diffs.where((d) => d.action == 'DELETE').toList();
  List<ImportDiffRow> get _noChanges => widget.diffs.where((d) => d.action == 'NO_CHANGE').toList();

  bool get _hasChanges => _creates.isNotEmpty || _updates.isNotEmpty || _deletes.isNotEmpty;
  bool get _hasWarnings => widget.diffs.any((d) => d.warnings.isNotEmpty);

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.preview_outlined, size: 20),
        const SizedBox(width: 8),
        Text(s.importPreviewTitle),
        const Spacer(),
        _SummaryChip(
          label: '${_creates.length} ${s.importPreviewCreate}',
          color: Colors.green,
          visible: _creates.isNotEmpty,
        ),
        const SizedBox(width: 4),
        _SummaryChip(
          label: '${_updates.length} ${s.importPreviewUpdate}',
          color: Colors.orange,
          visible: _updates.isNotEmpty,
        ),
        const SizedBox(width: 4),
        _SummaryChip(
          label: '${_deletes.length} ${s.importPreviewDelete}',
          color: Colors.red,
          visible: _deletes.isNotEmpty,
        ),
        const SizedBox(width: 4),
        _SummaryChip(
          label: '${_noChanges.length} ${s.importPreviewNoChange}',
          color: Colors.grey,
          visible: _noChanges.isNotEmpty,
        ),
      ]),
      content: SizedBox(
        width: 640,
        height: 480,
        child: !_hasChanges
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(s.importPreviewEmpty,
                      style: TextStyle(color: Colors.grey[600])),
                ]),
              )
            : ListView(children: [
                if (_creates.isNotEmpty) ...[
                  _SectionHeader(
                      label: s.importPreviewCreate,
                      color: Colors.green,
                      icon: Icons.add_circle_outline),
                  ..._creates.map((d) => _CreateTile(diff: d)),
                ],
                if (_updates.isNotEmpty) ...[
                  _SectionHeader(
                      label: s.importPreviewUpdate,
                      color: Colors.orange,
                      icon: Icons.edit_outlined),
                  ..._updates.map((d) => _UpdateTile(diff: d, s: s)),
                ],
                if (_deletes.isNotEmpty) ...[
                  _SectionHeader(
                      label: s.importPreviewDelete,
                      color: Colors.red,
                      icon: Icons.delete_outline),
                  ..._deletes.map((d) => _DeleteTile(diff: d, s: s)),
                ],
              ]),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(s.cancel),
        ),
        FilledButton.icon(
          style: _hasWarnings
              ? FilledButton.styleFrom(backgroundColor: Colors.orange)
              : null,
          onPressed: (_saving || !_hasChanges) ? null : _confirm,
          icon: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_hasWarnings ? Icons.warning_amber_rounded : Icons.check,
                  size: 16),
          label: Text(s.importConfirm),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool visible;
  const _SummaryChip({required this.label, required this.color, required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _SectionHeader({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
      ]),
    );
  }
}

class _CreateTile extends StatelessWidget {
  final ImportDiffRow diff;
  const _CreateTile({required this.diff});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: Colors.green.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.add, size: 14, color: Colors.green),
            const SizedBox(width: 8),
            Text(diff.code,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12,
                    color: Colors.green)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(diff.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
            if (diff.parentCode != null && diff.parentCode!.isNotEmpty)
              Text('↖ ${diff.parentCode}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
          if (diff.details.isNotEmpty) ...[
            const SizedBox(height: 6),
            _DetailsRow(details: diff.details),
          ],
        ]),
      ),
    );
  }
}

class _UpdateTile extends StatefulWidget {
  final ImportDiffRow diff;
  final AppLocalizations s;
  const _UpdateTile({required this.diff, required this.s});

  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final diff = widget.diff;
    final s = widget.s;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: Colors.orange.withValues(alpha: 0.05),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              const Icon(Icons.edit, size: 14, color: Colors.orange),
              const SizedBox(width: 8),
              Text(diff.code,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.orange)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(diff.name, style: const TextStyle(fontSize: 13))),
              Text('${diff.changes.length} thay đổi',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: Colors.grey),
            ]),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[100]),
                  children: [
                    _th('Field'),
                    _th(s.importPreviewOld),
                    _th(s.importPreviewNew),
                  ],
                ),
                ...diff.changes.map((c) => TableRow(children: [
                      _td(c.field, bold: true),
                      _td(c.oldValue.isEmpty ? '—' : c.oldValue,
                          color: Colors.red[700]),
                      _td(c.newValue.isEmpty ? '—' : c.newValue,
                          color: Colors.green[700]),
                    ])),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _th(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );

  Widget _td(String text, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: color)),
      );
}

class _DeleteTile extends StatelessWidget {
  final ImportDiffRow diff;
  final AppLocalizations s;
  const _DeleteTile({required this.diff, required this.s});

  @override
  Widget build(BuildContext context) {
    final hasWarnings = diff.warnings.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: Colors.red.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: hasWarnings
              ? Colors.orange.withValues(alpha: 0.6)
              : Colors.red.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.delete_outline, size: 14, color: Colors.red),
              const SizedBox(width: 8),
              Text(diff.code,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.red)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(diff.name,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
              if (hasWarnings)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 12, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(s.importPreviewDeleteWarning,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
            if (diff.details.isNotEmpty) ...[
              const SizedBox(height: 6),
              _DetailsRow(details: diff.details),
            ],
            if (hasWarnings) ...[
              const SizedBox(height: 6),
              ...diff.warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(left: 22, top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_right,
                            size: 14, color: Colors.orange),
                        const SizedBox(width: 2),
                        Expanded(
                            child: Text(w,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.orange))),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Details row — hiển thị thông tin bổ sung dạng chip ───────────────────────

class _DetailsRow extends StatelessWidget {
  final Map<String, String> details;
  const _DetailsRow({required this.details});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: details.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11),
                    children: [
                      TextSpan(
                          text: '${e.key}: ',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500)),
                      TextSpan(
                          text: e.value,
                          style: const TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}
