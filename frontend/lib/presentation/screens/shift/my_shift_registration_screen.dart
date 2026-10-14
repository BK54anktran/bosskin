import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/shift_registration_utils.dart';
import '../../../data/repositories/shift_registration_repository.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

/// Đăng ký lịch làm việc của nhân viên (V23): chọn đợt đang mở, bật từng ngày rồi chọn ca có sẵn,
/// giờ tuỳ chỉnh hoặc "rảnh cả ngày"; tối đa 2 khung / ngày. Gửi rồi vẫn sửa được tới khi đợt đóng.
class MyShiftRegistrationScreen extends StatefulWidget {
  const MyShiftRegistrationScreen({super.key});

  @override
  State<MyShiftRegistrationScreen> createState() => _MyShiftRegistrationScreenState();
}

class _Draft {
  String kind; // SHIFT | CUSTOM | ANY
  int? shiftId;
  String start;
  String end;
  _Draft({required this.kind, this.shiftId, this.start = '08:00', this.end = '17:00'});
}

class _MyShiftRegistrationScreenState extends State<MyShiftRegistrationScreen> {
  final _repo = ShiftRegistrationRepository();
  List<RegRound> _rounds = const [];
  int? _roundId;
  MyRegRound? _data;
  final Map<DateTime, List<_Draft>> _drafts = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRounds();
  }

  Future<void> _loadRounds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _repo.myRounds();
      _rounds = list;
      final keep = list.any((r) => r.id == _roundId);
      _roundId = keep ? _roundId : (list.where((r) => r.isOpen).firstOrNull ?? list.firstOrNull)?.id;
      if (_roundId != null) {
        await _loadRound(_roundId!);
      } else {
        _data = null;
      }
    } catch (e) {
      _error = serverMsg(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRound(int id) async {
    final data = await _repo.myRound(id);
    _applyData(data);
  }

  void _applyData(MyRegRound data) {
    _data = data;
    _drafts.clear();
    for (final r in data.registrations) {
      if (r.status == 'APPROVED') continue;
      _drafts.putIfAbsent(_day(r.workDate), () => []).add(_Draft(
            kind: r.kind,
            shiftId: r.shiftId,
            start: r.startTime ?? '08:00',
            end: r.endTime ?? '17:00',
          ));
    }
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _today => _day(DateTime.now());

  List<RegSlot> _approvedOn(DateTime d) =>
      (_data?.registrations ?? const []).where((r) => r.status == 'APPROVED' && _day(r.workDate) == d).toList();

  List<RegSlot> _rejectedOn(DateTime d) =>
      (_data?.registrations ?? const []).where((r) => r.status == 'REJECTED' && _day(r.workDate) == d).toList();

  bool _dayEditable(DateTime d) => (_data?.editable ?? false) && !d.isBefore(_today) && _approvedOn(d).isEmpty;

  (int days, int minutes) get _totals {
    final days = <DateTime>{};
    var minutes = 0;
    final shifts = {for (final x in _data?.shifts ?? const <RegShiftOption>[]) x.id: x};
    _drafts.forEach((d, list) {
      if (list.isEmpty) return;
      days.add(d);
      for (final x in list) {
        if (x.kind == 'CUSTOM') minutes += regSlotMinutes(x.start, x.end);
        if (x.kind == 'SHIFT' && shifts[x.shiftId] != null) {
          minutes += regSlotMinutes(shifts[x.shiftId]!.startTime, shifts[x.shiftId]!.endTime);
        }
      }
    });
    for (final r in _data?.registrations ?? const <RegSlot>[]) {
      if (r.status != 'APPROVED') continue;
      days.add(_day(r.workDate));
      if (r.startTime != null && r.endTime != null) minutes += regSlotMinutes(r.startTime!, r.endTime!);
    }
    return (days.length, minutes);
  }

  String? _problem(AppLocalizations s, List<_Draft> list) {
    final shifts = {for (final x in _data?.shifts ?? const <RegShiftOption>[]) x.id: x};
    if (list.any((x) => x.kind == 'SHIFT' && shifts[x.shiftId] == null)) return s.shiftRegPickShift;
    final p = validateRegDay([
      for (final x in list)
        (
          any: x.kind == 'ANY',
          start: x.kind == 'SHIFT' ? shifts[x.shiftId]!.startTime : x.start,
          end: x.kind == 'SHIFT' ? shifts[x.shiftId]!.endTime : x.end,
        ),
    ]);
    return switch (p) {
      RegDayProblem.tooMany => s.shiftRegTooManySlots,
      RegDayProblem.anyAlone => s.shiftRegAnyAlone,
      RegDayProblem.overlap => s.shiftRegOverlap,
      RegDayProblem.invalidTime => s.shiftRegInvalidTime,
      null => null,
    };
  }

  Future<void> _save() async {
    final s = AppLocalizations.of(context);
    final data = _data;
    if (data == null) return;
    for (final list in _drafts.values) {
      final p = _problem(s, list);
      if (p != null) {
        _toast(p, ok: false);
        return;
      }
    }
    final slots = <RegSlot>[];
    _drafts.forEach((d, list) {
      for (final x in list) {
        slots.add(RegSlot(
          workDate: d,
          kind: x.kind,
          shiftId: x.kind == 'SHIFT' ? x.shiftId : null,
          startTime: x.kind == 'CUSTOM' ? x.start : null,
          endTime: x.kind == 'CUSTOM' ? x.end : null,
        ));
      }
    });
    setState(() => _isSaving = true);
    try {
      final saved = await _repo.saveMine(data.round.id, slots);
      if (!mounted) return;
      setState(() => _applyData(saved));
      _toast(s.shiftRegSaved);
    } catch (e) {
      _toast(serverMsg(e), ok: false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toast(String msg, {bool ok = true}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: ok ? AppTheme.secondary : AppTheme.error));

  Future<String?> _pickTime(String current) async {
    final m = regTimeToMinutes(current) ?? 480;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return null;
    return regMinutesToTime(t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline, message: _error!, actionLabel: s.retry, onAction: _loadRounds);
    }
    final data = _data;
    if (data == null) {
      return EmptyState(icon: Icons.edit_calendar_outlined, message: s.shiftRegNoOpenRound);
    }
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final round = data.round;
    final (days, minutes) = _totals;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: RefreshIndicator(
                onRefresh: _loadRounds,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  children: [
                    if (_rounds.length > 1) ...[
                      AppDropdown<int>(
                        value: _roundId,
                        label: s.shiftRegRound,
                        items: [for (final r in _rounds) DropdownMenuItem(value: r.id, child: Text(r.name))],
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _roundId = v);
                          try {
                            await _loadRound(v);
                          } catch (e) {
                            _toast(serverMsg(e), ok: false);
                          }
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    _RoundBanner(round: round, editable: data.editable, localeTag: localeTag),
                    const SizedBox(height: 10),
                    for (final d in round.days) _dayCard(s, d, localeTag, data),
                  ],
                ),
              ),
            ),
          ),
        ),
        Material(
          color: AppTheme.background,
          elevation: 4,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.shiftRegTotals(days, formatRegHours(minutes)),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        if (round.minDays != null)
                          Text(s.shiftRegMinDaysHint(round.minDays!),
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  if (data.editable)
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_outlined, size: 18),
                      label: Text(data.registrations.isEmpty ? s.shiftRegSubmit : s.shiftRegUpdate),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayCard(AppLocalizations s, DateTime d, String localeTag, MyRegRound data) {
    final editable = _dayEditable(d);
    final approved = _approvedOn(d);
    final rejected = _rejectedOn(d);
    final list = _drafts[d] ?? const <_Draft>[];
    final on = list.isNotEmpty;
    final weekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
    final problem = on ? _problem(s, list) : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEEE, dd/MM', localeTag).format(d),
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14, color: weekend ? AppTheme.error : AppTheme.textPrimary)),
                      if (!on && approved.isEmpty)
                        Text(s.shiftRegNotWorking, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                if (approved.isNotEmpty) StatusBadge.requestStatus('APPROVED', s),
                if (approved.isEmpty && on && rejected.isNotEmpty) StatusBadge.requestStatus('REJECTED', s),
                if (editable)
                  Switch(
                    value: on,
                    onChanged: (v) => setState(() {
                      if (v) {
                        _drafts[d] = [_Draft(kind: data.shifts.isNotEmpty ? 'SHIFT' : 'CUSTOM', shiftId: data.shifts.firstOrNull?.id)];
                      } else {
                        _drafts.remove(d);
                      }
                    }),
                  ),
              ],
            ),
            for (final r in approved)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_slotText(s, r), style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ),
            if (on)
              for (var i = 0; i < list.length; i++) _slotEditor(s, d, list, i, data, editable),
            if (on && editable && list.length < maxRegSlotsPerDay && list.every((x) => x.kind != 'ANY'))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => list.add(_Draft(kind: 'CUSTOM', start: '17:00', end: '22:00'))),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(s.shiftRegAddSlot),
                ),
              ),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(problem, style: const TextStyle(fontSize: 12, color: AppTheme.error)),
              ),
          ],
        ),
      ),
    );
  }

  String _slotText(AppLocalizations s, RegSlot r) {
    if (r.isAny) return s.shiftRegAnyTime;
    final time = '${r.startTime ?? ''}–${r.endTime ?? ''}';
    return r.shiftCode != null ? '${r.shiftCode} · $time' : time;
  }

  Widget _slotEditor(AppLocalizations s, DateTime d, List<_Draft> list, int i, MyRegRound data, bool editable) {
    final x = list[i];
    final kinds = <(String, String)>[
      if (data.shifts.isNotEmpty) ('SHIFT', s.shiftRegKindShift),
      ('CUSTOM', s.shiftRegKindCustom),
      if (list.length == 1) ('ANY', s.shiftRegKindAny),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (k, label) in kinds)
                      ChoiceChip(
                        label: Text(label, style: const TextStyle(fontSize: 12)),
                        selected: x.kind == k,
                        visualDensity: VisualDensity.compact,
                        onSelected: editable
                            ? (_) => setState(() {
                                  x.kind = k;
                                  if (k == 'SHIFT') x.shiftId ??= data.shifts.firstOrNull?.id;
                                })
                            : null,
                      ),
                  ],
                ),
              ),
              if (editable && list.length > 1)
                IconButton(
                  tooltip: s.delete,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => list.removeAt(i)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (x.kind == 'SHIFT')
            AppDropdown<int>(
              value: data.shifts.any((o) => o.id == x.shiftId) ? x.shiftId : null,
              label: s.shiftRegShift,
              items: [
                for (final o in data.shifts)
                  DropdownMenuItem(value: o.id, child: Text('${o.code} · ${o.startTime}–${o.endTime}')),
              ],
              onChanged: editable ? (v) => setState(() => x.shiftId = v) : null,
            ),
          if (x.kind == 'CUSTOM')
            Row(
              children: [
                _TimeButton(
                  value: x.start,
                  onTap: editable
                      ? () async {
                          final t = await _pickTime(x.start);
                          if (t != null) setState(() => x.start = t);
                        }
                      : null,
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
                _TimeButton(
                  value: x.end,
                  onTap: editable
                      ? () async {
                          final t = await _pickTime(x.end);
                          if (t != null) setState(() => x.end = t);
                        }
                      : null,
                ),
                const SizedBox(width: 10),
                Text(s.shiftRegHours(formatRegHours(regSlotMinutes(x.start, x.end))),
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          if (x.kind == 'ANY')
            Text(s.shiftRegAnyHelper, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String value;
  final VoidCallback? onTap;
  const _TimeButton({required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.schedule, size: 16),
      label: Text(value, style: const TextStyle(fontSize: 14)),
    );
  }
}

class _RoundBanner extends StatelessWidget {
  final RegRound round;
  final bool editable;
  final String localeTag;
  const _RoundBanner({required this.round, required this.editable, required this.localeTag});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final df = DateFormat('dd/MM/yyyy');
    final lines = <String>[
      '${df.format(round.fromDate)} – ${df.format(round.toDate)}',
      if (round.closesAt != null) s.shiftRegDeadline(DateFormat('dd/MM HH:mm').format(round.closesAt!)),
      if (round.earliestTime != null && round.latestTime != null) s.shiftRegWindow(round.earliestTime!, round.latestTime!),
      if (round.note != null && round.note!.isNotEmpty) round.note!,
    ];
    final color = editable ? AppTheme.primary : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.tint(color),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_calendar_outlined, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(round.name, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                for (final l in lines) Text(l, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                if (!editable) Text(s.shiftRegClosedHint, style: const TextStyle(fontSize: 12, color: AppTheme.warning)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
