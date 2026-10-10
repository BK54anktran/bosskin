import 'dart:typed_data';

import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/file_picker_excel_utils.dart';
import '../../../core/utils/file_saver_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../data/models/work_calendar.dart';
import '../../../data/repositories/work_calendar_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/holiday_widgets.dart';
import '../../widgets/import_preview_dialog.dart';
import '../../widgets/status_badge.dart';

/// Tab "Lịch làm việc" trong Cài đặt công ty (bước J): lịch tuần (mặc định + theo phòng ban) và ngày lễ theo năm.
/// Năm công ty chưa chỉnh dùng danh sách mẫu của hệ thống; sửa lần đầu sẽ chép mẫu sang công ty.
class WorkCalendarTab extends StatefulWidget {
  const WorkCalendarTab({super.key});

  @override
  State<WorkCalendarTab> createState() => _WorkCalendarTabState();
}

class _DeptOption {
  final int id;
  final String name;
  final int level;
  const _DeptOption(this.id, this.name, this.level);
}

class _WorkCalendarTabState extends State<WorkCalendarTab> {
  final _repo = WorkCalendarRepository();
  int _year = DateTime.now().year;
  bool _loading = true;
  bool _loadingHolidays = false;
  bool _busy = false;
  String? _error;
  List<WorkCalendar> _calendars = [];
  List<_DeptOption> _depts = [];
  List<Holiday> _holidays = [];
  bool _customized = false;

