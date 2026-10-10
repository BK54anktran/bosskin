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
import '../../widgets/pagination_bar.dart';
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
  final _historyKey = GlobalKey<_HistoryCardState>();

  ({Uint8List bytes, String filename})? _pickedFile;
  UniversalImportResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  List<_TypeEntry> _buildTypes(AppLocalizations s) => [
    _TypeEntry('employee',          s.excelModuleEmployee,          Icons.people_outline),
    _TypeEntry('department',        s.excelModuleDepartment,        Icons.account_tree_outlined),
    _TypeEntry('position',          s.excelModulePosition,          Icons.work_outline),
    _TypeEntry('shift',             s.excelModuleShift,             Icons.schedule_outlined),
    _TypeEntry('shift_assignment',  s.excelModuleShiftAssignment,   Icons.calendar_month_outlined),
    _TypeEntry('attendance',        s.excelModuleAttendance,        Icons.fingerprint_outlined),
    _TypeEntry('salary_grade',      s.excelModuleSalaryGrade,       Icons.bar_chart_outlined),
    _TypeEntry('salary_formula',    s.excelModuleSalaryFormula,     Icons.functions_outlined),
    _TypeEntry('formula_variable',  s.excelModuleFormulaVariable,   Icons.data_object_outlined),
    _TypeEntry('payroll',           s.excelModulePayroll,           Icons.payments_outlined),
    _TypeEntry('leave_type',        s.excelModuleLeaveType,         Icons.event_available_outlined),
    _TypeEntry('leave_grant',       s.excelModuleLeaveGrant,        Icons.beach_access_outlined),
  ];

  Future<void> _loadMeta() async {
    setState(() => _metaLoading = true);
    try {
      final meta = await _repo.getMeta();
      if (mounted) setState(() { _meta = meta; _metaLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _metaLoading = false);
    }
  }

  void _reloadHistory() => _historyKey.currentState?.reload();

  Future<void> _export(AppLocalizations s) async {
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
            content: Text('${s.exportSuccess}: ${result.filename}'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _reloadHistory();
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
      await showInstantDialog<bool>(
        context,
        (ctx) => UniversalImportPreviewDialog(
          diffs: diffs,
          onConfirm: () => _doImport(file),
        ),
      );
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
        _reloadHistory();
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

  Future<void> _downloadHistoryFile(int id, String filename) async {
    try {
      final bytes = await _repo.downloadHistoryFile(id);
      await saveFileToDevice(bytes, filename);
    } catch (e) {
      if (mounted) _showError(serverMsg(e));
    }
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
    final allTypes = _buildTypes(s);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.excelScreenTitle),
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
                  allTypes: allTypes,
                  selectedTypes: _selectedTypes,
                  exporting: _exporting,
                  metaLoading: _metaLoading,
                  onToggle: (type) =>
                      setState(() => _selectedTypes.contains(type)
                          ? _selectedTypes.remove(type)
                          : _selectedTypes.add(type)),
                  onExport: () => _export(s),
                  s: s,
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
                const SizedBox(height: 20),
                _HistoryCard(
                  key: _historyKey,
                  onDownload: _downloadHistoryFile,
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
  final AppLocalizations s;

  const _ExportCard({
    required this.allTypes,
    required this.selectedTypes,
    required this.exporting,
    required this.metaLoading,
    required this.onToggle,
    required this.onExport,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.upload_outlined, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text(s.excelExportTitle,
                style: const TextStyle(
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
                    ? s.excelExportButton
                    : s.excelExportButtonN(selectedTypes.length)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            s.excelExportSubtitle,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
              color: AppTheme.tint(AppTheme.primary),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, size: 14, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.excelExportHint,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8)),
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
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.download_outlined, color: AppTheme.secondary),
            const SizedBox(width: 10),
            Text(s.excelImportTitle,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text(
            s.excelImportSubtitle,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          if (pickedFile == null)
            _DropZone(onTap: onPick, s: s)
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
              s: s,
            ),
          ],
          const SizedBox(height: 16),
          _ImportSteps(s: s),
        ]),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final VoidCallback onTap;
  final AppLocalizations s;
  const _DropZone({required this.onTap, required this.s});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3),
              style: BorderStyle.solid,
              width: 1.5,
            ),
          ),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.cloud_download_outlined,
                    size: 32, color: AppTheme.primary.withValues(alpha: 0.6)),
                const SizedBox(height: 8),
                Text(s.excelImportDropzone,
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
        color: AppTheme.tint(AppTheme.secondary),
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
            label: Text(s.excelImportPreviewBtn),
          ),
        ),
        const SizedBox(width: 6),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
            tooltip: s.excelImportClearFile,
            color: AppTheme.textSecondary,
          ),
        ),
      ]),
    );
  }
}

