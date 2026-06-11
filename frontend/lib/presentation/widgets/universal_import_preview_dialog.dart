import 'package:flutter/material.dart';
import '../../core/utils/error_utils.dart';
import '../../data/repositories/universal_excel_repository.dart';
import '../../l10n/app_localizations.dart';

/// Dialog preview universal import (Matrixify-style).
/// Hiển thị diff per-type (employee, department, shift, ...) trước khi confirm.
///
/// Dùng:
/// ```dart
/// final ok = await showInstantDialog<bool>(
///   context,
///   (ctx) => UniversalImportPreviewDialog(
///     diffs: diffs,
///     onConfirm: () async { ... },
///   ),
/// );
/// ```
class UniversalImportPreviewDialog extends StatefulWidget {
  final Map<String, List<UniversalImportDiff>> diffs;
  final Future<void> Function() onConfirm;

  const UniversalImportPreviewDialog({
    super.key,
    required this.diffs,
    required this.onConfirm,
  });

  @override
  State<UniversalImportPreviewDialog> createState() =>
      _UniversalImportPreviewDialogState();
}

class _UniversalImportPreviewDialogState
    extends State<UniversalImportPreviewDialog> {
  bool _saving = false;
  String? _errorMsg;

  bool get _hasChanges => widget.diffs.values.any(
      (rows) => rows.any((r) => r.action != 'SKIP' && !r.isError));

  bool get _hasErrors =>
      widget.diffs.values.any((rows) => rows.any((r) => r.isError));

  int get _totalCreate =>
      _count((r) => r.action == 'CREATE');
  int get _totalUpdate =>
      _count((r) => r.action == 'UPDATE');
  int get _totalMerge =>
      _count((r) => r.action == 'MERGE');
  int get _totalDelete =>
      _count((r) => r.action == 'DELETE');
  int get _totalError =>
      _count((r) => r.isError);

  int _count(bool Function(UniversalImportDiff) test) =>
      widget.diffs.values.expand((l) => l).where(test).length;

  Future<void> _confirm() async {
    setState(() { _saving = true; _errorMsg = null; });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _errorMsg = serverMsg(e); });
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
        if (_totalCreate > 0) ...[
          _Chip('$_totalCreate ${s.importPreviewCreate}', Colors.green),
          const SizedBox(width: 4),
        ],
        if (_totalMerge > 0) ...[
          _Chip('$_totalMerge MERGE', Colors.blue),
          const SizedBox(width: 4),
        ],
        if (_totalUpdate > 0) ...[
          _Chip('$_totalUpdate ${s.importPreviewUpdate}', Colors.orange),
          const SizedBox(width: 4),
        ],
        if (_totalDelete > 0) ...[
          _Chip('$_totalDelete ${s.importPreviewDelete}', Colors.red),
          const SizedBox(width: 4),
        ],
        if (_totalError > 0)
          _Chip('$_totalError lỗi', Colors.red.shade900),
      ]),
      content: SizedBox(
        width: 680,
        height: 520,
        child: widget.diffs.isEmpty || !_hasChanges && !_hasErrors
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(s.importPreviewEmpty,
                      style: TextStyle(color: Colors.grey[600])),
                ]),
              )
            : ListView(
                children: widget.diffs.entries.map((entry) {
                  final type = entry.key;
                  final rows = entry.value;
                  return _SheetSection(type: type, rows: rows, s: s);
                }).toList(),
              ),
      ),
      actions: [
        Row(children: [
          if (_errorMsg != null) ...[
            const Icon(Icons.error_outline, size: 16, color: Colors.red),
            const SizedBox(width: 6),
            Expanded(
                child: Text(_errorMsg!,
                    style: const TextStyle(fontSize: 12, color: Colors.red))),
          ] else
            const Spacer(),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: _hasErrors
                ? FilledButton.styleFrom(backgroundColor: Colors.orange)
                : null,
            onPressed: (_saving || !_hasChanges) ? null : _confirm,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(_hasErrors ? Icons.warning_amber_rounded : Icons.check,
                    size: 16),
            label: Text(s.importConfirm),
          ),
        ]),
      ],
    );
  }
}

// ── Sheet section ─────────────────────────────────────────────────────────────

class _SheetSection extends StatelessWidget {
  final String type;
  final List<UniversalImportDiff> rows;
  final AppLocalizations s;
  const _SheetSection(
      {required this.type, required this.rows, required this.s});

  static const _typeLabels = {
    'employee':   'Nhân viên',
    'department': 'Phòng ban',
    'position':   'Chức vụ',
    'shift':      'Ca làm việc',
  };

