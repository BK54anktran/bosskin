import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/shift_registration_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/repositories/shift_registration_repository.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/date_field.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import '../../../core/utils/company_currency_utils.dart';

/// Tab "Đăng ký lịch" ở Ca làm (V23): danh sách đợt (mở / đóng ngay trên dòng), tạo / sửa đợt,
/// lưới người × ngày để duyệt theo ngày hoặc từng ô → phân ca.
class ShiftRegistrationTab extends StatefulWidget {
  final List<DepartmentFlat> departments;
  /// Gọi sau khi duyệt (đã tạo phân ca) để tab Phân công ca tải lại.
  final VoidCallback? onApproved;

  const ShiftRegistrationTab({super.key, required this.departments, this.onApproved});

  @override
  State<ShiftRegistrationTab> createState() => _ShiftRegistrationTabState();
}

Color _statusColor(String status) => switch (status) {
      'OPEN' => AppTheme.secondary,
      'CLOSED' => AppTheme.warning,
      _ => AppTheme.textSecondary,
    };

String _statusLabel(AppLocalizations s, String status) => switch (status) {
      'OPEN' => s.shiftRegStatusOpen,
      'CLOSED' => s.shiftRegStatusClosed,
      _ => s.shiftRegStatusDraft,
    };

class _ShiftRegistrationTabState extends State<ShiftRegistrationTab> {
  final _repo = ShiftRegistrationRepository();
  List<RegRound> _items = const [];
  bool _isLoading = true;
  String? _error;
  int? _busyId;
  RegRound? _opened;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _repo.getRounds();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {bool ok = true}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: ok ? AppTheme.secondary : AppTheme.error));

  Future<void> _act(RegRound r, Future<void> Function() action, String okMsg) async {
    setState(() => _busyId = r.id);
    try {
      await action();
      _toast(okMsg);
      await _load();
    } catch (e) {
      _toast(serverMsg(e), ok: false);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _onEdit([RegRound? r]) async {
    final saved = await showInstantDialog<bool>(
        context, (ctx) => _RoundFormDialog(departments: widget.departments, initial: r));
    if (saved == true) _load();
  }

  Future<void> _onDelete(RegRound r) async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        title: Text(s.shiftRegDeleteTitle),
        content: Text(s.shiftRegDeleteConfirm(r.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok == true) await _act(r, () => _repo.deleteRound(r.id), s.shiftRegDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (_opened != null) {
      return _RoundBoard(
        round: _opened!,
        onBack: () {
          setState(() => _opened = null);
          _load();
        },
        onApproved: widget.onApproved,
      );
    }
    final df = DateFormat('dd/MM/yyyy');
    final dtf = DateFormat('dd/MM HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(s.shiftRegTabHelper, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _onEdit(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(s.shiftRegCreate),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? EmptyState(icon: Icons.error_outline, message: _error!, actionLabel: s.retry, onAction: _load)
                  : _items.isEmpty
                      ? EmptyState(icon: Icons.edit_calendar_outlined, message: s.shiftRegEmpty)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final r = _items[i];
                            final busy = _busyId == r.id;
                            final pct = r.employeeCount == 0 ? 0.0 : r.registeredCount / r.employeeCount;
                            return Card(
                              margin: EdgeInsets.zero,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() => _opened = r),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      SizedBox(
                                        width: 220,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                            Text('${df.format(r.fromDate)} – ${df.format(r.toDate)}',
                                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 220,
                                        child: Text(r.departments.map((d) => d.name).join(', '),
                                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                      ),
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                            r.closesAt != null ? s.shiftRegDeadline(dtf.format(r.closesAt!)) : s.shiftRegNoDeadline,
                                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                      ),
                                      SizedBox(
                                        width: 110,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.shiftRegRegistered(r.registeredCount, r.employeeCount),
                                                style: const TextStyle(fontSize: 12)),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(3),
                                              child: LinearProgressIndicator(
                                                value: pct,
                                                minHeight: 6,
                                                backgroundColor: AppTheme.surfaceAlt,
                                                color: AppTheme.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(label: _statusLabel(s, r.status), color: _statusColor(r.status)),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (r.isOpen)
                                            OutlinedButton.icon(
                                              onPressed: busy ? null : () => _act(r, () => _repo.close(r.id), s.shiftRegClosed),
                                              icon: const Icon(Icons.lock_outline, size: 16),
                                              label: Text(s.shiftRegClose),
                                            )
                                          else
                                            FilledButton.icon(
                                              onPressed: busy ? null : () => _act(r, () => _repo.open(r.id), s.shiftRegOpened),
                                              icon: const Icon(Icons.lock_open_outlined, size: 16),
                                              label: Text(r.isDraft ? s.shiftRegOpen : s.shiftRegReopen),
                                            ),
                                          PopupMenuButton<String>(
                                            onSelected: (v) => v == 'edit' ? _onEdit(r) : _onDelete(r),
                                            itemBuilder: (_) => [
                                              PopupMenuItem(value: 'edit', child: Text(s.edit)),
                                              PopupMenuItem(value: 'delete', child: Text(s.delete)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

// ── Hộp tạo / sửa đợt ──────────────────────────────────────────────────

class _RoundFormDialog extends StatefulWidget {
  final List<DepartmentFlat> departments;
  final RegRound? initial;
  const _RoundFormDialog({required this.departments, this.initial});

  @override
  State<_RoundFormDialog> createState() => _RoundFormDialogState();
}

class _RoundFormDialogState extends State<_RoundFormDialog> {
  final _repo = ShiftRegistrationRepository();
  final _nameCtrl = TextEditingController();
  final _earliestCtrl = TextEditingController();
  final _latestCtrl = TextEditingController();
  final _minHoursCtrl = TextEditingController();
  final _maxHoursCtrl = TextEditingController();
  final _minDaysCtrl = TextEditingController();
  final _neededCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final Set<int> _deptIds = {};
  DateTime? _from;
  DateTime? _to;
  DateTime? _deadline;
  String _preset = 'custom';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    if (r != null) {
      _nameCtrl.text = r.name;
      _from = r.fromDate;
      _to = r.toDate;
      _deadline = r.closesAt;
      _deptIds.addAll(r.departments.map((d) => d.id));
      _earliestCtrl.text = r.earliestTime ?? '';
      _latestCtrl.text = r.latestTime ?? '';
      _minHoursCtrl.text = r.minHours?.toString() ?? '';
      _maxHoursCtrl.text = r.maxHours?.toString() ?? '';
      _minDaysCtrl.text = r.minDays?.toString() ?? '';
      _neededCtrl.text = r.neededPerDay?.toString() ?? '';
      _noteCtrl.text = r.note ?? '';
    } else {
      _applyPreset('nextWeek');
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _earliestCtrl, _latestCtrl, _minHoursCtrl, _maxHoursCtrl, _minDaysCtrl, _neededCtrl, _noteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyPreset(String p) {
    final now = companyNow();
    final today = DateTime(now.year, now.month, now.day);
    final nextMon = today.add(Duration(days: 8 - today.weekday));
    setState(() {
      _preset = p;
      switch (p) {
        case 'nextWeek':
          _from = nextMon;
          _to = nextMon.add(const Duration(days: 6));
        case 'next2Weeks':
          _from = nextMon;
          _to = nextMon.add(const Duration(days: 13));
        case 'nextMonth':
          _from = DateTime(today.year, today.month + 1, 1);
          _to = DateTime(today.year, today.month + 2, 0);
      }
      if (p != 'custom' && _from != null) {
        // Hạn chót mặc định: 18:00 ba ngày trước ngày bắt đầu (không sớm hơn hôm nay)
        final d = _from!.subtract(const Duration(days: 3));
        _deadline = DateTime(d.year, d.month, d.day, 18).isBefore(now) ? null : DateTime(d.year, d.month, d.day, 18);
      }
    });
  }

  Future<void> _pickDeadline() async {
    final now = companyNow();
    final d = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? DateTime(d.year, d.month, d.day, 18)),
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    setState(() => _deadline = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save(bool open) async {
    final s = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty || _from == null || _to == null || _deptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.shiftRegFormRequired), backgroundColor: AppTheme.error));
      return;
    }
    String? time(TextEditingController c) {
      final m = regTimeToMinutes(c.text.trim());
      return m == null ? null : regMinutesToTime(m);
    }

    num? number(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.'));
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'fromDate': regYmd(_from!),
      'toDate': regYmd(_to!),
      'departmentIds': _deptIds.toList(),
      'closesAt': _deadline == null ? null : DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(_deadline!),
      'earliestTime': time(_earliestCtrl),
      'latestTime': time(_latestCtrl),
      'minHours': number(_minHoursCtrl),
      'maxHours': number(_maxHoursCtrl),
      'minDays': number(_minDaysCtrl)?.toInt(),
      'neededPerDay': number(_neededCtrl)?.toInt(),
      'note': _noteCtrl.text.trim(),
      'open': open,
    };
    setState(() => _isSaving = true);
    try {
      await _repo.saveRound(id: widget.initial?.id, body: body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isNew = widget.initial == null;
    final presets = <(String, String)>[
      ('nextWeek', s.shiftRegPresetNextWeek),
      ('next2Weeks', s.shiftRegPresetNext2Weeks),
      ('nextMonth', s.shiftRegPresetNextMonth),
      ('custom', s.shiftRegPresetCustom),
    ];
    Widget pair(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
    TextField num(TextEditingController c, String label, {String? hint}) => TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, hintText: hint),
        );
    return AlertDialog(
      title: Text(isNew ? s.shiftRegCreate : s.shiftRegEdit),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: s.shiftRegName)),
              const SizedBox(height: 12),
              Text(s.shiftRegRange, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (k, label) in presets)
                    ChoiceChip(label: Text(label), selected: _preset == k, onSelected: (_) => _applyPreset(k)),
                ],
              ),
              const SizedBox(height: 10),
              pair(
                DateField(
                  label: s.fromDate,
                  value: _from,
                  onChanged: (d) => setState(() {
                    _from = d;
                    _preset = 'custom';
                  }),
                ),
                DateField(
                  label: s.toDate,
                  value: _to,
                  onChanged: (d) => setState(() {
                    _to = d;
                    _preset = 'custom';
                  }),
                ),
              ),
              const SizedBox(height: 12),
              DepartmentMultiPickerField(
                departments: widget.departments,
                values: _deptIds,
                label: s.department,
                onChanged: (v) => setState(() {
                  _deptIds
                    ..clear()
                    ..addAll(v);
                }),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDeadline,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: s.shiftRegDeadlineLabel,
                    suffixIcon: _deadline != null
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _deadline = null))
                        : const Icon(Icons.timer_outlined, size: 18),
                  ),
                  child: Text(_deadline != null ? DateFormat('dd/MM/yyyy HH:mm').format(_deadline!) : s.shiftRegNoDeadline),
                ),
              ),
              const SizedBox(height: 14),
              Text(s.shiftRegLimits, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              pair(num(_earliestCtrl, s.shiftRegEarliest, hint: '06:00'), num(_latestCtrl, s.shiftRegLatest, hint: '23:00')),
              const SizedBox(height: 8),
              pair(num(_minHoursCtrl, s.shiftRegMinHours), num(_maxHoursCtrl, s.shiftRegMaxHours)),
              const SizedBox(height: 8),
              pair(num(_minDaysCtrl, s.shiftRegMinDays), num(_neededCtrl, s.shiftRegNeededPerDay)),
              const SizedBox(height: 8),
              TextField(controller: _noteCtrl, decoration: InputDecoration(labelText: s.note), maxLines: 2),
              const SizedBox(height: 8),
              Text(s.shiftRegFormHelper, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context, false), child: Text(s.cancel)),
        if (isNew)
          OutlinedButton(onPressed: _isSaving ? null : () => _save(false), child: Text(s.shiftRegSaveDraft)),
        FilledButton(
          onPressed: _isSaving ? null : () => _save(isNew),
          child: Text(isNew ? s.shiftRegSaveOpen : s.save),
        ),
      ],
    );
  }
}

