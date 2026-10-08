import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/file_saver_utils.dart';
import '../../../../core/utils/file_picker_excel_utils.dart';
import '../../../../data/models/attendance.dart';
import '../../../../data/models/department_model.dart';
import '../../../../data/models/employee.dart';
import '../../../../data/repositories/attendance_repository.dart';
import '../../../../data/repositories/company_setting_repository.dart';
import '../../../../data/repositories/leave_repository.dart';
import '../../../../data/repositories/employee_repository.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../../data/services/department_service.dart';
import '../../../widgets/department_picker_field.dart';
import '../../../widgets/import_preview_dialog.dart';
import '../attendance_shared.dart';
import '../widgets/attendance_grid.dart';

// ── Tab key ───────────────────────────────────────────────────────────────────

class AttendanceTimesheetTabKey extends GlobalKey<_AttendanceTimesheetTabState> {
  const AttendanceTimesheetTabKey() : super.constructor();
  Future<void> exportExcel() => currentState?._exportExcel() ?? Future.value();
  Future<void> importExcel() => currentState?._importExcel() ?? Future.value();
}

// ── Tab widget ────────────────────────────────────────────────────────────────

class AttendanceTimesheetTab extends StatefulWidget {
  final AttViewRangeMode initialMode;
  const AttendanceTimesheetTab({super.key, this.initialMode = AttViewRangeMode.payroll});

  @override
  State<AttendanceTimesheetTab> createState() => _AttendanceTimesheetTabState();
}

