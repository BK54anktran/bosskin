import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/file_saver_utils.dart';
import '../../../../core/utils/file_picker_excel_utils.dart';
import '../../../widgets/import_preview_dialog.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../data/models/attendance.dart';
import '../../../../data/models/department_model.dart';
import '../../../../data/repositories/attendance_repository.dart';
import '../../../../data/repositories/company_setting_repository.dart';
import '../../../../data/repositories/leave_repository.dart';
import '../../../../core/utils/locale_utils.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../widgets/day_offset_text.dart';
import '../../../../data/services/department_service.dart';
import '../../../widgets/department_picker_field.dart';
import '../attendance_shared.dart';
import '../../../widgets/holiday_widgets.dart';
import '../widgets/attendance_grid.dart';

// ── Tab key ───────────────────────────────────────────────────────────────────

class AttendanceDayTabKey extends GlobalKey<_AttendanceDayTabState> {
  const AttendanceDayTabKey() : super.constructor();
  Future<void> exportExcel() => currentState?._exportExcel() ?? Future.value();
  Future<void> importExcel() => currentState?._importExcel() ?? Future.value();
  Future<void> reload() => currentState?._loadRows() ?? Future.value();
}

// ── Tab widget ────────────────────────────────────────────────────────────────

class AttendanceDayTab extends StatefulWidget {
  const AttendanceDayTab({super.key});

  @override
  State<AttendanceDayTab> createState() => _AttendanceDayTabState();
}

typedef _CellKey = ({int employeeId, String date, String col});