// ── Lưới duyệt ─────────────────────────────────────────────────────────

class _RoundBoard extends StatefulWidget {
  final RegRound round;
  final VoidCallback onBack;
  final VoidCallback? onApproved;
  const _RoundBoard({required this.round, required this.onBack, this.onApproved});

  @override
  State<_RoundBoard> createState() => _RoundBoardState();
}

class _RoundBoardState extends State<_RoundBoard> {
  final _repo = ShiftRegistrationRepository();
  RegBoard? _board;
  bool _isLoading = true;
  String? _error;
  bool _isBusy = false;
  DateTime? _chartDay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final b = await _repo.board(widget.round.id);
      if (mounted) setState(() => _board = b);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {bool ok = true}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: ok ? AppTheme.secondary : AppTheme.error));

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  List<RegSlot> _slots(RegBoardEmployee e, DateTime d) => e.registrations.where((r) => _day(r.workDate) == d).toList();

  int _pendingOn(DateTime d) =>
      _board?.employees.fold<int>(0, (n, e) => n + _slots(e, d).where((r) => r.status == 'PENDING').length) ?? 0;

  int _peopleOn(DateTime d) =>
      _board?.employees.where((e) => _slots(e, d).any((r) => r.status != 'REJECTED')).length ?? 0;

  Future<void> _approveDay(DateTime d) async {
    final s = AppLocalizations.of(context);
    final board = _board!;
    final hasAny = board.employees.any((e) => _slots(e, d).any((r) => r.isAny && r.status == 'PENDING'));
    int? anyShift;
    if (hasAny) {
      final picked = await showInstantDialog<int>(context, (ctx) => _PickShiftDialog(shifts: board.shifts, title: s.shiftRegAnyPickTitle));
      if (picked == null) return;
      anyShift = picked < 0 ? null : picked;
    }
    setState(() => _isBusy = true);
    try {
      final res = await _repo.approveDay(widget.round.id, d, anyShiftId: anyShift);
      widget.onApproved?.call();
      if (!mounted) return;
      if (res.skipped.isEmpty) {
        _toast(s.shiftRegApprovedCount(res.approved));
      } else {
        await showInstantDialog<void>(
          context,
          (ctx) => AlertDialog(
            title: Text(s.shiftRegApprovedCount(res.approved)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.shiftRegSkippedTitle(res.skipped.length), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  for (final x in res.skipped) Text('• ${x.employeeName}: ${serverKeyMsg(x.reason)}', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close))],
          ),
        );
      }
      await _load();
    } catch (e) {
      _toast(serverMsg(e), ok: false);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _onSlot(RegBoardEmployee e, RegSlot r) async {
    if (r.status != 'PENDING' || r.id == null) return;
    final s = AppLocalizations.of(context);
    final action = await showInstantDialog<_SlotDecision>(
        context, (ctx) => _SlotDecisionDialog(employee: e, slot: r, shifts: _board!.shifts));
    if (action == null) return;
    setState(() => _isBusy = true);
    try {
      if (action.reject) {
        await _repo.reject(r.id!);
        _toast(s.shiftRegRejectedOne);
      } else {
        await _repo.approveOne(r.id!, shiftId: action.shiftId, startTime: action.start, endTime: action.end);
        widget.onApproved?.call();
        _toast(s.shiftRegApprovedCount(1));
      }
      await _load();
    } catch (err) {
      _toast(serverMsg(err), ok: false);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final round = _board?.round ?? widget.round;
    final df = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 12, 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: widget.onBack),
              Text('${round.name} · ${df.format(round.fromDate)} – ${df.format(round.toDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              StatusBadge(label: _statusLabel(s, round.status), color: _statusColor(round.status)),
              Text(s.shiftRegRegistered(round.registeredCount, round.employeeCount),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              if (_isBusy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(spacing: 14, runSpacing: 4, children: [
            _Legend(color: AppTheme.warning, label: s.pending),
            _Legend(color: AppTheme.secondary, label: s.approved),
            _Legend(color: AppTheme.error, label: s.rejected),
            Text(s.shiftRegBoardHelper, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? EmptyState(icon: Icons.error_outline, message: _error!, actionLabel: s.retry, onAction: _load)
                  : _buildGrid(s, round, localeTag),
        ),
      ],
    );
  }

  Widget _buildGrid(AppLocalizations s, RegRound round, String localeTag) {
    final board = _board!;
    final days = round.days;
    const nameW = 190.0;
    const cellW = 116.0;
    final border = BorderSide(color: AppTheme.border);
    Widget header(DateTime d) {
      final weekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
      final pending = _pendingOn(d);
      final people = _peopleOn(d);
      final need = round.neededPerDay;
      final short = need != null && people < need;
      return Container(
        width: cellW,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: weekend ? AppTheme.tint(AppTheme.error) : AppTheme.surfaceAlt,
          border: Border(right: border, bottom: border),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _chartDay = _chartDay == d ? null : d),
              child: Column(children: [
                Text(DateFormat('EEE dd/MM', localeTag).format(d),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: weekend ? AppTheme.error : AppTheme.textPrimary)),
                Text(need != null ? s.shiftRegPeopleNeed(people, need) : s.shiftRegPeople(people),
                    style: TextStyle(fontSize: 11, color: short ? AppTheme.error : AppTheme.textSecondary)),
              ]),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 26,
              child: pending > 0
                  ? FilledButton(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), textStyle: const TextStyle(fontSize: 12)),
                      onPressed: _isBusy ? null : () => _approveDay(d),
                      child: Text(s.shiftRegApproveDay(pending)),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    Widget cell(RegBoardEmployee e, DateTime d, Color bg) {
      final slots = _slots(e, d);
      return Container(
        width: cellW,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: bg, border: Border(right: border, bottom: border)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final r in slots)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: _SlotChip(slot: r, anyLabel: s.shiftRegAnyShort, onTap: r.status == 'PENDING' ? () => _onSlot(e, r) : null),
              ),
          ],
        ),
      );
    }

    final grid = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: nameW + cellW * days.length,
        child: Column(
          children: [
            Row(children: [
              Container(
                width: nameW,
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(color: AppTheme.surfaceAlt, border: Border(right: border, bottom: border)),
                child: Text(s.employee, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              for (final d in days) header(d),
            ]),
            Expanded(
              child: board.employees.isEmpty
                  ? EmptyState(message: s.shiftRegBoardEmpty)
                  : ListView.builder(
                      itemCount: board.employees.length,
                      itemBuilder: (_, i) {
                        final e = board.employees[i];
                        final bg = i.isOdd ? AppTheme.surfaceAlt : AppTheme.background;
                        final low = round.minDays != null && e.days < round.minDays!;
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: nameW,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(color: bg, border: Border(right: border, bottom: border)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(e.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                    Text(
                                      low ? '${e.code} • ${s.shiftRegDaysOf(e.days, round.minDays!)}' : '${e.code} • ${e.departmentName ?? ''}',
                                      style: TextStyle(fontSize: 10, color: low ? AppTheme.error : AppTheme.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              for (final d in days)
                                cell(e, d, d.weekday >= DateTime.saturday ? AppTheme.tint(AppTheme.error) : bg),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
    final chartDay = _chartDay;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: Container(color: AppTheme.background, child: grid)),
        if (chartDay != null)
          Container(
            width: 280,
            decoration: BoxDecoration(color: AppTheme.background, border: Border(left: border)),
            padding: const EdgeInsets.all(12),
            child: _HourChart(
              title: DateFormat('EEE dd/MM', localeTag).format(chartDay),
              slots: [for (final e in board.employees) ..._slots(e, chartDay)],
              shifts: board.shifts,
              needed: round.neededPerDay,
              onClose: () => setState(() => _chartDay = null),
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: AppTheme.tint(color), border: Border.all(color: color), borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ]);
}

class _SlotChip extends StatelessWidget {
  final RegSlot slot;
  final String anyLabel;
  final VoidCallback? onTap;
  const _SlotChip({required this.slot, required this.anyLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (slot.status) {
      'APPROVED' => AppTheme.secondary,
      'REJECTED' => AppTheme.error,
      _ => AppTheme.warning,
    };
    final text = slot.timeLabel() ?? anyLabel;
    // Đã duyệt khác đăng ký (rảnh cả ngày / đổi giờ) → di chuột xem bản đăng ký gốc
    final registered = slot.isAny ? anyLabel : '${slot.shiftCode != null ? '${slot.shiftCode} ' : ''}${slot.startTime}–${slot.endTime}';
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.tint(color), borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          decoration: slot.status == 'REJECTED' ? TextDecoration.lineThrough : null,
        ),
      ),
    );
    final shown = registered != text ? Tooltip(message: AppLocalizations.of(context).shiftRegRegisteredAs(registered), child: chip) : chip;
    if (onTap == null) return shown;
    return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, child: shown));
  }
}

/// Số người theo giờ của một ngày (6h–24h, mỗi cột 1 giờ). "Rảnh cả ngày" tính vào mọi giờ.
class _HourChart extends StatelessWidget {
  final String title;
  final List<RegSlot> slots;
  final List<RegShiftOption> shifts;
  final int? needed;
  final VoidCallback onClose;
  const _HourChart({required this.title, required this.slots, required this.shifts, required this.needed, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final live = slots.where((r) => r.status != 'REJECTED').toList();
    final counts = <int>[];
    for (var h = 6; h < 24; h++) {
      final m = h * 60;
      counts.add(live.where((r) {
        // Đã duyệt → theo giờ phân ca đã xếp; rảnh cả ngày chưa xếp → mọi giờ
        final start = r.hasAssigned ? r.assignedStartTime : r.startTime;
        final end = r.hasAssigned ? r.assignedEndTime : r.endTime;
        if (r.isAny && !r.hasAssigned) return true;
        final a = regTimeToMinutes(start);
        if (a == null || end == null) return false;
        final b = a + regSlotMinutes(start!, end);
        return (a <= m && m < b) || (a <= m + 1440 && m + 1440 < b);
      }).length);
    }
    final maxV = [...counts, needed ?? 0, 1].reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(s.shiftRegChartTitle(title), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClose),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < counts.length; i++)
                Expanded(
                  child: Tooltip(
                    message: '${(i + 6).toString().padLeft(2, '0')}:00 — ${counts[i]}',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: 4 + 120 * counts[i] / maxV,
                      decoration: BoxDecoration(
                        color: AppTheme.tint(needed != null && counts[i] < needed! ? AppTheme.error : AppTheme.primary),
                        border: Border(
                            top: BorderSide(
                                color: needed != null && counts[i] < needed! ? AppTheme.error : AppTheme.primary, width: 2)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (final h in ['6h', '9', '12', '15', '18', '21']) Text(h, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary))],
        ),
        const SizedBox(height: 8),
        Text(needed != null ? s.shiftRegChartNeedHelper(needed!) : s.shiftRegChartHelper,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

/// Chọn ca cho người đăng ký "rảnh cả ngày" khi duyệt cả ngày. Trả id ca, -1 = bỏ qua họ.
class _PickShiftDialog extends StatefulWidget {
  final List<RegShiftOption> shifts;
  final String title;
  const _PickShiftDialog({required this.shifts, required this.title});

  @override
  State<_PickShiftDialog> createState() => _PickShiftDialogState();
}

class _PickShiftDialogState extends State<_PickShiftDialog> {
  int? _shiftId;

  @override
  void initState() {
    super.initState();
    _shiftId = widget.shifts.firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: AppDropdown<int>(
          value: _shiftId,
          label: s.shiftRegShift,
          items: [for (final o in widget.shifts) DropdownMenuItem(value: o.id, child: Text('${o.code} · ${o.startTime}–${o.endTime}'))],
          onChanged: (v) => setState(() => _shiftId = v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        OutlinedButton(onPressed: () => Navigator.pop(context, -1), child: Text(s.shiftRegSkipAny)),
        FilledButton(onPressed: _shiftId == null ? null : () => Navigator.pop(context, _shiftId), child: Text(s.approve)),
      ],
    );
  }
}

class _SlotDecision {
  final bool reject;
  final int? shiftId;
  final String? start;
  final String? end;
  const _SlotDecision({this.reject = false, this.shiftId, this.start, this.end});
}

/// Bấm một ô chờ duyệt: duyệt theo đăng ký, đổi sang ca có sẵn / giờ khác, hoặc từ chối.
class _SlotDecisionDialog extends StatefulWidget {
  final RegBoardEmployee employee;
  final RegSlot slot;
  final List<RegShiftOption> shifts;
  const _SlotDecisionDialog({required this.employee, required this.slot, required this.shifts});

  @override
  State<_SlotDecisionDialog> createState() => _SlotDecisionDialogState();
}

class _SlotDecisionDialogState extends State<_SlotDecisionDialog> {
  late String _mode; // keep | shift | custom
  int? _shiftId;
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final r = widget.slot;
    _mode = r.isAny ? 'shift' : 'keep';
    _shiftId = r.shiftId ?? widget.shifts.firstOrNull?.id;
    _startCtrl.text = r.startTime ?? '08:00';
    _endCtrl.text = r.endTime ?? '17:00';
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _approve() {
    switch (_mode) {
      case 'shift':
        Navigator.pop(context, _SlotDecision(shiftId: _shiftId));
      case 'custom':
        final a = regTimeToMinutes(_startCtrl.text.trim()), b = regTimeToMinutes(_endCtrl.text.trim());
        if (a == null || b == null || a == b) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).shiftRegInvalidTime), backgroundColor: AppTheme.error));
          return;
        }
        Navigator.pop(context, _SlotDecision(start: regMinutesToTime(a), end: regMinutesToTime(b)));
      default:
        Navigator.pop(context, const _SlotDecision());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final r = widget.slot;
    final reg = r.isAny ? s.shiftRegAnyTime : '${r.shiftCode != null ? '${r.shiftCode} · ' : ''}${r.startTime}–${r.endTime}';
    return AlertDialog(
      title: Text('${widget.employee.name} · ${DateFormat('dd/MM/yyyy').format(r.workDate)}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.shiftRegRegisteredAs(reg), style: TextStyle(color: AppTheme.textSecondary)),
            if (r.note != null && r.note!.isNotEmpty) Text(r.note!, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [
              if (!r.isAny) ChoiceChip(label: Text(s.shiftRegKeep), selected: _mode == 'keep', onSelected: (_) => setState(() => _mode = 'keep')),
              if (widget.shifts.isNotEmpty)
                ChoiceChip(label: Text(s.shiftRegKindShift), selected: _mode == 'shift', onSelected: (_) => setState(() => _mode = 'shift')),
              ChoiceChip(label: Text(s.shiftRegKindCustom), selected: _mode == 'custom', onSelected: (_) => setState(() => _mode = 'custom')),
            ]),
            const SizedBox(height: 10),
            if (_mode == 'shift')
              AppDropdown<int>(
                value: _shiftId,
                label: s.shiftRegShift,
                items: [for (final o in widget.shifts) DropdownMenuItem(value: o.id, child: Text('${o.code} · ${o.startTime}–${o.endTime}'))],
                onChanged: (v) => setState(() => _shiftId = v),
              ),
            if (_mode == 'custom')
              Row(children: [
                Expanded(child: TextField(controller: _startCtrl, decoration: InputDecoration(labelText: s.shiftStartLabel, hintText: '08:00'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _endCtrl, decoration: InputDecoration(labelText: s.shiftEndLabel, hintText: '17:00'))),
              ]),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
          onPressed: () => Navigator.pop(context, const _SlotDecision(reject: true)),
          child: Text(s.reject),
        ),
        FilledButton(onPressed: _mode == 'shift' && _shiftId == null ? null : _approve, child: Text(s.approve)),
      ],
    );
  }
}
