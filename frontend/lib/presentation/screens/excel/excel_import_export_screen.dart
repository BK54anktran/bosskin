import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/file_picker_excel_utils.dart';
import '../../../core/utils/file_saver_utils.dart';
import '../../../data/repositories/universal_excel_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/export_options_dialog.dart';
import '../../widgets/universal_import_preview_dialog.dart';

/// Màn hình Export / Import tổng hợp kiểu Matrixify.
/// Route: /excel
class ExcelImportExportScreen extends StatefulWidget {
  const ExcelImportExportScreen({super.key});

  @override
  State<ExcelImportExportScreen> createState() =>
      _ExcelImportExportScreenState();
}

class _ExcelImportExportScreenState extends State<ExcelImportExportScreen> {
  final _repo = UniversalExcelRepository();

  final _selectedTypes = <String>{};

  bool _exporting = false;
  bool _previewing = false;
  bool _importing = false;
  bool _metaLoading = false;

  Map<String, ExportMeta> _meta = {};

  ({Uint8List bytes, String filename})? _pickedFile;
  UniversalImportResult? _lastResult;

  static const _allTypes = [
    _TypeEntry('employee',   'Nhân viên',    Icons.people_outline),
    _TypeEntry('department', 'Phòng ban',    Icons.account_tree_outlined),
    _TypeEntry('position',   'Chức vụ',      Icons.work_outline),
    _TypeEntry('shift',      'Ca làm việc',  Icons.schedule_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() => _metaLoading = true);
    try {
      final meta = await _repo.getMeta();
      if (mounted) setState(() { _meta = meta; _metaLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _metaLoading = false);
    }
  }

  Future<void> _export() async {
    if (_metaLoading) return;

    final opts = await showInstantDialog<ExportOptions>(
      context,
      (ctx) => ExportOptionsDialog(
        meta: _meta,
        selectedTypes: _selectedTypes.toList(),
      ),
    );
    if (opts == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      final result = await _repo.exportAll(
        types: opts.types.isEmpty ? null : opts.types,
        selectedColumns: opts.selectedColumns,
        filters: opts.filters,
      );
      await saveFileToDevice(result.bytes, result.filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context).exportSuccess}: ${result.filename}'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(serverMsg(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickFile() async {
    final file = await pickExcelFile();
    if (file == null || !mounted) return;
    setState(() => _pickedFile = file);
  }

  Future<void> _preview() async {
    final file = _pickedFile;
    if (file == null) return;
    setState(() => _previewing = true);
    try {
      final diffs = await _repo.previewImport(file.bytes, file.filename);
      if (!mounted) return;
      final confirmed = await showInstantDialog<bool>(
        context,
        (ctx) => UniversalImportPreviewDialog(
          diffs: diffs,
          onConfirm: () => _doImport(file),
        ),
      );
      if (confirmed == true && mounted) {
        // Import đã xảy ra trong onConfirm — kết quả được download bởi _doImport
      }
    } catch (e) {
      if (mounted) _showError(serverMsg(e));
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _doImport(({Uint8List bytes, String filename}) file) async {
    setState(() => _importing = true);
    try {
      final result = await _repo.importAll(file.bytes, file.filename);
      if (mounted) {
        setState(() {
          _pickedFile = null;
          _importing = false;
          _lastResult = result;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _importing = false);
      rethrow;
    }
  }

  Future<void> _downloadResult() async {
    final r = _lastResult;
    if (r == null) return;
    await saveFileToDevice(r.resultBytes, r.filename);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import / Export dữ liệu'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ExportCard(
                  allTypes: _allTypes,
                  selectedTypes: _selectedTypes,
                  exporting: _exporting,
                  metaLoading: _metaLoading,
                  onToggle: (type) =>
                      setState(() => _selectedTypes.contains(type)
                          ? _selectedTypes.remove(type)
                          : _selectedTypes.add(type)),
                  onExport: _export,
                ),
                const SizedBox(height: 20),
                _ImportCard(
                  pickedFile: _pickedFile,
                  previewing: _previewing,
                  importing: _importing,
                  lastResult: _lastResult,
                  onPick: _pickFile,
                  onClear: () => setState(() => _pickedFile = null),
                  onPreview: _preview,
                  onDownloadResult: _downloadResult,
                  onClearResult: () => setState(() => _lastResult = null),
                  s: s,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Export card ───────────────────────────────────────────────────────────────

class _ExportCard extends StatelessWidget {
  final List<_TypeEntry> allTypes;
  final Set<String> selectedTypes;
  final bool exporting;
  final bool metaLoading;
  final void Function(String) onToggle;
  final VoidCallback onExport;

  const _ExportCard({
    required this.allTypes,
    required this.selectedTypes,
    required this.exporting,
    required this.metaLoading,
    required this.onToggle,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.download_outlined, color: AppTheme.primary),
            const SizedBox(width: 10),
            const Text('Xuất dữ liệu',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: FilledButton.icon(
                onPressed: (exporting || metaLoading) ? null : onExport,
                icon: (exporting || metaLoading)
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.tune_outlined, size: 16),
                label: Text(selectedTypes.isEmpty
                    ? 'Chọn & Xuất'
                    : 'Chọn & Xuất (${selectedTypes.length})'),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Chọn module muốn xuất. Bỏ trống để xuất toàn bộ.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: allTypes.map((t) {
              final selected = selectedTypes.contains(t.key);
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: FilterChip(
                  avatar: Icon(t.icon,
                      size: 16,
                      color: selected
                          ? Colors.white
                          : AppTheme.textSecondary),
                  label: Text(t.label),
                  selected: selected,
                  onSelected: (_) => onToggle(t.key),
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppTheme.textPrimary),
                  checkmarkColor: Colors.white,
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 14, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'File Excel xuất ra có cột "Lệnh" (hoặc "Command"). '
                  'Điền CREATE / UPDATE / DELETE vào cột đó rồi import lại để thực hiện thay đổi hàng loạt.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Import card ───────────────────────────────────────────────────────────────

class _ImportCard extends StatelessWidget {
  final ({Uint8List bytes, String filename})? pickedFile;
  final bool previewing;
  final bool importing;
  final UniversalImportResult? lastResult;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback onPreview;
  final VoidCallback onDownloadResult;
  final VoidCallback onClearResult;
  final AppLocalizations s;

  const _ImportCard({
    required this.pickedFile,
    required this.previewing,
    required this.importing,
    required this.lastResult,
    required this.onPick,
    required this.onClear,
    required this.onPreview,
    required this.onDownloadResult,
    required this.onClearResult,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.upload_outlined, color: AppTheme.secondary),
            const SizedBox(width: 10),
            const Text('Nhập dữ liệu',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Chọn file Excel (đã điền cột Lệnh) để xem trước và nhập.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          if (pickedFile == null)
            _DropZone(onTap: onPick)
          else
            _SelectedFile(
              filename: pickedFile!.filename,
              bytes: pickedFile!.bytes,
              onClear: onClear,
              onPreview: onPreview,
              previewing: previewing || importing,
              s: s,
            ),
          if (lastResult != null) ...[
            const SizedBox(height: 12),
            _ResultBanner(
              result: lastResult!,
              onDownload: onDownloadResult,
              onDismiss: onClearResult,
            ),
          ],
          const SizedBox(height: 16),
          _ImportSteps(),
        ]),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final VoidCallback onTap;
  const _DropZone({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3),
              style: BorderStyle.solid,
              width: 1.5,
            ),
          ),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 32, color: AppTheme.primary.withValues(alpha: 0.6)),
                const SizedBox(height: 8),
                Text('Nhấn để chọn file .xlsx',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primary.withValues(alpha: 0.8))),
              ]),
        ),
      ),
    );
  }
}

class _SelectedFile extends StatelessWidget {
  final String filename;
  final Uint8List bytes;
  final VoidCallback onClear;
  final VoidCallback onPreview;
  final bool previewing;
  final AppLocalizations s;

  const _SelectedFile({
    required this.filename,
    required this.bytes,
    required this.onClear,
    required this.onPreview,
    required this.previewing,
    required this.s,
  });

  String get _size {
    final kb = bytes.lengthInBytes / 1024;
    return kb < 1024
        ? '${kb.toStringAsFixed(1)} KB'
        : '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(children: [
        const Icon(Icons.insert_drive_file_outlined,
            color: AppTheme.success, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(filename,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
            Text(_size,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: FilledButton.icon(
            onPressed: previewing ? null : onPreview,
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.secondary),
            icon: previewing
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.preview_outlined, size: 16),
            label: const Text('Xem trước & Nhập'),
          ),
        ),
        const SizedBox(width: 6),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Xóa file',
            color: AppTheme.textSecondary,
          ),
        ),
      ]),
    );
  }
}

