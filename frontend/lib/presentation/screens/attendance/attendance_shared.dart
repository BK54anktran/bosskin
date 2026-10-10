import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/attendance.dart';
import '../../widgets/status_badge.dart';
import '../../../data/models/department_model.dart';
import 'package:bosskin/l10n/app_localizations.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AttViewRangeMode { payroll, week, custom }

// ── Column definition ─────────────────────────────────────────────────────────

class AttCol {
  final String label;
  final double width;
  const AttCol(this.label, this.width);
}

List<AttCol> attCols(AppLocalizations s, {bool dayNight = true, bool otEnabled = true}) {
  return [
    AttCol(s.leave, 90),
    AttCol(s.shift, 120),
    AttCol(s.breakTime, 70),
    AttCol(s.checkIn, 72),
    AttCol(s.checkOut, 72),
    AttCol(s.checkInRequest, 86),
    AttCol(s.checkOutRequest, 86),
    AttCol(s.totalTime, 72),
    AttCol(s.dayHours, 78),
    if (otEnabled) AttCol(s.dayOT, 78),
    if (dayNight) AttCol(s.nightHours, 78),
    if (dayNight && otEnabled) AttCol(s.nightOT, 78),
    AttCol(s.workStatus, 140),
    AttCol(s.action, 68),
  ];
}

// ── Shared layout constants (public so tab files can use them) ────────────────

const double attDateColW    = 72;
const double attRowHeight   = 48;
const double attDayFirstColW = 190;
const double attDayRowHeight = 72;
const double attHeadHeight  = 52;
const String attEmpty       = '';
Color get attGridLine => AppTheme.border;
Color get attGridLineLight => AppTheme.border;

// ── Merged row models (public so tab files can use them) ──────────────────────

class AttMergedDayViewRow {
  final List<DayViewRow> slots;
  const AttMergedDayViewRow(this.slots);

  DayViewRow get first => slots.first;
  bool get weekend => first.weekend;
  String? get holidayName => first.holidayName;
}

class AttMergedTimesheetRow {
  final List<TimesheetRow> rows;
  const AttMergedTimesheetRow(this.rows);

  TimesheetRow get first => rows.first;
  bool get weekend => first.weekend;
  String? get holidayName => first.holidayName;
}

// ── Top-level parse helpers (public) ─────────────────────────────────────────

