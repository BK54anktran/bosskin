import 'package:bosskin/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../data/models/work_shift.dart';
import '../../../data/models/employee.dart';
import '../../../data/repositories/company_setting_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/pagination_bar.dart';

// ── Layout constants ─────────────────────────────────────────────────────────
const double _nameW = 200.0;
const double _dayW = 200.0;
const double _rowH = 56.0;
const double _headH = 44.0;
const Color _border = Color(0xFFD0D5DD);
const Color _headBg = Color(0xFFF2F4F7);

class ShiftAssignTab extends StatefulWidget {
  final List<WorkShift> shifts;
  final bool canManage;
  final String searchQuery;
  final int? departmentFilterId;
  final Set<int> departmentFilterScopeIds;

  const ShiftAssignTab({
    required this.shifts,
    required this.canManage,
    required this.searchQuery,
    required this.departmentFilterId,
    required this.departmentFilterScopeIds,
    super.key,
  });

  @override
  State<ShiftAssignTab> createState() => _ShiftAssignTabState();
}

class _ShiftAssignTabState extends State<ShiftAssignTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Employee> _employees = [];
  List<ShiftAssignment> _assignments = [];
  bool _loadingEmps = true;
  bool _loadingAssigns = false;
  int _cutoffDay = 1; // loaded from company settings

  // ── Quick-fill panel ────────────────────────────────────────────────────
  bool _panelOpen = false;
  int? _quickFill; // null = off, -1 = custom hours, >0 = shiftId

  final _settingRepo = CompanySettingRepository();

  /// Trả về danh sách ngày trong kỳ lương của _month dựa theo _cutoffDay.
  List<DateTime> get _periodDays {
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
    final days = <DateTime>[];
    for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(d);
    }
    return days;
  }

  // ── Pagination ───────────────────────────────────────────────────────────
  int _pageSize = 20;
  int _page = 0;

  List<Employee> get _filteredEmployees {
    final q = foldSearchText(widget.searchQuery);
    return _employees.where((e) {
      final byDept = widget.departmentFilterId == null ||
          widget.departmentFilterScopeIds.contains(e.departmentId);
      if (!byDept) return false;
      if (q.isEmpty) return true;
      return foldSearchText(e.fullName).contains(q) ||
          foldSearchText(e.employeeCode).contains(q) ||
          foldSearchText(e.departmentName).contains(q);
    }).toList();
  }

  List<Employee> get _pageEmployees {
    final filtered = _filteredEmployees;
    final start = _page * _pageSize;
    if (start >= filtered.length) return [];
    return filtered.sublist(
        start, (start + _pageSize).clamp(0, filtered.length));
  }

  int get _totalPages =>
      (_filteredEmployees.length / _pageSize).ceil().clamp(1, 999);

  @override
  void didUpdateWidget(covariant ShiftAssignTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.departmentFilterId != widget.departmentFilterId) {
      setState(() => _page = 0);
    }
  }

  // ── Scroll controllers ───────────────────────────────────────────────────
  final _hHead = ScrollController();
  final _hBody = ScrollController();
  final _vNames = ScrollController();
  final _vBody = ScrollController();
  bool _vSyncing = false;

  @override
  void initState() {
    super.initState();

    _hBody.addListener(() {
      if (!_hHead.hasClients) return;
      final clamped = _hBody.offset.clamp(
        _hHead.position.minScrollExtent,
        _hHead.position.maxScrollExtent,
      );
      if (_hHead.offset != clamped) _hHead.jumpTo(clamped);
    });

    _vBody.addListener(() {
      if (_vSyncing || !_vNames.hasClients) return;
      _vSyncing = true;
      final c = _vBody.offset.clamp(
          _vNames.position.minScrollExtent, _vNames.position.maxScrollExtent);
      if (_vNames.offset != c) _vNames.jumpTo(c);
      _vSyncing = false;
    });
    _vNames.addListener(() {
      if (_vSyncing || !_vBody.hasClients) return;
      _vSyncing = true;
      final c = _vNames.offset.clamp(
          _vBody.position.minScrollExtent, _vBody.position.maxScrollExtent);
      if (_vBody.offset != c) _vBody.jumpTo(c);
      _vSyncing = false;
    });

    _loadCutoffDay();
    _loadEmployees();
  }

  @override
  void dispose() {
    _hHead.dispose();
    _hBody.dispose();
    _vNames.dispose();
    _vBody.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  Future<void> _loadCutoffDay() async {
    try {
      final settings = await _settingRepo.get();
      final payroll = settings['payroll'] as Map<String, dynamic>?;
      final cutoff = (payroll?['payrollCutoffDay'] as num?)?.toInt() ?? 1;
      if (mounted) setState(() => _cutoffDay = cutoff);
    } catch (_) {}
  }

  Future<void> _loadEmployees() async {
    try {
      final list = await ApiService.instance.get<List<Employee>>(
        '/shifts/employees',
        (d) => (d as List)
            .map((e) => Employee.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      if (mounted) {
        setState(() {
          _employees = list;
          _loadingEmps = false;
        });
        _loadAssignments();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEmps = false);
    }
  }

  Future<void> _loadAssignments() async {
    setState(() => _loadingAssigns = true);
    final days = _periodDays;
    final from = _fmt(days.first);
    final to = _fmt(days.last);
    try {
      final list = await ApiService.instance.get<List<ShiftAssignment>>(
        '/shifts/assignments',
        (d) => (d as List)
            .map((e) => ShiftAssignment.fromJson(e as Map<String, dynamic>))
            .toList(),
        queryParams: {'from': from, 'to': to},
      );
      if (mounted) {
        setState(() {
          _assignments = list;
          _loadingAssigns = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAssigns = false);
    }
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  List<ShiftAssignment> _assignsFor(int empId, DateTime date) {
    final key = _fmt(date);
    return _assignments
        .where((a) => a.employeeId == empId && a.workDate == key)
        .toList();
  }

  // ── Cell tap → quick-fill or picker ──────────────────────────────────────

  Future<void> _onCellTap(Employee emp, DateTime date) async {
    // Quick-fill mode: assign preset shift immediately
    if (_quickFill != null && _quickFill != -1) {
      final existingList = _assignsFor(emp.id, date);
      final sameShift = existingList.where((a) => !a.isCustom && a.shiftId == _quickFill).toList();
      if (sameShift.isNotEmpty) {
        // Tap same shift again → remove it (with attendance check)
        for (final a in sameShift) {
          await _deleteById(a.id, hasAttendance: a.hasAttendance, approved: a.approved);
        }
        return;
      }
      // Otherwise assign (allow up to 2 per day, remove oldest if already 2)
      if (existingList.length >= 2) {
        await _deleteById(existingList.first.id,
            hasAttendance: existingList.first.hasAttendance,
            approved: existingList.first.approved);
        if (!mounted) return;
      }
      await _save(emp.id, _quickFill, date);
      return;
    }

    // Normal dialog mode
    final existingList = _assignsFor(emp.id, date);

    final result = await showInstantDialog<_AssignResult?>(
      context,
      (_) => _AssignPickerDialog(
        shifts: widget.shifts,
        employeeName: emp.fullName,
        date: date,
        currentAssigns: existingList,
      ),
    );
    if (result == null || !mounted) return;

    if (result.remove) {
      await _deleteById(result.removeId!, hasAttendance: result.removeHasAttendance, approved: result.removeApproved);
    } else {
      // Replace mode: delete old assignment first (replace never needs confirm)
      if (result.replaceId != null) await _deleteById(result.replaceId!);
      if (result.isCustom) {
        await _save(emp.id, null, date,
            customStart: result.customStart,
            customEnd: result.customEnd,
            customBreakStart: result.customBreakStart,
            customBreakEnd: result.customBreakEnd);
      } else {
        await _save(emp.id, result.shiftId, date);
      }
    }
  }

  Future<void> _save(int empId, int? shiftId, DateTime date,
      {String? customStart,
      String? customEnd,
      String? customBreakStart,
      String? customBreakEnd}) async {
    try {
      await ApiService.instance.post('/shifts/assignments', (_) => null, {
        'employeeId': empId,
        'workDate': _fmt(date),
        if (shiftId != null) 'shiftId': shiftId,
        if (customStart != null) 'customStartTime': customStart,
        if (customEnd != null) 'customEndTime': customEnd,
        if (customBreakStart != null) 'customBreakStart': customBreakStart,
        if (customBreakEnd != null) 'customBreakEnd': customBreakEnd,
      });
      _loadAssignments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_serverMsg(e, AppLocalizations.of(context)!)),
            backgroundColor: AppTheme.error));
      }
    }
  }

  static String _serverMsg(dynamic e, AppLocalizations s) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      // Try to get the server's own message first
      String? msg;
      if (data is Map) {
        msg = (data['message'] as String?)?.trim();
        if (msg == null || msg.isEmpty) {
          msg = (data['error'] as String?)?.trim();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        msg = data.trim();
      }

      if (msg != null && msg.isNotEmpty) return msg;

      // Fallback by HTTP status
      return switch (status) {
        400 => s.invalidData,
        401 => s.sessionExpired,
        403 => s.noPermissionForAction,
        404 => s.dataNotFound,
        409 => s.dataConflict,
        500 => s.serverErrorTryLater,
        _ => s.cannotConnectServerCode('$status'),
      };
    }
    return s.cannotConnectServer;
  }

  Future<void> _deleteById(int id, {bool hasAttendance = false, bool approved = false}) async {
    final s = AppLocalizations.of(context)!;
    if (approved) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.shiftAssignmentApprovedCannotDelete),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    if (hasAttendance) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.delete),
          content: Text(s.deleteShiftAssignmentWarning),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.delete),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    try {
      await ApiService.instance.delete('/shifts/assignments/$id');
      _loadAssignments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_serverMsg(e, AppLocalizations.of(context)!)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Timeline helpers ─────────────────────────────────────────────────────

  static int _parseMin(String? t) {
    if (t == null) return -1;
    final p = t.split(':');
    if (p.length < 2) return -1;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  int _startMin(ShiftAssignment a) {
    if (a.isCustom) return _parseMin(a.customStartTime);
    try {
      return _parseMin(
          widget.shifts.firstWhere((s) => s.id == a.shiftId).startTime);
    } catch (_) {
      return -1;
    }
  }

  int _endMin(ShiftAssignment a) {
    if (a.isCustom) return _parseMin(a.customEndTime);
    try {
      return _parseMin(
          widget.shifts.firstWhere((s) => s.id == a.shiftId).endTime);
    } catch (_) {
      return -1;
    }
  }

  bool _isOvernight(ShiftAssignment a) {
    final s = _startMin(a), e = _endMin(a);
    return s >= 0 && e >= 0 && e < s;
  }

  Widget _timelineBar(ShiftAssignment a, double cellW, double cellH,
      {required int fromMin,
      required int toMin,
      bool squareLeft = false,
      bool squareRight = false,
      bool hideLabel = false,
      double topOffset = 0,
      double barHeight = 28}) {
    if (toMin <= fromMin) return const SizedBox.shrink();
    final left = (fromMin / 1440.0) * cellW;
    final barW = ((toMin - fromMin) / 1440.0) * cellW;
    final clamped = barW.clamp(0.0, cellW - left);
    if (clamped < 1) return const SizedBox.shrink();

    final color = _ShiftBadge._hexColor(a.shiftColor);

    final displayLabel = a.isCustom
        ? '${a.customStartTime ?? '?'}–${a.customEndTime ?? '?'}'
        : (a.shiftCode ?? '');

    String tooltipText;
    if (a.isCustom) {
      final start = a.customStartTime ?? '?';
      final end = a.customEndTime ?? '?';
      final brk = (a.customBreakStart != null && a.customBreakEnd != null)
          ? '\n${AppLocalizations.of(context)!.breakTime}: ${a.customBreakStart} – ${a.customBreakEnd}'
          : '';
      tooltipText = '$start – $end$brk';
    } else {
      try {
        final s = widget.shifts.firstWhere((s) => s.id == a.shiftId);
        final hours =
            s.workHoursLabel.isNotEmpty ? '  (${s.workHoursLabel})' : '';
        tooltipText = '${s.name}\n${s.timeLabel}$hours';
      } catch (_) {
        tooltipText = a.shiftName ?? a.shiftCode ?? '';
      }
    }

    const r = Radius.circular(3);
    final radius = BorderRadius.only(
      topLeft: squareLeft ? Radius.zero : r,
      bottomLeft: squareLeft ? Radius.zero : r,
      topRight: squareRight ? Radius.zero : r,
      bottomRight: squareRight ? Radius.zero : r,
    );

    return Positioned(
      left: left,
      top: topOffset > 0 ? topOffset : (cellH - barHeight) / 2,
      width: clamped,
      height: barHeight,
      child: Tooltip(
        message: tooltipText,
        waitDuration: const Duration(milliseconds: 250),
        preferBelow: false,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.82),
            borderRadius: radius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          child: (!hideLabel && clamped > 18)
              ? Text(displayLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis)
              : null,
        ),
      ),
    );
  }

  Widget _fallbackBadgeBar(ShiftAssignment a, double cellW, double cellH) {
    final w = cellW > 84 ? 84.0 : cellW - 8;
    final left = (cellW - w) / 2;
    return Positioned(
      left: left < 2 ? 2 : left,
      top: (cellH - 22) / 2,
      width: w,
      height: 22,
      child: _ShiftBadge(a),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingEmps) return const Center(child: CircularProgressIndicator());
    final canManage = widget.canManage &&
        (AuthService.instance.currentUser?.can('SHIFT_MANAGE') ?? false);

    final periodDays = _periodDays;
    final emps = _pageEmployees;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _MonthNav(
        month: _month,
        loading: _loadingAssigns,
        panelOpen: _panelOpen,
        onPrev: () {
          setState(() {
            _month = DateTime(_month.year, _month.month - 1);
            _page = 0;
          });
          _loadAssignments();
        },
        onNext: () {
          setState(() {
            _month = DateTime(_month.year, _month.month + 1);
            _page = 0;
          });
          _loadAssignments();
        },
        onPick: _pickMonth,
        onTogglePanel: () => setState(() {
          _panelOpen = !_panelOpen;
          if (!_panelOpen) _quickFill = null;
        }),
      ),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildGrid(periodDays, emps, canManage)),
            if (canManage && _panelOpen)
              _QuickFillPanel(
                shifts: widget.shifts,
                selected: _quickFill,
                onSelect: (id) => setState(() => _quickFill = _quickFill == id ? null : id),
              ),
          ],
        ),
      ),
      PaginationBar(
        total: _filteredEmployees.length,
        page: _page,
        pageSize: _pageSize,
        onPageSizeChanged: (s) => setState(() {
          _pageSize = s;
          _page = 0;
        }),
        onPrev: _page > 0 ? () => setState(() => _page--) : null,
        onNext: _page < _totalPages - 1 ? () => setState(() => _page++) : null,
      ),
    ]);
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MonthPickerDialog(initialMonth: _month),
    );
    if (picked == null) return;
    setState(() {
      _month = DateTime(picked.year, picked.month);
      _page = 0;
    });
    _loadAssignments();
  }

  Widget _buildGrid(List<DateTime> periodDays, List<Employee> emps, bool canManage) {
    final s = AppLocalizations.of(context)!;
    final assignMap = <String, List<ShiftAssignment>>{};
    for (final a in _assignments) {
      assignMap.putIfAbsent('${a.employeeId}_${a.workDate}', () => []).add(a);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final nameW = constraints.maxWidth < 600 ? 130.0 : _nameW;
      final dayW = constraints.maxWidth < 600 ? 60.0 : _dayW;
      return _buildGridInner(periodDays, emps, canManage, s, assignMap, nameW, dayW);
    });
  }

  Widget _buildGridInner(
    List<DateTime> periodDays,
    List<Employee> emps,
    bool canManage,
    AppLocalizations s,
    Map<String, List<ShiftAssignment>> assignMap,
    double nameW,
    double dayW,
  ) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Frozen name column ─────────────────────────────────────────
      Container(
        width: nameW,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: _border, width: 2)),
        ),
        child: Column(children: [
          _cell(nameW, _headH, _headBg,
              border:
                  const Border(bottom: BorderSide(color: _border, width: 2)),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 8),
              child: Text(s.employeeShort,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary))),
          Expanded(
            child: ListView.builder(
              controller: _vNames,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: emps.length,
              itemExtent: _rowH,
              itemBuilder: (_, i) => _cell(
                nameW,
                _rowH,
                i.isOdd ? const Color(0xFFF8F9FA) : Colors.white,
                border: const Border(bottom: BorderSide(color: _border)),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emps[i].fullName,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${emps[i].employeeCode} • ${emps[i].departmentName}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),

      // ── Scrollable days grid ───────────────────────────────────────
      Expanded(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: _headH,
            child: SingleChildScrollView(
              controller: _hHead,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              child: Row(
                children: periodDays.map((date) {
                  final dow = date.weekday;
                  final wknd = dow >= 6;
                  return _cell(
                    dayW,
                    _headH,
                    _headBg,
                    border: const Border(
                        right: BorderSide(color: _border),
                        bottom: BorderSide(color: _border, width: 2)),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${date.day}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: wknd
                                      ? AppTheme.error
                                      : AppTheme.textPrimary)),
                          Text(_dowLabel(dow),
                              style: TextStyle(
                                  fontSize: 9,
                                  color: wknd
                                      ? AppTheme.error.withValues(alpha: .7)
                                      : AppTheme.textSecondary)),
                        ]),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _hBody,
              thumbVisibility: true,
              trackVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _hBody,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                child: SizedBox(
                  width: dayW * periodDays.length,
                  child: ListView.builder(
                    controller: _vBody,
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: emps.length,
                    itemExtent: _rowH,
                    itemBuilder: (_, i) {
                      final emp = emps[i];
                      final rowBg =
                          i.isOdd ? const Color(0xFFF8F9FA) : Colors.white;
                      return Row(
                        children: periodDays.map((date) {
                          final dow = date.weekday;
                          final wknd = dow >= 6;
                          final bg = wknd ? const Color(0xFFFFF0F0) : rowBg;

                          final dateStr = _fmt(date);
                          final prevDate = DateTime(date.year, date.month, date.day - 1);
                          final prevStr = _fmt(prevDate);
                          final assigns = assignMap['${emp.id}_$dateStr'] ?? [];
                          final prevAssigns =
                              assignMap['${emp.id}_$prevStr'] ?? [];
                          final overflows =
                              prevAssigns.where(_isOvernight).toList();

                          final List<Widget> bars = [];

                          for (final ov in overflows) {
                            final e = _endMin(ov);
                            if (e > 0) {
                              bars.add(_timelineBar(ov, dayW, _rowH,
                                  fromMin: 0,
                                  toMin: e,
                                  squareLeft: true,
                                  hideLabel: true));
                            }
                          }

                          for (final assign in assigns) {
                            final s = _startMin(assign);
                            final e = _endMin(assign);
                            final overnight = _isOvernight(assign);
                            if (s < 0) {
                              bars.add(_fallbackBadgeBar(assign, dayW, _rowH));
                            } else if (e < 0 || e > s) {
                              bars.add(_timelineBar(assign, dayW, _rowH,
                                  fromMin: s, toMin: e < 0 ? s + 480 : e));
                            } else {
                              bars.add(_timelineBar(assign, dayW, _rowH,
                                  fromMin: s,
                                  toMin: 1440,
                                  squareRight: overnight));
                            }
                          }

                          return GestureDetector(
                            onTap:
                                canManage ? () => _onCellTap(emp, date) : null,
                            child: Container(
                              width: dayW,
                              height: _rowH,
                              decoration: BoxDecoration(
                                color: bg,
                                border: const Border(
                                  right: BorderSide(color: _border),
                                  bottom: BorderSide(color: _border),
                                ),
                              ),
                              child: Stack(
                                  clipBehavior: Clip.hardEdge, children: bars),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _cell(
    double w,
    double h,
    Color bg, {
    Border? border,
    Widget? child,
    AlignmentGeometry alignment = Alignment.center,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 2),
  }) =>
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: bg, border: border),
        alignment: alignment,
        padding: padding,
        child: child,
      );

  String _dowLabel(int dow) =>
      const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][dow - 1];
}

// ── Shift badge ───────────────────────────────────────────────────────────────

class _ShiftBadge extends StatelessWidget {
  final ShiftAssignment a;
  const _ShiftBadge(this.a);

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(a.shiftColor);
    final label =
        a.isCustom ? (a.customStartTime ?? '?') : (a.shiftCode ?? '?');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center),
    );
  }

  static Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }
}

// ── Month navigator ───────────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  final DateTime month;
  final bool loading;
  final bool panelOpen;
  final VoidCallback onPrev, onNext, onPick, onTogglePanel;
  const _MonthNav({
    required this.month,
    required this.loading,
    required this.panelOpen,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.onTogglePanel,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: onPrev,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(DateFormat('MM/yyyy').format(month),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: onNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const Spacer(),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Tooltip(
            message: AppLocalizations.of(context).quickFillPanel,
            child: IconButton(
              icon: Icon(
                Icons.dashboard_customize_outlined,
                size: 20,
                color: panelOpen ? AppTheme.primary : null,
              ),
              style: panelOpen
                  ? IconButton.styleFrom(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1))
                  : null,
              onPressed: onTogglePanel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ]),
      );
}

// ── Quick-fill panel ──────────────────────────────────────────────────────────

class _QuickFillPanel extends StatelessWidget {
  final List<WorkShift> shifts;
  final int? selected; // null = none, >0 = shiftId
  final void Function(int id) onSelect;

  const _QuickFillPanel({
    required this.shifts,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _border, width: 1.5)),
        color: Color(0xFFFAFBFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: const BoxDecoration(
              color: _headBg,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(children: [
              const Icon(Icons.dashboard_customize_outlined,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(s.quickFillPanel,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
            ]),
          ),
          // Hint
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              s.quickFillHint,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  height: 1.4),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _border),
          // Shift list
          Expanded(
            child: shifts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(s.quickFillNoShifts,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  )
                : Builder(builder: (_) {
                    // Build grouped items list
                    final grouped = <String, List<WorkShift>>{};
                    for (final sh in shifts) {
                      final key = sh.groupName?.trim().isNotEmpty == true
                          ? sh.groupName!.trim()
                          : '';
                      grouped.putIfAbsent(key, () => []).add(sh);
                    }
                    final namedKeys = grouped.keys
                        .where((k) => k.isNotEmpty)
                        .toList()
                      ..sort();
                    final allKeys = [
                      ...namedKeys,
                      if (grouped.containsKey('')) ''
                    ];
                    final items = <Object>[];
                    for (final key in allKeys) {
                      if (allKeys.length > 1 || key.isNotEmpty) {
                        items.add(_PanelGroupHeader(
                            key.isEmpty ? s.shiftGroupUngrouped : key));
                      }
                      items.addAll(grouped[key]!);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        if (item is _PanelGroupHeader) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: Text(item.label,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 0.4)),
                          );
                        }
                        final shift = item as WorkShift;
                        final color = _ShiftBadge._hexColor(shift.color);
                        final isSelected = selected == shift.id;
                        return InkWell(
                          onTap: () => onSelect(shift.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : color.withValues(alpha: 0.25),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(children: [
                              Container(
                                width: 30,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color.withValues(
                                      alpha: isSelected ? 0.25 : 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(shift.code,
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(shift.name,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? color
                                                : AppTheme.textPrimary),
                                        overflow: TextOverflow.ellipsis),
                                    Text(shift.timeLabel,
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: AppTheme.textSecondary),
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle,
                                    size: 14, color: color),
                            ]),
                          ),
                        );
                      },
                    );
                  }),
          ),
          // Clear button (shown when a shift is selected)
          if (selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: OutlinedButton.icon(
                onPressed: () => onSelect(selected!),
                icon: const Icon(Icons.close, size: 12),
                label: Text(s.quickFillClearSelection,
                    style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: _border),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initialMonth;

  const _MonthPickerDialog({required this.initialMonth});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year;
    _month = widget.initialMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    const monthLabels = [
      'T1',
      'T2',
      'T3',
      'T4',
      'T5',
      'T6',
      'T7',
      'T8',
      'T9',
      'T10',
      'T11',
      'T12',
    ];

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.chooseMonth,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _year,
                decoration: InputDecoration(
                  labelText: s.year,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: List.generate(11, (index) {
                  final year = DateTime.now().year - 5 + index;
                  return DropdownMenuItem(
                    value: year,
                    child: Text('$year'),
                  );
                }),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _year = v);
                },
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: List.generate(12, (index) {
                  final month = index + 1;
                  final selected = _month == month;
                  return SizedBox(
                    width: 56,
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _month = month),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: selected
                            ? AppTheme.primary.withValues(alpha: 0.18)
                            : Colors.white,
                        side: BorderSide(
                          color: selected ? AppTheme.primary : AppTheme.border,
                        ),
                        foregroundColor:
                            selected ? AppTheme.primary : AppTheme.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(monthLabels[index]),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(s.cancel),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, DateTime(_year, _month)),
                    child: Text(s.apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Assign result ─────────────────────────────────────────────────────────────

class _AssignResult {
  final bool remove;
  final int? removeId;
  final bool removeHasAttendance;
  final bool removeApproved;
  final int? replaceId; // delete this ID before saving (replace-mode)
  final bool isCustom;
  final int? shiftId;
  final String? customStart;
  final String? customEnd;
  final String? customBreakStart;
  final String? customBreakEnd;

  const _AssignResult._({
    required this.remove,
    this.removeId,
    this.removeHasAttendance = false,
    this.removeApproved = false,
    this.replaceId,
    required this.isCustom,
    this.shiftId,
    this.customStart,
    this.customEnd,
    this.customBreakStart,
    this.customBreakEnd,
  });

  factory _AssignResult.shift(int? shiftId, {int? replaceId}) =>
      _AssignResult._(
          remove: false,
          isCustom: false,
          shiftId: shiftId,
          replaceId: replaceId);

  factory _AssignResult.custom(String? start, String? end,
          {String? breakStart, String? breakEnd, int? replaceId}) =>
      _AssignResult._(
          remove: false,
          isCustom: true,
          customStart: start,
          customEnd: end,
          customBreakStart: breakStart,
          customBreakEnd: breakEnd,
          replaceId: replaceId);

  factory _AssignResult.deleteById(int id, {bool hasAttendance = false, bool approved = false}) =>
      _AssignResult._(
          remove: true,
          removeId: id,
          removeHasAttendance: hasAttendance,
          removeApproved: approved,
          isCustom: false);
}

// ── Assign picker dialog ──────────────────────────────────────────────────────

class _AssignPickerDialog extends StatefulWidget {
  final List<WorkShift> shifts;
  final String employeeName;
  final DateTime date;
  final List<ShiftAssignment> currentAssigns;

  const _AssignPickerDialog({
    required this.shifts,
    required this.employeeName,
    required this.date,
    required this.currentAssigns,
  });

  @override
  State<_AssignPickerDialog> createState() => _AssignPickerDialogState();
}

class _AssignPickerDialogState extends State<_AssignPickerDialog> {
  // null = chips list; -1 = add new; positive = editing that assignment id
  int? _pickerMode;
  bool _customOpen = false;
  TimeOfDay? _customStart;
  TimeOfDay? _customEnd;
  TimeOfDay? _customBreakStart;
  TimeOfDay? _customBreakEnd;

  @override
  void initState() {
    super.initState();
    // Auto-enter edit mode when there is exactly 1 assignment
    if (widget.currentAssigns.length == 1) {
      final a = widget.currentAssigns.first;
      _customOpen = a.isCustom;
      _customStart = a.isCustom ? _toTOD(a.customStartTime) : null;
      _customEnd = a.isCustom ? _toTOD(a.customEndTime) : null;
      _customBreakStart = a.isCustom ? _toTOD(a.customBreakStart) : null;
      _customBreakEnd = a.isCustom ? _toTOD(a.customBreakEnd) : null;
      _pickerMode = a.id;
    }
  }

  void _enterEdit(ShiftAssignment a) {
    _customOpen = a.isCustom;
    _customStart = a.isCustom ? _toTOD(a.customStartTime) : null;
    _customEnd = a.isCustom ? _toTOD(a.customEndTime) : null;
    _customBreakStart = a.isCustom ? _toTOD(a.customBreakStart) : null;
    _customBreakEnd = a.isCustom ? _toTOD(a.customBreakEnd) : null;
    setState(() => _pickerMode = a.id);
  }

  static TimeOfDay? _toTOD(String? t) {
    if (t == null) return null;
    final p = t.split(':');
    if (p.length < 2) return null;
    return TimeOfDay(
        hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
  }

  String _fmtT(TimeOfDay? t) => t == null
      ? '--:--'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(
      String lbl, TimeOfDay? cur, void Function(TimeOfDay) cb) async {
    final t = await showTimePicker(
      context: context,
      initialTime: cur ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: lbl,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => cb(t));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final dateStr = DateFormat('dd/MM/yyyy').format(widget.date);
    final dowStr = [
      s.monday,
      s.tuesday,
      s.wednesday,
      s.thursday,
      s.friday,
      s.saturday,
      s.sunday,
    ][widget.date.weekday - 1];
    final inPicker = _pickerMode != null;
    final isAdd = _pickerMode == -1;
    // when editing an existing assignment, pass its id as replaceId
    final int? replaceId = (inPicker && !isAdd) ? _pickerMode : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: const BoxDecoration(
                color: _headBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.employeeName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('$dowStr, $dateStr',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
            ),

            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Vertical list: existing assignments (shown when 2 assigns, not in picker) ──
                    if (widget.currentAssigns.length == 2 && !inPicker) ...[
                      Text(s.assignedShifts,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      ...widget.currentAssigns.map((a) {
                        final color = _ShiftBadge._hexColor(a.shiftColor);
                        final label = a.isCustom
                            ? '${a.customStartTime ?? '?'} – ${a.customEndTime ?? '?'}'
                            : (a.shiftName ?? a.shiftCode ?? '?');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _enterEdit(a),
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(8)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 9),
                                  child: Row(children: [
                                    Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text(label,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: color)),
                                    const SizedBox(width: 6),
                                    Icon(Icons.edit,
                                        size: 12,
                                        color: color.withValues(alpha: 0.6)),
                                  ]),
                                ),
                              ),
                            ),
                            Container(
                                width: 1,
                                height: 36,
                                color: color.withValues(alpha: 0.25)),
                            InkWell(
                              onTap: () => Navigator.pop(
                                  context, _AssignResult.deleteById(a.id, hasAttendance: a.hasAttendance, approved: a.approved)),
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 9),
                                child: Icon(Icons.delete_outline,
                                    size: 16,
                                    color:
                                        AppTheme.error.withValues(alpha: 0.7)),
                              ),
                            ),
                          ]),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 2),
                        child: Text(s.maxShiftsPerDay,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ),
                    ],

                    // ── Auto-entered single assignment: compact header + optional add button ──
                    if (widget.currentAssigns.length == 1 && inPicker) ...[
                      Builder(builder: (_) {
                        final a = widget.currentAssigns.first;
                        final color = _ShiftBadge._hexColor(a.shiftColor);
                        final label = a.isCustom
                            ? '${a.customStartTime ?? '?'} – ${a.customEndTime ?? '?'}'
                            : (a.shiftName ?? a.shiftCode ?? '?');
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(label,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: color))),
                                InkWell(
                                  onTap: () => Navigator.pop(
                                      context, _AssignResult.deleteById(a.id, hasAttendance: a.hasAttendance, approved: a.approved)),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.delete_outline,
                                              size: 14,
                                              color: AppTheme.error
                                                  .withValues(alpha: 0.7)),
                                          const SizedBox(width: 3),
                                          Text(s.delete,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.error
                                                      .withValues(alpha: 0.8))),
                                        ]),
                                  ),
                                ),
                              ]),
                            ),
                            if (_pickerMode != -1) ...[
                              OutlinedButton.icon(
                                onPressed: () {
                                  _customOpen = false;
                                  _customStart = _customEnd =
                                      _customBreakStart =
                                          _customBreakEnd = null;
                                  setState(() => _pickerMode = -1);
                                },
                                icon: const Icon(Icons.add, size: 14),
                                label: Text(s.addSecondShift,
                                    style: const TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      }),
                    ],

                    // ── No assignments yet → show picker directly ────
                    if (widget.currentAssigns.isEmpty && !inPicker) ...[
                      Text(s.chooseShift,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                    ],

                    // ── Picker (add new or edit existing) ────────────
                    if (inPicker || widget.currentAssigns.isEmpty) ...[
                      if (inPicker) ...[
                        Text(isAdd ? s.addSecondShift : s.editShiftAssignment,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                      ],

                      // Custom hours section
                      InkWell(
                        onTap: () => setState(() => _customOpen = !_customOpen),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F4FD),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF90CAF9)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.access_time,
                                size: 16, color: Color(0xFF1565C0)),
                            const SizedBox(width: 8),
                            Text(s.customHoursLabel,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1565C0))),
                            const Spacer(),
                            Icon(
                                _customOpen
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                                color: const Color(0xFF1565C0)),
                          ]),
                        ),
                      ),

                      if (_customOpen) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _TimeTile(
                            label: s.startLabel,
                            value: _fmtT(_customStart),
                            onTap: () => _pick(s.startLabel, _customStart, (t) {
                              _customStart = t;
                            }),
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _TimeTile(
                            label: s.endLabel,
                            value: _fmtT(_customEnd),
                            onTap: () => _pick(s.endLabel, _customEnd, (t) {
                              _customEnd = t;
                            }),
                          )),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: _TimeTile(
                            label: s.shiftBreakStartLabel,
                            value: _fmtT(_customBreakStart),
                            onTap: () => _pick(
                                s.shiftBreakStartLabel, _customBreakStart, (t) {
                              _customBreakStart = t;
                            }),
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _TimeTile(
                            label: s.shiftBreakEndLabel,
                            value: _fmtT(_customBreakEnd),
                            onTap: () => _pick(
                                s.shiftBreakEndLabel, _customBreakEnd, (t) {
                              _customBreakEnd = t;
                            }),
                          )),
                        ]),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: (_customStart != null &&
                                    _customEnd != null)
                                ? () => Navigator.pop(
                                    context,
                                    _AssignResult.custom(
                                        _fmtT(_customStart), _fmtT(_customEnd),
                                        breakStart: _customBreakStart != null
                                            ? _fmtT(_customBreakStart)
                                            : null,
                                        breakEnd: _customBreakEnd != null
                                            ? _fmtT(_customBreakEnd)
                                            : null,
                                        replaceId: replaceId))
                                : null,
                            child: Text(s.applyTimeRange(
                                _fmtT(_customStart), _fmtT(_customEnd))),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Predefined shifts
                      Text(s.shiftTemplatesLabel,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),

                      if (widget.shifts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(s.noShiftsAvailable,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                        )
                      else
                        ...widget.shifts.map((s) {
                          final color = _ShiftBadge._hexColor(s.color);
                          return InkWell(
                            onTap: () => Navigator.pop(
                                context,
                                _AssignResult.shift(s.id,
                                    replaceId: replaceId)),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 7),
                              margin: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                Container(
                                  width: 36,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(s.code,
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    Text(s.timeLabel,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary)),
                                  ],
                                )),
                              ]),
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(children: [
                if (inPicker &&
                    (widget.currentAssigns.length != 1 || _pickerMode == -1))
                  TextButton.icon(
                    onPressed: () {
                      if (widget.currentAssigns.length == 1 &&
                          _pickerMode == -1) {
                        _enterEdit(widget.currentAssigns.first);
                      } else {
                        setState(() => _pickerMode = null);
                      }
                    },
                    icon: const Icon(Icons.arrow_back, size: 14),
                    label: Text(s.goBack, style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.close),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Time tile ─────────────────────────────────────────────────────────────────

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeTile(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            suffixIcon: const Icon(Icons.access_time, size: 16),
          ),
          child: Text(value,
              style: TextStyle(
                  color: value == '--:--'
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                  fontSize: 14)),
        ),
      );
}

class _PanelGroupHeader {
  final String label;
  const _PanelGroupHeader(this.label);
}
