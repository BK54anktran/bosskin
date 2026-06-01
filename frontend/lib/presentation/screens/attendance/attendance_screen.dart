import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/employee.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/company_setting_repository.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../data/services/department_service.dart';
import '../../widgets/department_picker_field.dart';

// â”€â”€ Column definitions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Col {
  final String label;
  final double width;
  const _Col(this.label, this.width);
}

List<_Col> _cols(AppLocalizations s, {bool dayNight = true, bool otEnabled = true}) {
  return [
    _Col(s.leave, 90),
    _Col(s.shift, 120),
    _Col(s.breakTime, 70),
    _Col(s.checkIn, 72),
    _Col(s.checkOut, 72),
    _Col(s.checkInRequest, 86),
    _Col(s.checkOutRequest, 86),
    _Col(s.totalTime, 72),
    _Col(s.dayHours, 78),
    if (otEnabled) _Col(s.dayOT, 78),
    if (dayNight) _Col(s.nightHours, 78),
    if (dayNight && otEnabled) _Col(s.nightOT, 78),
    _Col(s.workStatus, 140),
    _Col(s.action, 68),
  ];
}

const double _dateColW = 72;
const double _rowHeight = 48;
const double _dayFirstColW = 190;
const double _dayRowHeight = 72;
const double _headHeight = 52;
const String _empty = '';
const Color _gridLine = Color(0xFFD7DCE3);
const Color _gridLineLight = Color(0xFFE1E5EA);

String _formatMinutesAsTime(int minutes) {
  final hh = (minutes ~/ 60).toString().padLeft(2, '0');
  final mm = (minutes % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}

Widget _deptDropdownLabel(DepartmentFlat d) {
  return Padding(
    padding: EdgeInsets.only(left: d.level > 0 ? d.level * 18.0 : 0),
    child: Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        if (d.level > 0) ...[
          Text(
            '+',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            '${d.name} (${d.code})',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Set<int> _expandedDepartmentScopeIds(
  List<DepartmentFlat> departments,
  int? rootDeptId,
) {
  if (rootDeptId == null) return <int>{};
  final childrenByParent = <int, List<int>>{};
  for (final d in departments) {
    final parentId = d.parentId;
    if (parentId == null) continue;
    childrenByParent.putIfAbsent(parentId, () => <int>[]).add(d.id);
  }
  final result = <int>{rootDeptId};
  final queue = <int>[rootDeptId];
  var index = 0;
  while (index < queue.length) {
    final current = queue[index++];
    for (final child in childrenByParent[current] ?? const <int>[]) {
      if (result.add(child)) queue.add(child);
    }
  }
  return result;
}

class _MergedDayViewRow {
  final List<DayViewRow> slots;
  const _MergedDayViewRow(this.slots);

  DayViewRow get first => slots.first;
  bool get weekend => first.weekend;
}

class _MergedTimesheetRow {
  final List<TimesheetRow> rows;
  const _MergedTimesheetRow(this.rows);

  TimesheetRow get first => rows.first;
  bool get weekend => first.weekend;
}

Future<void> _showAttendanceInfoDialog(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) async {
  final s = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.close),
        ),
      ],
    ),
  );
}

Widget _detailLine(
  String label,
  String value, {
  Color? valueColor,
  bool strikeThrough = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              decoration: strikeThrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    ),
  );
}

String _requestStatusLabel(AppLocalizations s, String? status) {
  return switch (status) {
    'APPROVED' => s.approved,
    'REJECTED' => s.reject,
    'PENDING' => s.pending,
    'CANCELLED' => s.cancelled,
    _ => s.unknown,
  };
}

String _scopeLabel(AppLocalizations s, String? scope) {
  return switch (scope) {
    'IN_SHIFT' => s.insideShift,
    'OUTSIDE_SHIFT' => s.outsideShift,
    _ => s.unknown,
  };
}

String _periodLabel(AppLocalizations s, String? period) {
  return switch (period ?? 'DAY') {
    'DAY' => s.day,
    'NIGHT' => s.night,
    _ => s.day,
  };
}

String _requestTypeLabel(AppLocalizations s, String? type) {
  return switch (type) {
    'CHECK_IN' => s.checkInRequest,
    'CHECK_OUT' => s.checkOutRequest,
    'OT' => s.overtime,
    'EXTRA' => s.extraHours,
    _ => s.request,
  };
}

String _formatRequestDate(String? value) {
  final dt = value == null ? null : DateTime.tryParse(value);
  if (dt == null) return '-';
  return DateFormat('dd/MM/yyyy').format(dt);
}

String _formatRequestDateTime(String? value) {
  final dt = value == null ? null : DateTime.tryParse(value);
  if (dt == null) return '-';
  return DateFormat('dd/MM/yyyy HH:mm').format(dt);
}