String? parseAttendanceTime(String raw) {
  final d = raw.replaceAll(RegExp(r'[:\s]'), '');
  int? h, m;
  if (d.length == 1 || d.length == 2) {
    h = int.tryParse(d); m = 0;
  } else if (d.length == 3) {
    h = int.tryParse(d.substring(0, 1)); m = int.tryParse(d.substring(1));
  } else if (d.length == 4) {
    h = int.tryParse(d.substring(0, 2)); m = int.tryParse(d.substring(2));
  } else {
    final p = raw.split(':');
    if (p.length == 2) { h = int.tryParse(p[0].trim()); m = int.tryParse(p[1].trim()); }
  }
  if (h == null || m == null || h > 23 || m > 59) return null;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

int? parseAttendanceDuration(String raw) {
  final t = parseAttendanceTime(raw);
  if (t == null) return null;
  final p = t.split(':');
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String formatAttendanceMinutes(int minutes) {
  final hh = (minutes ~/ 60).toString().padLeft(2, '0');
  final mm = (minutes % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}

Set<int> expandedDepartmentScopeIds(
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

// ── Public shared helper functions used across tab files ──────────────────────

List<AttendanceChangeRequest> attMatchingRequests(
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

AttendanceChangeRequest? attPickVisibleRequest(
  List<AttendanceChangeRequest> requests,
) {
  final approved = requests.where((r) => r.status == 'APPROVED').toList();
  if (approved.isEmpty) return null;
  approved.sort((a, b) {
    if (a.applied != b.applied) {
      return a.applied ? -1 : 1;
    }
    final aTime = DateTime.tryParse(a.updatedAt ?? a.processedAt ?? a.createdAt ?? '');
    final bTime = DateTime.tryParse(b.updatedAt ?? b.processedAt ?? b.createdAt ?? '');
    final timeCmp = (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
    if (timeCmp != 0) return timeCmp;
    return b.id.compareTo(a.id);
  });
  return approved.first;
}

String attFormatRequestTimeOrDuration(AttendanceChangeRequest? req) {
  if (req == null) return attEmpty;
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

Future<void> showAttRequestCardsDialog(
  BuildContext context, {
  required String title,
  required List<AttendanceChangeRequest> requests,
  required Future<AttendanceChangeRequest> Function(int id, bool applied) onToggleApplied,
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
      final s = AppLocalizations.of(context);
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
                  ? Text(s.noApprovedRequests,
                      style: TextStyle(color: AppTheme.textSecondary))
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < visibleRequests.length; i++) ...[
                            _AttRequestInfoCard(
                              s: s,
                              req: visibleRequests[i],
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

Future<void> showAttLeaveRequestCardDialog(
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
      final s = AppLocalizations.of(context);
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
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: attGridLineLight),
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
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 3),
                              Text('$employeeName • $departmentName',
                                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        attRequestStatusBadge(s, status),
                        const SizedBox(width: 8),
                        Text(s.apply,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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
                                      if (context.mounted) setDialogState(() => updating = false);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    attDetailLine('ID', '#$requestId'),
                    attDetailLine(s.employee, employeeName),
                    attDetailLine(s.createdAt, createdAt != null ? _formatRequestDateTime(createdAt) : '-'),
                    attDetailLine(s.requestType, modeText),
                    attDetailLine(s.requestedTime, valueText, valueColor: AppTheme.primary, strikeThrough: !currentApplied),
                    attDetailLine(
                      _attRequestActionLabel(s, status),
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

Future<void> showAttInfoDialog(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) async {
  final s = AppLocalizations.of(context);
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.close)),
      ],
    ),
  );
}

// ── Public helper widgets / functions used across tabs ────────────────────────

Widget attDetailLine(String label, String value, {Color? valueColor, bool strikeThrough = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: RichText(
      text: TextSpan(
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
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

Widget attRequestStatusBadge(AppLocalizations s, String status) {
  final color = _attRequestStatusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      _attRequestStatusLabel(s, status),
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

// ── Shared edit cell widget ───────────────────────────────────────────────────

class AttEditTimeCell extends StatefulWidget {
  final TextEditingController ctrl;
  final double width;
  final double height;
  final bool isTime;
  final Color bg;

  const AttEditTimeCell({
    super.key,
    required this.ctrl,
    required this.width,
    required this.height,
    required this.bg,
    this.isTime = true,
  });

  @override
  State<AttEditTimeCell> createState() => _AttEditTimeCellState();
}

class _AttEditTimeCellState extends State<AttEditTimeCell> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus) return;
    final raw = widget.ctrl.text.trim();
    if (raw.isEmpty) return;
    final formatted = parseAttendanceTime(raw);
    if (formatted != null && formatted != widget.ctrl.text) {
      widget.ctrl.text = formatted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.bg,
        border: Border(
          bottom: BorderSide(color: attGridLineLight, width: 0.9),
          right: BorderSide(color: attGridLineLight, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: ListenableBuilder(
        listenable: widget.ctrl,
        builder: (context, _) => TextField(
          controller: widget.ctrl,
          focusNode: _focus,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppTheme.primary),
          keyboardType: TextInputType.datetime,
          maxLength: 5,
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: attGridLine, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: attGridLine, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            counterText: '',
            hintText: 'HH:MM',
            hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            suffixIcon: widget.ctrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () => widget.ctrl.clear(),
                    child: Icon(Icons.close, size: 13, color: AppTheme.textSecondary),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          ),
        ),
      ),
    );
  }
}

// ── Leave info card (used in day tab dialog) ──────────────────────────────────

class AttLeaveInfoCard extends StatefulWidget {
  final DayViewLeaveInfo leave;
  final bool? appliedOverride;
  final String employeeName;
  final String departmentName;
  final bool attendanceApproved;
  final Future<bool> Function(bool) onToggleApplied;
  final VoidCallback onChanged;

  const AttLeaveInfoCard({
    super.key,
    required this.leave,
    this.appliedOverride,
    required this.employeeName,
    required this.departmentName,
    required this.attendanceApproved,
    required this.onToggleApplied,
    required this.onChanged,
  });

  @override
  State<AttLeaveInfoCard> createState() => _AttLeaveInfoCardState();
}

class _AttLeaveInfoCardState extends State<AttLeaveInfoCard> {
  late bool _applied;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _applied = widget.appliedOverride ?? widget.leave.leaveApplied ?? true;
  }

  @override
  void didUpdateWidget(AttLeaveInfoCard old) {
    super.didUpdateWidget(old);
    if (widget.appliedOverride != old.appliedOverride && widget.appliedOverride != null) {
      _applied = widget.appliedOverride!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
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
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: attGridLineLight),
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text('${widget.employeeName} • ${widget.departmentName}',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              attRequestStatusBadge(s, status),
              const SizedBox(width: 8),
              Text(s.apply, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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
          attDetailLine('ID', '#${l.leaveRequestId}'),
          attDetailLine(s.employee, widget.employeeName),
          if (l.leaveCreatedAt != null)
            attDetailLine(s.createdAt, _formatRequestDateTime(l.leaveCreatedAt!)),
          attDetailLine(s.requestType, modeText),
          attDetailLine(s.requestedTime, valueText, valueColor: AppTheme.primary),
          if (l.leaveProcessedByName != null && l.leaveProcessedAt != null)
            attDetailLine(s.approvedBy,
                '${l.leaveProcessedByName} • ${_formatRequestDateTime(l.leaveProcessedAt!)}'),
        ],
      ),
    );
  }
}

// ── Private helpers (only used within this file) ──────────────────────────────

String _attRequestStatusLabel(AppLocalizations s, String? status) {
  return switch (status) {
    'APPROVED' => s.approved,
    'REJECTED' => s.reject,
    'PENDING' => s.pending,
    'CANCELLED' => s.cancelled,
    _ => s.unknown,
  };
}

Color _attRequestStatusColor(String status) {
  return switch (status) {
    'APPROVED' => Colors.green,
    'REJECTED' => AppTheme.error,
    'PENDING' => AppTheme.warning,
    'CANCELLED' => AppTheme.textSecondary,
    _ => AppTheme.textSecondary,
  };
}

String _attRequestActionLabel(AppLocalizations s, String status) {
  return switch (status) {
    'APPROVED' => s.approvedBy,
    'REJECTED' => s.rejectedBy,
    'CANCELLED' => s.cancelledBy,
    _ => s.processingBy,
  };
}

String _attPeriodLabel(AppLocalizations s, String? period) {
  return switch (period ?? 'DAY') {
    'DAY' => s.day,
    'NIGHT' => s.night,
    _ => s.day,
  };
}

String _attScopeLabel(AppLocalizations s, String? scope) {
  return switch (scope) {
    'IN_SHIFT' => s.insideShift,
    'OUTSIDE_SHIFT' => s.outsideShift,
    _ => s.unknown,
  };
}

String attRequestTypeLabel(AppLocalizations s, String? type) {
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

// ── Private widget: request info card (used inside showAttRequestCardsDialog) ─

class _AttRequestInfoCard extends StatelessWidget {
  final AppLocalizations s;
  final AttendanceChangeRequest req;
  final ValueChanged<bool>? onAppliedChanged;
  final bool appliedControlEnabled;

  const _AttRequestInfoCard({
    required this.s,
    required this.req,
    this.onAppliedChanged,
    this.appliedControlEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (req.requestType) {
      'OT' => '${s.overtime} ${_attPeriodLabel(s, req.requestedOvertimePeriod)}',
      'EXTRA' => '${s.extraHours} ${_attPeriodLabel(s, req.requestedOvertimePeriod)}',
      _ => attRequestTypeLabel(s, req.requestType),
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
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: attGridLineLight),
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
                    Text(title,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text('${req.employeeName} • ${req.departmentName}',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                    if (StatusBadge.managerStep(s,
                            awaitingManagerName: req.awaitingManagerName,
                            managerApprovedByName: req.managerApprovedByName) case final badge?)
                      Padding(padding: const EdgeInsets.only(top: 4), child: badge),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  attRequestStatusBadge(s, req.status),
                  if (req.status == 'APPROVED') ...[
                    const SizedBox(width: 8),
                    Text(s.apply,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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
          attDetailLine(s.date, _formatRequestDate(req.requestDate)),
          attDetailLine(
            req.requestType == 'OT'
                ? '${s.overtime} (${_attPeriodLabel(s, req.requestedOvertimePeriod)} • ${_attScopeLabel(s, req.requestedOvertimeScope)})'
                : req.requestType == 'EXTRA'
                    ? '${s.extraHours} (${_attPeriodLabel(s, req.requestedOvertimePeriod)})'
                    : attRequestTypeLabel(s, req.requestType),
            mainValue,
            valueColor: AppTheme.primary,
            strikeThrough: !req.applied,
          ),
          attDetailLine(s.createdAt, _formatRequestDateTime(req.createdAt)),
          attDetailLine(s.note,
              (req.note == null || req.note!.trim().isEmpty) ? '-' : req.note!.trim()),
          attDetailLine(
            _attRequestActionLabel(s, req.status),
            req.processedByName != null && req.processedAt != null
                ? '${req.processedByName} • ${_formatRequestDateTime(req.processedAt)}'
                : '-',
          ),
          attDetailLine(s.response,
              (req.adminNote == null || req.adminNote!.trim().isEmpty) ? '-' : req.adminNote!.trim()),
        ],
      ),
    );
  }
}