class _AttendanceDayTabState extends State<AttendanceDayTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _repo = AttendanceRepository();
  final _leaveRepo = LeaveRepository();
  final _settingRepo = CompanySettingRepository();

  List<DepartmentFlat> _depts = [];
  int? _filterDept;
  DateTime _date = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  int _page = 0;
  int _pageSize = 20;

  List<DayViewRow> _rows = [];
  bool _loading = false;
  String? _error;

  bool _dayNightMode = false;
  bool _otEnabled = true;

  // Bulk selection
  final Set<int> _selectedEmployeeIds = {};
  bool _dayBulkLoading = false;
  bool _daySelectionMode = false;

  // Inline editing
  final Set<String> _editingDaySlotKeys = {};
  final Map<String, TextEditingController> _dayEditCtrls = {};

  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    for (final c in _dayEditCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void _toggleSelectEmployee(int empId) {
    setState(() {
      if (_selectedEmployeeIds.contains(empId)) {
        _selectedEmployeeIds.remove(empId);
      } else {
        _selectedEmployeeIds.add(empId);
      }
    });
  }

  void _toggleSelectAllEmployees() {
    setState(() {
      final allIds = _pagedRows.map((r) => r.first.employeeId).toSet();
      if (_selectedEmployeeIds.containsAll(allIds)) {
        _selectedEmployeeIds.removeAll(allIds);
      } else {
        _selectedEmployeeIds.addAll(allIds);
      }
    });
  }

  // ── Bulk actions ───────────────────────────────────────────────────────────

  Future<void> _dayBulkApprove() async {
    final s = AppLocalizations.of(context);
    final ids = Set<int>.from(_selectedEmployeeIds);
    final slots = _pagedRows
        .where((r) => ids.contains(r.first.employeeId))
        .expand((r) => r.slots)
        .where((slot) => !slot.approved)
        .toList();
    if (slots.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.bulkApprove),
        content: Text('${s.bulkApprove} ${slots.length} ${s.checkIn.toLowerCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.approve)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _dayBulkLoading = true);
    int success = 0;
    String? firstError; // lỗi đầu tiên — hiện cho người dùng thay vì bỏ qua
    for (final slot in slots) {
      try {
        await _repo.approveAttendance(slot.attendanceId,
            employeeId: slot.employeeId, date: slot.date, shiftAssignmentId: slot.shiftAssignmentId);
        success++;
      } catch (e) { firstError ??= serverMsg(e); }
    }
    if (mounted) {
      setState(() { _dayBulkLoading = false; _selectedEmployeeIds.clear(); _daySelectionMode = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(firstError == null ? s.bulkActionDone(success, slots.length) : '${s.bulkActionDone(success, slots.length)}\n$firstError')));
      await _loadRows();
    }
  }

  Future<void> _dayBulkUnapprove() async {
    final s = AppLocalizations.of(context);
    final ids = Set<int>.from(_selectedEmployeeIds);
    final slots = _pagedRows
        .where((r) => ids.contains(r.first.employeeId))
        .expand((r) => r.slots)
        .where((slot) => slot.approved && slot.attendanceId != null)
        .toList();
    if (slots.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.bulkUnapprove),
        content: Text('${s.bulkUnapprove} ${slots.length} ${s.checkIn.toLowerCase()}?'),
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
    setState(() => _dayBulkLoading = true);
    int success = 0;
    String? firstError; // lỗi đầu tiên — hiện cho người dùng thay vì bỏ qua
    for (final slot in slots) {
      try { await _repo.unapproveAttendance(slot.attendanceId!); success++; } catch (e) { firstError ??= serverMsg(e); }
    }
    if (mounted) {
      setState(() { _dayBulkLoading = false; _selectedEmployeeIds.clear(); _daySelectionMode = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(firstError == null ? s.bulkActionDone(success, slots.length) : '${s.bulkActionDone(success, slots.length)}\n$firstError')));
      await _loadRows();
    }
  }

  // ── Inline editing ─────────────────────────────────────────────────────────

  String _daySlotKey(DayViewRow slot) =>
      '${slot.employeeId}_${slot.date}_${slot.shiftAssignmentId ?? 0}_${slot.attendanceId ?? 0}'; // một ngày có thể có nhiều lượt không ca → thêm mã dòng công

  TextEditingController _dayCtrlFor(String slotKey, String col, String initVal) {
    final k = '$slotKey:$col';
    return _dayEditCtrls.putIfAbsent(k, () => TextEditingController(text: initVal));
  }

  void _enterDayEditSlot(DayViewRow slot) {
    final slotKey = _daySlotKey(slot);
    _dayCtrlFor(slotKey, 'checkIn',  slot.overrideCheckIn  ?? slot.checkIn  ?? '').text = slot.overrideCheckIn  ?? slot.checkIn  ?? '';
    _dayCtrlFor(slotKey, 'checkOut', slot.overrideCheckOut ?? slot.checkOut ?? '').text = slot.overrideCheckOut ?? slot.checkOut ?? '';
    _dayCtrlFor(slotKey, 'break',
        slot.overrideBreakMinutes != null ? formatAttendanceMinutes(slot.overrideBreakMinutes!) : _formatBreak(slot.breakMinutes)).text =
        slot.overrideBreakMinutes != null ? formatAttendanceMinutes(slot.overrideBreakMinutes!) : _formatBreak(slot.breakMinutes);
    _dayCtrlFor(slotKey, 'otDay',
        slot.overrideOtDayMinutes != null ? formatAttendanceMinutes(slot.overrideOtDayMinutes!) : (slot.otDayHours > 0 ? _formatHours(slot.otDayHours) : '')).text =
        slot.overrideOtDayMinutes != null ? formatAttendanceMinutes(slot.overrideOtDayMinutes!) : (slot.otDayHours > 0 ? _formatHours(slot.otDayHours) : '');
    _dayCtrlFor(slotKey, 'otNight',
        slot.overrideOtNightMinutes != null ? formatAttendanceMinutes(slot.overrideOtNightMinutes!) : (slot.otNightHours > 0 ? _formatHours(slot.otNightHours) : '')).text =
        slot.overrideOtNightMinutes != null ? formatAttendanceMinutes(slot.overrideOtNightMinutes!) : (slot.otNightHours > 0 ? _formatHours(slot.otNightHours) : '');
    setState(() => _editingDaySlotKeys.add(slotKey));
  }

  void _cancelDayEditSlot([String? slotKey]) {
    setState(() {
      if (slotKey != null) {
        _editingDaySlotKeys.remove(slotKey);
      } else {
        _editingDaySlotKeys.clear();
      }
    });
  }

  void _dayBulkEnterEdit() {
    final ids = Set<int>.from(_selectedEmployeeIds);
    final slots = _pagedRows
        .where((r) => ids.contains(r.first.employeeId))
        .expand((r) => r.slots)
        .where((slot) => !slot.approved)
        .toList();
    for (final slot in slots) {
      final slotKey = _daySlotKey(slot);
      _dayCtrlFor(slotKey, 'checkIn',  slot.overrideCheckIn  ?? slot.checkIn  ?? '').text = slot.overrideCheckIn  ?? slot.checkIn  ?? '';
      _dayCtrlFor(slotKey, 'checkOut', slot.overrideCheckOut ?? slot.checkOut ?? '').text = slot.overrideCheckOut ?? slot.checkOut ?? '';
      _dayCtrlFor(slotKey, 'break',
          slot.overrideBreakMinutes != null ? formatAttendanceMinutes(slot.overrideBreakMinutes!) : _formatBreak(slot.breakMinutes)).text =
          slot.overrideBreakMinutes != null ? formatAttendanceMinutes(slot.overrideBreakMinutes!) : _formatBreak(slot.breakMinutes);
      _dayCtrlFor(slotKey, 'otDay',
          slot.overrideOtDayMinutes != null ? formatAttendanceMinutes(slot.overrideOtDayMinutes!) : (slot.otDayHours > 0 ? _formatHours(slot.otDayHours) : '')).text =
          slot.overrideOtDayMinutes != null ? formatAttendanceMinutes(slot.overrideOtDayMinutes!) : (slot.otDayHours > 0 ? _formatHours(slot.otDayHours) : '');
      _dayCtrlFor(slotKey, 'otNight',
          slot.overrideOtNightMinutes != null ? formatAttendanceMinutes(slot.overrideOtNightMinutes!) : (slot.otNightHours > 0 ? _formatHours(slot.otNightHours) : '')).text =
          slot.overrideOtNightMinutes != null ? formatAttendanceMinutes(slot.overrideOtNightMinutes!) : (slot.otNightHours > 0 ? _formatHours(slot.otNightHours) : '');
      _editingDaySlotKeys.add(slotKey);
    }
    setState(() { _daySelectionMode = false; _selectedEmployeeIds.clear(); });
  }

  Future<void> _saveDayAllEditSlots() async {
    final s = AppLocalizations.of(context);
    final editingKeys = Set<String>.from(_editingDaySlotKeys);
    final slotMap = <String, DayViewRow>{};
    for (final row in _rows) {
      final k = _daySlotKey(row);
      if (editingKeys.contains(k)) slotMap[k] = row;
    }
    if (slotMap.isEmpty) return;
    setState(() { _editingDaySlotKeys.clear(); _dayBulkLoading = true; });
    int success = 0;
    String? firstError; // lỗi đầu tiên — hiện cho người dùng thay vì bỏ qua
    for (final entry in slotMap.entries) {
      final slotKey = entry.key;
      final slot = entry.value;
      final ciRaw = _dayEditCtrls['$slotKey:checkIn']?.text.trim()  ?? '';
      final coRaw = _dayEditCtrls['$slotKey:checkOut']?.text.trim() ?? '';
      final brRaw = _dayEditCtrls['$slotKey:break']?.text.trim()    ?? '';
      final odRaw = _dayEditCtrls['$slotKey:otDay']?.text.trim()    ?? '';
      final onRaw = _dayEditCtrls['$slotKey:otNight']?.text.trim()  ?? '';
      final ci = ciRaw.isEmpty ? null : parseAttendanceTime(ciRaw);
      final co = coRaw.isEmpty ? null : parseAttendanceTime(coRaw);
      final br = brRaw.isEmpty ? null : parseAttendanceDuration(brRaw);
      final od = odRaw.isEmpty ? null : parseAttendanceDuration(odRaw);
      final on = onRaw.isEmpty ? null : parseAttendanceDuration(onRaw);
      if ((ciRaw.isNotEmpty && ci == null) || (coRaw.isNotEmpty && co == null) ||
          (brRaw.isNotEmpty && br == null) || (odRaw.isNotEmpty && od == null) ||
          (onRaw.isNotEmpty && on == null)) {
        continue;
      }

      String? norm(String? v) { final x = (v ?? '').trim(); return x.isEmpty ? null : parseAttendanceTime(x); }
      int? effBr(int m) => m > 0 ? m : null;
      int? effOt(double h) => h <= 0 ? null : (h * 60).round();

      final nextCI = ciRaw.isEmpty ? null : (norm(slot.overrideCheckIn) != null ? (ci == norm(slot.overrideCheckIn) ? slot.overrideCheckIn : ci) : (ci == norm(slot.checkIn) ? null : ci));
      final nextCO = coRaw.isEmpty ? null : (norm(slot.overrideCheckOut) != null ? (co == norm(slot.overrideCheckOut) ? slot.overrideCheckOut : co) : (co == norm(slot.checkOut) ? null : co));
      final nextBr = brRaw.isEmpty ? null : (slot.overrideBreakMinutes != null ? (br == slot.overrideBreakMinutes ? slot.overrideBreakMinutes : br) : (br == effBr(slot.breakMinutes) ? null : br));
      final nextOD = odRaw.isEmpty ? null : (slot.overrideOtDayMinutes != null ? (od == slot.overrideOtDayMinutes ? slot.overrideOtDayMinutes : od) : (od == effOt(slot.otDayHours) ? null : od));
      final nextON = onRaw.isEmpty ? null : (slot.overrideOtNightMinutes != null ? (on == slot.overrideOtNightMinutes ? slot.overrideOtNightMinutes : on) : (on == effOt(slot.otNightHours) ? null : on));
      try {
        final int attId = slot.attendanceId ?? await _repo.ensureAttendance(slot.employeeId, slot.date);
        await _repo.saveOverride(attId, checkIn: nextCI, checkOut: nextCO,
            breakMinutes: nextBr, otDayMinutes: nextOD, otNightMinutes: nextON, note: slot.overrideNote);
        success++;
      } catch (e) { firstError ??= serverMsg(e); }
    }
    if (mounted) {
      setState(() => _dayBulkLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(firstError == null ? s.bulkActionDone(success, slotMap.length) : '${s.bulkActionDone(success, slotMap.length)}\n$firstError')));
      await _loadRows();
    }
  }

  Future<void> _saveDayEditSlot(DayViewRow slot) async {
    final slotKey = _daySlotKey(slot);
    setState(() => _editingDaySlotKeys.remove(slotKey));
    final ciRaw = _dayEditCtrls['$slotKey:checkIn']?.text.trim()  ?? '';
    final coRaw = _dayEditCtrls['$slotKey:checkOut']?.text.trim() ?? '';
    final brRaw = _dayEditCtrls['$slotKey:break']?.text.trim()    ?? '';
    final odRaw = _dayEditCtrls['$slotKey:otDay']?.text.trim()    ?? '';
    final onRaw = _dayEditCtrls['$slotKey:otNight']?.text.trim()  ?? '';

    final ci = ciRaw.isEmpty ? null : parseAttendanceTime(ciRaw);
    final co = coRaw.isEmpty ? null : parseAttendanceTime(coRaw);
    final br = brRaw.isEmpty ? null : parseAttendanceDuration(brRaw);
    final od = odRaw.isEmpty ? null : parseAttendanceDuration(odRaw);
    final on = onRaw.isEmpty ? null : parseAttendanceDuration(onRaw);
    if ((ciRaw.isNotEmpty && ci == null) || (coRaw.isNotEmpty && co == null) ||
        (brRaw.isNotEmpty && br == null) || (odRaw.isNotEmpty && od == null) ||
        (onRaw.isNotEmpty && on == null)) {
      return;
    }

    String? norm(String? v) { final s = (v ?? '').trim(); return s.isEmpty ? null : parseAttendanceTime(s); }
    int? effBr(int m) => m > 0 ? m : null;
    int? effOt(double h) => h <= 0 ? null : (h * 60).round();

    final nextCI = ciRaw.isEmpty ? null : (norm(slot.overrideCheckIn) != null ? (ci == norm(slot.overrideCheckIn) ? slot.overrideCheckIn : ci) : (ci == norm(slot.checkIn) ? null : ci));
    final nextCO = coRaw.isEmpty ? null : (norm(slot.overrideCheckOut) != null ? (co == norm(slot.overrideCheckOut) ? slot.overrideCheckOut : co) : (co == norm(slot.checkOut) ? null : co));
    final nextBr = brRaw.isEmpty ? null : (slot.overrideBreakMinutes != null ? (br == slot.overrideBreakMinutes ? slot.overrideBreakMinutes : br) : (br == effBr(slot.breakMinutes) ? null : br));
    final nextOD = odRaw.isEmpty ? null : (slot.overrideOtDayMinutes != null ? (od == slot.overrideOtDayMinutes ? slot.overrideOtDayMinutes : od) : (od == effOt(slot.otDayHours) ? null : od));
    final nextON = onRaw.isEmpty ? null : (slot.overrideOtNightMinutes != null ? (on == slot.overrideOtNightMinutes ? slot.overrideOtNightMinutes : on) : (on == effOt(slot.otNightHours) ? null : on));

    try {
      final int attId = slot.attendanceId ?? await _repo.ensureAttendance(slot.employeeId, slot.date);
      await _repo.saveOverride(attId, checkIn: nextCI, checkOut: nextCO,
          breakMinutes: nextBr, otDayMinutes: nextOD, otNightMinutes: nextON, note: slot.overrideNote);
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  // ── Inline cell widget ─────────────────────────────────────────────────────

  Widget _inlineCell({
    required _CellKey key,
    required String displayVal,
    required String? overrideVal,
    required double width,
    required Color bg,
    required DayViewRow slot,
    bool isTime = true,
    bool rounded = false,
    String? roundedRawVal,
    int displayOffset = 0,
    int overrideOffset = 0,
  }) {
    final slotKey = _daySlotKey(slot);
    if (_editingDaySlotKeys.contains(slotKey)) {
      final ctrl = _dayEditCtrls['$slotKey:${key.col}'] ??
          TextEditingController(text: overrideVal ?? displayVal);
      return AttEditTimeCell(ctrl: ctrl, width: width, height: attDayRowHeight, bg: bg, isTime: isTime);
    }

    final showActual = displayVal.isNotEmpty && displayVal != overrideVal;
    return Container(
      width: width, height: attDayRowHeight, alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, border: Border(
        bottom: BorderSide(color: attGridLineLight, width: 0.9),
        right: BorderSide(color: attGridLineLight, width: 0.8),
      )),
      child: overrideVal != null
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                DayOffsetText(overrideVal, dayOffset: overrideOffset,
                    style: const TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                const Icon(Icons.edit, size: 9, color: AppTheme.error),
                if (rounded) ...[
                  const SizedBox(width: 2),
                  Tooltip(message: roundedRawVal ?? displayVal,
                      child: const Icon(Icons.schedule, size: 9, color: AppTheme.primary)),
                ],
              ]),
              if (showActual)
                DayOffsetText('($displayVal)', dayOffset: displayOffset,
                    style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              DayOffsetText(displayVal, dayOffset: displayOffset,
                  style: TextStyle(fontSize: 12,
                      color: displayVal.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)),
              if (rounded && displayVal.isNotEmpty) ...[
                const SizedBox(width: 2),
                Tooltip(message: roundedRawVal ?? displayVal,
                    child: const Icon(Icons.schedule, size: 10, color: AppTheme.primary)),
              ],
            ]),
    );
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _init() async {
    // Mỗi nguồn tải riêng; dữ liệu công luôn được tải dù phòng ban / cài đặt lỗi.
    final depts = await DepartmentService.instance.getFlat(permission: 'ATTENDANCE_VIEW').catchError((_) => <DepartmentFlat>[]);
    final settings = await _settingRepo.get().catchError((_) => <String, dynamic>{});
    if (!mounted) return;
    final att = settings['attendance'] as Map<String, dynamic>? ?? {};
    setState(() {
      _depts = depts;
      _dayNightMode = att['dayNightMode'] == true;
      _otEnabled = att['otEnabled'] != false;
    });
    _loadRows();
  }

  Future<void> _loadRows() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _repo.getDayView(date: _date, departmentId: _filterDept);
      if (mounted) setState(() { _rows = rows; _loading = false; _page = 0; });
    } catch (e) {
      if (mounted) setState(() { _error = serverMsg(e); _loading = false; });
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
        await _loadRows();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _exportExcel() async {
    final s = AppLocalizations.of(context);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final result = await _repo.exportDayView(
        date: dateStr,
        departmentId: _filterDept,
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

  Future<AttendanceChangeRequest> _setRequestApplied(int id, bool applied) async {
    final updated = await _repo.setRequestApplied(id, applied);
    if (mounted) await _loadRows();
    return updated;
  }

  Future<bool> _setLeaveRequestApplied(int id, bool applied) async {
    final updated = await _leaveRepo.setRequestApplied(id, applied);
    if (mounted) await _loadRows();
    return updated['applied'] == true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020, 1, 1), lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    _loadRows();
  }

  String _dayLabel(DateTime date) => fullDayLabel(context, date);

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year && _date.month == now.month && _date.day == now.day;
  }

  // ── Merged rows / pagination ───────────────────────────────────────────────

  List<AttMergedDayViewRow> get _mergedRows {
    final groups = <String, List<DayViewRow>>{};
    for (final row in _rows) {
      final key = '${row.employeeId}_${row.date.year}-${row.date.month}-${row.date.day}';
      groups.putIfAbsent(key, () => []).add(row);
    }
    return groups.values.map((rows) {
      rows.sort(_compareDayViewSlots);
      return AttMergedDayViewRow(rows);
    }).toList();
  }

  List<AttMergedDayViewRow> get _pagedRows {
    final start = _page * _pageSize;
    final merged = _mergedRows;
    if (start >= merged.length) return const [];
    return merged.sublist(start, (start + _pageSize).clamp(0, merged.length));
  }

  int get _totalPages => _mergedRows.isEmpty ? 1 : (_mergedRows.length / _pageSize).ceil();

  int _compareDayViewSlots(DayViewRow a, DayViewRow b) {
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
    return DateTime(1970, 1, 1, hour, minute);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar
        Container(
          color: AppTheme.background,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: () { setState(() { _date = _date.subtract(const Duration(days: 1)); _page = 0; }); _loadRows(); },
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
              InkWell(
                onTap: _pickDate, borderRadius: BorderRadius.circular(6),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(_dayLabel(_date),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              ),
              IconButton(icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: () { setState(() { _date = _date.add(const Duration(days: 1)); _page = 0; }); _loadRows(); },
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              DepartmentPickerField(
                departments: _depts, value: _filterDept, label: s.departmentShort,
                allowAll: true, compact: true,
                onChanged: (v) { setState(() { _filterDept = v; _page = 0; }); _loadRows(); },
              ),
              const SizedBox(width: 8),
              if (_loading)
                const Padding(padding: EdgeInsets.only(right: 8),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              TextButton.icon(onPressed: _loadRows,
                  icon: const Icon(Icons.refresh, size: 18), label: Text(s.refresh)),
              const Spacer(),
            ]),
          ]),
        ),
        const Divider(height: 1),
        // Checklist toolbar
        Container(
          color: AppTheme.background,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const Spacer(),
            Tooltip(
              message: s.bulkEdit,
              child: IconButton(
                icon: Icon(Icons.checklist_outlined, size: 20,
                    color: _daySelectionMode ? AppTheme.primary : AppTheme.textSecondary),
                style: _daySelectionMode
                    ? IconButton.styleFrom(backgroundColor: AppTheme.primary.withValues(alpha: 0.1))
                    : null,
                onPressed: () => setState(() {
                  _daySelectionMode = !_daySelectionMode;
                  if (!_daySelectionMode) _selectedEmployeeIds.clear();
                }),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ]),
        ),
        // Bulk action bar
        if (_daySelectionMode)
          Container(
            color: AppTheme.primary.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              InkWell(
                onTap: _toggleSelectAllEmployees, borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.checklist_outlined, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      _selectedEmployeeIds.isEmpty ? s.selectAll : s.selectedCount(_selectedEmployeeIds.length),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                    ),
                  ]),
                ),
              ),
              const Spacer(),
              if (_dayBulkLoading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                if (canManageAttendance()) OutlinedButton.icon(
                  onPressed: _selectedEmployeeIds.isEmpty ? null : _dayBulkEnterEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16), label: Text(s.bulkEdit),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                if (canApproveAttendance()) FilledButton.icon(
                  onPressed: _selectedEmployeeIds.isEmpty ? null : _dayBulkApprove,
                  icon: const Icon(Icons.check_circle_outline, size: 16), label: Text(s.bulkApprove),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                if (canApproveAttendance()) OutlinedButton.icon(
                  onPressed: _selectedEmployeeIds.isEmpty ? null : _dayBulkUnapprove,
                  icon: const Icon(Icons.lock_open_outlined, size: 16), label: Text(s.bulkUnapprove),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.warning,
                      side: const BorderSide(color: AppTheme.warning),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.close, size: 18), tooltip: s.cancel,
                  onPressed: () => setState(() { _daySelectionMode = false; _selectedEmployeeIds.clear(); })),
            ]),
          ),
        // Bulk edit save bar
        if (_editingDaySlotKeys.isNotEmpty)
          Container(
            color: AppTheme.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(s.uiRowsEditing('${_editingDaySlotKeys.length}'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
              const Spacer(),
              if (_dayBulkLoading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                FilledButton.icon(onPressed: _saveDayAllEditSlots,
                    icon: const Icon(Icons.check, size: 16), label: Text(s.save),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12))),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: () => _cancelDayEditSlot(),
                    icon: const Icon(Icons.close, size: 16), label: Text(s.cancel),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12))),
              ],
            ]),
          ),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
              : _rows.isEmpty && !_loading
                  ? Center(child: Text(s.noAttendanceDataForThisDay,
                        style: TextStyle(color: AppTheme.textSecondary)))
                  : _buildTable(),
        ),
      ],
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  Widget _buildTable() {
    final s = AppLocalizations.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      const checkW = 40.0;
      final isMobile = constraints.maxWidth < 600;
      final dayFirstColW = isMobile ? 130.0 : attDayFirstColW;
      final fixedW = (_daySelectionMode ? checkW : 0.0) + dayFirstColW;
      final cols = attCols(s, dayNight: _dayNightMode, otEnabled: _otEnabled);
      final dataMin = cols.fold<double>(0, (sum, c) => sum + c.width);
      final available = constraints.maxWidth - fixedW - 1;
      final scale = available > dataMin ? available / dataMin : 1.0;
      final dataWidths = cols.map((c) => c.width * scale).toList();
      final paged = _pagedRows;

      return Column(children: [
        Expanded(
          child: AttendanceGrid(
            fixedColumnHeader: s.employee,
            fixedColumnWidth: dayFirstColW,
            columnHeaders: cols.map((c) => c.label).toList(),
            columnWidths: dataWidths,
            rowCount: paged.length,
            rowHeightAt: (i) {
              final slots = _dayDisplaySlots(paged[i]);
              return attDayRowHeight * (slots.isEmpty ? 1 : slots.length);
            },
            isWeekend: (i) => paged[i].weekend,
            isToday: (i) => _isToday,
            selectionMode: _daySelectionMode,
            isSelected: (i) => _daySelectionMode &&
                _selectedEmployeeIds.contains(paged[i].first.employeeId),
            allSelected: _selectedEmployeeIds.isEmpty
                ? false
                : _selectedEmployeeIds
                        .containsAll(paged.map((r) => r.first.employeeId).toSet())
                    ? true
                    : null,
            onToggleSelectAll: _toggleSelectAllEmployees,
            onToggleSelect: (i) => _toggleSelectEmployee(paged[i].first.employeeId),
            checkboxWidth: checkW,
            fixedCellBuilder: (i, width, bg, selected) {
              final row = paged[i];
              final slots = _dayDisplaySlots(row);
              final height = attDayRowHeight * (slots.isEmpty ? 1 : slots.length);
              return _dayEmployeeCellSelectable(row, width, height,
                  selected: selected,
                  onTap: _daySelectionMode
                      ? () => _toggleSelectEmployee(row.first.employeeId)
                      : null);
            },
            dataCellsBuilder: (i, widths, bg, selected) {
              final row = paged[i];
              final slots = _dayDisplaySlots(row);
              final rowCount = slots.isEmpty ? 1 : slots.length;
              return [
                GestureDetector(
                  onTap: _daySelectionMode
                      ? () => _toggleSelectEmployee(row.first.employeeId)
                      : null,
                  child: Column(children: [
                    for (int si = 0; si < rowCount; si++)
                      SizedBox(
                        height: attDayRowHeight,
                        child: ColoredBox(
                          color: bg,
                          child: Row(
                            children: _daySlotCells(row, slots[si],
                                slotIndex: si, cw: widths, bg: bg),
                          ),
                        ),
                      ),
                  ]),
                ),
              ];
            },
            hScrollController: _hScroll,
            vScrollController: _vScroll,
          ),
        ),
        Padding(padding: const EdgeInsets.only(bottom: 4), child: _buildPaginationBar()),
      ]);
    });
  }

  // ── Pagination bar ─────────────────────────────────────────────────────────

  Widget _buildPaginationBar() {
    final s = AppLocalizations.of(context);
    final total = _rows.length;
    final totalPages = _totalPages;
    final page = _page.clamp(0, totalPages - 1);
    final first = total == 0 ? 0 : page * _pageSize + 1;
    final last = total == 0 ? 0 : ((page + 1) * _pageSize).clamp(0, total);

    return Container(
      height: 40,
      decoration: BoxDecoration(color: AppTheme.surfaceAlt,
          border: Border(top: BorderSide(color: attGridLine))),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Text('${s.rowsPerPage}:',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(width: 6),
        PopupMenuButton<int>(
          initialValue: _pageSize, position: PopupMenuPosition.over, tooltip: '',
          onSelected: (value) => setState(() { _pageSize = value; _page = 0; }),
          itemBuilder: (_) => [10, 20, 50, 100]
              .map((n) => PopupMenuItem(value: n, height: 36,
                  child: Text('$n', style: const TextStyle(fontSize: 13)))).toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: attGridLine),
                borderRadius: BorderRadius.circular(4)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$_pageSize', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 16),
            ]),
          ),
        ),
        const Spacer(),
        Text('$first-$last / $total',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(width: 4),
        IconButton(icon: const Icon(Icons.chevron_left, size: 18),
            onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: s.previousPage),
        Text('${page + 1} / $totalPages',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        IconButton(icon: const Icon(Icons.chevron_right, size: 18),
            onPressed: page < totalPages - 1 ? () => setState(() => _page = page + 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: s.nextPage),
      ]),
    );
  }

  // ── Cell builders ──────────────────────────────────────────────────────────

  Widget _dayEmployeeCellSelectable(AttMergedDayViewRow row, double width, double height,
      {bool selected = false, VoidCallback? onTap}) {
    final first = row.first;
    final bg = selected ? AppTheme.primary.withValues(alpha: 0.10)
        : row.holidayName != null ? holidayCellColor
        : row.weekend ? AppTheme.tint(AppTheme.warning)
        : _isToday ? AppTheme.tint(AppTheme.primary) : AppTheme.background;
    final cell = Container(
      width: width, height: height, alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: bg, border: Border(
        bottom: BorderSide(color: attGridLineLight, width: 0.9),
        right: BorderSide(color: attGridLine, width: 0.8),
      )),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(first.employeeFullName, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(
          [first.employeeCode, if (first.departmentName.isNotEmpty) first.departmentName]
              .where((e) => e.isNotEmpty).join(' • '),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ]),
    );
    return onTap == null ? cell : GestureDetector(onTap: onTap, child: cell);
  }

  List<DayViewRow?> _dayDisplaySlots(AttMergedDayViewRow row) {
    if (row.slots.isEmpty) return [null];
    return row.slots.take(2).map((slot) => slot as DayViewRow?).toList();
  }

  Widget _dayCell({required double width, required Color bg, required Widget child}) {
    return Container(
      width: width, height: attDayRowHeight, alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, border: Border(
        bottom: BorderSide(color: attGridLineLight, width: 0.9),
        right: BorderSide(color: attGridLineLight, width: 0.8),
      )),
      child: child,
    );
  }

  List<AttendanceChangeRequest> _slotRequestsForSlot(AttMergedDayViewRow row, int slotIndex,
      {required String requestType, String? period, String? scope}) {
    final slot = slotIndex < row.slots.length ? row.slots[slotIndex] : null;
    final slotId = slot?.shiftAssignmentId;
    final requests = row.slots.expand((s) => s.requests).toList();
    final filtered = requests.where((r) {
      if (r.requestType != requestType) return false;
      if (period != null && (r.requestedOvertimePeriod ?? 'DAY') != period) return false;
      if (scope != null && r.requestedOvertimeScope != scope) return false;
      if (r.shiftAssignmentId == null) return slotIndex == 0;
      return slotId != null && r.shiftAssignmentId == slotId;
    }).toList();
    final seenIds = <int>{};
    return filtered.where((r) => seenIds.add(r.id)).toList();
  }

  List<Widget> _daySlotCells(AttMergedDayViewRow row, DayViewRow? slot,
      {required int slotIndex, required List<double> cw, required Color bg}) {
    final s = AppLocalizations.of(context);
    final colCount = attCols(s, dayNight: _dayNightMode, otEnabled: _otEnabled).length;
    if (slot == null) {
      return List.generate(colCount, (i) => _dayCell(width: cw[i], bg: bg, child: const SizedBox.shrink()));
    }

    final checkInRequests  = _slotRequestsForSlot(row, slotIndex, requestType: 'CHECK_IN');
    final checkOutRequests = _slotRequestsForSlot(row, slotIndex, requestType: 'CHECK_OUT');
    final otDayRequests    = _slotRequestsForSlot(row, slotIndex, requestType: 'OT', period: 'DAY');
    final otNightRequests  = _slotRequestsForSlot(row, slotIndex, requestType: 'OT', period: 'NIGHT');
    final checkInRequest   = attPickVisibleRequest(checkInRequests);
    final checkOutRequest  = attPickVisibleRequest(checkOutRequests);

    var idx = 0;
    final cells = <Widget>[];
    final leaveNotApplied = slot.leaveCode != null && slot.leaveApplied == false;
    final dateStr = '${slot.date.year}-${slot.date.month.toString().padLeft(2,'0')}-${slot.date.day.toString().padLeft(2,'0')}';

    cells.add(_dayLeaveCell(row, slot, cw[idx++], bg));
    cells.add(_dayShiftCellForSlot(slot, cw[idx++], bg));
    // Break
    cells.add(_inlineCell(
      key: (employeeId: slot.employeeId, date: dateStr, col: 'break'),
      displayVal: _formatBreak(slot.breakMinutes),
      overrideVal: slot.overrideBreakMinutes != null ? formatAttendanceMinutes(slot.overrideBreakMinutes!) : null,
      width: cw[idx++], bg: bg, slot: slot, isTime: false,
    ));
    // Check-in
    cells.add(_inlineCell(
      key: (employeeId: slot.employeeId, date: dateStr, col: 'checkIn'),
      displayVal: slot.checkIn ?? '', overrideVal: slot.overrideCheckIn,
      displayOffset: slot.checkInDayOffset, overrideOffset: slot.overrideCheckInDayOffset,
      width: cw[idx++], bg: bg, slot: slot, rounded: slot.checkInRounded, roundedRawVal: slot.checkInRaw,
    ));
    // Check-out
    cells.add(_inlineCell(
      key: (employeeId: slot.employeeId, date: dateStr, col: 'checkOut'),
      displayVal: slot.checkOut ?? '', overrideVal: slot.overrideCheckOut,
      displayOffset: slot.checkOutDayOffset, overrideOffset: slot.overrideCheckOutDayOffset,
      width: cw[idx++], bg: bg, slot: slot, rounded: slot.checkOutRounded, roundedRawVal: slot.checkOutRaw,
    ));
    cells.add(_dayRequestCell(attFormatRequestTimeOrDuration(checkInRequest), checkInRequest?.status,
        width: cw[idx++], bg: bg, strikeThrough: checkInRequest != null && !checkInRequest.applied,
        onTap: checkInRequests.isNotEmpty
            ? () => showAttRequestCardsDialog(context, title: s.checkInRequest,
                requests: checkInRequests, onToggleApplied: _setRequestApplied, attendanceApproved: slot.approved)
            : null));
    cells.add(_dayRequestCell(attFormatRequestTimeOrDuration(checkOutRequest), checkOutRequest?.status,
        width: cw[idx++], bg: bg, strikeThrough: checkOutRequest != null && !checkOutRequest.applied,
        onTap: checkOutRequests.isNotEmpty
            ? () => showAttRequestCardsDialog(context, title: s.checkOutRequest,
                requests: checkOutRequests, onToggleApplied: _setRequestApplied, attendanceApproved: slot.approved)
            : null));

    final mergedDayOt = !_otEnabled
        ? (!_dayNightMode ? [...otDayRequests, ...otNightRequests] : otDayRequests)
        : <AttendanceChangeRequest>[];
    cells.add(_dayNumCell(slot.totalHours, cw[idx++], bg, strikeThrough: leaveNotApplied));
    cells.add(_dayNumCell(slot.regularDayHours, cw[idx++], bg,
        highlight: mergedDayOt.isNotEmpty, strikeThrough: leaveNotApplied,
        onTap: mergedDayOt.isNotEmpty
            ? () => showAttRequestCardsDialog(context, title: s.dayHours,
                requests: mergedDayOt, onToggleApplied: _setRequestApplied, attendanceApproved: slot.approved)
            : null));
    if (_otEnabled) {
      cells.add(_inlineCell(
        key: (employeeId: slot.employeeId, date: dateStr, col: 'otDay'),
        displayVal: slot.otDayHours > 0 ? _formatHours(slot.otDayHours) : '',
        overrideVal: slot.overrideOtDayMinutes != null ? _formatHours(slot.overrideOtDayMinutes! / 60.0) : null,
        width: cw[idx++], bg: bg, slot: slot, isTime: false,
      ));
    }
    if (_dayNightMode) {
      final mergedNightOt = !_otEnabled ? otNightRequests : <AttendanceChangeRequest>[];
      cells.add(_dayNumCell(slot.regularNightHours, cw[idx++], bg,
          highlight: mergedNightOt.isNotEmpty, strikeThrough: leaveNotApplied,
          onTap: mergedNightOt.isNotEmpty
              ? () => showAttRequestCardsDialog(context, title: s.nightHours,
                  requests: mergedNightOt, onToggleApplied: _setRequestApplied, attendanceApproved: slot.approved)
              : null));
      if (_otEnabled) {
        cells.add(_inlineCell(
          key: (employeeId: slot.employeeId, date: dateStr, col: 'otNight'),
          displayVal: slot.otNightHours > 0 ? _formatHours(slot.otNightHours) : '',
          overrideVal: slot.overrideOtNightMinutes != null ? _formatHours(slot.overrideOtNightMinutes! / 60.0) : null,
          width: cw[idx++], bg: bg, slot: slot, isTime: false,
        ));
      }
    }
    cells.add(_dayWorkStatusCell(slot, cw[idx++], bg));
    cells.add(_daySlotActionCell(slot, cw[idx++], bg));
    return cells;
  }

  Widget _dayLeaveCell(AttMergedDayViewRow row, DayViewRow slot, double width, Color bg) {
    final effectiveLeaves = slot.leaves.isNotEmpty
        ? slot.leaves
        : slot.leaveRequestId != null
            ? [DayViewLeaveInfo(
                leaveRequestId: slot.leaveRequestId!,
                leaveCode: slot.leaveCode, leaveMode: slot.leaveMode,
                leaveStatus: slot.leaveStatus, leaveApplied: slot.leaveApplied,
                leaveProcessedByName: slot.leaveProcessedByName,
                leaveProcessedAt: slot.leaveProcessedAt, leaveCreatedAt: slot.leaveCreatedAt,
                leaveAmount: slot.leaveAmount, leaveFromTime: slot.leaveFromTime, leaveToTime: slot.leaveToTime,
              )]
            : <DayViewLeaveInfo>[];

    final isLeave = effectiveLeaves.isNotEmpty;
    DayViewLeaveInfo? visibleLeave;
    if (isLeave) {
      visibleLeave = effectiveLeaves.firstWhere((l) => l.leaveApplied == true, orElse: () => effectiveLeaves.last);
    }
    final hasAnyDayRange = effectiveLeaves.any((l) => l.leaveMode == 'DAY_RANGE');
    final effectiveBg = hasAnyDayRange && isLeave ? AppTheme.tint(AppTheme.secondary) : bg;

    Widget buildBadge(DayViewLeaveInfo l) {
      final notApplied = l.leaveApplied == false;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: notApplied ? AppTheme.textSecondary.withValues(alpha: 0.1) : const Color(0xFF4CAF50).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(l.leaveCode ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: notApplied ? AppTheme.textSecondary : const Color(0xFF2E7D32),
              decoration: notApplied ? TextDecoration.lineThrough : null,
              decorationColor: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ),
        if (l.leaveMode == 'HOUR_RANGE' && l.leaveFromTime != null && l.leaveToTime != null)
          Text('${l.leaveFromTime}-${l.leaveToTime}', style: TextStyle(fontSize: 9,
              color: notApplied ? AppTheme.textSecondary : const Color(0xFF2E7D32),
              decoration: notApplied ? TextDecoration.lineThrough : null)),
      ]);
    }

    final child = _dayCell(width: width, bg: effectiveBg,
        child: visibleLeave != null ? buildBadge(visibleLeave) : const SizedBox.shrink());
    if (!isLeave) return child;
    return Material(color: Colors.transparent, child: InkWell(
      onTap: () => _showLeaveCardsDialog(
          employeeName: row.first.employeeFullName,
          departmentName: row.first.departmentName,
          leaves: effectiveLeaves, attendanceApproved: slot.approved),
      child: child,
    ));
  }

  Future<void> _showLeaveCardsDialog({
    required String employeeName, required String departmentName,
    required List<DayViewLeaveInfo> leaves, required bool attendanceApproved,
  }) async {
    final s = AppLocalizations.of(context);
    final appliedIds = <int>{for (final l in leaves) if (l.leaveApplied == true) l.leaveRequestId};
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.leave),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: leaves.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AttLeaveInfoCard(
                  leave: l,
                  appliedOverride: appliedIds.contains(l.leaveRequestId),
                  employeeName: employeeName,
                  departmentName: departmentName,
                  attendanceApproved: attendanceApproved,
                  onToggleApplied: (value) async {
                    if (value) {
                      for (final other in leaves.where((o) => o.leaveRequestId != l.leaveRequestId)) {
                        if (appliedIds.contains(other.leaveRequestId)) {
                          await _setLeaveRequestApplied(other.leaveRequestId, false);
                          setDialogState(() => appliedIds.remove(other.leaveRequestId));
                        }
                      }
                    }
                    final updated = await _setLeaveRequestApplied(l.leaveRequestId, value);
                    setDialogState(() {
                      if (updated) {
                        appliedIds.add(l.leaveRequestId);
                      } else {
                        appliedIds.remove(l.leaveRequestId);
                      }
                    });
                    return updated;
                  },
                  onChanged: () => _loadRows(),
                ),
              )).toList()),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close))],
        ),
      ),
    );
  }

  Widget _dayShiftCellForSlot(DayViewRow? slot, double width, Color bg) {
    if (slot == null) return _dayCell(width: width, bg: bg, child: const SizedBox.shrink());
    Color? dotColor;
    if (slot.shiftColor != null) {
      try { dotColor = Color(int.parse(slot.shiftColor!.replaceAll('#', '0xFF'))); } catch (_) {}
    }
    return _dayCell(width: width, bg: bg, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (dotColor != null) ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
        ],
        Flexible(child: Text(slot.shiftName ?? '', style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
      ]),
      if ((slot.shiftStart ?? '').isNotEmpty || (slot.shiftEnd ?? '').isNotEmpty)
        Text(_formatShiftRange(slot.shiftStart, slot.shiftEnd),
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
    ]));
  }

  /// Quyền duyệt / bỏ duyệt công tách riêng khỏi quyền xem (BE: ATTENDANCE_APPROVE).
  bool get _canApprove => canApproveAttendance();

  Widget _daySlotActionCell(DayViewRow? slot, double width, Color bg) {
    final s = AppLocalizations.of(context);
    if (slot == null) return _dayCell(width: width, bg: bg, child: const SizedBox.shrink());
    if (slot.approved) {
      return _dayCell(width: width, bg: bg, child: Row(
        mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: slot.approvedByName != null ? '${s.approved}: ${slot.approvedByName}' : s.approved,
            child: const Icon(Icons.check_circle, color: AppTheme.secondary, size: 18),
          ),
          if (_canApprove) ...[
            const SizedBox(width: 2),
            SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 15,
                icon: const Icon(Icons.lock_open_outlined, color: AppTheme.warning),
                tooltip: s.unapprove, onPressed: () => _unapproveAttendance(slot))),
          ],
        ],
      ));
    }
    final slotKey = _daySlotKey(slot);
    final isEditing = _editingDaySlotKeys.contains(slotKey);
    return _dayCell(width: width, bg: bg, child: FittedBox(fit: BoxFit.scaleDown, child: Row(
      mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
      children: [
        if (isEditing) ...[
          SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
              icon: const Icon(Icons.check, color: AppTheme.secondary),
              tooltip: s.save, onPressed: () => _saveDayEditSlot(slot))),
          const SizedBox(width: 2),
          SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
              icon: const Icon(Icons.close, color: AppTheme.error),
              tooltip: s.cancel, onPressed: () => _cancelDayEditSlot(slotKey))),
        ] else ...[
          if (canManageAttendance())
            SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
                icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                tooltip: s.edit, onPressed: () => _enterDayEditSlot(slot))),
          if (slot.attendanceId != null && canManageAttendance()) ...[
            const SizedBox(width: 2),
            SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                tooltip: s.delete, onPressed: () => _confirmDelete(slot))),
          ],
          if (_canApprove) ...[
            const SizedBox(width: 2),
            SizedBox(width: 24, height: 24, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
                icon: const Icon(Icons.check_circle_outline, color: AppTheme.secondary),
                tooltip: s.approve, onPressed: () => _approveAttendance(slot))),
          ],
        ],
      ],
    )));
  }

  Widget _dayNumCell(double val, double width, Color bg,
      {bool highlight = false, VoidCallback? onTap, bool strikeThrough = false}) {
    final text = val > 0 ? _formatHours(val) : '';
    final child = Container(
      width: width, height: attDayRowHeight, alignment: Alignment.center,
      decoration: BoxDecoration(
          color: highlight ? AppTheme.warning.withValues(alpha: 0.08) : bg,
          border: Border(bottom: BorderSide(color: attGridLineLight, width: 0.9),
              right: BorderSide(color: attGridLineLight, width: 0.8))),
      child: Text(text, style: TextStyle(fontSize: 12,
          fontWeight: val > 0 ? FontWeight.w600 : FontWeight.normal,
          color: strikeThrough ? AppTheme.textSecondary
              : highlight ? AppTheme.warning
              : val > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
          decoration: strikeThrough ? TextDecoration.lineThrough : null)),
    );
    return onTap == null ? child : Material(color: Colors.transparent,
        child: InkWell(onTap: onTap, child: child));
  }

  Widget _dayWorkStatusCell(DayViewRow slot, double width, Color bg) {
    final s = AppLocalizations.of(context);
    final flags = slot.workFlags;
    if (flags.isEmpty) return _dayCell(width: width, bg: bg, child: const SizedBox.shrink());
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
    return _dayCell(width: width, bg: bg,
        child: SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(mainAxisSize: MainAxisSize.min, children: chips)));
  }

  Widget _dayRequestCell(String? value, String? status, {
    required double width, required Color bg,
    bool strikeThrough = false, VoidCallback? onTap,
  }) {
    final text = value ?? '';
    final color = switch (status) {
      'APPROVED' => Colors.green, 'REJECTED' => AppTheme.error,
      'PENDING' => AppTheme.warning, _ => AppTheme.textSecondary,
    };
    final child = Container(
      width: width, height: attDayRowHeight, alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, border: Border(
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

  Future<void> _approveAttendance(DayViewRow slot) async {
    final s = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(title: Text(s.approve),
          content: Text(s.uiApproveAttendanceConfirm(slot.employeeFullName, '${slot.date.day}/${slot.date.month}/${slot.date.year}')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.approve))],
        ));
    if (confirm != true || !mounted) return;
    try {
      await _repo.approveAttendance(slot.attendanceId,
          employeeId: slot.employeeId, date: slot.date, shiftAssignmentId: slot.shiftAssignmentId);
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _unapproveAttendance(DayViewRow slot) async {
    final s = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(title: Text(s.unapprove),
          content: Text(s.uiUnapproveAttendanceConfirm(slot.employeeFullName, '${slot.date.day}/${slot.date.month}/${slot.date.year}')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.warning),
                onPressed: () => Navigator.pop(ctx, true), child: Text(s.unapprove))],
        ));
    if (confirm != true || !mounted) return;
    try {
      await _repo.unapproveAttendance(slot.attendanceId!);
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _confirmDelete(DayViewRow row) async {
    final s = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(title: Text(s.delete),
          content: Text('${s.delete} ${row.employeeFullName} ${row.date.day}/${row.date.month}/${row.date.year}?'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete))],
        ));
    if (confirm != true || !mounted) return;
    try {
      await _repo.deleteAttendance(row.attendanceId!);
      await _loadRows();
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