class _AttendanceTimesheetTabState extends State<AttendanceTimesheetTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _repo = AttendanceRepository();
  final _leaveRepo = LeaveRepository();
  final _empRepo = EmployeeRepository();
  final _settingRepo = CompanySettingRepository();

  List<Employee> _employees = [];
  List<DepartmentFlat> _depts = [];
  int? _filterDept;
  Employee? _selected;

  List<TimesheetRow> _rows = [];
  bool _loading = false;
  String? _error;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _weekFocus = DateTime.now();
  DateTimeRange? _customRange;
  late AttViewRangeMode _rangeMode;
  int _cutoffDay = 1;

  bool _dayNightMode = false;
  bool _otEnabled = true;

  final Set<String> _selectedDates = {};
  bool _bulkLoading = false;
  bool _selectionMode = false;

  final Set<String> _editingRows = {};
  final Map<String, TextEditingController> _editCtrls = {};

  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _rangeMode = widget.initialMode;
    _init();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    for (final c in _editCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Range helpers ──────────────────────────────────────────────────────────

  DateTimeRange get _currentRange {
    switch (_rangeMode) {
      case AttViewRangeMode.payroll:
        final DateTime from;
        final DateTime to;
        if (_cutoffDay <= 1) {
          from = DateTime(_month.year, _month.month, 1);
          to = DateTime(_month.year, _month.month + 1, 0);
        } else {
          final prev = DateTime(_month.year, _month.month - 1);
          final maxPrev = DateTime(prev.year, prev.month + 1, 0).day;
          from = DateTime(prev.year, prev.month, _cutoffDay.clamp(1, maxPrev));
          final maxCur = DateTime(_month.year, _month.month + 1, 0).day;
          to = DateTime(_month.year, _month.month, (_cutoffDay - 1).clamp(1, maxCur));
        }
        return DateTimeRange(start: from, end: to);
      case AttViewRangeMode.week:
        final base = DateTime(_weekFocus.year, _weekFocus.month, _weekFocus.day);
        final start = base.subtract(Duration(days: base.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return DateTimeRange(start: start, end: end);
      case AttViewRangeMode.custom:
        return _customRange ??
            DateTimeRange(
              start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
              end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 6),
            );
    }
  }

  String get _rangeLabel {
    final range = _currentRange;
    switch (_rangeMode) {
      case AttViewRangeMode.payroll:
        return DateFormat('MM/yyyy').format(_month);
      case AttViewRangeMode.week:
        return '${DateFormat('dd/MM').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}';
      case AttViewRangeMode.custom:
        return '${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}';
    }
  }

  void _shiftRange(int direction) {
    setState(() {
      switch (_rangeMode) {
        case AttViewRangeMode.payroll:
          _month = DateTime(_month.year, _month.month + direction);
          break;
        case AttViewRangeMode.week:
          _weekFocus = DateTime(_weekFocus.year, _weekFocus.month, _weekFocus.day + (7 * direction));
          break;
        case AttViewRangeMode.custom:
          final current = _currentRange;
          final span = current.end.difference(current.start).inDays + 1;
          _customRange = DateTimeRange(
            start: current.start.add(Duration(days: span * direction)),
            end: current.end.add(Duration(days: span * direction)),
          );
          break;
      }
    });
    _loadTimesheet();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Selection ──────────────────────────────────────────────────────────────

  void _toggleSelectDate(String key) {
    setState(() {
      if (_selectedDates.contains(key)) {
        _selectedDates.remove(key);
      } else {
        _selectedDates.add(key);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final allKeys = _mergedRows.map((r) => _dateKey(r.first.date)).toSet();
      if (_selectedDates.containsAll(allKeys)) {
        _selectedDates.clear();
      } else {
        _selectedDates.addAll(allKeys);
      }
    });
  }

  // ── Bulk actions ───────────────────────────────────────────────────────────

  Future<void> _bulkApprove() async {
    final s = AppLocalizations.of(context);
    final keys = Set<String>.from(_selectedDates);
    final rows = _mergedRows.where((r) => keys.contains(_dateKey(r.first.date))).toList();
    final unapprovedRows = rows.expand((r) => r.rows).where((r) => !r.approved).toList();
    if (unapprovedRows.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.bulkApprove),
        content: Text('${s.bulkApprove} ${unapprovedRows.length} ${s.checkIn.toLowerCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.approve)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _bulkLoading = true);
    int success = 0;
    for (final row in unapprovedRows) {
      try {
        await _repo.approveAttendance(row.attendanceId,
            employeeId: _selected?.id, date: row.date, shiftAssignmentId: row.shiftAssignmentId);
        success++;
      } catch (_) {}
    }
    if (mounted) {
      setState(() { _bulkLoading = false; _selectedDates.clear(); _selectionMode = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.bulkActionDone(success, unapprovedRows.length))));
      await _loadTimesheet();
    }
  }

  Future<void> _bulkUnapprove() async {
    final s = AppLocalizations.of(context);
    final keys = Set<String>.from(_selectedDates);
    final rows = _mergedRows.where((r) => keys.contains(_dateKey(r.first.date))).toList();
    final approvedRows = rows.expand((r) => r.rows)
        .where((r) => r.approved && r.attendanceId != null).toList();
    if (approvedRows.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.bulkUnapprove),
        content: Text('${s.bulkUnapprove} ${approvedRows.length} ${s.checkIn.toLowerCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.unapprove),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _bulkLoading = true);
    int success = 0;
    for (final row in approvedRows) {
      try { await _repo.unapproveAttendance(row.attendanceId!); success++; } catch (_) {}
    }
    if (mounted) {
      setState(() { _bulkLoading = false; _selectedDates.clear(); _selectionMode = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.bulkActionDone(success, approvedRows.length))));
      await _loadTimesheet();
    }
  }

  void _bulkEnterEdit() {
    final keys = Set<String>.from(_selectedDates);
    final rows = _mergedRows
        .where((r) => keys.contains(_dateKey(r.first.date)))
        .expand((r) => r.rows)
        .where((r) => !r.approved)
        .toList();
    for (final row in rows) {
      final dk = _dateKey(row.date);
      _ctrlFor(dk, 'checkIn',  row.overrideCheckIn  ?? row.checkIn  ?? '').text = row.overrideCheckIn  ?? row.checkIn  ?? '';
      _ctrlFor(dk, 'checkOut', row.overrideCheckOut ?? row.checkOut ?? '').text = row.overrideCheckOut ?? row.checkOut ?? '';
      _ctrlFor(dk, 'break',
          row.overrideBreakMinutes != null ? formatAttendanceMinutes(row.overrideBreakMinutes!) : _formatBreak(row.breakMinutes)).text =
          row.overrideBreakMinutes != null ? formatAttendanceMinutes(row.overrideBreakMinutes!) : _formatBreak(row.breakMinutes);
      _ctrlFor(dk, 'otDay',
          row.overrideOtDayMinutes != null ? formatAttendanceMinutes(row.overrideOtDayMinutes!) : (row.otDayHours > 0 ? _formatHours(row.otDayHours) : '')).text =
          row.overrideOtDayMinutes != null ? formatAttendanceMinutes(row.overrideOtDayMinutes!) : (row.otDayHours > 0 ? _formatHours(row.otDayHours) : '');
      _ctrlFor(dk, 'otNight',
          row.overrideOtNightMinutes != null ? formatAttendanceMinutes(row.overrideOtNightMinutes!) : (row.otNightHours > 0 ? _formatHours(row.otNightHours) : '')).text =
          row.overrideOtNightMinutes != null ? formatAttendanceMinutes(row.overrideOtNightMinutes!) : (row.otNightHours > 0 ? _formatHours(row.otNightHours) : '');
      _editingRows.add(dk);
    }
    setState(() { _selectionMode = false; _selectedDates.clear(); });
  }

  // ── Inline row editing ─────────────────────────────────────────────────────

  TextEditingController _ctrlFor(String dateKey, String col, String initVal) {
    final k = '$dateKey:$col';
    return _editCtrls.putIfAbsent(k, () => TextEditingController(text: initVal));
  }

  void _enterEditRow(String dateKey, TimesheetRow row) {
    _ctrlFor(dateKey, 'checkIn',  row.overrideCheckIn  ?? row.checkIn  ?? '').text = row.overrideCheckIn  ?? row.checkIn  ?? '';
    _ctrlFor(dateKey, 'checkOut', row.overrideCheckOut ?? row.checkOut ?? '').text = row.overrideCheckOut ?? row.checkOut ?? '';
    _ctrlFor(dateKey, 'break',
        row.overrideBreakMinutes != null ? formatAttendanceMinutes(row.overrideBreakMinutes!) : _formatBreak(row.breakMinutes)).text =
        row.overrideBreakMinutes != null ? formatAttendanceMinutes(row.overrideBreakMinutes!) : _formatBreak(row.breakMinutes);
    _ctrlFor(dateKey, 'otDay',
        row.overrideOtDayMinutes != null ? formatAttendanceMinutes(row.overrideOtDayMinutes!) : (row.otDayHours > 0 ? _formatHours(row.otDayHours) : '')).text =
        row.overrideOtDayMinutes != null ? formatAttendanceMinutes(row.overrideOtDayMinutes!) : (row.otDayHours > 0 ? _formatHours(row.otDayHours) : '');
    _ctrlFor(dateKey, 'otNight',
        row.overrideOtNightMinutes != null ? formatAttendanceMinutes(row.overrideOtNightMinutes!) : (row.otNightHours > 0 ? _formatHours(row.otNightHours) : '')).text =
        row.overrideOtNightMinutes != null ? formatAttendanceMinutes(row.overrideOtNightMinutes!) : (row.otNightHours > 0 ? _formatHours(row.otNightHours) : '');
    setState(() => _editingRows.add(dateKey));
  }

  void _cancelEditRow([String? dateKey]) {
    setState(() {
      if (dateKey != null) {
        _editingRows.remove(dateKey);
      } else {
        _editingRows.clear();
      }
    });
  }

  ({String? checkIn, String? checkOut, int? breakMinutes, int? otDayMinutes, int? otNightMinutes})?
      _buildSavePayload(TimesheetRow row, String dateKey) {
    final ciRaw = _editCtrls['$dateKey:checkIn']?.text.trim()  ?? '';
    final coRaw = _editCtrls['$dateKey:checkOut']?.text.trim() ?? '';
    final brRaw = _editCtrls['$dateKey:break']?.text.trim()    ?? '';
    final odRaw = _editCtrls['$dateKey:otDay']?.text.trim()    ?? '';
    final onRaw = _editCtrls['$dateKey:otNight']?.text.trim()  ?? '';

    final ci = ciRaw.isEmpty ? null : parseAttendanceTime(ciRaw);
    final co = coRaw.isEmpty ? null : parseAttendanceTime(coRaw);
    final br = brRaw.isEmpty ? null : parseAttendanceDuration(brRaw);
    final od = odRaw.isEmpty ? null : parseAttendanceDuration(odRaw);
    final on = onRaw.isEmpty ? null : parseAttendanceDuration(onRaw);
    if ((ciRaw.isNotEmpty && ci == null) || (coRaw.isNotEmpty && co == null) ||
        (brRaw.isNotEmpty && br == null) || (odRaw.isNotEmpty && od == null) ||
        (onRaw.isNotEmpty && on == null)) {
      return null;
    }

    String? norm(String? v) { final s = (v ?? '').trim(); return s.isEmpty ? null : parseAttendanceTime(s); }
    int? effBr(int m) => m > 0 ? m : null;
    int? effOt(double h) => h <= 0 ? null : (h * 60).round();

    final curCI = norm(row.checkIn); final curCO = norm(row.checkOut);
    final curBr = effBr(row.breakMinutes);
    final curOD = effOt(row.otDayHours); final curON = effOt(row.otNightHours);
    final ovCI = norm(row.overrideCheckIn); final ovCO = norm(row.overrideCheckOut);

    return (
      checkIn: ciRaw.isEmpty ? null : (ovCI != null ? (ci == ovCI ? row.overrideCheckIn : ci) : (ci == curCI ? null : ci)),
      checkOut: coRaw.isEmpty ? null : (ovCO != null ? (co == ovCO ? row.overrideCheckOut : co) : (co == curCO ? null : co)),
      breakMinutes: brRaw.isEmpty ? null : (row.overrideBreakMinutes != null ? (br == row.overrideBreakMinutes ? row.overrideBreakMinutes : br) : (br == curBr ? null : br)),
      otDayMinutes: odRaw.isEmpty ? null : (row.overrideOtDayMinutes != null ? (od == row.overrideOtDayMinutes ? row.overrideOtDayMinutes : od) : (od == curOD ? null : od)),
      otNightMinutes: onRaw.isEmpty ? null : (row.overrideOtNightMinutes != null ? (on == row.overrideOtNightMinutes ? row.overrideOtNightMinutes : on) : (on == curON ? null : on)),
    );
  }

  Future<void> _saveEditRow(TimesheetRow row, String dateKey) async {
    setState(() => _editingRows.remove(dateKey));
    final payload = _buildSavePayload(row, dateKey);
    if (payload == null) return;
    try {
      final int attId = row.attendanceId ?? await _repo.ensureAttendance(_selected!.id, row.date);
      await _repo.saveOverride(attId,
          checkIn: payload.checkIn, checkOut: payload.checkOut,
          breakMinutes: payload.breakMinutes, otDayMinutes: payload.otDayMinutes,
          otNightMinutes: payload.otNightMinutes, note: row.overrideNote);
      await _loadTimesheet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _saveAllEditRows() async {
    final s = AppLocalizations.of(context);
    final editingKeys = Set<String>.from(_editingRows);
    final rowMap = <String, TimesheetRow>{};
    for (final r in _mergedRows.expand((m) => m.rows)) {
      final k = _dateKey(r.date);
      if (editingKeys.contains(k)) rowMap[k] = r;
    }
    if (rowMap.isEmpty) return;
    setState(() { _editingRows.clear(); _bulkLoading = true; });
    int success = 0;
    for (final entry in rowMap.entries) {
      final payload = _buildSavePayload(entry.value, entry.key);
      if (payload == null) continue;
      try {
        final int attId = entry.value.attendanceId ?? await _repo.ensureAttendance(_selected!.id, entry.value.date);
        await _repo.saveOverride(attId,
            checkIn: payload.checkIn, checkOut: payload.checkOut,
            breakMinutes: payload.breakMinutes, otDayMinutes: payload.otDayMinutes,
            otNightMinutes: payload.otNightMinutes, note: entry.value.overrideNote);
        success++;
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _bulkLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.bulkActionDone(success, rowMap.length))));
      await _loadTimesheet();
    }
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      final results = await Future.wait([
        DepartmentService.instance.getFlat(permission: 'ATTENDANCE_VIEW'),
        _empRepo.getAllForPicker(),
        _settingRepo.get(),
      ]);
      if (!mounted) return;
      final depts = results[0] as List<DepartmentFlat>;
      final emps = results[1] as List<Employee>;
      final settings = results[2] as Map<String, dynamic>;
      final att = settings['attendance'] as Map<String, dynamic>? ?? {};
      final payroll = settings['payroll'] as Map<String, dynamic>? ?? {};
      setState(() {
        _depts = depts;
        _employees = emps;
        _dayNightMode = att['dayNightMode'] == true;
        _otEnabled = att['otEnabled'] != false;
        _cutoffDay = (payroll['payrollCutoffDay'] as num?)?.toInt() ?? 1;
      });
      if (emps.isNotEmpty) _selectEmployee(emps.first);
    } catch (_) {}
  }

  void _selectEmployee(Employee e) {
    setState(() => _selected = e);
    _loadTimesheet();
  }

  Future<void> _loadTimesheet() async {
    if (_selected == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final List<TimesheetRow> rows;
      if (_rangeMode == AttViewRangeMode.payroll) {
        rows = await _repo.getTimesheet(
            employeeId: _selected!.id, year: _month.year, month: _month.month);
      } else {
        final range = _currentRange;
        final fmt = DateFormat('yyyy-MM-dd');
        rows = await _repo.getTimesheetRange(
            employeeId: _selected!.id,
            from: fmt.format(range.start),
            to: fmt.format(range.end));
      }
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = serverMsg(e); _loading = false; });
    }
  }

  Future<AttendanceChangeRequest> _setRequestApplied(int id, bool applied) async {
    final updated = await _repo.setRequestApplied(id, applied);
    if (mounted) await _loadTimesheet();
    return updated;
  }

  Future<bool> _setLeaveRequestApplied(int id, bool applied) async {
    final updated = await _leaveRepo.setRequestApplied(id, applied);
    if (mounted) await _loadTimesheet();
    return updated['applied'] == true;
  }

  Future<void> _pickMonth() async {
    switch (_rangeMode) {
      case AttViewRangeMode.week:
        final picked = await showDatePicker(context: context,
            initialDate: _weekFocus, firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (picked == null || !mounted) return;
        setState(() => _weekFocus = picked);
        _loadTimesheet();
        return;
      case AttViewRangeMode.custom:
        final cur = _currentRange;
        final picked = await showDialog<DateTimeRange>(
          context: context,
          barrierDismissible: true,
          builder: (_) => _AttSmallDateRangeDialog(initialRange: cur),
        );
        if (picked == null || !mounted) return;
        setState(() => _customRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        ));
        _loadTimesheet();
        return;
      case AttViewRangeMode.payroll:
        break;
    }
    final s = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        var selectedYear = _month.year;
        var selectedMonth = _month.month;
        final years = List.generate(11, (i) => now.year - 10 + i);
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(s.chooseMonth),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedYear,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: s.year, floatingLabelBehavior: FloatingLabelBehavior.always),
                    items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (v) { if (v != null) setDialogState(() => selectedYear = v); },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: List.generate(12, (i) {
                      final month = i + 1;
                      final selected = selectedMonth == month;
                      return SizedBox(
                        width: 76,
                        child: ChoiceChip(
                          label: Text('$month'),
                          selected: selected,
                          onSelected: (_) => setDialogState(() => selectedMonth = month),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
              FilledButton(
                onPressed: () => Navigator.pop(context, DateTime(selectedYear, selectedMonth)),
                child: Text(s.apply),
              ),
            ],
          );
        });
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _month = picked);
    _loadTimesheet();
  }

  Future<void> _exportExcel() async {
    if (_selected == null) return;
    final s = AppLocalizations.of(context);
    try {
      final range = _currentRange;
      final fmt = DateFormat('yyyy-MM-dd');
      final result = await _repo.exportTimesheetExcel(
        employeeId: _selected!.id,
        from: fmt.format(range.start),
        to: fmt.format(range.end),
      );
      await saveFileToDevice(result.bytes, result.filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.exportSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _importExcel() async {
    final s = AppLocalizations.of(context);
    final picked = await pickExcelFile();
    if (picked == null || !mounted) return;
    try {
      final rawDiffs = await _repo.previewImportTimesheet(picked.bytes, picked.filename);
      if (!mounted) return;
      final diffs = rawDiffs.map((d) {
        final action = d['action'] ?? 'CREATE';
        final changes = (d['changes'] as List? ?? []).map((c) => ImportFieldChange(
          field: c['field'] ?? '', oldValue: c['oldValue'] ?? '', newValue: c['newValue'] ?? '',
        )).toList();
        final details = <String, String>{
          for (final c in (d['changes'] as List? ?? []))
            (c['field'] ?? '') as String:
              action == 'CREATE'
                ? (c['newValue'] ?? '') as String
                : '${c['oldValue'] ?? ''} → ${c['newValue'] ?? ''}',
        };
        return ImportDiffRow(
          action: action, code: d['code'] ?? '', name: d['name'] ?? '',
          changes: changes, warnings: (d['warnings'] as List? ?? []).cast<String>(),
          details: details,
        );
      }).toList();
      final confirmed = await showInstantDialog<bool>(
        context,
        (ctx) => ImportPreviewDialog(
          diffs: diffs,
          onConfirm: () async { await _repo.importTimesheet(picked.bytes, picked.filename); },
        ),
      );
      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.importAttendanceSuccess)));
        await _loadTimesheet();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  // ── Merged rows ────────────────────────────────────────────────────────────

  List<Employee> get _filteredEmps {
    if (_filterDept == null) return _employees;
    final ids = expandedDepartmentScopeIds(_depts, _filterDept);
    return _employees.where((e) => ids.contains(e.departmentId)).toList();
  }

  List<AttMergedTimesheetRow> _mergedRowsCache = [];
  List<TimesheetRow> _lastRowsForCache = [];

  List<AttMergedTimesheetRow> get _mergedRows {
    if (identical(_lastRowsForCache, _rows)) return _mergedRowsCache;
    _lastRowsForCache = _rows;
    final groups = <String, List<TimesheetRow>>{};
    for (final row in _rows) {
      final d = row.date;
      groups.putIfAbsent('${d.year}-${d.month}-${d.day}', () => []).add(row);
    }
    _mergedRowsCache = groups.entries.map((e) {
      final rows = List<TimesheetRow>.from(e.value)..sort(_compareTimesheetRows);
      return AttMergedTimesheetRow(rows);
    }).toList()
      ..sort((a, b) => a.first.date.compareTo(b.first.date));
    return _mergedRowsCache;
  }

  int _compareTimesheetRows(TimesheetRow a, TimesheetRow b) {
    final aStart = _parseTimeString(a.shiftStart);
    final bStart = _parseTimeString(b.shiftStart);
    if (aStart != null && bStart != null) {
      final cmp = aStart.compareTo(bStart);
      if (cmp != 0) return cmp;
    } else if (aStart != null) {
      return -1;
    } else if (bStart != null) {
      return 1;
    }
    return (a.shiftAssignmentId ?? 0).compareTo(b.shiftAssignmentId ?? 0);
  }

  DateTime? _parseTimeString(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(2000, 1, 1, hour, minute);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        // Range nav
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => _shiftRange(-1), padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
            InkWell(
              onTap: _pickMonth, borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(_rangeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            IconButton(icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () => _shiftRange(1), padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
            const Spacer(),
          ]),
        ),
        // Filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Wrap(spacing: 12, runSpacing: 10, children: [
            SizedBox(
              width: 220, height: 56,
              child: DepartmentPickerField(
                compact: true, departments: _depts, value: _filterDept,
                label: s.department, allowAll: true,
                onChanged: (v) {
                  setState(() {
                    _filterDept = v;
                    final emps = _filteredEmps;
                    if (emps.isNotEmpty &&
                        (_selected == null || !emps.any((e) => e.id == _selected!.id))) {
                      _selected = emps.first;
                      _loadTimesheet();
                    }
                  });
                },
              ),
            ),
            SizedBox(
              width: 320, height: 56,
              child: DropdownButtonFormField<int?>(
                initialValue: _selected?.id,
                borderRadius: BorderRadius.circular(8),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: s.employee,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _filteredEmps
                    .map((e) => DropdownMenuItem(
                        value: e.id, child: Text(e.fullName, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  _selectEmployee(_employees.firstWhere((e) => e.id == v));
                },
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        // Toolbar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const Spacer(),
            Tooltip(
              message: s.bulkEdit,
              child: IconButton(
                icon: Icon(Icons.checklist_outlined, size: 20,
                    color: _selectionMode ? AppTheme.primary : AppTheme.textSecondary),
                style: _selectionMode
                    ? IconButton.styleFrom(backgroundColor: AppTheme.primary.withValues(alpha: 0.1))
                    : null,
                onPressed: () => setState(() {
                  _selectionMode = !_selectionMode;
                  if (!_selectionMode) _selectedDates.clear();
                }),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ]),
        ),
        // Bulk action bar
        if (_selectionMode)
          Container(
            color: AppTheme.primary.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              InkWell(
                onTap: _toggleSelectAll,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.checklist_outlined, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      _selectedDates.isEmpty ? s.selectAll : s.selectedCount(_selectedDates.length),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                    ),
                  ]),
                ),
              ),
              const Spacer(),
              if (_bulkLoading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                OutlinedButton.icon(
                  onPressed: _selectedDates.isEmpty ? null : _bulkEnterEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16), label: Text(s.bulkEdit),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _selectedDates.isEmpty ? null : _bulkApprove,
                  icon: const Icon(Icons.check_circle_outline, size: 16), label: Text(s.bulkApprove),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _selectedDates.isEmpty ? null : _bulkUnapprove,
                  icon: const Icon(Icons.lock_open_outlined, size: 16), label: Text(s.bulkUnapprove),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.warning,
                      side: const BorderSide(color: AppTheme.warning),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 18), tooltip: s.cancel,
                onPressed: () => setState(() { _selectionMode = false; _selectedDates.clear(); }),
              ),
            ]),
          ),
        // Bulk edit save bar
        if (_editingRows.isNotEmpty)
          Container(
            color: AppTheme.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(s.uiRowsEditing('${_editingRows.length}'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
              const Spacer(),
              if (_bulkLoading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                FilledButton.icon(
                  onPressed: _saveAllEditRows,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(AppLocalizations.of(context).save),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _cancelEditRow(),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(AppLocalizations.of(context).cancel),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
              ],
            ]),
          ),
        Expanded(child: _buildTable()),
        const SizedBox(height: 25),
      ],
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  Widget _buildTable() {
    final s = AppLocalizations.of(context);
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: const TextStyle(color: AppTheme.error)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _loadTimesheet, child: Text(s.retry)),
      ]));
    }
    if (_selected == null) {
      return Center(child: Text(s.selectEmployeeToViewTimesheet,
          style: const TextStyle(color: AppTheme.textSecondary)));
    }

    return LayoutBuilder(builder: (context, constraints) {
      const checkW = 40.0;
      final isMobile = constraints.maxWidth < 600;
      final dateColW = isMobile ? 56.0 : attDateColW;
      final fixedW = (_selectionMode ? checkW : 0.0) + dateColW;
      final cols = attCols(s, dayNight: _dayNightMode, otEnabled: _otEnabled);
      final totalMin = cols.fold(0.0, (sum, c) => sum + c.width);
      final available = constraints.maxWidth - fixedW - 1;
      final scale = available > totalMin ? available / totalMin : 1.0;
      final colWidths = cols.map((c) => c.width * scale).toList();
      final merged = _mergedRows;

      return AttendanceGrid(
        fixedColumnHeader: s.date,
        fixedColumnWidth: dateColW,
        columnHeaders: cols.map((c) => c.label).toList(),
        columnWidths: colWidths,
        rowCount: merged.length,
        rowHeightAt: (i) => attRowHeight * merged[i].rows.length,
        isWeekend: (i) => merged[i].weekend,
        isToday: (i) {
          final d = merged[i].first.date;
          final now = DateTime.now();
          return d.year == now.year && d.month == now.month && d.day == now.day;
        },
        selectionMode: _selectionMode,
        isSelected: (i) => _selectionMode && _selectedDates.contains(_dateKey(merged[i].first.date)),
        allSelected: _selectedDates.isEmpty
            ? false
            : _selectedDates.containsAll(merged.map((r) => _dateKey(r.first.date)).toSet())
                ? true
                : null,
        onToggleSelectAll: _toggleSelectAll,
        onToggleSelect: (i) => _toggleSelectDate(_dateKey(merged[i].first.date)),
        checkboxWidth: checkW,
        fixedCellBuilder: (i, width, bg, selected) {
          final row = merged[i];
          final key = _dateKey(row.first.date);
          final onTap = _selectionMode ? () => _toggleSelectDate(key) : null;
          return row.rows.length <= 1
              ? _dateCell(row.first, width: width, selected: selected, onTap: onTap)
              : _dateCellMerged(row, attRowHeight * row.rows.length,
                  width: width, selected: selected, onTap: onTap);
        },
        dataCellsBuilder: (i, widths, bg, selected) {
          final row = merged[i];
          final key = _dateKey(row.first.date);
          if (row.rows.length <= 1) {
            return [
              GestureDetector(
                onTap: _selectionMode ? () => _toggleSelectDate(key) : null,
                child: Row(children: _dataCells(row.first, widths, selected: selected)),
              ),
            ];
          }
          return [
            Column(children: [
              for (final slot in row.rows)
                SizedBox(
                  height: attRowHeight,
                  child: Row(children: _dataCells(slot, widths, selected: selected)),
                ),
            ]),
          ];
        },
        hScrollController: _hScroll,
        vScrollController: _vScroll,
      );
    });
  }

  // ── Cell builders ──────────────────────────────────────────────────────────

  Widget _dateCell(TimesheetRow row, {double width = attDateColW, bool selected = false, VoidCallback? onTap}) {
    final isToday = row.date.year == DateTime.now().year &&
        row.date.month == DateTime.now().month && row.date.day == DateTime.now().day;
    final color = selected ? AppTheme.primary.withValues(alpha: 0.10)
        : row.weekend ? const Color(0xFFFFF3E0)
        : isToday ? const Color(0xFFE3F2FD) : Colors.white;
    final cell = Container(
      width: width, height: attRowHeight, alignment: Alignment.center,
      decoration: BoxDecoration(color: color, border: const Border(
        bottom: BorderSide(color: attGridLineLight, width: 0.9),
        right: BorderSide(color: attGridLine, width: 0.8),
      )),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${row.date.day}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: row.weekend ? AppTheme.warning : (isToday ? AppTheme.primary : AppTheme.textPrimary))),
        Text(row.dayLabel, style: TextStyle(fontSize: 10,
            color: row.weekend ? AppTheme.warning : AppTheme.textSecondary)),
      ]),
    );
    return onTap == null ? cell : GestureDetector(onTap: onTap, child: cell);
  }

  Widget _dateCellMerged(AttMergedTimesheetRow row, double height,
      {double width = attDateColW, bool selected = false, VoidCallback? onTap}) {
    final first = row.first;
    final isToday = first.date.year == DateTime.now().year &&
        first.date.month == DateTime.now().month && first.date.day == DateTime.now().day;
    final color = selected ? AppTheme.primary.withValues(alpha: 0.10)
        : row.weekend ? const Color(0xFFFFF3E0)
        : isToday ? const Color(0xFFE3F2FD) : Colors.white;
    final cell = Container(
      width: width, height: height, alignment: Alignment.center,
      decoration: BoxDecoration(color: color, border: const Border(
        bottom: BorderSide(color: attGridLineLight, width: 0.9),
        right: BorderSide(color: attGridLine, width: 0.8),
      )),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${first.date.day}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: row.weekend ? AppTheme.warning : (isToday ? AppTheme.primary : AppTheme.textPrimary))),
        Text(first.dayLabel, style: TextStyle(fontSize: 10,
            color: row.weekend ? AppTheme.warning : AppTheme.textSecondary)),
      ]),
    );
    return onTap == null ? cell : GestureDetector(onTap: onTap, child: cell);
  }

  Widget _inlineCellT({
    required String dateKey, required String col,
    required String displayVal, required String? overrideVal,
    required double width, required Color bg,
    bool isTime = true, bool rounded = false, String? roundedRawVal,
  }) {
    if (_editingRows.contains(dateKey)) {
      final ctrl = _editCtrls['$dateKey:$col'] ?? TextEditingController(text: overrideVal ?? displayVal);
      return AttEditTimeCell(ctrl: ctrl, width: width, height: attRowHeight, bg: bg, isTime: isTime);
    }
    final showActual = displayVal.isNotEmpty && displayVal != overrideVal;
    return Container(
      width: width, height: attRowHeight, alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, border: const Border(
        bottom: BorderSide(color: attGridLineLight, width: 0.9),
        right: BorderSide(color: attGridLineLight, width: 0.8),
      )),
      child: overrideVal != null
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(overrideVal, style: const TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                const Icon(Icons.edit, size: 9, color: AppTheme.error),
                if (rounded) ...[
                  const SizedBox(width: 2),
                  Tooltip(message: roundedRawVal ?? displayVal,
                      child: const Icon(Icons.schedule, size: 9, color: AppTheme.primary)),
                ],
              ]),
              if (showActual)
                Text('($displayVal)', style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Text(displayVal, style: TextStyle(fontSize: 12,
                  color: displayVal.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)),
              if (rounded && displayVal.isNotEmpty) ...[
                const SizedBox(width: 2),
                Tooltip(message: roundedRawVal ?? displayVal,
                    child: const Icon(Icons.schedule, size: 10, color: AppTheme.primary)),
              ],
            ]),
    );
  }

  List<Widget> _dataCells(TimesheetRow row, List<double> cw, {bool selected = false}) {
    final s = AppLocalizations.of(context);
    final isToday = row.date.year == DateTime.now().year &&
        row.date.month == DateTime.now().month && row.date.day == DateTime.now().day;
    final bg = selected ? AppTheme.primary.withValues(alpha: 0.08)
        : row.weekend ? const Color(0xFFFFF3E0)
        : isToday ? const Color(0xFFE3F2FD) : Colors.white;

    final checkInRequests  = attMatchingRequests(row, row.requests, requestType: 'CHECK_IN');
    final checkOutRequests = attMatchingRequests(row, row.requests, requestType: 'CHECK_OUT');
    final otDayRequests    = attMatchingRequests(row, row.requests, requestType: 'OT', period: 'DAY');
    final otNightRequests  = attMatchingRequests(row, row.requests, requestType: 'OT', period: 'NIGHT');
    final checkInRequest   = attPickVisibleRequest(checkInRequests);
    final checkOutRequest  = attPickVisibleRequest(checkOutRequests);

    var idx = 0;
    final cells = <Widget>[];
    final dateKey = _dateKey(row.date);

    cells.add(_leaveCell(row, cw[idx++], bg));
    cells.add(_shiftCell(row, cw[idx++], bg));
    // Break
    cells.add(_inlineCellT(dateKey: dateKey, col: 'break',
        displayVal: _formatBreak(row.breakMinutes),
        overrideVal: row.overrideBreakMinutes != null ? formatAttendanceMinutes(row.overrideBreakMinutes!) : null,
        width: cw[idx++], bg: bg, isTime: false));
    // Check-in
    cells.add(_inlineCellT(dateKey: dateKey, col: 'checkIn',
        displayVal: row.checkIn ?? attEmpty, overrideVal: row.overrideCheckIn,
        width: cw[idx++], bg: bg,
        rounded: row.overrideCheckIn == null && row.checkInRounded,
        roundedRawVal: row.checkInRaw));
    // Check-out
    cells.add(_inlineCellT(dateKey: dateKey, col: 'checkOut',
        displayVal: row.checkOut ?? attEmpty, overrideVal: row.overrideCheckOut,
        width: cw[idx++], bg: bg,
        rounded: row.overrideCheckOut == null && row.checkOutRounded,
        roundedRawVal: row.checkOutRaw));
    // CI request
    cells.add(_requestCell(attFormatRequestTimeOrDuration(checkInRequest), checkInRequest?.status,
        width: cw[idx++], bg: bg,
        strikeThrough: checkInRequest != null && !checkInRequest.applied,
        onTap: checkInRequests.isNotEmpty ? () => showAttRequestCardsDialog(context,
            title: s.checkInRequest, requests: checkInRequests,
            onToggleApplied: _setRequestApplied, attendanceApproved: row.approved) : null));
    // CO request
    cells.add(_requestCell(attFormatRequestTimeOrDuration(checkOutRequest), checkOutRequest?.status,
        width: cw[idx++], bg: bg,
        strikeThrough: checkOutRequest != null && !checkOutRequest.applied,
        onTap: checkOutRequests.isNotEmpty ? () => showAttRequestCardsDialog(context,
            title: s.checkOutRequest, requests: checkOutRequests,
            onToggleApplied: _setRequestApplied, attendanceApproved: row.approved) : null));

    final mergedDayOt = !_otEnabled
        ? (!_dayNightMode ? [...otDayRequests, ...otNightRequests] : otDayRequests)
        : <AttendanceChangeRequest>[];
    cells.add(_numCell(row.totalHours, cw[idx++], bg));
    cells.add(_numCell(row.regularDayHours, cw[idx++], bg,
        highlight: mergedDayOt.isNotEmpty,
        onTap: mergedDayOt.isNotEmpty ? () => showAttRequestCardsDialog(context,
            title: s.dayHours, requests: mergedDayOt,
            onToggleApplied: _setRequestApplied, attendanceApproved: row.approved) : null));
    if (_otEnabled) {
      cells.add(_inlineCellT(dateKey: dateKey, col: 'otDay',
          displayVal: row.otDayHours > 0 ? _formatHours(row.otDayHours) : attEmpty,
          overrideVal: row.overrideOtDayMinutes != null ? _formatHours(row.overrideOtDayMinutes! / 60.0) : null,
          width: cw[idx++], bg: bg, isTime: false));
    }
    if (_dayNightMode) {
      final mergedNightOt = !_otEnabled ? otNightRequests : <AttendanceChangeRequest>[];
      cells.add(_numCell(row.regularNightHours, cw[idx++], bg,
          highlight: mergedNightOt.isNotEmpty,
          onTap: mergedNightOt.isNotEmpty ? () => showAttRequestCardsDialog(context,
              title: s.nightHours, requests: mergedNightOt,
              onToggleApplied: _setRequestApplied, attendanceApproved: row.approved) : null));
      if (_otEnabled) {
        cells.add(_inlineCellT(dateKey: dateKey, col: 'otNight',
            displayVal: row.otNightHours > 0 ? _formatHours(row.otNightHours) : attEmpty,
            overrideVal: row.overrideOtNightMinutes != null ? _formatHours(row.overrideOtNightMinutes! / 60.0) : null,
            width: cw[idx++], bg: bg, isTime: false));
      }
    }
    cells.add(_workStatusCell(row, cw[idx++], bg));
    cells.add(_actionCell(row, cw[idx++], bg));
    return cells;
  }

  Widget _leaveCell(TimesheetRow row, double width, Color bg) {
    final isLeave = row.leaveCode != null;
    final leaveNotApplied = isLeave && row.leaveApplied == false;
    final effectiveBg = (row.leaveMode == 'DAY_RANGE') && isLeave ? const Color(0xFFE8F5E9) : bg;
    final s = AppLocalizations.of(context);
    final child = Container(
      width: width, height: attRowHeight, alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: effectiveBg, border: const Border(
        bottom: BorderSide(color: attGridLineLight, width: 0.9),
        right: BorderSide(color: attGridLineLight, width: 0.8),
      )),
      child: isLeave
          ? Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: leaveNotApplied
                    ? AppTheme.textSecondary.withValues(alpha: 0.1)
                    : const Color(0xFF4CAF50).withValues(alpha: 0.15)),
                child: Text(row.leaveCode!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: leaveNotApplied ? AppTheme.textSecondary : const Color(0xFF2E7D32),
                    decoration: leaveNotApplied ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.textSecondary), textAlign: TextAlign.center),
              ),
              if (row.leaveMode == 'HOUR_RANGE' && row.leaveFromTime != null && row.leaveToTime != null)
                Text('${row.leaveFromTime}-${row.leaveToTime}', style: TextStyle(fontSize: 9,
                    color: leaveNotApplied ? AppTheme.textSecondary : const Color(0xFF2E7D32),
                    decoration: leaveNotApplied ? TextDecoration.lineThrough : null)),
            ])
          : const SizedBox.shrink(),
    );
    if (!isLeave || row.leaveRequestId == null) return child;
    return Material(color: Colors.transparent, child: InkWell(
      onTap: () => showAttLeaveRequestCardDialog(context,
          requestId: row.leaveRequestId!, employeeName: _selected?.fullName ?? '-',
          departmentName: _selected?.departmentName ?? '-',
          leaveCode: row.leaveCode, leaveMode: row.leaveMode,
          leaveFromTime: row.leaveFromTime, leaveToTime: row.leaveToTime,
          leaveAmount: row.leaveAmount,
          status: row.leaveStatus ?? 'APPROVED', applied: row.leaveApplied ?? true,
          processedByName: row.leaveProcessedByName, processedAt: row.leaveProcessedAt,
          createdAt: row.leaveCreatedAt,
          onToggleApplied: (value) => _setLeaveRequestApplied(row.leaveRequestId!, value)),
      child: child,
    ));
  }

  Widget _shiftCell(TimesheetRow row, double width, Color bg) {
    Color? dotColor;
    if (row.shiftColor != null) {
      try { dotColor = Color(int.parse(row.shiftColor!.replaceAll('#', '0xFF'))); } catch (_) {}
    }
    return Container(
      width: width, height: attRowHeight, alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: bg, border: const Border(
        bottom: BorderSide(color: attGridLineLight, width: 0.9),
        right: BorderSide(color: attGridLineLight, width: 0.8),
      )),
      child: row.shiftName == null ? const SizedBox.shrink()
          : Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (dotColor != null) ...[
                  Container(width: 6, height: 6,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                ],
                Flexible(child: Text(row.shiftName!, style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
              ]),
              if (row.shiftStart != null || row.shiftEnd != null) ...[
                const SizedBox(height: 2),
                Text(_formatShiftRange(row.shiftStart, row.shiftEnd),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              ],
            ]),
    );
  }

  Widget _numCell(double val, double width, Color bg, {bool highlight = false, VoidCallback? onTap}) {
    final text = val > 0 ? _formatHours(val) : attEmpty;
    final child = Container(
      width: width, height: attRowHeight, alignment: Alignment.center,
      decoration: BoxDecoration(
          color: highlight ? AppTheme.warning.withValues(alpha: 0.08) : bg,
          border: const Border(bottom: BorderSide(color: attGridLineLight, width: 0.9),
              right: BorderSide(color: attGridLineLight, width: 0.8))),
      child: Text(text, style: TextStyle(fontSize: 12,
          fontWeight: val > 0 ? FontWeight.w600 : FontWeight.normal,
          color: highlight ? AppTheme.warning : val > 0 ? AppTheme.textPrimary : AppTheme.textSecondary)),
    );
    return onTap == null ? child : Material(color: Colors.transparent,
        child: InkWell(onTap: onTap, child: child));
  }

  Widget _requestCell(String? value, String? status, {
    required double width, required Color bg,
    bool strikeThrough = false, VoidCallback? onTap,
  }) {
    final text = value ?? attEmpty;
    final color = switch (status) {
      'APPROVED' => Colors.green, 'REJECTED' => AppTheme.error,
      'PENDING' => AppTheme.warning, _ => AppTheme.textSecondary,
    };
    final child = Container(
      width: width, height: attRowHeight, alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, border: const Border(
        bottom: BorderSide(color: attGridLineLight, width: 0.9),
        right: BorderSide(color: attGridLineLight, width: 0.8),
      )),
      child: Text(text, style: TextStyle(fontSize: 12,
          fontWeight: text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
          color: text.isEmpty ? AppTheme.textSecondary : color,
          decoration: strikeThrough ? TextDecoration.lineThrough : null)),
    );
    return onTap == null ? child : Material(color: Colors.transparent,
        child: InkWell(onTap: onTap, child: child));
  }

  Widget _workStatusCell(TimesheetRow row, double width, Color bg) {
    final s = AppLocalizations.of(context);
    final flags = row.workFlags;
    if (flags.isEmpty) {
      return Container(width: width, height: attRowHeight,
          decoration: BoxDecoration(color: bg,
              border: const Border(bottom: BorderSide(color: attGridLineLight, width: 0.9))));
    }
    final chips = flags.map((f) {
      final (label, color) = switch (f) {
        'LATE_IN' => (s.lateIn, AppTheme.error), 'EARLY_OUT' => (s.earlyOut, AppTheme.warning),
        'ON_TIME' => (s.onTime, AppTheme.secondary), 'OVERTIME' => (s.overtime, const Color(0xFFFF9800)),
        'LEAVE' => (s.leave, const Color(0xFF607D8B)), _ => (f, AppTheme.textSecondary),
      };
      return Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8)),
        child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );
    }).toList();
    return Container(
      width: width, height: attRowHeight, alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: bg,
          border: const Border(bottom: BorderSide(color: attGridLineLight, width: 0.9))),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: chips)),
    );
  }

  Widget _actionCell(TimesheetRow row, double width, Color bg) {
    final s = AppLocalizations.of(context);
    return Container(
      width: width, height: attRowHeight, alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(color: bg,
          border: const Border(bottom: BorderSide(color: attGridLineLight, width: 0.9))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (row.approved) ...[
          Tooltip(
            message: row.approvedByName != null ? '${s.approved}: ${row.approvedByName}' : s.approved,
            child: const Icon(Icons.check_circle, color: AppTheme.secondary, size: 18),
          ),
          const SizedBox(width: 2),
          SizedBox(width: 24, height: 24, child: IconButton(
            padding: EdgeInsets.zero, iconSize: 15,
            icon: const Icon(Icons.lock_open_outlined, color: AppTheme.warning),
            tooltip: s.unapprove, onPressed: () => _unapproveRow(row),
          )),
        ] else
          Builder(builder: (_) {
            final dk = _dateKey(row.date);
            final isEditing = _editingRows.contains(dk);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              if (isEditing) ...[
                SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
                    icon: const Icon(Icons.check, color: AppTheme.secondary),
                    tooltip: s.save, onPressed: () => _saveEditRow(row, dk))),
                const SizedBox(width: 2),
                SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
                    icon: const Icon(Icons.close, color: AppTheme.error),
                    tooltip: s.cancel, onPressed: () => _cancelEditRow(dk))),
              ] else ...[
                SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                    tooltip: s.edit, onPressed: () => _enterEditRow(dk, row))),
                if (row.attendanceId != null) ...[
                  const SizedBox(width: 2),
                  SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                      tooltip: s.delete, onPressed: () => _deleteRow(row))),
                ],
                const SizedBox(width: 2),
                SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
                    icon: const Icon(Icons.check_circle_outline, color: AppTheme.secondary),
                    tooltip: s.approve, onPressed: () => _approveRow(row))),
              ],
            ]);
          }),
      ]),
    );
  }

  Future<void> _approveRow(TimesheetRow row) async {
    final s = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(title: Text(s.approve),
          content: Text('${s.approve} ${row.date.day}/${row.date.month}/${row.date.year}?'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.approve))],
        ));
    if (confirm != true || !mounted) return;
    try {
      await _repo.approveAttendance(row.attendanceId,
          employeeId: _selected!.id, date: row.date, shiftAssignmentId: row.shiftAssignmentId);
      await _loadTimesheet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _unapproveRow(TimesheetRow row) async {
    final s = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(title: Text(s.unapprove),
          content: Text('${s.unapprove} ${row.date.day}/${row.date.month}/${row.date.year}?'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.warning),
                onPressed: () => Navigator.pop(ctx, true), child: Text(s.unapprove))],
        ));
    if (confirm != true || !mounted) return;
    try {
      await _repo.unapproveAttendance(row.attendanceId!);
      await _loadTimesheet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _deleteRow(TimesheetRow row) async {
    final s = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(title: Text(s.delete),
          content: Text('${s.delete} ${row.date.day}/${row.date.month}/${row.date.year}?'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete))],
        ));
    if (confirm != true || !mounted) return;
    try {
      await _repo.deleteAttendance(row.attendanceId!);
      await _loadTimesheet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  // ── Format helpers ─────────────────────────────────────────────────────────

  String _formatBreak(int minutes) {
    if (minutes == 0) return attEmpty;
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  String _formatShiftRange(String? start, String? end) {
    if ((start ?? '').isEmpty && (end ?? '').isEmpty) return attEmpty;
    if ((start ?? '').isEmpty) return end!;
    if ((end ?? '').isEmpty) return start!;
    return '$start - $end';
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    return '${(totalMinutes ~/ 60).toString().padLeft(2, '0')}:${(totalMinutes % 60).toString().padLeft(2, '0')}';
  }
}

// ── Small date-range dialog (same compact style as shift screen) ──────────────

class _AttSmallDateRangeDialog extends StatefulWidget {
  final DateTimeRange initialRange;
  const _AttSmallDateRangeDialog({required this.initialRange});
  @override
  State<_AttSmallDateRangeDialog> createState() => _AttSmallDateRangeDialogState();
}

class _AttSmallDateRangeDialogState extends State<_AttSmallDateRangeDialog> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = DateTime(widget.initialRange.start.year, widget.initialRange.start.month, widget.initialRange.start.day);
    _end   = DateTime(widget.initialRange.end.year,   widget.initialRange.end.month,   widget.initialRange.end.day);
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _start : (_end.isBefore(_start) ? _start : _end);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isStart ? DateTime(2020) : _start,
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = DateTime(picked.year, picked.month, picked.day);
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final fmt = DateFormat('dd/MM/yyyy');
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.chooseTimeRange,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              _AttDateRow(label: s.fromDate, value: fmt.format(_start), onTap: () => _pickDate(true)),
              const SizedBox(height: 8),
              _AttDateRow(label: s.toDate,   value: fmt.format(_end),   onTap: () => _pickDate(false)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, DateTimeRange(start: _start, end: _end)),
                  child: Text(s.apply),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttDateRow extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _AttDateRow({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD0D5DD)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ])),
        const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
      ]),
    ),
  );
}