  bool get _canManage {
    final u = AuthService.instance.currentUser;
    return u != null && (u.isSystemAdmin || (u.can('CALENDAR_VIEW') && u.can('CALENDAR_MANAGE')));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _repo.getCalendars(),
        ApiService.instance.dio.get('/work-calendars/departments'),
      ]);
      final deptData = (results[1] as dynamic).data as List;
      _calendars = results[0] as List<WorkCalendar>;
      _depts = deptData
          .map((e) => _DeptOption((e['id'] as num).toInt(), e['name'] as String? ?? '', (e['level'] as num?)?.toInt() ?? 0))
          .toList();
      await _loadHolidays();
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHolidays() async {
    setState(() => _loadingHolidays = true);
    try {
      final r = await _repo.getHolidays(_year);
      if (!mounted) return;
      setState(() {
        _holidays = r.items;
        _customized = r.customized;
      });
    } catch (e) {
      if (mounted) _snack(serverMsg(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingHolidays = false);
    }
  }

  void _snack(String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: error ? AppTheme.error : null),
      );

  Future<void> _run(Future<void> Function() action, {bool reloadCalendars = false}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (reloadCalendars) {
        final c = await _repo.getCalendars();
        if (mounted) setState(() => _calendars = c);
      } else {
        await _loadHolidays();
      }
    } catch (e) {
      if (mounted) _snack(serverMsg(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Lịch tuần ────────────────────────────────────────────────────────────

  Future<void> _editCalendar(WorkCalendar? cal) async {
    final isDefault = cal?.isDefault ?? false;
    final usedElsewhere = <int>{
      for (final c in _calendars)
        if (!c.isDefault && c.id != cal?.id) ...c.departmentIds,
    };
    final result = await showDialog<_CalendarResult>(
      context: context,
      builder: (ctx) => _CalendarDialog(
        calendar: cal,
        isDefault: isDefault,
        departments: _depts,
        usedElsewhere: usedElsewhere,
      ),
    );
    if (result == null) return;
    await _run(() async {
      if (isDefault) {
        await _repo.saveDefault(result.pattern);
      } else if (cal?.id == null) {
        await _repo.createCalendar(result.name, result.pattern, result.departmentIds);
      } else {
        await _repo.updateCalendar(cal!.id!, result.name, result.pattern, result.departmentIds);
      }
    }, reloadCalendars: true);
  }

  Future<void> _deleteCalendar(WorkCalendar cal) async {
    final s = AppLocalizations.of(context);
    final ok = await _confirm(s.workCalendarDeleteConfirm(cal.name));
    if (ok != true) return;
    await _run(() => _repo.deleteCalendar(cal.id!), reloadCalendars: true);
  }

  // ── Ngày lễ ──────────────────────────────────────────────────────────────

  Future<void> _editHoliday(Holiday? h) async {
    final result = await showDialog<Holiday>(
      context: context,
      builder: (ctx) => HolidayFormDialog(existing: h, year: _year),
    );
    if (result == null) return;
    await _run(() => h?.id == null ? _repo.createHoliday(result) : _repo.updateHoliday(h!.id!, result));
  }

  Future<void> _deleteHoliday(Holiday h) async {
    final s = AppLocalizations.of(context);
    final ok = await _confirm(s.holidayDeleteConfirm(h.name, DateFormat('dd/MM/yyyy').format(h.date)));
    if (ok != true) return;
    await _run(() => _repo.deleteHoliday(h.id!));
  }

  Future<bool?> _confirm(String message) {
    final s = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final res = await _repo.exportHolidays(_year);
      final disposition = res.headers.value('content-disposition') ?? '';
      final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
      await saveFileToDevice(Uint8List.fromList(res.data!), match?.group(1) ?? 'holidays_$_year.xlsx');
    } catch (e) {
      if (mounted) _snack(serverMsg(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final s = AppLocalizations.of(context);
    final picked = await pickExcelFile();
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final raw = await _repo.previewImportHolidays(picked.bytes, picked.filename);
      if (!mounted) return;
      final diffs = raw.map((d) {
        final m = d as Map<String, dynamic>;
        return ImportDiffRow(
          action: m['action'] ?? 'CREATE',
          code: m['code'] ?? '',
          name: m['name'] ?? '',
          changes: ((m['changes'] as List?) ?? const [])
              .map((c) => ImportFieldChange(
                    field: _fieldLabel(s, c['field'] as String? ?? ''),
                    oldValue: _valueLabel(s, c['oldValue'] as String? ?? ''),
                    newValue: _valueLabel(s, c['newValue'] as String? ?? ''),
                  ))
              .toList(),
          warnings: ((m['warnings'] as List?) ?? const []).map((w) => w.toString()).toList(),
        );
      }).toList();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => ImportPreviewDialog(
          diffs: diffs,
          onConfirm: () => _repo.importHolidays(picked.bytes, picked.filename),
        ),
      );
      if (confirmed == true && mounted) {
        _snack(s.importSuccess);
        await _loadHolidays();
      }
    } catch (e) {
      if (mounted) _snack(serverMsg(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fieldLabel(AppLocalizations s, String f) => switch (f) {
        'name' => s.holidayName,
        'type' => s.holidayType,
        'paid' => s.holidayPaidLabel,
        _ => f,
      };

  String _valueLabel(AppLocalizations s, String v) => switch (v) {
        'true' => s.holidayPaid,
        'false' => s.holidayUnpaid,
        'HOLIDAY' || 'COMPENSATORY' || 'SWAP_WORKDAY' => holidayTypeLabel(s, v),
        _ => v,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
                  ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                _weekCard(s),
                const SizedBox(height: 12),
                _holidayCard(s),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekCard(AppLocalizations s) {
    final deptName = {for (final d in _depts) d.id: d.name};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(s.workCalendarWeekTitle, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (_canManage)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _editCalendar(null),
                icon: const Icon(Icons.add, size: 16),
                label: Text(s.workCalendarAdd),
              ),
          ]),
          const SizedBox(height: 4),
          Text(s.workCalendarWeekHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          for (final c in _calendars)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.isDefault ? s.workCalendarDefaultName : c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 6),
                WeekPatternChips(pattern: c.weekPattern),
                const SizedBox(height: 4),
                Text(
                  c.isDefault
                      ? s.workCalendarDefaultHint
                      : (c.departmentIds.isEmpty
                          ? s.workCalendarNoDepartments
                          : c.departmentIds.map((id) => deptName[id] ?? '#$id').join(', ')),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                Text(s.workCalendarWeekDays(_fmtDays(c.weekPattern)),
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
              trailing: !_canManage
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: s.edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: _busy ? null : () => _editCalendar(c),
                      ),
                      if (!c.isDefault)
                        IconButton(
                          tooltip: s.delete,
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                          onPressed: _busy ? null : () => _deleteCalendar(c),
                        ),
                    ]),
            ),
        ]),
      ),
    );
  }

  /// Số công chuẩn một tuần theo lịch: F = 1, H = 0,5.
  String _fmtDays(String p) =>
      formatDays(p.split('').fold<double>(0, (a, c) => a + (c == 'F' ? 1 : c == 'H' ? 0.5 : 0)));

  Widget _holidayCard(AppLocalizations s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(s.holidayTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
              HolidayYearBar(year: _year, onChanged: (y) {
                setState(() => _year = y);
                _loadHolidays();
              }),
              StatusBadge(
                label: _customized ? s.holidayCustomized : s.holidayUsingTemplate,
                color: _customized ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (_canManage)
              FilledButton.icon(
                onPressed: _busy ? null : () => _editHoliday(null),
                icon: const Icon(Icons.add, size: 16),
                label: Text(s.holidayAdd),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: Text(s.exportExcel),
            ),
            if (_canManage)
              OutlinedButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: Text(s.importExcel),
              ),
          ]),
          const SizedBox(height: 4),
          Text(_customized ? s.holidayCustomizedHint : s.holidayTemplateHint,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          if (_loadingHolidays)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (_holidays.isEmpty)
            EmptyState(icon: Icons.event_busy_outlined, message: s.holidayEmpty)
          else
            for (final h in _holidays)
              HolidayListTile(
                holiday: h,
                onEdit: _canManage && !_busy ? () => _editHoliday(h) : null,
                onDelete: _canManage && !_busy ? () => _deleteHoliday(h) : null,
              ),
        ]),
      ),
    );
  }
}

