import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/repositories/shift_plan_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

/// Đổi ca / nhường ca (Mốc 2b): nhân viên gửi yêu cầu, người có quyền SHIFT_SWAP_APPROVE duyệt.
class ShiftSwapScreen extends StatefulWidget {
  const ShiftSwapScreen({super.key});

  @override
  State<ShiftSwapScreen> createState() => _ShiftSwapScreenState();
}

class _ShiftSwapScreenState extends State<ShiftSwapScreen> {
  final _repo = ShiftPlanRepository();
  List<ShiftSwap> _items = const [];
  String? _status = 'PENDING';
  bool _isLoading = true;
  String? _error;
  int? _busyId;

  bool get _canApprove {
    final u = AuthService.instance.currentUser;
    return (u?.isSystemAdmin ?? false) || (u?.can('SHIFT_SWAP_APPROVE') ?? false);
  }

  bool get _canRequest {
    final u = AuthService.instance.currentUser;
    return !AuthService.instance.isImpersonating && (u?.can('ATTENDANCE_SELF') ?? false) && u?.employeeId != null;
  }

  int? get _myEmployeeId => AuthService.instance.currentUser?.employeeId;

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
      final list = await _repo.getSwaps(status: _status);
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {bool ok = true}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? AppTheme.secondary : AppTheme.error));

  Future<void> _act(ShiftSwap r, Future<void> Function() action, String okMsg) async {
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

  Future<void> _onReject(ShiftSwap r) async {
    final s = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final note = await showInstantDialog<String>(
      context,
      (ctx) => AlertDialog(
        title: Text(s.swapRejectTitle),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: s.reason)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(s.swapReject)),
        ],
      ),
    );
    ctrl.dispose();
    if (note == null) return;
    await _act(r, () => _repo.rejectSwap(r.id, note: note.isEmpty ? null : note), s.swapRejected);
  }

  Future<void> _onCreate() async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(context, (ctx) => const _CreateSwapDialog());
    if (ok == true) {
      _toast(s.swapSent);
      _load();
    }
  }


  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final st in [('PENDING', s.pending), (null, s.all)])
            ChoiceChip(
              label: Text(st.$2),
              selected: _status == st.$1,
              onSelected: (_) {
                setState(() => _status = st.$1);
                _load();
              },
            ),
          if (_canRequest)
            FilledButton.icon(
              onPressed: _onCreate,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(s.swapCreate),
            ),
        ]),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
                : _items.isEmpty
                    ? EmptyState(message: s.swapEmpty)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final r = _items[i];
                          final pending = r.status == 'PENDING';
                          final mine = _myEmployeeId != null && r.requesterId == _myEmployeeId;
                          final involved = mine || (_myEmployeeId != null && r.targetEmployeeId == _myEmployeeId);
                          final busy = _busyId == r.id;
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Icon(r.kind == 'GIVE' ? Icons.redo : Icons.swap_horiz, size: 18, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    r.kind == 'GIVE'
                                        ? s.swapGiveTitle(r.requesterName, r.targetEmployeeName)
                                        : s.swapSwapTitle(r.requesterName, r.targetEmployeeName),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                StatusBadge.requestStatus(r.status, s),
                              ]),
                              if (StatusBadge.managerStep(s,
                                      awaitingManagerName: r.awaitingManagerName,
                                      managerApprovedByName: r.managerApprovedByName) case final badge?)
                                Padding(padding: const EdgeInsets.only(top: 6), child: badge),
                              const SizedBox(height: 8),
                              Text('${r.requesterName}: ${r.requesterDate} · ${r.requesterShift}'),
                              if (r.kind == 'SWAP')
                                Text('${r.targetEmployeeName}: ${r.targetDate ?? ''} · ${r.targetShift ?? ''}'),
                              if ((r.reason ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('${s.reason}: ${r.reason}',
                                      style: TextStyle(color: AppTheme.textSecondary)),
                                ),
                              if ((r.adminNote ?? '').isNotEmpty || r.processedByName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    [r.processedByName, r.adminNote].where((x) => (x ?? '').isNotEmpty).join(' · '),
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ),
                              if (pending && ((_canApprove && !involved) || mine)) ...[
                                const SizedBox(height: 10),
                                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  if (busy)
                                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  else ...[
                                    if (mine)
                                      TextButton(
                                        onPressed: () => _act(r, () => _repo.cancelSwap(r.id), s.swapCancelled),
                                        child: Text(s.cancel),
                                      ),
                                    if (_canApprove && !involved) ...[
                                      OutlinedButton(onPressed: () => _onReject(r), child: Text(s.swapReject)),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: () => _act(r, () => _repo.approveSwap(r.id), s.swapApproved),
                                        child: Text(s.approve),
                                      ),
                                    ],
                                  ],
                                ]),
                              ],
                            ]),
                          );
                        },
                      ),
      ),
    ]);
  }
}