String _formatDurationMinutes(int minutes) {
  final hh = minutes ~/ 60;
  final mm = minutes % 60;
  return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

String _formatRequestTimeOrDuration(AttendanceChangeRequest? req) {
  if (req == null) return _empty;
  if (req.requestType == 'OT') {
    if (req.requestedOvertimeMinutes == null) return '-';
    final totalMinutes = req.requestedOvertimeMinutes!;
    final hh = totalMinutes ~/ 60;
    final mm = totalMinutes % 60;
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }
  return req.requestType == 'CHECK_OUT'
      ? (req.requestedCheckOut ?? '-')
      : (req.requestedCheckIn ?? '-');
}

Color _requestStatusColor(String status) {
  return switch (status) {
    'APPROVED' => Colors.green,
    'REJECTED' => AppTheme.error,
    'PENDING' => AppTheme.warning,
    'CANCELLED' => AppTheme.textSecondary,
    _ => AppTheme.textSecondary,
  };
}

String _requestActionLabel(AppLocalizations s, String status) {
  return switch (status) {
    'APPROVED' => s.approvedBy,
    'REJECTED' => s.rejectedBy,
    'CANCELLED' => s.cancelledBy,
    _ => s.processingBy,
  };
}

List<AttendanceChangeRequest> _matchingRequests(
  TimesheetRow row,
  List<AttendanceChangeRequest> requests, {
  required String requestType,
  String? period,
  String? scope,
}) {
  return requests.where((r) {
    if (r.requestType != requestType) return false;
    if (period != null && (r.requestedOvertimePeriod ?? 'DAY') != period) return false;
    if (scope != null && r.requestedOvertimeScope != scope) return false;
    if (r.shiftAssignmentId == null) {
      return row.shiftAssignmentId == null;
    }
    if (row.shiftAssignmentId == null) return false;
    if (r.shiftAssignmentId != row.shiftAssignmentId) return false;
    return true;
  }).toList();
}

AttendanceChangeRequest? _pickVisibleRequest(
  List<AttendanceChangeRequest> requests,
) {
  final approved = requests.where((r) => r.status == 'APPROVED').toList();
  if (approved.isEmpty) return null;
  approved.sort((a, b) {
    if (a.applied != b.applied) {
      return a.applied ? -1 : 1;
    }
    final aTime =
        DateTime.tryParse(a.updatedAt ?? a.processedAt ?? a.createdAt ?? '');
    final bTime =
        DateTime.tryParse(b.updatedAt ?? b.processedAt ?? b.createdAt ?? '');
    final timeCmp = (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
    if (timeCmp != 0) return timeCmp;
    return b.id.compareTo(a.id);
  });
  return approved.first;
}

Widget _requestStatusBadge(AppLocalizations s, String status) {
  final color = _requestStatusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      _requestStatusLabel(s, status),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _requestInfoCard(
  AppLocalizations s,
  AttendanceChangeRequest req, {
  ValueChanged<bool>? onAppliedChanged,
  bool appliedControlEnabled = true,
}) {
  final title = switch (req.requestType) {
    'OT' => '${s.overtime} ${_periodLabel(s, req.requestedOvertimePeriod)}',
    'EXTRA' => '${s.extraHours} ${_periodLabel(s, req.requestedOvertimePeriod)}',
    _ => _requestTypeLabel(s, req.requestType),
  };
  final mainValue = req.requestType == 'OT'
      ? (req.requestedOvertimeMinutes != null
          ? _formatDurationMinutes(req.requestedOvertimeMinutes!)
          : '-')
      : (req.requestType == 'CHECK_OUT'
          ? (req.requestedCheckOut ?? '-')
          : (req.requestedCheckIn ?? '-'));

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _gridLineLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${req.employeeName} • ${req.departmentName}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _requestStatusBadge(s, req.status),
                if (req.status == 'APPROVED') ...[
                  const SizedBox(width: 8),
                  Text(
                    s.apply,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.72,
                    child: Switch.adaptive(
                      value: req.applied,
                      onChanged: appliedControlEnabled ? onAppliedChanged : null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        _detailLine(s.date, _formatRequestDate(req.requestDate)),
        _detailLine(
          req.requestType == 'OT'
              ? '${s.overtime} (${_periodLabel(s, req.requestedOvertimePeriod)} • ${_scopeLabel(s, req.requestedOvertimeScope)})'
              : req.requestType == 'EXTRA'
                  ? '${s.extraHours} (${_periodLabel(s, req.requestedOvertimePeriod)})'
                  : _requestTypeLabel(s, req.requestType),
          mainValue,
          valueColor: AppTheme.primary,
          strikeThrough: !req.applied,
        ),
        _detailLine(s.createdAt, _formatRequestDateTime(req.createdAt)),
        _detailLine(
            s.note,
            (req.note == null || req.note!.trim().isEmpty)
                ? '-'
                : req.note!.trim()),
        _detailLine(
          _requestActionLabel(s, req.status),
          req.processedByName != null && req.processedAt != null
              ? '${req.processedByName} • ${_formatRequestDateTime(req.processedAt)}'
              : '-',
        ),
        _detailLine(
            s.response,
            (req.adminNote == null || req.adminNote!.trim().isEmpty)
                ? '-'
                : req.adminNote!.trim()),
      ],
    ),
  );
}

Future<void> _showRequestCardsDialog(
  BuildContext context, {
  required String title,
  required List<AttendanceChangeRequest> requests,
  required Future<AttendanceChangeRequest> Function(int id, bool applied)
      onToggleApplied,
  bool attendanceApproved = false,
}) async {
  final deduped = <AttendanceChangeRequest>[];
  final seenIds = <int>{};
  for (final request in requests) {
    if (!seenIds.add(request.id)) continue;
    deduped.add(request);
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final s = AppLocalizations.of(context)!;
      var visibleRequests = List<AttendanceChangeRequest>.from(deduped);

      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> toggleApplied(int index, bool applied) async {
            final current = visibleRequests[index];
            try {
              final updated = await onToggleApplied(current.id, applied);
              if (!context.mounted) return;
              setDialogState(() {
                visibleRequests[index] = updated;
                if (updated.applied &&
                    (updated.requestType == 'CHECK_IN' ||
                        updated.requestType == 'CHECK_OUT')) {
                  for (var i = 0; i < visibleRequests.length; i++) {
                    if (i == index) continue;
                    final other = visibleRequests[i];
                    if (other.requestType == updated.requestType &&
                        other.shiftAssignmentId == updated.shiftAssignmentId) {
                      visibleRequests[i] = other.copyWith(applied: false);
                    }
                  }
                }
              });
            } catch (e) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(serverMsg(e))),
                );
              }
            } finally {
              if (context.mounted) setDialogState(() {});
            }
          }

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 620,
              child: visibleRequests.isEmpty
                  ? Text(
                      s.noApprovedRequests,
                      style: TextStyle(color: AppTheme.textSecondary),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < visibleRequests.length; i++) ...[
                            _requestInfoCard(
                              s,
                              visibleRequests[i],
                              onAppliedChanged: visibleRequests[i].status == 'APPROVED' && !attendanceApproved
                                  ? (value) => toggleApplied(i, value)
                                  : null,
                              appliedControlEnabled: visibleRequests[i].status == 'APPROVED' && !attendanceApproved,
                            ),
                            if (i != visibleRequests.length - 1)
                              const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(s.close),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showLeaveRequestCardDialog(
  BuildContext context, {
  required int requestId,
  required String employeeName,
  required String departmentName,
  required String? leaveCode,
  required String? leaveMode,
  required String? leaveFromTime,
  required String? leaveToTime,
  required double? leaveAmount,
  required String status,
  required bool applied,
  String? processedByName,
  String? processedAt,
  String? createdAt,
  required Future<bool> Function(bool applied) onToggleApplied,
  bool attendanceApproved = false,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final s = AppLocalizations.of(context)!;
      bool currentApplied = applied;
      bool updating = false;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final modeText = leaveMode == 'HOUR_RANGE' ? s.leaveByHour : s.leaveByDay;
          final valueText = leaveMode == 'HOUR_RANGE'
              ? ((leaveFromTime != null && leaveToTime != null)
                  ? '$leaveFromTime - $leaveToTime'
                  : '-')
              : s.leaveAllDay;
          return AlertDialog(
            title: Text(s.leave),
            content: SizedBox(
              width: 620,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _gridLineLight),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                leaveCode == null ? s.leave : '${s.leave} ($leaveCode)',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$employeeName • $departmentName',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _requestStatusBadge(s, status),
                        const SizedBox(width: 8),
                        Text(
                          s.apply,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.72,
                          child: Switch.adaptive(
                            value: currentApplied,
                            onChanged: updating || (attendanceApproved && currentApplied)
                                ? null
                                : (value) async {
                                    setDialogState(() => updating = true);
                                    try {
                                      final updated = await onToggleApplied(value);
                                      if (!context.mounted) return;
                                      setDialogState(() => currentApplied = updated);
                                    } catch (e) {
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                                          SnackBar(content: Text(serverMsg(e))),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setDialogState(() => updating = false);
                                      }
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _detailLine('ID', '#$requestId'),
                    _detailLine(s.employee, employeeName),
                    _detailLine(s.createdAt, createdAt != null ? _formatRequestDateTime(createdAt) : '-'),
                    _detailLine(s.requestType, modeText),
                    _detailLine(
                      s.requestedTime,
                      valueText,
                      valueColor: AppTheme.primary,
                      strikeThrough: !currentApplied,
                    ),
                    _detailLine(
                      _requestActionLabel(s, status),
                      processedByName != null && processedAt != null
                          ? '$processedByName • ${_formatRequestDateTime(processedAt)}'
                          : '-',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(s.close),
              ),
            ],
          );
        },
      );
    },
  );
}

// â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, animationDuration: Duration.zero);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            tabs: [
              Tab(text: s.byDay),
              Tab(text: s.byMonth),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _DayViewTab(),
              _TimesheetTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Tab 1: Timesheet table â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TimesheetTab extends StatefulWidget {
  const _TimesheetTab();

  @override
  State<_TimesheetTab> createState() => _TimesheetTabState();
}

class _TimesheetTabState extends State<_TimesheetTab> {
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

  bool _dayNightMode = false;
  bool _otEnabled = true;

  // Inline row editing
  String? _editingRow; // dateKey of row in edit mode
  final Map<String, TextEditingController> _editCtrls = {};

  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  final _vScrollFixed = ScrollController();
  bool _syncingScroll = false;

  void _onVScroll() {
    if (_syncingScroll) return;
    if (_vScrollFixed.hasClients && _vScrollFixed.offset != _vScroll.offset) {
      _syncingScroll = true;
      _vScrollFixed.jumpTo(_vScroll.offset);
      _syncingScroll = false;
    }
  }

  void _onVScrollFixed() {
    if (_syncingScroll) return;
    if (_vScroll.hasClients && _vScroll.offset != _vScrollFixed.offset) {
      _syncingScroll = true;
      _vScroll.jumpTo(_vScrollFixed.offset);
      _syncingScroll = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
    _vScroll.addListener(_onVScroll);
    _vScrollFixed.addListener(_onVScrollFixed);
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    _vScrollFixed.dispose();
    for (final c in _editCtrls.values) c.dispose();
    super.dispose();
  }

  // ── Inline row editing (timesheet) ────────────────────────────────────────

  TextEditingController _ctrlFor(String dateKey, String col, String initVal) {
    final k = '$dateKey:$col';
    return _editCtrls.putIfAbsent(k, () => TextEditingController(text: initVal));
  }

  void _enterEditRow(String dateKey, TimesheetRow row) {
    // Pre-populate controllers with existing override or actual values
    _ctrlFor(dateKey, 'checkIn',  row.overrideCheckIn  ?? row.checkIn  ?? '').text = row.overrideCheckIn  ?? row.checkIn  ?? '';
    _ctrlFor(dateKey, 'checkOut', row.overrideCheckOut ?? row.checkOut ?? '').text = row.overrideCheckOut ?? row.checkOut ?? '';
    _ctrlFor(dateKey, 'break',
        row.overrideBreakMinutes != null ? _formatMinutesAsTime(row.overrideBreakMinutes!) : _formatBreak(row.breakMinutes)).text =
        row.overrideBreakMinutes != null ? _formatMinutesAsTime(row.overrideBreakMinutes!) : _formatBreak(row.breakMinutes);
    _ctrlFor(dateKey, 'otDay',
        row.overrideOtDayMinutes != null ? _formatMinutesAsTime(row.overrideOtDayMinutes!) : (row.otDayHours > 0 ? _formatHours(row.otDayHours) : '')).text =
        row.overrideOtDayMinutes != null ? _formatMinutesAsTime(row.overrideOtDayMinutes!) : (row.otDayHours > 0 ? _formatHours(row.otDayHours) : '');
    _ctrlFor(dateKey, 'otNight',
        row.overrideOtNightMinutes != null ? _formatMinutesAsTime(row.overrideOtNightMinutes!) : (row.otNightHours > 0 ? _formatHours(row.otNightHours) : '')).text =
        row.overrideOtNightMinutes != null ? _formatMinutesAsTime(row.overrideOtNightMinutes!) : (row.otNightHours > 0 ? _formatHours(row.otNightHours) : '');
    setState(() => _editingRow = dateKey);
  }

  void _cancelEditRow() => setState(() => _editingRow = null);

  Future<void> _saveEditRow(TimesheetRow row, String dateKey) async {
    setState(() => _editingRow = null);
    final ciRaw  = _editCtrls['$dateKey:checkIn']?.text.trim()  ?? '';
    final coRaw  = _editCtrls['$dateKey:checkOut']?.text.trim() ?? '';
    final brRaw  = _editCtrls['$dateKey:break']?.text.trim()    ?? '';
    final odRaw  = _editCtrls['$dateKey:otDay']?.text.trim()    ?? '';
    final onRaw  = _editCtrls['$dateKey:otNight']?.text.trim()  ?? '';

    final ci = ciRaw.isEmpty ? null : _DayViewTabState._parseTimeInput(ciRaw);
    final co = coRaw.isEmpty ? null : _DayViewTabState._parseTimeInput(coRaw);
    final br = brRaw.isEmpty ? null : _DayViewTabState._parseDurationInput(brRaw);
    final od = odRaw.isEmpty ? null : _DayViewTabState._parseDurationInput(odRaw);
    final on = onRaw.isEmpty ? null : _DayViewTabState._parseDurationInput(onRaw);
    if ((ciRaw.isNotEmpty && ci == null) ||
        (coRaw.isNotEmpty && co == null) ||
        (brRaw.isNotEmpty && br == null) ||
        (odRaw.isNotEmpty && od == null) ||
        (onRaw.isNotEmpty && on == null)) {
      return;
    }

    String? _normalizeTime(String? v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return null;
      return _DayViewTabState._parseTimeInput(s);
    }

    int? _effectiveBreak(int m) => m > 0 ? m : null;
    int? _effectiveOtMinutes(double h) {
      if (h <= 0) return null;
      return (h * 60).round();
    }

    final currentCheckIn = _normalizeTime(row.checkIn);
    final currentCheckOut = _normalizeTime(row.checkOut);
    final currentBreak = _effectiveBreak(row.breakMinutes);
    final currentOtDay = _effectiveOtMinutes(row.otDayHours);
    final currentOtNight = _effectiveOtMinutes(row.otNightHours);

    final ovCheckIn = _normalizeTime(row.overrideCheckIn);
    final ovCheckOut = _normalizeTime(row.overrideCheckOut);
    final ovBreak = row.overrideBreakMinutes;
    final ovOtDay = row.overrideOtDayMinutes;
    final ovOtNight = row.overrideOtNightMinutes;

    final nextCheckIn = ciRaw.isEmpty
        ? null
        : (ovCheckIn != null
            ? (ci == ovCheckIn ? row.overrideCheckIn : ci)
            : (ci == currentCheckIn ? null : ci));
    final nextCheckOut = coRaw.isEmpty
        ? null
        : (ovCheckOut != null
            ? (co == ovCheckOut ? row.overrideCheckOut : co)
            : (co == currentCheckOut ? null : co));
    final nextBreak = brRaw.isEmpty
        ? null
        : (ovBreak != null
            ? (br == ovBreak ? ovBreak : br)
            : (br == currentBreak ? null : br));
    final nextOtDay = odRaw.isEmpty
        ? null
        : (ovOtDay != null
            ? (od == ovOtDay ? ovOtDay : od)
            : (od == currentOtDay ? null : od));
    final nextOtNight = onRaw.isEmpty
        ? null
        : (ovOtNight != null
            ? (on == ovOtNight ? ovOtNight : on)
            : (on == currentOtNight ? null : on));

    try {
      final int attId = row.attendanceId ??
          await _repo.ensureAttendance(_selected!.id, row.date);
      await _repo.saveOverride(attId,
        checkIn: nextCheckIn, checkOut: nextCheckOut,
        breakMinutes: nextBreak, otDayMinutes: nextOtDay, otNightMinutes: nextOtNight,
        note: row.overrideNote,
      );
      await _loadTimesheet();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
      );
    }
  }

  // Cell widget: edit mode shows TextField, view mode shows value
  Widget _inlineCellT({
    required String dateKey,
    required String col,
    required String displayVal,
    required String? overrideVal,
    required double width,
    required Color bg,
    bool isTime = true,
  }) {
    final isEditing = _editingRow == dateKey;
    if (isEditing) {
      final ctrl = _editCtrls['$dateKey:$col'] ?? TextEditingController(text: overrideVal ?? displayVal);
      return Container(
        width: width,
        height: _rowHeight,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.05),
          border: const Border(
            bottom: BorderSide(color: _gridLineLight, width: 0.9),
            right: BorderSide(color: _gridLineLight, width: 0.8),
            top: BorderSide(color: AppTheme.primary, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        child: TextField(
          controller: ctrl,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppTheme.primary),
          keyboardType: TextInputType.datetime,
          maxLength: 5,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            counterText: '',
            hintText: '--',
            hintStyle: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    // View mode
    final showActualUnderOverride = displayVal.isNotEmpty && displayVal != overrideVal;
    return Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: overrideVal != null
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(overrideVal,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                const Icon(Icons.edit, size: 9, color: AppTheme.error),
              ]),
              if (showActualUnderOverride)
                Text('($displayVal)',
                    style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            ])
          : Text(displayVal,
              style: TextStyle(
                  fontSize: 12,
                  color: displayVal.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)),
    );
  }

  Future<void> _init() async {
    try {
      final results = await Future.wait([
        DepartmentService.instance.getFlat(permission: 'ATTENDANCE_VIEW'),
        _empRepo.getAll(page: 0, size: 500),
      ]);
      if (!mounted) return;
      final depts = results[0] as List<DepartmentFlat>;
      final emps = (results[1] as ({List<Employee> items, int total})).items;
      setState(() {
        _depts = depts;
        _employees = emps;
      });
      if (emps.isNotEmpty) _selectEmployee(emps.first);
    } catch (_) {}
    try {
      final settings = await _settingRepo.get();
      final att = settings['attendance'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _dayNightMode = att['dayNightMode'] == true;
          _otEnabled = att['otEnabled'] != false;
        });
      }
    } catch (_) {}
  }

  void _selectEmployee(Employee e) {
    setState(() {
      _selected = e;
    });
    _loadTimesheet();
  }

  Future<void> _loadTimesheet() async {
    if (_selected == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repo.getTimesheet(
        employeeId: _selected!.id,
        year: _month.year,
        month: _month.month,
      );
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = serverMsg(e);
          _loading = false;
        });
      }
    }
  }

  Future<AttendanceChangeRequest> _setRequestApplied(
    int id,
    bool applied,
  ) async {
    final updated = await _repo.setRequestApplied(id, applied);
    if (mounted) {
      await _loadTimesheet();
    }
    return updated;
  }

  Future<bool> _setLeaveRequestApplied(int id, bool applied) async {
    final updated = await _leaveRepo.setRequestApplied(id, applied);
    if (mounted) {
      await _loadTimesheet();
    }
    return updated['applied'] == true;
  }

  Future<void> _pickMonth() async {
    final s = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        var selectedYear = _month.year;
        var selectedMonth = _month.month;
        final years = List.generate(11, (i) => now.year - 10 + i);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(s.chooseMonth),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedYear,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: s.year,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      items: years
                          .map((y) =>
                              DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() => selectedYear = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (i) {
                        final month = i + 1;
                        final selected = selectedMonth == month;
                        return SizedBox(
                          width: 76,
                          child: ChoiceChip(
                            label: Text('$month'),
                            selected: selected,
                            onSelected: (_) =>
                                setDialogState(() => selectedMonth = month),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    DateTime(selectedYear, selectedMonth),
                  ),
                  child: Text(s.apply),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() => _month = picked);
    _loadTimesheet();
  }

  List<Employee> get _filteredEmps {
    if (_filterDept == null) return _employees;
    final deptScopeIds = _expandedDepartmentScopeIds(_depts, _filterDept);
    return _employees
        .where((e) => deptScopeIds.contains(e.departmentId))
        .toList();
  }

  List<_MergedTimesheetRow> get _mergedRows {
    final groups = <String, List<TimesheetRow>>{};
    for (final row in _rows) {
      final key = '${row.date.year}-${row.date.month}-${row.date.day}';
      groups.putIfAbsent(key, () => []).add(row);
    }
    return groups.entries.map((entry) {
      final rows = List<TimesheetRow>.from(entry.value)
        ..sort(_compareTimesheetRows);
      return _MergedTimesheetRow(rows);
    }).toList()
      ..sort((a, b) => a.first.date.compareTo(b.first.date));
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

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final monthFmt = DateFormat('MM/yyyy', localeTag);
    final monthLabel =
        '${AppLocalizations.of(context)!.month} ${monthFmt.format(_month)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // â”€â”€ Toolbar â”€â”€
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 320,
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 40, height: 48),
                      onPressed: () {
                        setState(() =>
                            _month = DateTime(_month.year, _month.month - 1));
                        _loadTimesheet();
                      },
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickMonth,
                        icon:
                            const Icon(Icons.calendar_month_outlined, size: 18),
                        label: Text(
                          monthLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.center,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 40, height: 48),
                      onPressed: () {
                        setState(() =>
                            _month = DateTime(_month.year, _month.month + 1));
                        _loadTimesheet();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  // Dept filter
                  SizedBox(
                    width: 220,
                    height: 56,
                    child: DepartmentPickerField(
                      compact: true,
                      departments: _depts,
                      value: _filterDept,
                      label: s.department,
                      allowAll: true,
                      onChanged: (v) {
                        setState(() {
                          _filterDept = v;
                          final emps = _filteredEmps;
                          if (emps.isNotEmpty &&
                              (_selected == null ||
                                  !emps.any((e) => e.id == _selected!.id))) {
                            _selected = emps.first;
                            _loadTimesheet();
                          }
                        });
                      },
                    ),
                  ),
                  // Employee picker
                  SizedBox(
                    width: 320,
                    height: 56,
                    child: DropdownButtonFormField<int?>(
                      value: _selected?.id,
                      borderRadius: BorderRadius.circular(8),
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: s.employee,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _filteredEmps
                          .map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.fullName,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final emp = _employees.firstWhere((e) => e.id == v);
                        _selectEmployee(emp);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // â”€â”€ Table â”€â”€
        Expanded(child: _buildTable()),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildTable() {
    final s = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadTimesheet, child: Text(s.retry)),
        ]),
      );
    }
    if (_selected == null) {
      return Center(
        child: Text(
          s.selectEmployeeToViewTimesheet,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final dateColW = isMobile ? 56.0 : _dateColW;
        final cols = _cols(s, dayNight: _dayNightMode, otEnabled: _otEnabled);
        final totalMin = cols.fold(0.0, (sum, c) => sum + c.width);
        final available = constraints.maxWidth - dateColW - 1;
        final scale = available > totalMin ? available / totalMin : 1.0;
        final colWidths = cols.map((c) => c.width * scale).toList();
        final scrollWidth = colWidths.fold(0.0, (s, w) => s + w);
        final merged = _mergedRows;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cột Ngày - cố định
            SizedBox(
              width: dateColW,
              child: Column(
                children: [
                  _headCell(s.date, width: dateColW),
                  Expanded(
                    child: ListView.builder(
                      controller: _vScrollFixed,
                      physics: const ClampingScrollPhysics(),
                      itemCount: merged.length,
                      itemBuilder: (_, i) {
                        final row = merged[i];
                        if (row.rows.length <= 1) {
                          return _dateCell(row.first, width: dateColW);
                        }
                        final height = _rowHeight * row.rows.length;
                        return _dateCellMerged(row, height, width: dateColW);
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Phần data - scroll ngang
            Expanded(
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: scrollWidth,
                  child: Column(
                    children: [
                      Row(
                        children: List.generate(cols.length,
                            (i) => _headCell(cols[i].label, width: colWidths[i])),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _vScroll,
                          physics: const ClampingScrollPhysics(),
                          itemCount: merged.length,
                          itemBuilder: (_, i) {
                            final row = merged[i];
                            if (row.rows.length <= 1) {
                              return SizedBox(
                                height: _rowHeight,
                                child: Row(children: _dataCells(row.first, colWidths)),
                              );
                            }
                            final height = _rowHeight * row.rows.length;
                            return SizedBox(
                              height: height,
                              child: Column(
                                children: [
                                  for (final slot in row.rows)
                                    SizedBox(
                                      height: _rowHeight,
                                      child: Row(children: _dataCells(slot, colWidths)),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // â”€â”€ Cell builders â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _headCell(String label,
      {required double width, bool isFirst = false}) {
    return Container(
      width: width,
      height: _headHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(
          bottom: const BorderSide(color: _gridLine, width: 1.1),
          right: BorderSide(color: _gridLine, width: isFirst ? 0 : 0.8),
        ),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _dateCell(TimesheetRow row, {double width = _dateColW}) {
    final isToday = row.date.year == DateTime.now().year &&
        row.date.month == DateTime.now().month &&
        row.date.day == DateTime.now().day;
    final color = row.weekend
        ? const Color(0xFFFFF3E0)
        : isToday
            ? const Color(0xFFE3F2FD)
            : Colors.white;

    return Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLine, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${row.date.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: row.weekend
                  ? AppTheme.warning
                  : (isToday ? AppTheme.primary : AppTheme.textPrimary),
            ),
          ),
          Text(
            row.dayLabel,
            style: TextStyle(
              fontSize: 10,
              color: row.weekend ? AppTheme.warning : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateCellMerged(_MergedTimesheetRow row, double height, {double width = _dateColW}) {
    final first = row.first;
    final isToday = first.date.year == DateTime.now().year &&
        first.date.month == DateTime.now().month &&
        first.date.day == DateTime.now().day;
    final color = row.weekend
        ? const Color(0xFFFFF3E0)
        : isToday
            ? const Color(0xFFE3F2FD)
            : Colors.white;

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLine, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${first.date.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: row.weekend
                  ? AppTheme.warning
                  : (isToday ? AppTheme.primary : AppTheme.textPrimary),
            ),
          ),
          Text(
            first.dayLabel,
            style: TextStyle(
              fontSize: 10,
              color: row.weekend ? AppTheme.warning : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _dataCells(TimesheetRow row, List<double> cw) {
    final s = AppLocalizations.of(context)!;
    final isToday = row.date.year == DateTime.now().year &&
        row.date.month == DateTime.now().month &&
        row.date.day == DateTime.now().day;
    final bg = row.weekend
        ? const Color(0xFFFFF3E0)
        : isToday
            ? const Color(0xFFE3F2FD)
            : Colors.white;
    final checkInRequests =
        _matchingRequests(row, row.requests, requestType: 'CHECK_IN');
    final checkOutRequests =
        _matchingRequests(row, row.requests, requestType: 'CHECK_OUT');
    final otDayRequests = _matchingRequests(
      row,
      row.requests,
      requestType: 'OT',
      period: 'DAY',
    );
    final otNightRequests = _matchingRequests(
      row,
      row.requests,
      requestType: 'OT',
      period: 'NIGHT',
    );
    final checkInRequest = _pickVisibleRequest(checkInRequests);
    final checkOutRequest = _pickVisibleRequest(checkOutRequests);

    var idx = 0;
    final cells = <Widget>[];

    cells.add(_leaveCell(
      row.leaveRequestId,
      row.leaveCode,
      row.leaveMode,
      row.leaveStatus,
      row.leaveApplied,
      row.leaveProcessedByName,
      row.leaveProcessedAt,
      row.leaveCreatedAt,
      row.leaveAmount,
      row.leaveFromTime,
      row.leaveToTime,
      _selected?.fullName ?? '-',
      _selected?.departmentName ?? '-',
      cw[idx++],
      bg,
    ));
    cells.add(_shiftCell(row, cw[idx++], bg));
    final dateKey = '${row.date.year}-${row.date.month.toString().padLeft(2,'0')}-${row.date.day.toString().padLeft(2,'0')}';
    // Break
    cells.add(_inlineCellT(
      dateKey: dateKey, col: 'break',
      displayVal: _formatBreak(row.breakMinutes),
      overrideVal: row.overrideBreakMinutes != null ? _formatMinutesAsTime(row.overrideBreakMinutes!) : null,
      width: cw[idx++], bg: bg, isTime: false,
    ));
    // Check-in
    cells.add(_inlineCellT(
      dateKey: dateKey, col: 'checkIn',
      displayVal: row.checkIn ?? _empty,
      overrideVal: row.overrideCheckIn,
      width: cw[idx++], bg: bg,
    ));
    // Check-out
    cells.add(_inlineCellT(
      dateKey: dateKey, col: 'checkOut',
      displayVal: row.checkOut ?? _empty,
      overrideVal: row.overrideCheckOut,
      width: cw[idx++], bg: bg,
    ));
    cells.add(_requestCell(
      _formatRequestTimeOrDuration(checkInRequest),
      checkInRequest?.status,
      width: cw[idx++],
      bg: bg,
      strikeThrough: checkInRequest != null && !checkInRequest.applied,
      onTap: checkInRequests.isNotEmpty
          ? () {
              _showRequestCardsDialog(
                context,
                title: s.checkInRequest,
                requests: checkInRequests,
                onToggleApplied: _setRequestApplied,
                attendanceApproved: row.approved,
              );
            }
          : null,
    ));
    cells.add(_requestCell(
      _formatRequestTimeOrDuration(checkOutRequest),
      checkOutRequest?.status,
      width: cw[idx++],
      bg: bg,
      strikeThrough: checkOutRequest != null && !checkOutRequest.applied,
      onTap: checkOutRequests.isNotEmpty
          ? () {
              _showRequestCardsDialog(
                context,
                title: s.checkOutRequest,
                requests: checkOutRequests,
                onToggleApplied: _setRequestApplied,
                attendanceApproved: row.approved,
              );
            }
          : null,
    ));
    final mergedDayOt = !_otEnabled
        ? (!_dayNightMode ? [...otDayRequests, ...otNightRequests] : otDayRequests)
        : <AttendanceChangeRequest>[];
    cells.add(_numCell(row.totalHours, cw[idx++], bg));
    cells.add(_numCell(
      row.regularDayHours,
      cw[idx++],
      bg,
      highlight: mergedDayOt.isNotEmpty,
      onTap: mergedDayOt.isNotEmpty
          ? () => _showRequestCardsDialog(
                context,
                title: s.dayHours,
                requests: mergedDayOt,
                onToggleApplied: _setRequestApplied,
                attendanceApproved: row.approved,
              )
          : null,
    ));
    if (_otEnabled) {
      cells.add(_inlineCellT(
        dateKey: dateKey, col: 'otDay',
        displayVal: row.otDayHours > 0 ? _formatHours(row.otDayHours) : _empty,
        overrideVal: row.overrideOtDayMinutes != null ? _formatHours(row.overrideOtDayMinutes! / 60.0) : null,
        width: cw[idx++], bg: bg, isTime: false,
      ));
    }
    if (_dayNightMode) {
      final mergedNightOt = !_otEnabled ? otNightRequests : <AttendanceChangeRequest>[];
      cells.add(_numCell(row.regularNightHours, cw[idx++], bg,
        highlight: mergedNightOt.isNotEmpty,
        onTap: mergedNightOt.isNotEmpty
            ? () => _showRequestCardsDialog(context, title: s.nightHours,
                  requests: mergedNightOt, onToggleApplied: _setRequestApplied,
                  attendanceApproved: row.approved)
            : null,
      ));
      if (_otEnabled) {
        cells.add(_inlineCellT(
          dateKey: dateKey, col: 'otNight',
          displayVal: row.otNightHours > 0 ? _formatHours(row.otNightHours) : _empty,
          overrideVal: row.overrideOtNightMinutes != null ? _formatHours(row.overrideOtNightMinutes! / 60.0) : null,
          width: cw[idx++], bg: bg, isTime: false,
        ));
      }
    }
    cells.add(_workStatusCell(row, cw[idx++], bg));
    cells.add(_actionCell(row, cw[idx++], bg));

    return cells;
  }

  Widget _leaveCell(
    int? leaveRequestId,
    String? leaveCode,
    String? leaveMode,
    String? leaveStatus,
    bool? leaveApplied,
    String? leaveProcessedByName,
    String? leaveProcessedAt,
    String? leaveCreatedAt,
    double? leaveAmount,
    String? leaveFromTime,
    String? leaveToTime,
    String employeeName,
    String departmentName,
    double width,
    Color bg,
  ) {
    final isLeave = leaveCode != null;
    final isDayRange = leaveMode == 'DAY_RANGE';
    final leaveNotApplied = isLeave && leaveApplied == false;
    final effectiveBg = isDayRange && isLeave
        ? const Color(0xFFE8F5E9)
        : bg;
    final s = AppLocalizations.of(context)!;
    final child = Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: effectiveBg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: isLeave
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: leaveNotApplied
                        ? AppTheme.textSecondary.withValues(alpha: 0.1)
                        : const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  ),
                  child: Text(
                    leaveCode!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: leaveNotApplied ? AppTheme.textSecondary : const Color(0xFF2E7D32),
                      decoration: leaveNotApplied ? TextDecoration.lineThrough : null,
                      decorationColor: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (leaveMode == 'HOUR_RANGE' && leaveFromTime != null && leaveToTime != null)
                  Text(
                    '$leaveFromTime-$leaveToTime',
                    style: TextStyle(
                      fontSize: 9,
                      color: leaveNotApplied ? AppTheme.textSecondary : const Color(0xFF2E7D32),
                      decoration: leaveNotApplied ? TextDecoration.lineThrough : null,
                    ),
                  ),
              ],
            )
          : const SizedBox.shrink(),
    );
    if (!isLeave || leaveRequestId == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await _showLeaveRequestCardDialog(
            context,
            requestId: leaveRequestId,
            employeeName: employeeName,
            departmentName: departmentName,
            leaveCode: leaveCode,
            leaveMode: leaveMode,
            leaveFromTime: leaveFromTime,
            leaveToTime: leaveToTime,
            leaveAmount: leaveAmount,
            status: leaveStatus ?? 'APPROVED',
            applied: leaveApplied ?? true,
            processedByName: leaveProcessedByName,
            processedAt: leaveProcessedAt,
            createdAt: leaveCreatedAt,
            onToggleApplied: (value) => _setLeaveRequestApplied(leaveRequestId, value),
          );
        },
        child: child,
      ),
    );
  }

  Widget _shiftCell(TimesheetRow row, double width, Color bg) {
    Color? dotColor;
    if (row.shiftColor != null) {
      try {
        dotColor = Color(int.parse(row.shiftColor!.replaceAll('#', '0xFF')));
      } catch (_) {}
    }
    return Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: row.shiftName == null
          ? const SizedBox.shrink()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (dotColor != null) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: dotColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        row.shiftName!,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                if (row.shiftStart != null || row.shiftEnd != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatShiftRange(row.shiftStart, row.shiftEnd),
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _textCell(
    String text, {
    required double width,
    required Color bg,
    Color? color,
    VoidCallback? onTap,
  }) {
    final child = Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              color: color ??
                  (text.isEmpty
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary))),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }

  // Cell hiển thị giá trị override (đỏ + bút) và giá trị thật bên dưới nhỏ
  Widget _overrideCell({
    required String overrideVal,
    required String actualVal,
    required double width,
    required Color bg,
  }) {
    return Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(overrideVal,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w700)),
          const SizedBox(width: 2),
          const Icon(Icons.edit, size: 9, color: AppTheme.error),
        ]),
        if (actualVal.isNotEmpty)
          Text('($actualVal)',
              style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _numCell(double val, double width, Color bg,
      {bool highlight = false, VoidCallback? onTap}) {
    final text = val > 0 ? _formatHours(val) : _empty;
    final child = Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight ? AppTheme.warning.withValues(alpha: 0.08) : bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: val > 0 ? FontWeight.w600 : FontWeight.normal,
          color: highlight
              ? AppTheme.warning
              : val > 0
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
        ),
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }

  Widget _requestCell(
    String? value,
    String? status, {
    required double width,
    required Color bg,
    bool highlight = false,
    bool strikeThrough = false,
    VoidCallback? onTap,
  }) {
    final text = value ?? _empty;
    final color = switch (status) {
      'APPROVED' => Colors.green,
      'REJECTED' => AppTheme.error,
      'PENDING' => AppTheme.warning,
      _ => highlight ? AppTheme.primary : AppTheme.textSecondary,
    };
    final child = Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.08) : bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
          color: text.isEmpty ? AppTheme.textSecondary : color,
          decoration: strikeThrough ? TextDecoration.lineThrough : null,
        ),
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }

  Widget _workStatusCell(TimesheetRow row, double width, Color bg) {
    final s = AppLocalizations.of(context)!;
    final flags = row.workFlags;
    if (flags.isEmpty) {
      return Container(
        width: width, height: _rowHeight,
        decoration: BoxDecoration(
          color: bg,
          border: const Border(bottom: BorderSide(color: _gridLineLight, width: 0.9)),
        ),
      );
    }

    final chips = flags.map((f) {
      final (label, color) = switch (f) {
        'LATE_IN'   => (s.lateIn,   AppTheme.error),
        'EARLY_OUT' => (s.earlyOut, AppTheme.warning),
        'ON_TIME'   => (s.onTime,   AppTheme.secondary),
        'OVERTIME'  => (s.overtime, const Color(0xFFFF9800)),
        'LEAVE'     => (s.leave,    const Color(0xFF607D8B)),
        _           => (f,          AppTheme.textSecondary),
      };
      return Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );
    }).toList();

    return Container(
      width: width, height: _rowHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(bottom: BorderSide(color: _gridLineLight, width: 0.9)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: chips),
      ),
    );
  }

  Widget _actionCell(TimesheetRow row, double width, Color bg) {
    final s = AppLocalizations.of(context)!;
    final hasRecord = row.checkIn != null || row.checkOut != null || row.attendanceId != null;
    return Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: bg,
        border:
            const Border(bottom: BorderSide(color: _gridLineLight, width: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.approved) ...[
            Tooltip(
              message: row.approvedByName != null
                  ? '${s.approved}: ${row.approvedByName}'
                  : s.approved,
              child: const Icon(Icons.check_circle, color: AppTheme.secondary, size: 18),
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 24, height: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 15,
                icon: const Icon(Icons.lock_open_outlined, color: AppTheme.warning),
                tooltip: s.unapprove,
                onPressed: () => _unapproveRow(row),
              ),
            ),
          ] else
            Builder(builder: (_) {
              final dateKey = '${row.date.year}-${row.date.month.toString().padLeft(2,'0')}-${row.date.day.toString().padLeft(2,'0')}';
              final isEditing = _editingRow == dateKey;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                if (isEditing) ...[
                  SizedBox(width: 24, height: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero, iconSize: 16,
                      icon: const Icon(Icons.check, color: AppTheme.secondary),
                      tooltip: s.save,
                      onPressed: () => _saveEditRow(row, dateKey),
                    ),
                  ),
                  const SizedBox(width: 2),
                  SizedBox(width: 24, height: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero, iconSize: 16,
                      icon: const Icon(Icons.close, color: AppTheme.error),
                      tooltip: s.cancel,
                      onPressed: _cancelEditRow,
                    ),
                  ),
                ] else ...[
                  SizedBox(width: 24, height: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero, iconSize: 16,
                      icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                      tooltip: s.edit,
                      onPressed: () => _enterEditRow(dateKey, row),
                    ),
                  ),
                  if (hasRecord) ...[
                    const SizedBox(width: 2),
                    SizedBox(width: 24, height: 24,
                      child: IconButton(
                        padding: EdgeInsets.zero, iconSize: 16,
                        icon: const Icon(Icons.check_circle_outline, color: AppTheme.secondary),
                        tooltip: s.approve,
                        onPressed: () => _approveRow(row),
                      ),
                    ),
                  ],
                ],
              ]);
            }),
        ],
      ),
    );
  }

  Future<void> _approveRow(TimesheetRow row) async {
    final s = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.approve),
        content: Text('${s.approve} ${row.date.day}/${row.date.month}/${row.date.year}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.approve)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.approveAttendance(
        row.attendanceId,
        employeeId: _selected!.id,
        date: row.date,
        shiftAssignmentId: row.shiftAssignmentId,
      );
      await _loadTimesheet();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _unapproveRow(TimesheetRow row) async {
    final s = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.unapprove),
        content: Text('${s.unapprove} ${row.date.day}/${row.date.month}/${row.date.year}?'),
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
    try {
      await _repo.unapproveAttendance(row.attendanceId!);
      await _loadTimesheet();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
      );
    }
  }

  String _formatBreak(int minutes) {
    if (minutes == 0) return _empty;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  String _formatShiftRange(String? start, String? end) {
    if ((start ?? '').isEmpty && (end ?? '').isEmpty) return _empty;
    if ((start ?? '').isEmpty) return end!;
    if ((end ?? '').isEmpty) return start!;
    return '$start - $end';
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final hh = totalMinutes ~/ 60;
    final mm = totalMinutes % 60;
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  Color? _checkInColor(TimesheetRow row) {
    if (row.status == AttendanceStatus.late) return AppTheme.warning;
    if (row.checkIn != null) return Colors.green;
    return null;
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬ Tab 2: Day view Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _DayViewTab extends StatefulWidget {
  const _DayViewTab();

  @override
  State<_DayViewTab> createState() => _DayViewTabState();
}

// Key identifying an editable cell: employee+date+column type
typedef _CellKey = ({int employeeId, String date, String col});

class _DayViewTabState extends State<_DayViewTab> {
  final _repo = AttendanceRepository();
  final _leaveRepo = LeaveRepository();
  final _settingRepo = CompanySettingRepository();
  List<DepartmentFlat> _depts = [];
  int? _filterDept;
  DateTime _date =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  int _page = 0;
  int _pageSize = 20;

  List<DayViewRow> _rows = [];
  bool _loading = false;
  String? _error;

  bool _dayNightMode = false;
  bool _otEnabled = true;

  // Inline row editing (day view), triggered from right action button like month view
  String? _editingDaySlotKey;
  final Map<String, TextEditingController> _dayEditCtrls = {};

  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  final _vScrollFixed = ScrollController();
  bool _syncingScroll = false;

  void _onVScroll() {
    if (_syncingScroll) return;
    if (_vScrollFixed.hasClients && _vScrollFixed.offset != _vScroll.offset) {
      _syncingScroll = true;
      _vScrollFixed.jumpTo(_vScroll.offset);
      _syncingScroll = false;
    }
  }

  void _onVScrollFixed() {
    if (_syncingScroll) return;
    if (_vScroll.hasClients && _vScroll.offset != _vScrollFixed.offset) {
      _syncingScroll = true;
      _vScroll.jumpTo(_vScrollFixed.offset);
      _syncingScroll = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
    _vScroll.addListener(_onVScroll);
    _vScrollFixed.addListener(_onVScrollFixed);
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    _vScrollFixed.dispose();
    for (final c in _dayEditCtrls.values) c.dispose();
    super.dispose();
  }

  // ── Inline cell editing ────────────────────────────────────────────────────

  String _daySlotKey(DayViewRow slot) =>
      '${slot.employeeId}_${slot.date}_${slot.shiftAssignmentId ?? 0}';

  TextEditingController _dayCtrlFor(
    String slotKey,
    String col,
    String initVal,
  ) {
    final k = '$slotKey:$col';
    return _dayEditCtrls.putIfAbsent(k, () => TextEditingController(text: initVal));
  }

  void _enterDayEditSlot(DayViewRow slot) {
    final slotKey = _daySlotKey(slot);
    _dayCtrlFor(slotKey, 'checkIn', slot.overrideCheckIn ?? slot.checkIn ?? '').text =
        slot.overrideCheckIn ?? slot.checkIn ?? '';
    _dayCtrlFor(slotKey, 'checkOut', slot.overrideCheckOut ?? slot.checkOut ?? '').text =
        slot.overrideCheckOut ?? slot.checkOut ?? '';
    _dayCtrlFor(
      slotKey,
      'break',
      slot.overrideBreakMinutes != null
          ? _formatMinutesAsTime(slot.overrideBreakMinutes!)
          : _formatBreak(slot.breakMinutes),
    ).text = slot.overrideBreakMinutes != null
        ? _formatMinutesAsTime(slot.overrideBreakMinutes!)
        : _formatBreak(slot.breakMinutes);
    _dayCtrlFor(
      slotKey,
      'otDay',
      slot.overrideOtDayMinutes != null
          ? _formatMinutesAsTime(slot.overrideOtDayMinutes!)
          : (slot.otDayHours > 0 ? _formatHours(slot.otDayHours) : ''),
    ).text = slot.overrideOtDayMinutes != null
        ? _formatMinutesAsTime(slot.overrideOtDayMinutes!)
        : (slot.otDayHours > 0 ? _formatHours(slot.otDayHours) : '');
    _dayCtrlFor(
      slotKey,
      'otNight',
      slot.overrideOtNightMinutes != null
          ? _formatMinutesAsTime(slot.overrideOtNightMinutes!)
          : (slot.otNightHours > 0 ? _formatHours(slot.otNightHours) : ''),
    ).text = slot.overrideOtNightMinutes != null
        ? _formatMinutesAsTime(slot.overrideOtNightMinutes!)
        : (slot.otNightHours > 0 ? _formatHours(slot.otNightHours) : '');
    setState(() => _editingDaySlotKey = slotKey);
  }

  void _cancelDayEditSlot() {
    setState(() => _editingDaySlotKey = null);
  }

  Future<void> _saveDayEditSlot(DayViewRow slot) async {
    final slotKey = _daySlotKey(slot);
    setState(() => _editingDaySlotKey = null);
    final ciRaw = _dayEditCtrls['$slotKey:checkIn']?.text.trim() ?? '';
    final coRaw = _dayEditCtrls['$slotKey:checkOut']?.text.trim() ?? '';
    final brRaw = _dayEditCtrls['$slotKey:break']?.text.trim() ?? '';
    final odRaw = _dayEditCtrls['$slotKey:otDay']?.text.trim() ?? '';
    final onRaw = _dayEditCtrls['$slotKey:otNight']?.text.trim() ?? '';

    final ci = ciRaw.isEmpty ? null : _parseTimeInput(ciRaw);
    final co = coRaw.isEmpty ? null : _parseTimeInput(coRaw);
    final br = brRaw.isEmpty ? null : _parseDurationInput(brRaw);
    final od = odRaw.isEmpty ? null : _parseDurationInput(odRaw);
    final on = onRaw.isEmpty ? null : _parseDurationInput(onRaw);
    if ((ciRaw.isNotEmpty && ci == null) ||
        (coRaw.isNotEmpty && co == null) ||
        (brRaw.isNotEmpty && br == null) ||
        (odRaw.isNotEmpty && od == null) ||
        (onRaw.isNotEmpty && on == null)) {
      return;
    }

    String? _normalizeTime(String? v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return null;
      return _parseTimeInput(s);
    }

    int? _effectiveBreak(int m) => m > 0 ? m : null;
    int? _effectiveOtMinutes(double h) {
      if (h <= 0) return null;
      return (h * 60).round();
    }

    final currentCheckIn = _normalizeTime(slot.checkIn);
    final currentCheckOut = _normalizeTime(slot.checkOut);
    final currentBreak = _effectiveBreak(slot.breakMinutes);
    final currentOtDay = _effectiveOtMinutes(slot.otDayHours);
    final currentOtNight = _effectiveOtMinutes(slot.otNightHours);

    final ovCheckIn = _normalizeTime(slot.overrideCheckIn);
    final ovCheckOut = _normalizeTime(slot.overrideCheckOut);
    final ovBreak = slot.overrideBreakMinutes;
    final ovOtDay = slot.overrideOtDayMinutes;
    final ovOtNight = slot.overrideOtNightMinutes;

    final nextCheckIn = ciRaw.isEmpty
        ? null
        : (ovCheckIn != null
            ? (ci == ovCheckIn ? slot.overrideCheckIn : ci)
            : (ci == currentCheckIn ? null : ci));
    final nextCheckOut = coRaw.isEmpty
        ? null
        : (ovCheckOut != null
            ? (co == ovCheckOut ? slot.overrideCheckOut : co)
            : (co == currentCheckOut ? null : co));
    final nextBreak = brRaw.isEmpty
        ? null
        : (ovBreak != null
            ? (br == ovBreak ? ovBreak : br)
            : (br == currentBreak ? null : br));
    final nextOtDay = odRaw.isEmpty
        ? null
        : (ovOtDay != null
            ? (od == ovOtDay ? ovOtDay : od)
            : (od == currentOtDay ? null : od));
    final nextOtNight = onRaw.isEmpty
        ? null
        : (ovOtNight != null
            ? (on == ovOtNight ? ovOtNight : on)
            : (on == currentOtNight ? null : on));

    try {
      final int attId = slot.attendanceId ?? await _repo.ensureAttendance(slot.employeeId, slot.date);
      await _repo.saveOverride(
        attId,
        checkIn: nextCheckIn,
        checkOut: nextCheckOut,
        breakMinutes: nextBreak,
        otDayMinutes: nextOtDay,
        otNightMinutes: nextOtNight,
        note: slot.overrideNote,
      );
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  static String? _parseTimeInput(String raw) {
    final d = raw.replaceAll(RegExp(r'[:\s]'), '');
    int? h, m;
    if (d.length == 3) { h = int.tryParse(d.substring(0,1)); m = int.tryParse(d.substring(1)); }
    else if (d.length == 4) { h = int.tryParse(d.substring(0,2)); m = int.tryParse(d.substring(2)); }
    else { final p = raw.split(':'); if (p.length==2) { h=int.tryParse(p[0].trim()); m=int.tryParse(p[1].trim()); } }
    if (h==null||m==null||h>23||m>59) return null;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}';
  }

  static int? _parseDurationInput(String raw) {
    final t = _parseTimeInput(raw);
    if (t == null) return null;
    final p = t.split(':');
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  Widget _inlineCell({
    required _CellKey key,
    required String displayVal,
    required String? overrideVal,
    required double width,
    required Color bg,
    required DayViewRow slot,
    bool isTime = true,
  }) {
    final slotKey = _daySlotKey(slot);
    final isEditing = _editingDaySlotKey == slotKey;
    if (isEditing) {
      final ctrl = _dayEditCtrls['$slotKey:${key.col}'] ?? TextEditingController(
        text: overrideVal ?? displayVal,
      );
      return Container(
        width: width,
        height: _dayRowHeight,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.05),
          border: const Border(
            bottom: BorderSide(color: _gridLineLight, width: 0.9),
            right: BorderSide(color: _gridLineLight, width: 0.8),
            top: BorderSide(color: AppTheme.primary, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        child: TextField(
          controller: ctrl,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppTheme.primary),
          keyboardType: TextInputType.datetime,
          maxLength: 5,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            counterText: '',
            hintText: '--',
            hintStyle: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final showActualUnderOverride = displayVal.isNotEmpty && displayVal != overrideVal;
    return Container(
      width: width,
      height: _dayRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: overrideVal != null
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(overrideVal,
                    style: const TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                const Icon(Icons.edit, size: 9, color: AppTheme.error),
              ]),
              if (showActualUnderOverride)
                Text('($displayVal)',
                    style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            ])
          : Text(displayVal,
              style: TextStyle(fontSize: 12,
                  color: displayVal.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)),
    );
  }

  Future<void> _init() async {
    try {
      final results = await Future.wait([
        DepartmentService.instance.getFlat(permission: 'ATTENDANCE_VIEW'),
        _settingRepo.get(),
      ]);
      if (!mounted) return;
      final depts = results[0] as List<DepartmentFlat>;
      final settings = results[1] as Map<String, dynamic>;
      final att = settings['attendance'] as Map<String, dynamic>? ?? {};
      setState(() {
        _depts = depts;
        _dayNightMode = att['dayNightMode'] == true;
        _otEnabled = att['otEnabled'] != false;
      });
      _loadRows();
    } catch (_) {}
  }

  Future<void> _loadRows() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repo.getDayView(
        date: _date,
        departmentId: _filterDept,
      );
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
          _page = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = serverMsg(e);
          _loading = false;
        });
      }
    }
  }

  Future<AttendanceChangeRequest> _setRequestApplied(
    int id,
    bool applied,
  ) async {
    final updated = await _repo.setRequestApplied(id, applied);
    if (mounted) {
      await _loadRows();
    }
    return updated;
  }

  Future<bool> _setLeaveRequestApplied(int id, bool applied) async {
    final updated = await _leaveRepo.setRequestApplied(id, applied);
    if (mounted) {
      await _loadRows();
    }
    return updated['applied'] == true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    _loadRows();
  }

  String _dayLabel(DateTime date) {
    return DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  List<double> get _colWidths {
    final s = AppLocalizations.of(context)!;
    return [_dayFirstColW, ..._cols(s, dayNight: _dayNightMode, otEnabled: _otEnabled).map((c) => c.width).toList()];
  }

  List<_MergedDayViewRow> get _mergedRows {
    final groups = <String, List<DayViewRow>>{};
    for (final row in _rows) {
      final key =
          '${row.employeeId}_${row.date.year}-${row.date.month}-${row.date.day}';
      groups.putIfAbsent(key, () => []).add(row);
    }
    return groups.values.map((rows) {
      rows.sort(_compareDayViewSlots);
      return _MergedDayViewRow(rows);
    }).toList();
  }

  List<_MergedDayViewRow> get _pagedRows {
    final start = _page * _pageSize;
    final merged = _mergedRows;
    if (start >= merged.length) return const [];
    final end = (start + _pageSize).clamp(0, merged.length);
    return merged.sublist(start, end);
  }

  int get _totalPages =>
      _mergedRows.isEmpty ? 1 : (_mergedRows.length / _pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 340,
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 40, height: 48),
                      onPressed: () {
                        setState(() {
                          _date = _date.subtract(const Duration(days: 1));
                          _page = 0;
                        });
                        _loadRows();
                      },
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _pickDate,
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: AppTheme.primary.withValues(alpha: .6)),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month_outlined,
                                  color: AppTheme.primary, size: 17),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _dayLabel(_date),
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 40, height: 48),
                      onPressed: () {
                        setState(() {
                          _date = _date.add(const Duration(days: 1));
                          _page = 0;
                        });
                        _loadRows();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  DepartmentPickerField(
                    departments: _depts,
                    value: _filterDept,
                    label: s.departmentShort,
                    allowAll: true,
                    compact: true,
                    onChanged: (v) {
                      setState(() {
                        _filterDept = v;
                        _page = 0;
                      });
                      _loadRows();
                    },
                  ),
                  const SizedBox(width: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _loadRows,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(s.refresh),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                )
              : _rows.isEmpty && !_loading
                  ? Center(
                      child: Text(
                        s.noAttendanceDataForThisDay,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : _buildTable(),
        ),
      ],
    );
  }

  Widget _buildTable() {
    final s = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final dayFirstColW = isMobile ? 130.0 : _dayFirstColW;
        final cols = _cols(s, dayNight: _dayNightMode, otEnabled: _otEnabled);
        final dataMin = cols.fold<double>(0, (sum, c) => sum + c.width);
        final available = constraints.maxWidth - dayFirstColW - 1;
        final scale = available > dataMin ? available / dataMin : 1.0;
        final dataWidths = cols.map((c) => c.width * scale).toList();
        final scrollWidth = dataWidths.fold<double>(0, (sum, w) => sum + w);

        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cột Nhân viên - cố định
                  SizedBox(
                    width: dayFirstColW,
                    child: Column(
                      children: [
                        _headCell(s.employee,
                            width: dayFirstColW, isFirst: true),
                        Expanded(
                          child: ListView.builder(
                            controller: _vScrollFixed,
                            physics: const ClampingScrollPhysics(),
                            itemCount: _pagedRows.length,
                            itemBuilder: (_, i) {
                              final row = _pagedRows[i];
                              final slots = _dayDisplaySlots(row);
                              final rowCount =
                                  slots.isEmpty ? 1 : slots.length;
                              final height = _dayRowHeight * rowCount;
                              return _dayEmployeeCell(row, dayFirstColW, height);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Phần data - scroll ngang
                  Expanded(
                    child: Scrollbar(
                      controller: _hScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _hScroll,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: scrollWidth,
                          child: Column(
                            children: [
                              Row(
                                children: List.generate(cols.length, (i) {
                                  return _headCell(cols[i].label,
                                      width: dataWidths[i]);
                                }),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  controller: _vScroll,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: _pagedRows.length,
                                  itemBuilder: (_, i) {
                                    final row = _pagedRows[i];
                                    final slots = _dayDisplaySlots(row);
                                    final rowCount =
                                        slots.isEmpty ? 1 : slots.length;
                                    final height = _dayRowHeight * rowCount;
                                    final bg = row.weekend
                                        ? const Color(0xFFFFF3E0)
                                        : _isToday
                                            ? const Color(0xFFE3F2FD)
                                            : Colors.white;
                                    return SizedBox(
                                      height: height,
                                      child: Column(
                                        children: [
                                          for (int si = 0;
                                              si < rowCount;
                                              si++)
                                            SizedBox(
                                              height: _dayRowHeight,
                                              child: Row(
                                                children: _daySlotCells(
                                                  row,
                                                  slots[si],
                                                  slotIndex: si,
                                                  cw: dataWidths,
                                                  bg: bg,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildPaginationBar(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaginationBar() {
    final s = AppLocalizations.of(context)!;
    final total = _rows.length;
    final totalPages = _totalPages;
    final page = _page.clamp(0, totalPages - 1);
    final first = total == 0 ? 0 : page * _pageSize + 1;
    final last = total == 0 ? 0 : ((page + 1) * _pageSize).clamp(0, total);

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(top: BorderSide(color: _gridLine)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            '${s.rowsPerPage}:',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<int>(
            initialValue: _pageSize,
            position: PopupMenuPosition.over,
            tooltip: '',
            onSelected: (value) {
              setState(() {
                _pageSize = value;
                _page = 0;
              });
            },
            itemBuilder: (_) => [10, 20, 50, 100]
                .map((n) => PopupMenuItem(
                      value: n,
                      height: 36,
                      child: Text('$n', style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: _gridLine),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_pageSize',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            '$first-$last / $total',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: s.previousPage,
          ),
          Text(
            '${page + 1} / $totalPages',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            onPressed: page < totalPages - 1
                ? () => setState(() => _page = page + 1)
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: s.nextPage,
          ),
        ],
      ),
    );
  }

  Widget _headCell(String label,
      {required double width, bool isFirst = false}) {
    return Container(
      width: width,
      height: _headHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(
          bottom: const BorderSide(color: _gridLine, width: 1.1),
          right: BorderSide(color: _gridLine, width: isFirst ? 0 : 0.8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _dayEmployeeCell(_MergedDayViewRow row, double width, double height) {
    final first = row.first;
    final bg = row.weekend
        ? const Color(0xFFFFF3E0)
        : _isToday
            ? const Color(0xFFE3F2FD)
            : Colors.white;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLine, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            first.employeeFullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              first.employeeCode,
              if (first.departmentName.isNotEmpty) first.departmentName
            ].where((e) => e.isNotEmpty).join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<DayViewRow?> _dayDisplaySlots(_MergedDayViewRow row) {
    if (row.slots.isEmpty) return [null];
    return row.slots.take(2).map((slot) => slot as DayViewRow?).toList();
  }

  List<AttendanceChangeRequest> _slotRequestsForSlot(
    _MergedDayViewRow row,
    int slotIndex, {
    required String requestType,
    String? period,
    String? scope,
  }) {
    final slot = slotIndex < row.slots.length ? row.slots[slotIndex] : null;
    final slotId = slot?.shiftAssignmentId;
    final requests = row.slots.expand((s) => s.requests).toList();
    final filtered = requests.where((r) {
      if (r.requestType != requestType) return false;
      if (period != null && (r.requestedOvertimePeriod ?? 'DAY') != period) return false;
      if (scope != null && r.requestedOvertimeScope != scope) return false;
      if (r.shiftAssignmentId == null) {
        return slotIndex == 0;
      }
      return slotId != null && r.shiftAssignmentId == slotId;
    }).toList();
    final seenIds = <int>{};
    return filtered.where((r) => seenIds.add(r.id)).toList();
  }

  Widget _dayTextCell(
    String text, {
    required double width,
    required Color bg,
    Color? color,
    VoidCallback? onTap,
    bool strikeThrough = false,
  }) {
    final child = _dayCell(
      width: width,
      bg: bg,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: strikeThrough
              ? AppTheme.textSecondary
              : color ?? (text.isEmpty || text == '-' ? AppTheme.textSecondary : AppTheme.textPrimary),
          decoration: strikeThrough ? TextDecoration.lineThrough : null,
        ),
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }

  List<Widget> _daySlotCells(
    _MergedDayViewRow row,
    DayViewRow? slot, {
    required int slotIndex,
    required List<double> cw,
    required Color bg,
  }) {
    final s = AppLocalizations.of(context)!;
    final colCount = _cols(s, dayNight: _dayNightMode, otEnabled: _otEnabled).length;
    if (slot == null) {
      return List.generate(
        colCount,
        (i) => _dayCell(width: cw[i], bg: bg, child: const SizedBox.shrink()),
      );
    }
    final checkInRequests = _slotRequestsForSlot(row, slotIndex, requestType: 'CHECK_IN');
    final checkOutRequests = _slotRequestsForSlot(row, slotIndex, requestType: 'CHECK_OUT');
    final otDayRequests = _slotRequestsForSlot(row, slotIndex, requestType: 'OT', period: 'DAY');
    final otNightRequests = _slotRequestsForSlot(row, slotIndex, requestType: 'OT', period: 'NIGHT');
    final checkInRequest = _pickVisibleRequest(checkInRequests);
    final checkOutRequest = _pickVisibleRequest(checkOutRequests);

    var idx = 0;
    final cells = <Widget>[];

    cells.add(_dayLeaveCell(
      slot.leaveRequestId,
      slot.leaveCode,
      slot.leaveMode,
      slot.leaveStatus,
      slot.leaveApplied,
      slot.leaveProcessedByName,
      slot.leaveProcessedAt,
      slot.leaveCreatedAt,
      slot.leaveAmount,
      slot.leaveFromTime,
      slot.leaveToTime,
      row.first.employeeFullName,
      row.first.departmentName,
      cw[idx++],
      bg,
      approved: slot.approved,
      leaves: slot.leaves,
    ));
    final leaveNotApplied = slot.leaveCode != null && slot.leaveApplied == false;
    final dateStr = '${slot.date.year}-${slot.date.month.toString().padLeft(2,'0')}-${slot.date.day.toString().padLeft(2,'0')}';
    cells.add(_dayShiftCellForSlot(slot, cw[idx++], bg));
    // Break
    cells.add(_inlineCell(
      key: (employeeId: slot.employeeId, date: dateStr, col: 'break'),
      displayVal: _formatBreak(slot.breakMinutes),
      overrideVal: slot.overrideBreakMinutes != null ? _formatMinutesAsTime(slot.overrideBreakMinutes!) : null,
      width: cw[idx++], bg: bg, slot: slot, isTime: false,
    ));
    // Check-in
    cells.add(_inlineCell(
      key: (employeeId: slot.employeeId, date: dateStr, col: 'checkIn'),
      displayVal: slot.checkIn ?? '',
      overrideVal: slot.overrideCheckIn,
      width: cw[idx++], bg: bg, slot: slot,
    ));
    // Check-out
    cells.add(_inlineCell(
      key: (employeeId: slot.employeeId, date: dateStr, col: 'checkOut'),
      displayVal: slot.checkOut ?? '',
      overrideVal: slot.overrideCheckOut,
      width: cw[idx++], bg: bg, slot: slot,
    ));
    cells.add(_dayRequestCell(
      _formatRequestTimeOrDuration(checkInRequest),
      checkInRequest?.status,
      width: cw[idx++],
      bg: bg,
      strikeThrough: checkInRequest != null && !checkInRequest.applied,
      onTap: checkInRequests.isNotEmpty
          ? () => _showRequestCardsDialog(context, title: s.checkInRequest, requests: checkInRequests, onToggleApplied: _setRequestApplied, attendanceApproved: slot.approved)
          : null,
    ));
    cells.add(_dayRequestCell(
      _formatRequestTimeOrDuration(checkOutRequest),
      checkOutRequest?.status,
      width: cw[idx++],
      bg: bg,
      strikeThrough: checkOutRequest != null && !checkOutRequest.applied,
      onTap: checkOutRequests.isNotEmpty
          ? () => _showRequestCardsDialog(context, title: s.checkOutRequest, requests: checkOutRequests, onToggleApplied: _setRequestApplied, attendanceApproved: slot.approved)
          : null,
    ));
    final mergedDayOt = !_otEnabled
        ? (!_dayNightMode ? [...otDayRequests, ...otNightRequests] : otDayRequests)
        : <AttendanceChangeRequest>[];
    cells.add(_dayNumCell(slot.totalHours, cw[idx++], bg, strikeThrough: leaveNotApplied));
    cells.add(_dayNumCell(
      slot.regularDayHours,
      cw[idx++],
      bg,
      highlight: mergedDayOt.isNotEmpty,
      strikeThrough: leaveNotApplied,
      onTap: mergedDayOt.isNotEmpty
          ? () => _showRequestCardsDialog(context, title: s.dayHours, requests: mergedDayOt, onToggleApplied: _setRequestApplied, attendanceApproved: slot.approved)
          : null,
    ));
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
      cells.add(_dayNumCell(
        slot.regularNightHours, cw[idx++], bg,
        highlight: mergedNightOt.isNotEmpty, strikeThrough: leaveNotApplied,
        onTap: mergedNightOt.isNotEmpty
            ? () => _showRequestCardsDialog(context, title: s.nightHours, requests: mergedNightOt, onToggleApplied: _setRequestApplied, attendanceApproved: slot.approved)
            : null,
      ));
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

  Widget _dayWorkStatusCell(DayViewRow slot, double width, Color bg) {
    final s = AppLocalizations.of(context)!;
    final flags = slot.workFlags;
    if (flags.isEmpty) {
      return _dayCell(width: width, bg: bg, child: const SizedBox.shrink());
    }
    final chips = flags.map((f) {
      final (label, color) = switch (f) {
        'LATE_IN'   => (s.lateIn,   AppTheme.error),
        'EARLY_OUT' => (s.earlyOut, AppTheme.warning),
        'ON_TIME'   => (s.onTime,   AppTheme.secondary),
        'OVERTIME'  => (s.overtime, const Color(0xFFFF9800)),
        'LEAVE'     => (s.leave,    const Color(0xFF607D8B)),
        _           => (f,          AppTheme.textSecondary),
      };
      return Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );
    }).toList();

    return _dayCell(
      width: width,
      bg: bg,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: chips),
      ),
    );
  }

  Widget _dayLeaveCell(
    int? leaveRequestId,
    String? leaveCode,
    String? leaveMode,
    String? leaveStatus,
    bool? leaveApplied,
    String? leaveProcessedByName,
    String? leaveProcessedAt,
    String? leaveCreatedAt,
    double? leaveAmount,
    String? leaveFromTime,
    String? leaveToTime,
    String employeeName,
    String departmentName,
    double width,
    Color bg, {
    bool approved = false,
    List<DayViewLeaveInfo> leaves = const [],
  }) {
    // Dùng leaves list nếu có, fallback về single leave
    final effectiveLeaves = leaves.isNotEmpty
        ? leaves
        : leaveRequestId != null
            ? [DayViewLeaveInfo(
                leaveRequestId: leaveRequestId,
                leaveCode: leaveCode,
                leaveMode: leaveMode,
                leaveStatus: leaveStatus,
                leaveApplied: leaveApplied,
                leaveProcessedByName: leaveProcessedByName,
                leaveProcessedAt: leaveProcessedAt,
                leaveCreatedAt: leaveCreatedAt,
                leaveAmount: leaveAmount,
                leaveFromTime: leaveFromTime,
                leaveToTime: leaveToTime,
              )]
            : <DayViewLeaveInfo>[];

    final isLeave = effectiveLeaves.isNotEmpty;

    // Chọn 1 leave để hiển thị: applied trước, nếu không có thì lấy cái cuối (với strike)
    DayViewLeaveInfo? visibleLeave;
    if (isLeave) {
      visibleLeave = effectiveLeaves.firstWhere(
        (l) => l.leaveApplied == true,
        orElse: () => effectiveLeaves.last,
      );
    }

    final hasAnyDayRange = effectiveLeaves.any((l) => l.leaveMode == 'DAY_RANGE');
    final effectiveBg = hasAnyDayRange && isLeave ? const Color(0xFFE8F5E9) : bg;

    Widget buildBadge(DayViewLeaveInfo l) {
      final notApplied = l.leaveApplied == false;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: notApplied
                  ? AppTheme.textSecondary.withValues(alpha: 0.1)
                  : const Color(0xFF4CAF50).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              l.leaveCode ?? '',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: notApplied ? AppTheme.textSecondary : const Color(0xFF2E7D32),
                decoration: notApplied ? TextDecoration.lineThrough : null,
                decorationColor: AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (l.leaveMode == 'HOUR_RANGE' && l.leaveFromTime != null && l.leaveToTime != null)
            Text(
              '${l.leaveFromTime}-${l.leaveToTime}',
              style: TextStyle(
                fontSize: 9,
                color: notApplied ? AppTheme.textSecondary : const Color(0xFF2E7D32),
                decoration: notApplied ? TextDecoration.lineThrough : null,
              ),
            ),
        ],
      );
    }

    final child = _dayCell(
      width: width,
      bg: effectiveBg,
      child: visibleLeave != null
          ? buildBadge(visibleLeave)
          : const SizedBox.shrink(),
    );

    if (!isLeave) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showLeaveCardsDialog(
          employeeName: employeeName,
          departmentName: departmentName,
          leaves: effectiveLeaves,
          attendanceApproved: approved,
        ),
        child: child,
      ),
    );
  }

  Future<void> _showLeaveCardsDialog({
    required String employeeName,
    required String departmentName,
    required List<DayViewLeaveInfo> leaves,
    required bool attendanceApproved,
  }) async {
    final s = AppLocalizations.of(context)!;
    // State tập trung: id nào đang applied
    final appliedIds = <int>{
      for (final l in leaves)
        if (l.leaveApplied == true) l.leaveRequestId,
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        title: Text(s.leave),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: leaves.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LeaveInfoCard(
                  leave: l,
                  appliedOverride: appliedIds.contains(l.leaveRequestId),
                  employeeName: employeeName,
                  departmentName: departmentName,
                  attendanceApproved: attendanceApproved,
                  onToggleApplied: (value) async {
                    // Nếu bật → tắt tất cả cái khác trước
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
                      if (updated) appliedIds.add(l.leaveRequestId);
                      else appliedIds.remove(l.leaveRequestId);
                    });
                    return updated;
                  },
                  onChanged: () => _loadRows(),
                ),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close)),
        ],
      ),
      ),
    );
  }

  Widget _dayShiftCellForSlot(DayViewRow? slot, double width, Color bg) {
    if (slot == null) {
      return _dayCell(width: width, bg: bg, child: const SizedBox.shrink());
    }
    Color? dotColor;
    if (slot.shiftColor != null) {
      try {
        dotColor = Color(int.parse(slot.shiftColor!.replaceAll('#', '0xFF')));
      } catch (_) {}
    }
    final shiftTitle = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                slot.shiftName ?? '',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        if ((slot.shiftStart ?? '').isNotEmpty ||
            (slot.shiftEnd ?? '').isNotEmpty)
          Text(
            _formatShiftRange(slot.shiftStart, slot.shiftEnd),
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
      ],
    );
    return _dayCell(width: width, bg: bg, child: shiftTitle);
  }

  Widget _daySlotActionCell(DayViewRow? slot, double width, Color bg) {
    final s = AppLocalizations.of(context)!;
    if (slot == null) {
      return _dayCell(width: width, bg: bg, child: const SizedBox.shrink());
    }
    final approved = slot.approved;
    final hasRecord = slot.attendanceId != null ||
        slot.checkIn != null ||
        slot.checkOut != null;

    if (approved) {
      return _dayCell(
        width: width,
        bg: bg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: slot.approvedByName != null
                  ? '${s.approved}: ${slot.approvedByName}'
                  : s.approved,
              child: const Icon(Icons.check_circle, color: AppTheme.secondary, size: 18),
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 15,
                icon: const Icon(Icons.lock_open_outlined, color: AppTheme.warning),
                tooltip: 'Bỏ phê duyệt',
                onPressed: () => _unapproveAttendance(slot),
              ),
            ),
          ],
        ),
      );
    }

    final slotKey = _daySlotKey(slot);
    final isEditing = _editingDaySlotKey == slotKey;
    return _dayCell(
      width: width,
      bg: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing) ...[
            SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.check, color: AppTheme.secondary),
                tooltip: s.save,
                onPressed: () => _saveDayEditSlot(slot),
              ),
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.close, color: AppTheme.error),
                tooltip: s.cancel,
                onPressed: _cancelDayEditSlot,
              ),
            ),
          ] else ...[
            SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                tooltip: s.edit,
                onPressed: () => _enterDayEditSlot(slot),
              ),
            ),
            if (hasRecord) ...[
              const SizedBox(width: 2),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  tooltip: s.delete,
                  onPressed: () => _confirmDelete(slot),
                ),
              ),
            ],
            const SizedBox(width: 2),
            SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.check_circle_outline, color: AppTheme.secondary),
                tooltip: s.approve,
                onPressed: () => _approveAttendance(slot),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _approveAttendance(DayViewRow slot) async {
    final s = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.approve),
        content: Text('Phê duyệt chấm công ${slot.employeeFullName} ngày ${slot.date.day}/${slot.date.month}/${slot.date.year}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.approve)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.approveAttendance(
        slot.attendanceId,
        employeeId: slot.employeeId,
        date: slot.date,
        shiftAssignmentId: slot.shiftAssignmentId,
      );
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _unapproveAttendance(DayViewRow slot) async {
    final s = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ phê duyệt'),
        content: Text('Bỏ phê duyệt chấm công ${slot.employeeFullName} ngày ${slot.date.day}/${slot.date.month}/${slot.date.year}? Dữ liệu sẽ được tính toán lại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ phê duyệt'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.unapproveAttendance(slot.attendanceId!);
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Widget _dayCell({
    required double width,
    required Color bg,
    required Widget child,
  }) {
    return Container(
      width: width,
      height: _dayRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: child,
    );
  }

  Widget _dayNumCell(double val, double width, Color bg,
      {bool highlight = false, VoidCallback? onTap, bool strikeThrough = false}) {
    final text = val > 0 ? _formatHours(val) : '';
    final child = Container(
      width: width,
      height: _dayRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight ? AppTheme.warning.withValues(alpha: 0.08) : bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: val > 0 ? FontWeight.w600 : FontWeight.normal,
          color: strikeThrough
              ? AppTheme.textSecondary
              : highlight
                  ? AppTheme.warning
                  : val > 0
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
          decoration: strikeThrough ? TextDecoration.lineThrough : null,
        ),
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }

  Widget _dayRequestCell(
    String? value,
    String? status, {
    required double width,
    required Color bg,
    bool highlight = false,
    bool strikeThrough = false,
    VoidCallback? onTap,
  }) {
    final text = value ?? '';
    final color = switch (status) {
      'APPROVED' => Colors.green,
      'REJECTED' => AppTheme.error,
      'PENDING' => AppTheme.warning,
      _ => highlight ? AppTheme.primary : AppTheme.textSecondary,
    };
    final child = Container(
      width: width,
      height: _dayRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.08) : bg,
        border: const Border(
          bottom: BorderSide(color: _gridLineLight, width: 0.9),
          right: BorderSide(color: _gridLineLight, width: 0.8),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
          color: text.isEmpty ? AppTheme.textSecondary : color,
          decoration: strikeThrough ? TextDecoration.lineThrough : null,
        ),
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }

  Widget _dayActionCell(_MergedDayViewRow row, double width, Color bg) {
    final slot = row.slots.isEmpty ? null : row.slots.first;
    if (slot == null) {
      return _dayCell(width: width, bg: bg, child: const SizedBox.shrink());
    }
    return _daySlotActionCell(slot, width, bg);
  }


  void _confirmDelete(DayViewRow row) {
    // TODO: confirm and delete attendance record
  }

  Future<void> _showRequestDetail({
    required String title,
    required List<Widget> lines,
  }) {
    return _showAttendanceInfoDialog(
      context,
      title: title,
      children: lines,
    );
  }

  String _formatBreak(int minutes) {
    if (minutes == 0) return _empty;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  String _formatShiftRange(String? start, String? end) {
    if ((start ?? '').isEmpty && (end ?? '').isEmpty) return _empty;
    if ((start ?? '').isEmpty) return end!;
    if ((end ?? '').isEmpty) return start!;
    return '$start - $end';
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final hh = totalMinutes ~/ 60;
    final mm = totalMinutes % 60;
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  List<AttendanceChangeRequest> _dayRequests(
    _MergedDayViewRow row, {
    required String requestType,
    String? period,
    String? scope,
  }) {
    final requests = row.slots.expand((slot) => slot.requests).toList();
    final filtered = requests.where((r) {
      if (r.requestType != requestType) return false;
      if (period != null && (r.requestedOvertimePeriod ?? 'DAY') != period) return false;
      if (scope != null && r.requestedOvertimeScope != scope) return false;
      if (r.shiftAssignmentId == null) return true;
      return row.slots
          .any((slot) => slot.shiftAssignmentId == r.shiftAssignmentId);
    }).toList();
    final seenIds = <int>{};
    return filtered.where((r) => seenIds.add(r.id)).toList();
  }

  String? _slotRequestSummary(_MergedDayViewRow row,
      {required String requestType, String? period, String? scope}) {
    final requests = _dayRequests(row,
        requestType: requestType, period: period, scope: scope);
    final first = _pickVisibleRequest(requests);
    if (first == null) return null;
    return switch (requestType) {
      'CHECK_IN' => first.requestedCheckIn,
      'CHECK_OUT' => first.requestedCheckOut,
      'OT' => first.requestedOvertimeMinutes != null
          ? _formatHours(first.requestedOvertimeMinutes! / 60.0)
          : null,
      _ => null,
    };
  }

  String? _slotRequestStatus(_MergedDayViewRow row,
      {required String requestType, String? period, String? scope}) {
    final requests = _dayRequests(row,
        requestType: requestType, period: period, scope: scope);
    final first = _pickVisibleRequest(requests);
    return first?.status;
  }

  Color? _dayCheckInColor(DayViewRow? row) {
    if (row == null) return null;
    if (row.status == AttendanceStatus.late) return AppTheme.warning;
    if (row.checkIn != null) return Colors.green;
    return null;
  }

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
    final aId = a.shiftAssignmentId ?? 0;
    final bId = b.shiftAssignmentId ?? 0;
    return aId.compareTo(bId);
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
}

class _LeaveInfoCard extends StatefulWidget {
  final DayViewLeaveInfo leave;
  final bool? appliedOverride;
  final String employeeName;
  final String departmentName;
  final bool attendanceApproved;
  final Future<bool> Function(bool) onToggleApplied;
  final VoidCallback onChanged;

  const _LeaveInfoCard({
    required this.leave,
    this.appliedOverride,
    required this.employeeName,
    required this.departmentName,
    required this.attendanceApproved,
    required this.onToggleApplied,
    required this.onChanged,
  });

  @override
  State<_LeaveInfoCard> createState() => _LeaveInfoCardState();
}

class _LeaveInfoCardState extends State<_LeaveInfoCard> {
  late bool _applied;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _applied = widget.appliedOverride ?? widget.leave.leaveApplied ?? true;
  }

  @override
  void didUpdateWidget(_LeaveInfoCard old) {
    super.didUpdateWidget(old);
    if (widget.appliedOverride != old.appliedOverride && widget.appliedOverride != null) {
      _applied = widget.appliedOverride!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final l = widget.leave;
    final status = l.leaveStatus ?? 'APPROVED';
    final modeText = l.leaveMode == 'HOUR_RANGE' ? s.leaveByHour : s.leaveByDay;
    final valueText = l.leaveMode == 'HOUR_RANGE' && l.leaveFromTime != null && l.leaveToTime != null
        ? '${l.leaveFromTime} - ${l.leaveToTime}'
        : s.leaveAllDay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gridLineLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.leaveCode == null ? s.leave : '${s.leave} (${l.leaveCode})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text('${widget.employeeName} • ${widget.departmentName}',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              _requestStatusBadge(s, status),
              const SizedBox(width: 8),
              Text(s.apply, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(width: 4),
              Transform.scale(
                scale: 0.72,
                child: Switch.adaptive(
                  value: _applied,
                  onChanged: _updating || (widget.attendanceApproved && _applied)
                      ? null
                      : (value) async {
                          setState(() => _updating = true);
                          try {
                            final updated = await widget.onToggleApplied(value);
                            if (mounted) setState(() => _applied = updated);
                            widget.onChanged();
                          } catch (_) {
                          } finally {
                            if (mounted) setState(() => _updating = false);
                          }
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _detailLine('ID', '#${l.leaveRequestId}'),
          _detailLine(s.employee, widget.employeeName),
          if (l.leaveCreatedAt != null)
            _detailLine(s.createdAt, _formatRequestDateTime(l.leaveCreatedAt!)),
          _detailLine(s.requestType, modeText),
          _detailLine(s.requestedTime, valueText, valueColor: AppTheme.primary),
          if (l.leaveProcessedByName != null && l.leaveProcessedAt != null)
            _detailLine(s.approvedBy,
                '${l.leaveProcessedByName} • ${_formatRequestDateTime(l.leaveProcessedAt!)}'),
        ],
      ),
    );
  }
}

// ── Override result ───────────────────────────────────────────────────────────

class _OverrideResult {
  final bool clear;
  final String? checkIn;
  final String? checkOut;
  final int? breakMinutes;
  final int? otDayMinutes;
  final int? otNightMinutes;
  final String? note;

  const _OverrideResult({
    this.clear = false,
    this.checkIn,
    this.checkOut,
    this.breakMinutes,
    this.otDayMinutes,
    this.otNightMinutes,
    this.note,
  });
}

// ── Override dialog ───────────────────────────────────────────────────────────

class _OverrideDialog extends StatefulWidget {
  final TimesheetRow row;
  final AppLocalizations s;
  const _OverrideDialog({required this.row, required this.s});

  @override
  State<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends State<_OverrideDialog> {
  late final TextEditingController _checkIn;
  late final TextEditingController _checkOut;
  late final TextEditingController _break;
  late final TextEditingController _otDay;
  late final TextEditingController _otNight;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _checkIn  = TextEditingController(text: r.checkIn  ?? '');
    _checkOut = TextEditingController(text: r.checkOut ?? '');
    _break    = TextEditingController(text: r.breakMinutes > 0 ? r.breakMinutes.toString() : '');
    _otDay    = TextEditingController(text: r.otDayHours   > 0 ? (r.otDayHours   * 60).round().toString() : '');
    _otNight  = TextEditingController(text: r.otNightHours > 0 ? (r.otNightHours * 60).round().toString() : '');
    _note     = TextEditingController();
  }

  @override
  void dispose() {
    _checkIn.dispose(); _checkOut.dispose(); _break.dispose();
    _otDay.dispose(); _otNight.dispose(); _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController ctrl, String label) async {
    final parts = ctrl.text.split(':');
    final init = parts.length == 2
        ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 8, minute: 0);
    final t = await showTimePicker(
      context: context,
      initialTime: init,
      helpText: label,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) {
      ctrl.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final row = widget.row;
    final date = '${row.date.day}/${row.date.month}/${row.date.year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(s.adminOverrideTitle,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(date, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
              const SizedBox(height: 4),
              Text(s.adminOverrideHint,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),

              // Check-in / Check-out
              Row(children: [
                Expanded(child: _TimeTile(label: s.checkIn, ctrl: _checkIn,
                    onTap: () => _pickTime(_checkIn, s.checkIn))),
                const SizedBox(width: 12),
                Expanded(child: _TimeTile(label: s.checkOut, ctrl: _checkOut,
                    onTap: () => _pickTime(_checkOut, s.checkOut))),
              ]),
              const SizedBox(height: 12),

              // Break / OT Day / OT Night
              Row(children: [
                Expanded(child: _MinTile(label: s.adminOverrideBreak, ctrl: _break)),
                const SizedBox(width: 8),
                Expanded(child: _MinTile(label: s.adminOverrideOtDay, ctrl: _otDay)),
                const SizedBox(width: 8),
                Expanded(child: _MinTile(label: s.adminOverrideOtNight, ctrl: _otNight)),
              ]),
              const SizedBox(height: 12),

              TextField(
                controller: _note,
                decoration: InputDecoration(
                    labelText: s.adminOverrideNote, isDense: true,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              Row(children: [
                if (row.attendanceId != null)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context,
                        const _OverrideResult(clear: true)),
                    icon: const Icon(Icons.clear, size: 14, color: AppTheme.error),
                    label: Text(s.adminOverrideClear,
                        style: const TextStyle(color: AppTheme.error, fontSize: 12)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                  ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _OverrideResult(
                    checkIn:      _checkIn.text.trim().isEmpty  ? null : _checkIn.text.trim(),
                    checkOut:     _checkOut.text.trim().isEmpty ? null : _checkOut.text.trim(),
                    breakMinutes: int.tryParse(_break.text.trim()),
                    otDayMinutes: int.tryParse(_otDay.text.trim()),
                    otNightMinutes: int.tryParse(_otNight.text.trim()),
                    note:         _note.text.trim().isEmpty ? null : _note.text.trim(),
                  )),
                  child: Text(s.save),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.ctrl, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: TextField(
      controller: ctrl,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.access_time, size: 16),
      ),
    ),
  );
}

class _MinTile extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _MinTile({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
  );
}
