import 'package:flutter/material.dart';
import '../../core/utils/error_utils.dart';
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

  /// Nếu file có nhiều sheet: tên từng section (vd: ['Phòng ban', 'Chức vụ']).
  /// Null = 1 section duy nhất, không hiện header phân chia.
  final List<String>? sectionLabels;

  /// Số lượng diffs thuộc từng section — phải cùng độ dài với [sectionLabels].
  final List<int>? sectionCounts;

  const ImportPreviewDialog({
    super.key,
    required this.diffs,
    required this.onConfirm,
    this.sectionLabels,
    this.sectionCounts,
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

  String? _errorMessage;

  Future<void> _confirm() async {
    setState(() { _saving = true; _errorMessage = null; });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _extractMessage(e);
        });
      }
    }
  }

  String _extractMessage(Object e) => serverMsg(e);

  List<Widget> _buildContent(AppLocalizations s) {
    final labels = widget.sectionLabels;
    final counts = widget.sectionCounts;

    if (labels == null || counts == null || labels.length != counts.length) {
      // 1 section — render thẳng
      return _buildDiffsForRange(widget.diffs, s);
    }

    // Nhiều section — render header phân chia rồi diffs của từng section
    final items = <Widget>[];
    int offset = 0;
    for (int i = 0; i < labels.length; i++) {
      final slice = widget.diffs.skip(offset).take(counts[i]).toList();
      offset += counts[i];
      final hasChange = slice.any((d) => d.action != 'NO_CHANGE');
      // Header phân chia sheet
      items.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 4),
        child: Row(children: [
          const Icon(Icons.table_chart_outlined, size: 14, color: Color(0xFF3B82F6)),
          const SizedBox(width: 6),
          Text(labels[i],
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6))),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: const Color(0xFF3B82F6).withValues(alpha: 0.3))),
          if (!hasChange) ...[
            const SizedBox(width: 8),
            Text(s.importPreviewNoChange,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ]),
      ));
      items.addAll(_buildDiffsForRange(slice, s));
    }
    return items;
  }

  List<Widget> _buildDiffsForRange(List<ImportDiffRow> diffs, AppLocalizations s) {
    final creates   = diffs.where((d) => d.action == 'CREATE').toList();
    final updates   = diffs.where((d) => d.action == 'UPDATE').toList();
    final deletes   = diffs.where((d) => d.action == 'DELETE').toList();
    final items = <Widget>[];
    if (creates.isNotEmpty) {
      items.add(_SectionHeader(label: s.importPreviewCreate, color: Colors.green, icon: Icons.add_circle_outline));
      items.addAll(creates.map((d) => _CreateTile(diff: d)));
    }
    if (updates.isNotEmpty) {
      items.add(_SectionHeader(label: s.importPreviewUpdate, color: Colors.orange, icon: Icons.edit_outlined));
      items.addAll(updates.map((d) => _UpdateTile(diff: d, s: s)));
    }
    if (deletes.isNotEmpty) {
      items.add(_SectionHeader(label: s.importPreviewDelete, color: Colors.red, icon: Icons.delete_outline));
      items.addAll(deletes.map((d) => _DeleteTile(diff: d, s: s)));
    }
    return items;
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
            : ListView(children: _buildContent(s)),
      ),
      actions: [
        Row(children: [
          if (_errorMessage != null) ...[
            const Icon(Icons.error_outline, size: 16, color: Colors.red),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ] else
            const Spacer(),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          const SizedBox(width: 8),
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
        ]),
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
    final hasWarnings = diff.warnings.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: Colors.green.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: hasWarnings
              ? Colors.orange.withValues(alpha: 0.6)
              : Colors.green.withValues(alpha: 0.2),
        ),
      ),
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
          if (hasWarnings) ...[
            const SizedBox(height: 6),
            _WarningsBlock(warnings: diff.warnings),
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
              Text(s.xlChangesCount('${diff.changes.length}'),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: Colors.grey),
            ]),
          ),
        ),
        if (diff.warnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _WarningsBlock(warnings: diff.warnings),
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
              _WarningsBlock(warnings: diff.warnings),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Warnings block — hiển thị danh sách lỗi/cảnh báo ────────────────────────

class _WarningsBlock extends StatelessWidget {
  final List<String> warnings;
  const _WarningsBlock({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: warnings.map((w) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.orange),
            const SizedBox(width: 6),
            Expanded(child: Text(serverKeyMsg(w),
                style: const TextStyle(fontSize: 12, color: Colors.orange))),
          ]),
        )).toList(),
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