class _ImportSteps extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.download_outlined,     'Xuất file mẫu ở trên'),
      (Icons.edit_outlined,          'Điền cột Lệnh: CREATE / UPDATE / DELETE'),
      (Icons.upload_file_outlined,   'Chọn file đã điền'),
      (Icons.preview_outlined,       'Xem trước thay đổi'),
      (Icons.check_circle_outlined,  'Xác nhận → nhận file kết quả'),
    ];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
              child: Divider(color: AppTheme.border, thickness: 1));
        }
        final (icon, label) = steps[i ~/ 2];
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppTheme.primary),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 80,
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ),
        ]);
      }),
    );
  }
}

// ── Result banner ─────────────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final UniversalImportResult result;
  final VoidCallback onDownload;
  final VoidCallback onDismiss;
  const _ResultBanner({
    required this.result,
    required this.onDownload,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = result.error > 0;
    final color = hasError ? AppTheme.warning : AppTheme.success;
    final parts = <String>[];
    if (result.ok    > 0) parts.add('${result.ok} thành công');
    if (result.error > 0) parts.add('${result.error} lỗi');
    if (result.skip  > 0) parts.add('${result.skip} bỏ qua');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(hasError ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(parts.join(' · '),
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: TextButton.icon(
            onPressed: onDownload,
            icon: Icon(Icons.download_outlined, size: 16, color: color),
            label: Text('Tải file kết quả', style: TextStyle(color: color, fontSize: 12)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ),
        IconButton(
          onPressed: onDismiss,
          icon: const Icon(Icons.close, size: 16),
          color: AppTheme.textSecondary,
          tooltip: 'Đóng',
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

// ── Type entry ────────────────────────────────────────────────────────────────

class _TypeEntry {
  final String key;
  final String label;
  final IconData icon;
  const _TypeEntry(this.key, this.label, this.icon);
}