/// 7 ô T2→CN: xanh = cả ngày, vàng = nửa ngày, xám = nghỉ. [onTap] có thì bấm để đổi F → H → O.
class WeekPatternChips extends StatelessWidget {
  final String pattern;
  final void Function(int index)? onTap;
  const WeekPatternChips({super.key, required this.pattern, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final labels = [s.dowMon, s.dowTue, s.dowWed, s.dowThu, s.dowFri, s.dowSat, s.dowSun];
    return Wrap(spacing: 4, runSpacing: 4, children: [
      for (var i = 0; i < 7; i++) _chip(s, labels[i], i < pattern.length ? pattern[i] : 'F', i),
    ]);
  }

  Widget _chip(AppLocalizations s, String label, String code, int i) {
    final (bg, fg, tip) = switch (code) {
      'H' => (AppTheme.tint(AppTheme.warning), const Color(0xFF92400E), s.workDayHalf),
      'O' => (AppTheme.surfaceAlt, AppTheme.textSecondary, s.workDayOff),
      _ => (AppTheme.tint(AppTheme.secondary), const Color(0xFF166534), s.workDayFull),
    };
    final box = Tooltip(
      message: tip,
      child: Container(
        width: onTap != null ? 44 : 34,
        height: onTap != null ? 40 : 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
          if (onTap != null)
            Text(code == 'H' ? '½' : code == 'O' ? '–' : '1', style: TextStyle(fontSize: 11, color: fg)),
        ]),
      ),
    );
    if (onTap == null) return box;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => onTap!(i), child: box),
    );
  }
}

class _CalendarResult {
  final String name;
  final String pattern;
  final List<int> departmentIds;
  const _CalendarResult(this.name, this.pattern, this.departmentIds);
}

class _CalendarDialog extends StatefulWidget {
  final WorkCalendar? calendar;
  final bool isDefault;
  final List<_DeptOption> departments;
  final Set<int> usedElsewhere;
  const _CalendarDialog({
    required this.calendar,
    required this.isDefault,
    required this.departments,
    required this.usedElsewhere,
  });

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late final TextEditingController _nameCtrl;
  late String _pattern;
  late Set<int> _deptIds;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.calendar?.name ?? '');
    _pattern = widget.calendar?.weekPattern ?? defaultWeekPattern;
    _deptIds = {...?widget.calendar?.departmentIds};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _cycle(int i) {
    const next = {'F': 'H', 'H': 'O', 'O': 'F'};
    setState(() => _pattern = _pattern.replaceRange(i, i + 1, next[_pattern[i]] ?? 'F'));
  }

  void _submit() {
    final s = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    if (!widget.isDefault && name.isEmpty) {
      setState(() => _nameError = s.workCalendarNameRequired);
      return;
    }
    Navigator.pop(context, _CalendarResult(name, _pattern, _deptIds.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.isDefault
          ? s.workCalendarDefaultName
          : (widget.calendar == null ? s.workCalendarAdd : s.workCalendarEdit)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!widget.isDefault) ...[
              TextField(
                controller: _nameCtrl,
                maxLength: 100,
                decoration: InputDecoration(labelText: s.workCalendarName, errorText: _nameError),
              ),
              const SizedBox(height: 4),
            ],
            Text(s.workCalendarPatternHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            WeekPatternChips(pattern: _pattern, onTap: _cycle),
            if (!widget.isDefault) ...[
              const SizedBox(height: 16),
              Text(s.workCalendarDepartments, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(s.workCalendarDepartmentsHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              for (final d in widget.departments)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.only(left: 16.0 * d.level),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _deptIds.contains(d.id),
                  title: Text(d.name),
                  subtitle: widget.usedElsewhere.contains(d.id) && !_deptIds.contains(d.id)
                      ? Text(s.workCalendarDeptHasOther, style: const TextStyle(fontSize: 11))
                      : null,
                  onChanged: (v) => setState(() => v == true ? _deptIds.add(d.id) : _deptIds.remove(d.id)),
                ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}
