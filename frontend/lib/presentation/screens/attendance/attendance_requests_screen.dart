import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/utils/attendance_message_utils.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/department_model.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/company_setting_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/department_service.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/search_text_field.dart';

class AttendanceRequestsScreen extends StatefulWidget {
  const AttendanceRequestsScreen({super.key});

  @override
  State<AttendanceRequestsScreen> createState() =>
      _AttendanceRequestsScreenState();
}

class _AttendanceRequestsScreenState extends State<AttendanceRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AttendanceRepository();
  final _settingRepo = CompanySettingRepository();
  late final TabController _tabs;

  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _checkInCtrl = TextEditingController();
  final _checkOutCtrl = TextEditingController();
  final _otCtrl = TextEditingController();
  String _filterType = 'ALL';
  DateTime? _filterFrom;
  DateTime? _filterTo;
  bool _loading = true;
  final bool _submitting = false;
  bool _acting = false;
  String? _error;
  List<DepartmentFlat> _depts = [];
  int? _filterDept;
  List<AttendanceChangeRequest> _pending = [];
  List<AttendanceChangeRequest> _resolved = [];
  bool _otEnabled = true;

  bool get _canApprove {
    final user = AuthService.instance.currentUser;
    if (user == null) return false;
    return user.isSystemAdmin || user.can('ATTENDANCE_REQUEST_APPROVE');
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, animationDuration: Duration.zero);
    _loadDepartments();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    _checkInCtrl.dispose();
    _checkOutCtrl.dispose();
    _otCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts =
          await DepartmentService.instance.getFlat(permission: 'ATTENDANCE_VIEW');
      if (!mounted) return;
      setState(() => _depts = depts);
    } catch (_) {}
    try {
      final settings = await _settingRepo.get();
      final att = settings['attendance'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _otEnabled = att['otEnabled'] != false;
          if (!_otEnabled && _filterType == 'OT') _filterType = 'ALL';
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _repo.getRequests(departmentId: _filterDept);
      if (!mounted) return;
      setState(() {
        _pending = all.where((r) => r.status == 'PENDING').toList();
        _resolved = all.where((r) => r.status != 'PENDING').toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateRequestDialog() async {
    final s = AppLocalizations.of(context);
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _CreateRequestDialog(otEnabled: _otEnabled),
    );
    if (created == true && mounted) {
      _showSnack(s.requestSent, success: true);
      await _load();
    }
  }

  Future<void> _approve(AttendanceChangeRequest req) async {
    final s = AppLocalizations.of(context);
    await _runAction(() => _repo.approveRequest(req.id), s.approved);
  }

  Future<void> _cancel(AttendanceChangeRequest req) async {
    final s = AppLocalizations.of(context);
    await _runAction(() => _repo.cancelRequest(req.id), s.cancelled);
  }

  Future<void> _reject(AttendanceChangeRequest req) async {
    final s = AppLocalizations.of(context);
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.rejectRequest),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: s.reason,
            hintText: s.enterRejectionReason,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, noteCtrl.text.trim()),
            child: Text(s.reject),
          ),
        ],
      ),
    );
    if (note == null) return;
    await _runAction(
      () => _repo.rejectRequest(req.id, adminNote: note.isEmpty ? null : note),
      s.rejected,
    );
  }

  Future<void> _runAction(
    Future<AttendanceChangeRequest> Function() action,
    String success,
  ) async {
    setState(() => _acting = true);
    try {
      await action();
      if (!mounted) return;
      _showSnack(success, success: true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack(serverMsg(e), success: false);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppTheme.secondary : AppTheme.error,
      ),
    );
  }

  Future<void> _pickFilterDate(bool isFrom) async {
    final current = isFrom ? _filterFrom : _filterTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _filterFrom = picked;
      } else {
        _filterTo = picked;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _filterType = 'ALL';
      _filterFrom = null;
      _filterTo = null;
      _filterDept = null;
    });
    _load();
  }

  List<AttendanceChangeRequest> _applyFilters(
    List<AttendanceChangeRequest> items,
  ) {
    final s = AppLocalizations.of(context);
    final q = foldSearchText(_searchCtrl.text);
    final from = _filterFrom == null
        ? null
        : DateTime(_filterFrom!.year, _filterFrom!.month, _filterFrom!.day);
    final to = _filterTo == null
        ? null
        : DateTime(_filterTo!.year, _filterTo!.month, _filterTo!.day);

    return items.where((r) {
      if (_filterType != 'ALL' && r.requestType != _filterType) return false;

      if (from != null || to != null) {
        final requestDate = DateTime.tryParse(r.requestDate);
        if (requestDate != null) {
          final d = DateTime(
            requestDate.year,
            requestDate.month,
            requestDate.day,
          );
          if (from != null && d.isBefore(from)) return false;
          if (to != null && d.isAfter(to)) return false;
        }
      }

      if (q.isEmpty) return true;
      final haystack = foldSearchText([
        r.employeeCode,
        r.employeeName,
        r.departmentName,
        r.requestDate,
        _requestTypeLabel(s, r.requestType),
        _periodLabel(s, r.requestedOvertimePeriod),
        _scopeLabel(s, r.requestedOvertimeScope),
        r.note ?? '',
        r.adminNote ?? '',
        r.processedByName ?? '',
        r.status,
      ].join(' '));
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isImpersonating = AuthService.instance.isImpersonating;
    final pending = _applyFilters(_pending);
    final resolved = _applyFilters(_resolved);
    final currentEmployeeId = AuthService.instance.currentUser?.employeeId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        if (!isImpersonating)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Spacer(),
                FilledButton.icon(
                  onPressed: _openCreateRequestDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(s.createRequest),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        // ── Body ──
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
              ),
              child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
            ),
          )
        else if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _FilterPanel(
                        searchCtrl: _searchCtrl,
                        filterType: _filterType,
                        filterFrom: _filterFrom,
                        filterTo: _filterTo,
                        departments: _depts,
                        filterDepartmentId: _filterDept,
                        otEnabled: _otEnabled,
                        onSearchChanged: (_) => setState(() {}),
                        onTypeChanged: (v) => setState(() => _filterType = v),
                        onPickFrom: () => _pickFilterDate(true),
                        onPickTo: () => _pickFilterDate(false),
                        onDepartmentChanged: (v) async {
                          setState(() => _filterDept = v);
                          await _load();
                        },
                        onClear: _clearFilters,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabs,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(s.pendingTab),
                                if (pending.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  _Badge(pending.length),
                                ],
                              ],
                            ),
                          ),
                          Tab(text: s.processedTab),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _RequestList(
                            requests: pending,
                            canApprove: _canApprove,
                            acting: _acting,
                            currentEmployeeId: currentEmployeeId,
                            onApprove: _approve,
                            onReject: _reject,
                            onCancel: _cancel,
                            emptyMessage: s.noPendingRequests,
                          ),
                          _RequestList(
                            requests: resolved,
                            canApprove: false,
                            acting: _acting,
                            currentEmployeeId: currentEmployeeId,
                            emptyMessage: s.noProcessedRequests,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
      ],
    );
  }
}