class _CreateSwapDialog extends StatefulWidget {
  const _CreateSwapDialog();

  @override
  State<_CreateSwapDialog> createState() => _CreateSwapDialogState();
}

class _CreateSwapDialogState extends State<_CreateSwapDialog> {
  final _repo = ShiftPlanRepository();
  final _reasonCtrl = TextEditingController();
  List<ShiftOption> _myShifts = const [];
  List<SwapColleague> _colleagues = const [];
  ShiftOption? _mine;
  int? _targetEmployeeId;
  /// null = nhường ca, còn lại = id ca của đồng nghiệp để đổi
  int? _targetAssignmentId;
  bool _isLoading = true;
  bool _isSaving = false;

  String? get _selectedKey =>
      _targetEmployeeId == null ? null : '$_targetEmployeeId:${_targetAssignmentId ?? 'give'}';

  @override
  void initState() {
    super.initState();
    _repo.myShifts().then((list) {
      if (mounted) setState(() { _myShifts = list; _isLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMine(ShiftOption? o) async {
    setState(() {
      _mine = o;
      _colleagues = const [];
      _targetEmployeeId = null;
      _targetAssignmentId = null;
    });
    if (o == null) return;
    try {
      final list = await _repo.colleagues(o.assignmentId);
      if (mounted) setState(() => _colleagues = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(serverMsg(e))));
      }
    }
  }

  Future<void> _send() async {
    if (_mine == null || _targetEmployeeId == null) return;
    setState(() => _isSaving = true);
    try {
      await _repo.createSwap(
        requesterAssignmentId: _mine!.assignmentId,
        targetEmployeeId: _targetEmployeeId!,
        targetAssignmentId: _targetAssignmentId,
        reason: _reasonCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.swapCreate),
      content: SizedBox(
        width: 520,
        height: 480,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<int>(
                  initialValue: _mine?.assignmentId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s.swapMyShift),
                  items: [
                    for (final o in _myShifts)
                      DropdownMenuItem(value: o.assignmentId, child: Text('${o.date} · ${o.label}')),
                  ],
                  onChanged: (v) => _pickMine(_myShifts.where((o) => o.assignmentId == v).firstOrNull),
                ),
                if (_myShifts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(s.swapNoUpcoming, style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                const SizedBox(height: 8),
                if (_mine != null) Text(s.swapPickColleague, style: const TextStyle(fontWeight: FontWeight.w600)),
                Expanded(
                  child: ListView(children: [
                    for (final c in _colleagues) ...[
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.fullName),
                        subtitle: Text(c.departmentName ?? ''),
                      ),
                      RadioListTile<String>(
                        dense: true,
                        value: '${c.employeeId}:give',
                        groupValue: _selectedKey,
                        title: Text(s.swapGiveOption),
                        onChanged: (_) => setState(() {
                          _targetEmployeeId = c.employeeId;
                          _targetAssignmentId = null;
                        }),
                      ),
                      for (final o in c.shifts)
                        RadioListTile<String>(
                          dense: true,
                          value: '${c.employeeId}:${o.assignmentId}',
                          groupValue: _selectedKey,
                          title: Text(s.swapWithShift(o.label)),
                          onChanged: (_) => setState(() {
                            _targetEmployeeId = c.employeeId;
                            _targetAssignmentId = o.assignmentId;
                          }),
                        ),
                      const Divider(height: 1),
                    ],
                  ]),
                ),
                TextField(controller: _reasonCtrl, decoration: InputDecoration(labelText: s.reason)),
              ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _isSaving || _mine == null || _targetEmployeeId == null ? null : _send,
          child: Text(s.swapSend),
        ),
      ],
    );
  }
}