  @override
  Widget build(BuildContext context) {
    final label = _typeLabels[type] ?? type;
    final creates = rows.where((r) => r.action == 'CREATE' && !r.isError).toList();
    final merges  = rows.where((r) => r.action == 'MERGE'  && !r.isError).toList();
    final updates = rows.where((r) => r.action == 'UPDATE' && !r.isError).toList();
    final deletes = rows.where((r) => r.action == 'DELETE' && !r.isError).toList();
    final errors  = rows.where((r) => r.isError).toList();
    final skips   = rows.where((r) => r.action == 'SKIP' && !r.isError).length;

    final hasAnything = creates.isNotEmpty || merges.isNotEmpty ||
        updates.isNotEmpty || deletes.isNotEmpty || errors.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Row(children: [
          const Icon(Icons.table_chart_outlined, size: 14, color: Color(0xFF3B82F6)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6))),
          const SizedBox(width: 8),
          if (skips > 0)
            Text('$skips bỏ qua',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(width: 8),
          const Expanded(
              child: Divider(color: Color(0x553B82F6))),
        ]),
        if (!hasAnything)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 20),
            child: Text(s.importPreviewNoChange,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
        if (creates.isNotEmpty) ...[
          _RowGroupHeader(s.importPreviewCreate, Colors.green, Icons.add_circle_outline),
          ...creates.map((r) => _DiffTile(diff: r, color: Colors.green)),
        ],
        if (merges.isNotEmpty) ...[
          _RowGroupHeader('MERGE', Colors.blue, Icons.merge_outlined),
          ...merges.map((r) => _DiffTile(diff: r, color: Colors.blue)),
        ],
        if (updates.isNotEmpty) ...[
          _RowGroupHeader(s.importPreviewUpdate, Colors.orange, Icons.edit_outlined),
          ...updates.map((r) => _DiffTile(diff: r, color: Colors.orange)),
        ],
        if (deletes.isNotEmpty) ...[
          _RowGroupHeader(s.importPreviewDelete, Colors.red, Icons.delete_outline),
          ...deletes.map((r) => _DiffTile(diff: r, color: Colors.red)),
        ],
        if (errors.isNotEmpty) ...[
          _RowGroupHeader('Lỗi (${errors.length})', Colors.red.shade900,
              Icons.error_outline),
          ...errors.map((r) => _DiffTile(diff: r, color: Colors.red.shade900, isError: true)),
        ],
      ]),
    );
  }
}

class _RowGroupHeader extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _RowGroupHeader(this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 3),
      child: Row(children: [
        const SizedBox(width: 20),
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Expanded(child: Divider(color: color.withValues(alpha: 0.25))),
      ]),
    );
  }
}

// ── Summary key parser ────────────────────────────────────────────────────────

Map<String, String> _buildColLabels(AppLocalizations s) => {
  'excel.col.employee.code':          s.excelColEmployeeCode,
  'excel.col.employee.fullName':      s.excelColEmployeeFullName,
  'excel.col.employee.email':         s.excelColEmployeeEmail,
  'excel.col.employee.phone':         s.excelColEmployeePhone,
  'excel.col.employee.gender':        s.excelColEmployeeGender,
  'excel.col.employee.dateOfBirth':   s.excelColEmployeeDateOfBirth,
  'excel.col.employee.joinDate':      s.excelColEmployeeJoinDate,
  'excel.col.employee.leaveDate':     s.excelColEmployeeLeaveDate,
  'excel.col.employee.status':        s.excelColEmployeeStatus,
  'excel.col.employee.departmentCode':s.excelColEmployeeDepartmentCode,
  'excel.col.employee.positionCode':  s.excelColEmployeePositionCode,
  'excel.col.employee.salaryGradeCode':s.excelColEmployeeSalaryGradeCode,
  'excel.col.employee.contractSalary':s.excelColEmployeeContractSalary,
  'excel.col.employee.identityCard':  s.excelColEmployeeIdentityCard,
  'excel.col.employee.address':       s.excelColEmployeeAddress,
  'excel.col.employee.personalEmail': s.excelColEmployeePersonalEmail,
  'excel.col.employee.bankAccount':   s.excelColEmployeeBankAccount,
  'excel.col.employee.bankName':      s.excelColEmployeeBankName,
};

String _parseSummary(String? raw, AppLocalizations s) {
  if (raw == null || raw.isEmpty) return '';
  final colLabels = _buildColLabels(s);
  if (raw.startsWith('preview.create:')) {
    final parts = raw.substring('preview.create:'.length).split('|').where((p) => p.isNotEmpty).join(' · ');
    return '${s.importPreviewCreate}: $parts';
  }
  if (raw.startsWith('preview.delete:')) {
    return '${s.importPreviewDelete}: ${raw.substring('preview.delete:'.length)}';
  }
  // Danh sách thay đổi: "key1,key2:old→new,key3"
  final parts = raw.split(',');
  final labels = <String>[];
  for (final part in parts) {
    final colonIdx = part.indexOf(':');
    if (colonIdx < 0) {
      labels.add(colLabels[part] ?? part);
    } else {
      final key   = part.substring(0, colonIdx);
      final arrow = part.substring(colonIdx + 1).replaceAll('→', ' → ');
      final label = colLabels[key] ?? key;
      labels.add('$label: $arrow');
    }
  }
  return labels.join(' · ');
}

// ─────────────────────────────────────────────────────────────────────────────

class _DiffTile extends StatelessWidget {
  final UniversalImportDiff diff;
  final Color color;
  final bool isError;
  const _DiffTile({required this.diff, required this.color, this.isError = false});

  List<Widget> _buildIdentifierWidgets(String identifier, Color color) {
    final parts = identifier.split('|');
    final code = parts.isNotEmpty ? parts[0] : identifier;
    final name = parts.length > 1 ? parts[1] : '';
    final dept = parts.length > 2 ? parts[2] : '';
    return [
      Text(code,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      if (name.isNotEmpty) ...[
        const SizedBox(width: 4),
        Text('·', style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.5))),
        const SizedBox(width: 4),
        Text(name, style: const TextStyle(fontSize: 12)),
      ],
      if (dept.isNotEmpty) ...[
        const SizedBox(width: 4),
        Text('·', style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.5))),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(dept,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Text('${s.importPreviewRow} ${diff.rowNum}',
              style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          if (diff.identifier.isNotEmpty) ...[
            ..._buildIdentifierWidgets(diff.identifier, color),
            const SizedBox(width: 8),
          ],
          if (diff.summary != null && diff.summary!.isNotEmpty)
            Expanded(
                child: Text(_parseSummary(diff.summary, s),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
          if (isError && diff.error != null)
            Expanded(
                child: Text(diff.error!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