class _CreateRequestDialog extends StatefulWidget {
  final bool otEnabled;
  const _CreateRequestDialog({this.otEnabled = true});

  @override
  State<_CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<_CreateRequestDialog> {
  final _repo = AttendanceRepository();
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  final _checkInCtrl = TextEditingController();
  final _checkOutCtrl = TextEditingController();
  final _otCtrl = TextEditingController();

  DateTime _requestDate = DateTime.now();
  String _type = 'CHECK_IN_OUT';
  String _otScope = 'IN_SHIFT';
  String _otPeriod = 'DAY';
  String _extraPeriod = 'DAY';
  int? _shiftAssignmentId;
  SelfTodayAttendance? _requestDayInfo;
  bool _loadingRequestDayInfo = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadRequestDayInfo();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _checkInCtrl.dispose();
    _checkOutCtrl.dispose();
    _otCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _requestDate = picked;
      _requestDayInfo = null;
      _loadingRequestDayInfo = true;
      _shiftAssignmentId = null;
    });
    await _loadRequestDayInfo();
  }

  Future<void> _loadRequestDayInfo() async {
    try {
      final info = await _repo.getSelfToday(date: _requestDate);
      if (!mounted) return;
      setState(() {
        _requestDayInfo = info;
        final shifts = info.shifts;
        if (shifts.isNotEmpty) {
          final ids = shifts.map((s) => s.id).whereType<int>().toList();
          if (ids.isNotEmpty) {
            _shiftAssignmentId ??= ids.first;
            if (!ids.contains(_shiftAssignmentId)) {
              _shiftAssignmentId = ids.first;
            }
          }
        } else {
          _shiftAssignmentId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requestDayInfo = null;
        _shiftAssignmentId = null;
      });
    } finally {
      if (mounted) setState(() => _loadingRequestDayInfo = false);
    }
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (picked == null) return;
    ctrl.text = _formatTimeOfDay(picked);
    setState(() {});
  }

  Future<void> _showDayInfo() async {
    final s = AppLocalizations.of(context);
    final info = _requestDayInfo;
    final dateLabel = DateFormat(
            'EEEE, dd/MM/yyyy', Localizations.localeOf(context).toLanguageTag())
        .format(_requestDate);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.dayShifts),
        content: SizedBox(
          width: 360,
          child: _loadingRequestDayInfo
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (info?.shift != null) ...[
                      Text(
                        info!.shift!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${info.shift!.startTime} - ${info.shift!.endTime}'),
                      const SizedBox(height: 8),
                      Text(
                          '${s.checkInTime}: ${info.shift!.checkInFrom} - ${info.shift!.checkInTo}'),
                      Text(
                          '${s.checkOutTime}: ${info.shift!.checkOutFrom} - ${info.shift!.checkOutTo}'),
                    ] else ...[
                      Text(
                        attendanceMessage(s, info?.message),
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
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

  Future<bool> _submit() async {
    final s = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    final shifts = _requestDayInfo?.shifts ?? const [];
    final effectiveShiftId = shifts.length > 1
        ? (_shiftAssignmentId ?? shifts.first.id)
        : _shiftAssignmentId;
    if (shifts.length > 1 && effectiveShiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.pleaseChooseShift),
          backgroundColor: AppTheme.error,
        ),
      );
      return false;
    }
    setState(() => _submitting = true);
    try {
      await _repo.createRequest(
        date: _requestDate,
        type: _type,
        shiftAssignmentId: effectiveShiftId,
        requestedCheckIn: _type == 'CHECK_IN_OUT' && _checkInCtrl.text.trim().isNotEmpty ? _checkInCtrl.text.trim() : null,
        requestedCheckOut: _type == 'CHECK_IN_OUT' && _checkOutCtrl.text.trim().isNotEmpty ? _checkOutCtrl.text.trim() : null,
        requestedOvertimeMinutes: (_type == 'OT' || _type == 'EXTRA')
            ? _parseDurationMinutes(_otCtrl.text.trim(), s)
            : null,
        requestedOvertimeScope: _type == 'OT' ? _otScope : null,
        requestedOvertimePeriod: _type == 'OT'
            ? _otPeriod
            : _type == 'EXTRA'
                ? _extraPeriod
                : null,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return false;
      Navigator.of(context).pop(true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(serverMsg(e)),
          backgroundColor: AppTheme.error,
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _onTypeChanged(String v) {
    setState(() {
      _type = v;
      if (v != 'CHECK_IN_OUT') {
        _checkInCtrl.clear();
        _checkOutCtrl.clear();
      }
      if (v != 'OT' && v != 'EXTRA') {
        _otCtrl.clear();
        _otScope = 'IN_SHIFT';
        _otPeriod = 'DAY';
        _extraPeriod = 'DAY';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: _RequestForm(
            formKey: _formKey,
            requestDate: _requestDate,
            dayInfo: _requestDayInfo,
            loadingDayInfo: _loadingRequestDayInfo,
            type: _type,
            otEnabled: widget.otEnabled,
            otScope: _otScope,
            otPeriod: _otPeriod,
            extraPeriod: _extraPeriod,
            shiftAssignmentId: _shiftAssignmentId,
            checkInCtrl: _checkInCtrl,
            checkOutCtrl: _checkOutCtrl,
            otCtrl: _otCtrl,
            noteCtrl: _noteCtrl,
            submitting: _submitting,
            onPickDate: _pickDate,
            onPickTime: _pickTime,
            onTypeChanged: _onTypeChanged,
            onShiftChanged: (v) => setState(() => _shiftAssignmentId = v),
            onOtScopeChanged: (v) {
              if (v == null) return;
              setState(() => _otScope = v);
            },
            onOtPeriodChanged: (v) {
              if (v == null) return;
              setState(() => _otPeriod = v);
            },
            onExtraPeriodChanged: (v) {
              if (v == null) return;
              setState(() => _extraPeriod = v);
            },
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

class _RequestForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final DateTime requestDate;
  final SelfTodayAttendance? dayInfo;
  final bool loadingDayInfo;
  final String type;
  final bool otEnabled;
  final String otScope;
  final String otPeriod;
  final String extraPeriod;
  final int? shiftAssignmentId;
  final TextEditingController checkInCtrl;
  final TextEditingController checkOutCtrl;
  final TextEditingController otCtrl;
  final TextEditingController noteCtrl;
  final bool submitting;
  final VoidCallback onPickDate;
  final Future<void> Function(TextEditingController) onPickTime;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int?> onShiftChanged;
  final ValueChanged<String?> onOtScopeChanged;
  final ValueChanged<String?> onOtPeriodChanged;
  final ValueChanged<String?> onExtraPeriodChanged;
  final VoidCallback onSubmit;

  const _RequestForm({
    required this.formKey,
    required this.requestDate,
    required this.dayInfo,
    required this.loadingDayInfo,
    required this.type,
    this.otEnabled = true,
    required this.otScope,
    required this.otPeriod,
    required this.extraPeriod,
    required this.shiftAssignmentId,
    required this.checkInCtrl,
    required this.checkOutCtrl,
    required this.otCtrl,
    required this.noteCtrl,
    required this.submitting,
    required this.onPickDate,
    required this.onPickTime,
    required this.onTypeChanged,
    required this.onShiftChanged,
    required this.onOtScopeChanged,
    required this.onOtPeriodChanged,
    required this.onExtraPeriodChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final dateLabel = DateFormat('EEEE, dd/MM/yyyy', 'vi').format(requestDate);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.createAttendanceRequestTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        color: AppTheme.primary, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _DayShiftsSection(
              dayInfo: dayInfo,
              loading: loadingDayInfo,
            ),
            const SizedBox(height: 12),
            if ((dayInfo?.shifts.length ?? 0) > 1) ...[
              Builder(
                builder: (_) {
                  final shifts = dayInfo?.shifts ?? const [];
                  final selectedShiftId = shiftAssignmentId ??
                      (shifts.isNotEmpty ? shifts.first.id : null);
                  return DropdownButtonFormField<int>(
                    initialValue: selectedShiftId,
                    decoration: InputDecoration(
                      labelText: s.chooseShiftApply,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      ...?dayInfo?.shifts.map(
                        (shift) => DropdownMenuItem<int>(
                          value: shift.id,
                          child: Text(
                            '${shift.name} • ${shift.startTime} - ${shift.endTime}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: onShiftChanged,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: InputDecoration(
                labelText: s.requestType,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'CHECK_IN_OUT',
                  child: Text(s.checkInOut),
                ),
                if (otEnabled)
                  DropdownMenuItem(
                    value: 'OT',
                    child: Text(s.overtime),
                  ),
                DropdownMenuItem(
                  value: 'EXTRA',
                  child: Text(s.extraHours),
                ),
              ],
              onChanged: (v) {
                if (v != null) onTypeChanged(v);
              },
            ),
            const SizedBox(height: 12),
            if (type == 'CHECK_IN_OUT') ...[
              _TimeInput(
                controller: checkInCtrl,
                label: s.checkInRequestTime,
                onPick: () => onPickTime(checkInCtrl),
                validator: (v) {
                  if (type != 'CHECK_IN_OUT') return null;
                  if ((v == null || v.trim().isEmpty) && checkOutCtrl.text.trim().isEmpty) {
                    return s.pleaseEnterCheckInTime;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _TimeInput(
                controller: checkOutCtrl,
                label: s.checkOutRequestTime,
                onPick: () => onPickTime(checkOutCtrl),
              ),
            ],
            if (type == 'OT')
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.otDayNight,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ChoiceChip(
                        label: Text(s.day),
                        selected: otPeriod == 'DAY',
                        onSelected: (_) => onOtPeriodChanged('DAY'),
                        showCheckmark: true,
                      ),
                      ChoiceChip(
                        label: Text(s.night),
                        selected: otPeriod == 'NIGHT',
                        onSelected: (_) => onOtPeriodChanged('NIGHT'),
                        showCheckmark: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.otScope,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ChoiceChip(
                        label: Text(s.insideShift),
                        selected: otScope == 'IN_SHIFT',
                        onSelected: (_) => onOtScopeChanged('IN_SHIFT'),
                        showCheckmark: true,
                      ),
                      ChoiceChip(
                        label: Text(s.outsideShift),
                        selected: otScope == 'OUTSIDE_SHIFT',
                        onSelected: (_) => onOtScopeChanged('OUTSIDE_SHIFT'),
                        showCheckmark: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: otCtrl,
                    decoration: InputDecoration(
                      labelText: s.overtimeDuration,
                      hintText: s.timeFormatHint,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (type != 'OT') return null;
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return s.pleaseEnterOvertimeDuration;
                      try {
                        _parseDurationMinutes(text, s);
                        return null;
                      } catch (_) {
                        return s.validHhmmFormat;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            if (type == 'EXTRA')
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.extraHoursDayNight,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ChoiceChip(
                        label: Text(s.day),
                        selected: extraPeriod == 'DAY',
                        onSelected: (_) => onExtraPeriodChanged('DAY'),
                        showCheckmark: true,
                      ),
                      ChoiceChip(
                        label: Text(s.night),
                        selected: extraPeriod == 'NIGHT',
                        onSelected: (_) => onExtraPeriodChanged('NIGHT'),
                        showCheckmark: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: otCtrl,
                    decoration: InputDecoration(
                      labelText: s.extraHoursDuration,
                      hintText: s.timeFormatHint,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (type != 'EXTRA') return null;
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return s.pleaseEnterOvertimeDuration;
                      try {
                        _parseDurationMinutes(text, s);
                        return null;
                      } catch (_) {
                        return s.validHhmmFormat;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            if (type != 'OT' && type != 'EXTRA') const SizedBox(height: 12),
            TextFormField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: s.note,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_outlined),
                    label: Text(s.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: submitting ? null : onSubmit,
                    icon: submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(s.sendRequest),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayShiftsSection extends StatelessWidget {
  final SelfTodayAttendance? dayInfo;
  final bool loading;

  const _DayShiftsSection({
    required this.dayInfo,
    required this.loading,
  });

  Color _shiftColor(SelfShiftInfo shift) {
    final hex = shift.color;
    if (hex == null || hex.isEmpty) return AppTheme.primary;
    final normalized = hex.replaceFirst('#', '');
    if (normalized.length == 6) {
      final value = int.tryParse('FF$normalized', radix: 16);
      if (value != null) return Color(value);
    }
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    final shifts = dayInfo?.shifts ?? const [];
    if (shifts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          attendanceMessage(s, dayInfo?.message),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                shifts.length == 1
                    ? s.dayShifts
                    : '${s.dayShifts} (${shifts.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...shifts.asMap().entries.map((entry) {
            final index = entry.key;
            final shift = entry.value;
            final isLast = index == shifts.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: _ShiftInfoCard(
                shift: shift,
                color: _shiftColor(shift),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ShiftInfoCard extends StatelessWidget {
  final SelfShiftInfo shift;
  final Color color;

  const _ShiftInfoCard({
    required this.shift,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final title = shift.name.trim().isEmpty ? s.shift : shift.name.trim();
    final mainTime = '${shift.startTime} - ${shift.endTime}';
    final checkIn =
        '${s.checkInTime}: ${shift.checkInFrom} - ${shift.checkInTo}';
    final checkOut =
        '${s.checkOutTime}: ${shift.checkOutFrom} - ${shift.checkOutTo}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mainTime,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$checkIn | $checkOut',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatefulWidget {
  final TextEditingController searchCtrl;
  final String filterType;
  final DateTime? filterFrom;
  final DateTime? filterTo;
  final List<DepartmentFlat> departments;
  final int? filterDepartmentId;
  final bool otEnabled;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final ValueChanged<int?> onDepartmentChanged;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.searchCtrl,
    required this.filterType,
    required this.filterFrom,
    required this.filterTo,
    required this.departments,
    required this.filterDepartmentId,
    this.otEnabled = true,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onDepartmentChanged,
    required this.onClear,
  });

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final dateFmt = DateFormat('dd/MM/yyyy', 'vi');
    final hasFilters = widget.searchCtrl.text.trim().isNotEmpty ||
        widget.filterType != 'ALL' ||
        widget.filterFrom != null ||
        widget.filterTo != null ||
        widget.filterDepartmentId != null;
    final isMobile = MediaQuery.of(context).size.width < 600;

    Widget dateButton({
      required String label,
      required DateTime? value,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(
                value == null ? s.all : dateFmt.format(value),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final advancedFilters = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: widget.filterType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(value: 'ALL', child: Text(s.all)),
                  DropdownMenuItem(value: 'CHECK_IN', child: Text(s.checkIn)),
                  DropdownMenuItem(value: 'CHECK_OUT', child: Text(s.checkOut)),
                  if (widget.otEnabled)
                    DropdownMenuItem(value: 'OT', child: Text(s.overtime)),
                  DropdownMenuItem(value: 'EXTRA', child: Text(s.extraHours)),
                ],
                onChanged: (v) {
                  if (v != null) widget.onTypeChanged(v);
                },
              ),
            ),
            DepartmentPickerField(
              departments: widget.departments,
              value: widget.filterDepartmentId,
              allowAll: true,
              allLabel: s.all,
              label: s.department,
              compact: true,
              onChanged: widget.onDepartmentChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            dateButton(label: s.fromDate, value: widget.filterFrom, onTap: widget.onPickFrom),
            dateButton(label: s.toDate, value: widget.filterTo, onTap: widget.onPickTo),
            TextButton.icon(
              onPressed: hasFilters ? widget.onClear : null,
              icon: const Icon(Icons.clear_all_outlined),
              label: Text(s.clearFilters),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SearchTextField(
                  controller: widget.searchCtrl,
                  onChanged: widget.onSearchChanged,
                  onClear: () => widget.onSearchChanged(''),
                ),
              ),
              if (isMobile) ...[
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded ? Icons.filter_list_off : Icons.filter_list,
                        color: hasFilters ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                      tooltip: s.clearFilters,
                    ),
                    if (hasFilters && !_expanded)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
          if (!isMobile || _expanded) advancedFilters,
        ],
      ),
    );
  }
}

class _TimeInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onPick;
  final String? Function(String?)? validator;

  const _TimeInput({
    required this.controller,
    required this.label,
    required this.onPick,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: s.timeFormatHint,
              border: const OutlineInputBorder(),
            ),
            validator: validator,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onPick,
          icon: const Icon(Icons.schedule_outlined),
          tooltip: s.chooseTime,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RequestList extends StatefulWidget {
  final List<AttendanceChangeRequest> requests;
  final bool canApprove;
  final bool acting;
  final int? currentEmployeeId;
  final Future<void> Function(AttendanceChangeRequest)? onApprove;
  final Future<void> Function(AttendanceChangeRequest)? onReject;
  final Future<void> Function(AttendanceChangeRequest)? onCancel;
  final String emptyMessage;

  const _RequestList({
    required this.requests,
    required this.canApprove,
    required this.acting,
    required this.currentEmployeeId,
    this.onApprove,
    this.onReject,
    this.onCancel,
    required this.emptyMessage,
  });

  @override
  State<_RequestList> createState() => _RequestListState();
}

class _RequestListState extends State<_RequestList> {
  int _page = 0;
  int _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (widget.requests.isEmpty) {
      return EmptyState(message: widget.emptyMessage);
    }
    final paged = widget.requests.skip(_page * _pageSize).take(_pageSize).toList();
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: paged.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final r = paged[i];
        final statusColor = switch (r.status) {
          'APPROVED' => AppTheme.secondary,
          'REJECTED' => AppTheme.error,
          'CANCELLED' => AppTheme.textSecondary,
          _ => AppTheme.warning,
        };
        final statusLabel = switch (r.status) {
          'APPROVED' => s.approved,
          'REJECTED' => s.rejected,
          'CANCELLED' => s.cancelled,
          _ => s.pending,
        };
        final processedLabel = switch (r.status) {
          'APPROVED' => s.approve,
          'REJECTED' => s.rejected,
          'CANCELLED' => s.cancel,
          _ => s.processingBy,
        };
        final isOwner =
            widget.currentEmployeeId != null && widget.currentEmployeeId == r.employeeId;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      r.employeeName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.employeeName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${r.departmentName} • ${_requestTypeLabel(s, r.requestType)}'
                          '${(r.requestType == 'OT' || r.requestType == 'EXTRA') && r.requestedOvertimePeriod != null ? ' • ${_periodLabel(s, r.requestedOvertimePeriod)}' : ''}'
                          '${r.requestType == 'OT' && r.requestedOvertimeScope != null ? ' • ${_scopeLabel(s, r.requestedOvertimeScope)}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('${s.date}: ${r.requestDate}'),
              const SizedBox(height: 4),
              Text(_detailText(s, r)),
              const SizedBox(height: 4),
              Text(
                '${s.createdAt}: ${_formatDateTime(r.createdAt)}',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '${s.note}: ${(r.note != null && r.note!.trim().isNotEmpty) ? r.note : '-'}',
              ),
              if (r.status != 'PENDING' && r.processedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${r.status == 'APPROVED' ? s.approvedBy : s.rejectedBy}: ${r.processedByName ?? ''}'
                  ' • ${_formatDateTime(r.processedAt)}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
              if (r.adminNote != null && r.adminNote!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '${s.response}: ${r.adminNote}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
              if (widget.canApprove && r.status == 'PENDING') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.acting ? null : () => widget.onApprove?.call(r),
                        icon: const Icon(Icons.check),
                        label: Text(s.approve),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.acting ? null : () => widget.onReject?.call(r),
                        icon: const Icon(Icons.close),
                        label: Text(s.reject),
                      ),
                    ),
                  ],
                ),
              ],
              if (isOwner && r.status == 'PENDING') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.acting ? null : () => widget.onCancel?.call(r),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(s.cancel),
                  ),
                ),
              ],
            ],
          ),
        );
      },
          ),
        ),
        PaginationBar(
          total: widget.requests.length,
          page: _page,
          pageSize: _pageSize,
          onPageSizeChanged: (v) => setState(() { _pageSize = v; _page = 0; }),
          onPrev: _page > 0 ? () => setState(() => _page--) : null,
          onNext: (_page + 1) * _pageSize < widget.requests.length ? () => setState(() => _page++) : null,
        ),
      ],
    );
  }

  String _detailText(AppLocalizations s, AttendanceChangeRequest r) {
    if (r.requestType == 'CHECK_IN') {
      return '${s.checkInRequest}: ${r.requestedCheckIn ?? ''}';
    }
    if (r.requestType == 'CHECK_OUT') {
      return '${s.checkOutRequest}: ${r.requestedCheckOut ?? ''}';
    }
    final minutes = r.requestedOvertimeMinutes ?? 0;
    final hh = minutes ~/ 60;
    final mm = minutes % 60;
    final duration = '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    final period = _periodLabel(s, r.requestedOvertimePeriod);
    if (r.requestType == 'EXTRA') {
      return '${s.extraHours}${period.isNotEmpty ? ' ($period)' : ''}: $duration';
    }
    final scope = _scopeLabel(s, r.requestedOvertimeScope);
    final tags = [
      if (period.isNotEmpty) period,
      if (scope.isNotEmpty) scope,
    ].join(' • ');
    return '${s.overtime}${tags.isNotEmpty ? ' ($tags)' : ''}: $duration';
  }
}

String _formatTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

int _parseDurationMinutes(String value, AppLocalizations s) {
  final parts = value.split(':');
  if (parts.length != 2) {
    throw FormatException(s.durationMustBeHHmm);
  }
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null || minutes < 0 || minutes >= 60) {
    throw FormatException(s.durationMustBeHHmm);
  }
  return hours * 60 + minutes;
}

String _scopeLabel(AppLocalizations s, String? scope) {
  return switch (scope) {
    'IN_SHIFT' => s.insideShift,
    'OUTSIDE_SHIFT' => s.outsideShift,
    _ => '',
  };
}

String _periodLabel(AppLocalizations s, String? period) {
  return switch (period) {
    'DAY' => s.day,
    'NIGHT' => s.night,
    _ => '',
  };
}

String _requestTypeLabel(AppLocalizations s, String type) {
  return switch (type) {
    'CHECK_IN' => s.checkIn,
    'CHECK_OUT' => s.checkOut,
    'OT' => s.overtime,
    'EXTRA' => s.extraHours,
    _ => type,
  };
}

String _formatDateTime(String? value) {
  if (value == null || value.isEmpty) return '';
  try {
    final dt = DateTime.parse(value).toLocal();
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  } catch (_) {
    return value;
  }
}