class _ImportSteps extends StatelessWidget {
  final AppLocalizations s;
  const _ImportSteps({required this.s});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.upload_outlined,       s.excelStepExport),
      (Icons.edit_outlined,         s.excelStepFill),
      (Icons.download_outlined,     s.excelStepPick),
      (Icons.preview_outlined,      s.excelStepPreview),
      (Icons.check_circle_outlined, s.excelStepConfirm),
    ];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
              child: Divider(color: AppTheme.border, thickness: 1));
        }
        final (icon, label) = steps[i ~/ 2];
        return Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: AppTheme.primary),
            ),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ]),
        );
      }),
    );
  }
}

// ── Result banner ─────────────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final UniversalImportResult result;
  final VoidCallback onDownload;
  final VoidCallback onDismiss;
  final AppLocalizations s;

  const _ResultBanner({
    required this.result,
    required this.onDownload,
    required this.onDismiss,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = result.error > 0;
    final color = hasError ? AppTheme.warning : AppTheme.success;
    final parts = <String>[];
    if (result.ok    > 0) parts.add(s.excelImportResultOk(result.ok));
    if (result.error > 0) parts.add(s.excelImportResultError(result.error));
    if (result.skip  > 0) parts.add(s.excelImportResultSkip(result.skip));

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
            label: Text(s.excelImportResultDownload, style: TextStyle(color: color, fontSize: 12)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ),
        IconButton(
          onPressed: onDismiss,
          icon: const Icon(Icons.close, size: 16),
          color: AppTheme.textSecondary,
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatefulWidget {
  final Future<void> Function(int id, String filename) onDownload;
  final AppLocalizations s;

  const _HistoryCard({required super.key, required this.onDownload, required this.s});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  final _repo = UniversalExcelRepository();

  List<ExcelHistoryEntry> _items = [];
  int _total = 0;
  bool _loading = false;

  int _page = 0;
  int _pageSize = 10;
  String? _filterType;
  String? _filterModule;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() {
    setState(() => _page = 0);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _repo.getHistoryPaged(
        type: _filterType,
        module: _filterModule,
        dateFrom: _dateFrom != null
            ? '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2,'0')}-${_dateFrom!.day.toString().padLeft(2,'0')}'
            : null,
        dateTo: _dateTo != null
            ? '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2,'0')}-${_dateTo!.day.toString().padLeft(2,'0')}'
            : null,
        page: _page,
        size: _pageSize,
      );
      if (mounted) setState(() { _items = result.items; _total = result.total; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) _dateFrom = picked; else _dateTo = picked;
      _page = 0;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Icon(Icons.history_outlined, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Text(s.excelHistoryTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          // Filter bar
          Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<String?>(
                initialValue: _filterType,
                decoration: InputDecoration(
                  labelText: s.excelHistoryFilterType,
                  labelStyle: const TextStyle(fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                items: [
                  DropdownMenuItem(value: null,     child: Text(s.excelHistoryModuleAll,       style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'EXPORT', child: Text(s.excelHistoryTypeExport,       style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'IMPORT', child: Text(s.excelHistoryTypeImport,       style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'REPORT', child: Text(s.excelHistoryTypeReport,       style: const TextStyle(fontSize: 12))),
                ],
                onChanged: (v) { setState(() { _filterType = v; _page = 0; }); _load(); },
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String?>(
                initialValue: _filterModule,
                decoration: InputDecoration(
                  labelText: s.excelHistoryFilterModule,
                  labelStyle: const TextStyle(fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                items: [
                  DropdownMenuItem(value: null,              child: Text(s.excelHistoryModuleAll,        style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'employee',        child: Text(s.excelModuleEmployee,          style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'department',      child: Text(s.excelModuleDepartment,        style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'position',        child: Text(s.excelModulePosition,          style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'shift',            child: Text(s.excelModuleShift,            style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'shift_assignment',child: Text(s.excelModuleShiftAssignment,  style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'attendance',      child: Text(s.excelModuleAttendance,       style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'salary_grade',     child: Text(s.excelModuleSalaryGrade,     style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'salary_formula',   child: Text(s.excelModuleSalaryFormula,   style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'formula_variable', child: Text(s.excelModuleFormulaVariable, style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'payroll',          child: Text(s.excelModulePayroll,          style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'leave_type',       child: Text(s.excelModuleLeaveType,       style: const TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'leave_grant',      child: Text(s.excelModuleLeaveGrant,      style: const TextStyle(fontSize: 12))),
                ],
                onChanged: (v) { setState(() { _filterModule = v; _page = 0; }); _load(); },
              ),
            ),
            _DateChip(
              label: _dateFrom == null ? s.excelHistoryFilterFrom : _fmt(_dateFrom!),
              onTap: () => _pickDate(true),
              onClear: _dateFrom == null ? null : () { setState(() { _dateFrom = null; _page = 0; }); _load(); },
            ),
            _DateChip(
              label: _dateTo == null ? s.excelHistoryFilterTo : _fmt(_dateTo!),
              onTap: () => _pickDate(false),
              onClear: _dateTo == null ? null : () { setState(() { _dateTo = null; _page = 0; }); _load(); },
            ),
          ]),
          const SizedBox(height: 12),
          // List
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(s.excelHistoryEmpty,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            )
          else
            ..._items.map((e) => _HistoryTile(entry: e, onDownload: widget.onDownload, s: s)),
          // Pagination
          if (_total > 0) ...[
            const SizedBox(height: 8),
            PaginationBar(
              total: _total,
              page: _page,
              pageSize: _pageSize,
              onPageSizeChanged: (sz) { setState(() { _pageSize = sz; _page = 0; }); _load(); },
              onPrev: _page > 0 ? () { setState(() => _page--); _load(); } : null,
              onNext: (_page + 1) * _pageSize < _total ? () { setState(() => _page++); _load(); } : null,
            ),
          ],
        ]),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateChip({required this.label, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final active = onClear != null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: active ? AppTheme.primary : AppTheme.border),
            borderRadius: BorderRadius.circular(6),
            color: active ? AppTheme.primary.withValues(alpha: 0.06) : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_outlined, size: 13,
                color: active ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12,
                color: active ? AppTheme.primary : AppTheme.textSecondary)),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 13, color: AppTheme.primary),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatefulWidget {
  final ExcelHistoryEntry entry;
  final Future<void> Function(int id, String filename) onDownload;
  final AppLocalizations s;

  const _HistoryTile({
    required this.entry,
    required this.onDownload,
    required this.s,
  });

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  bool _downloading = false;

  String _moduleLabel(AppLocalizations s) {
    final labels = <String, String>{
      'employee':        s.excelModuleEmployee,
      'department':      s.excelModuleDepartment,
      'position':        s.excelModulePosition,
      'shift':           s.excelModuleShift,
      'shift_assignment': s.excelModuleShiftAssignment,
      'attendance':      s.excelModuleAttendance,
      'payroll':         s.excelModulePayroll,
      'salary_grade':     s.excelModuleSalaryGrade,
      'salary_formula':   s.excelModuleSalaryFormula,
      'formula_variable': s.excelModuleFormulaVariable,
      'leave_type':       s.excelModuleLeaveType,
      'leave_grant':      s.excelModuleLeaveGrant,
    };
    return widget.entry.module
        .split(',')
        .map((m) => labels[m.trim()] ?? (m.trim() == 'universal' ? s.excelModuleUniversal : m.trim()))
        .join(', ');
  }

  Future<void> _handleDownload() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await Future.microtask(
          () => widget.onDownload(widget.entry.id, widget.entry.filename));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final s = widget.s;
    final isImport = entry.type == 'IMPORT';
    final isReport = entry.type == 'REPORT';
    final Color color = isImport
        ? AppTheme.secondary
        : isReport
            ? const Color(0xFF7C3AED)
            : AppTheme.primary;
    final String typeLabel = isImport
        ? s.excelHistoryTypeImport
        : isReport
            ? s.excelHistoryTypeReport
            : s.excelHistoryTypeExport;
    final IconData icon = isImport
        ? Icons.upload_outlined
        : isReport
            ? Icons.summarize_outlined
            : Icons.download_outlined;

    final parts = <String>[];
    if ((entry.okCount ?? 0)    > 0) parts.add(s.excelHistoryOk(entry.okCount!));
    if ((entry.errorCount ?? 0) > 0) parts.add(s.excelHistoryError(entry.errorCount!));
    if ((entry.skipCount ?? 0)  > 0) parts.add(s.excelHistorySkip(entry.skipCount!));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(typeLabel,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_moduleLabel(s),
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(entry.filename,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            if (parts.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(parts.join(' · '),
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 2),
            Row(children: [
              Text(_formatDate(entry.createdAt),
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
              if (entry.performedBy != null) ...[
                Text(' · ',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                Text(entry.performedBy!,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500)),
              ],
            ]),
          ]),
        ),
        if (entry.fileUrl != null)
          MouseRegion(
            cursor: _downloading
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: SizedBox(
              width: 36, height: 36,
              child: _downloading
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : IconButton(
                      onPressed: _handleDownload,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      color: color,
                      tooltip: s.excelHistoryDownload,
                      visualDensity: VisualDensity.compact,
                    ),
            ),
          ),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Type entry ────────────────────────────────────────────────────────────────

class _TypeEntry {
  final String key;
  final String label;
  final IconData icon;
  const _TypeEntry(this.key, this.label, this.icon);
}

