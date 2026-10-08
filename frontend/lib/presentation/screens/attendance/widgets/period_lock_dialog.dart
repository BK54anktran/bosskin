import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../data/repositories/attendance_repository.dart';

/// Khoá / mở lại kỳ công theo năm (A12). Mở bằng [showPeriodLockDialog].
/// Kỳ tính theo ngày chốt công trong cài đặt công ty — backend trả sẵn from/to.
Future<void> showPeriodLockDialog(BuildContext context) =>
    showInstantDialog<void>(context, (ctx) => const _PeriodLockDialog());

class _PeriodLockDialog extends StatefulWidget {
  const _PeriodLockDialog();

  @override
  State<_PeriodLockDialog> createState() => _PeriodLockDialogState();
}

class _PeriodLockDialogState extends State<_PeriodLockDialog> {
  final _repo = AttendanceRepository();
  int _year = DateTime.now().year;
  List<AttendancePeriod> _periods = const [];
  bool _isLoading = true;
  String? _error;
  int? _busyMonth;

  static final _dayFmt = DateFormat('dd/MM/yyyy');
  static final _timeFmt = DateFormat('dd/MM/yyyy HH:mm');

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
      final list = await _repo.getPeriods(_year);
      if (!mounted) return;
      setState(() => _periods = list);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _replace(AttendancePeriod p) {
    setState(() {
      _periods = [for (final x in _periods) x.month == p.month && x.year == p.year ? p : x];
    });
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _onLock(AttendancePeriod p) async {
    final s = AppLocalizations.of(context);
    final ok = await showInstantDialog<bool>(
      context,
      (ctx) => AlertDialog(
        title: Text(s.periodLockButton),
        content: Text(s.periodLockConfirm(
          '${p.month}/${p.year}', _dayFmt.format(p.from), _dayFmt.format(p.to))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.periodLockAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyMonth = p.month);
    try {
      _replace(await _repo.lockPeriod(p.year, p.month));
      _toast(s.periodLockDone);
    } catch (e) {
      _toast(serverMsg(e));
    } finally {
      if (mounted) setState(() => _busyMonth = null);
    }
  }

  Future<void> _onUnlock(AttendancePeriod p) async {
    final s = AppLocalizations.of(context);
    final reasonCtrl = TextEditingController();
    final reason = await showInstantDialog<String>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text('${s.periodUnlockAction} · ${s.periodLabel('${p.month}', '${p.year}')}'),
          content: TextField(
            controller: reasonCtrl,
            autofocus: true,
            maxLines: 3,
            onChanged: (_) => setInner(() {}),
            decoration: InputDecoration(
              hintText: s.periodUnlockReasonHint,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: reasonCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, reasonCtrl.text.trim()),
              child: Text(s.periodUnlockAction),
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || !mounted) return;
    setState(() => _busyMonth = p.month);
    try {
      _replace(await _repo.unlockPeriod(p.year, p.month, reason));
      _toast(s.periodUnlockDone);
    } catch (e) {
      _toast(serverMsg(e));
    } finally {
      if (mounted) setState(() => _busyMonth = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget body;
    if (_isLoading) {
      body = const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
      );
    } else {
      body = ListView.separated(
        shrinkWrap: true,
        itemCount: _periods.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = _periods[i];
          final busy = _busyMonth == p.month;
          final sub = <String>['${_dayFmt.format(p.from)} – ${_dayFmt.format(p.to)}'];
          if (p.locked && p.lockedAt != null) sub.add(s.periodLockedAt(_timeFmt.format(p.lockedAt!)));
          if (!p.locked && (p.unlockReason?.isNotEmpty ?? false)) sub.add(s.periodReopened(p.unlockReason!));
          return ListTile(
            leading: Icon(p.locked ? Icons.lock : Icons.lock_open,
                color: p.locked ? theme.colorScheme.primary : theme.disabledColor),
            title: Text(s.periodLabel('${p.month}', '${p.year}')),
            subtitle: Text(sub.join(' · ')),
            trailing: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : p.locked
                    ? OutlinedButton(onPressed: () => _onUnlock(p), child: Text(s.periodUnlockAction))
                    : FilledButton.tonal(onPressed: () => _onLock(p), child: Text(s.periodLockAction)),
          );
        },
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _isLoading ? null : () { _year--; _load(); },
              ),
              Expanded(
                child: Text(s.periodLockTitle('$_year'),
                    textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _isLoading ? null : () { _year++; _load(); },
              ),
              IconButton(
                tooltip: s.close,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const Divider(height: 1),
          Flexible(child: body),
        ]),
      ),
    );
  }
}
