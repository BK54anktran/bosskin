import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/repositories/team_approval_repository.dart';
import '../../../data/services/team_approval_service.dart';
import '../../widgets/empty_state.dart';
import '../attendance/attendance_shared.dart' show attRequestTypeLabel;

/// Bước K — quản lý trực tiếp duyệt bước 1 đơn nghỉ / sửa công / đổi ca của cấp dưới.
/// HR duyệt cuối ở các màn Nghỉ phép, Đơn chấm công, Đổi ca như cũ.
class TeamApprovalsScreen extends StatefulWidget {
  const TeamApprovalsScreen({super.key});

  @override
  State<TeamApprovalsScreen> createState() => _TeamApprovalsScreenState();
}

class _TeamApprovalsScreenState extends State<TeamApprovalsScreen> {
  final _repo = TeamApprovalRepository();
  TeamApprovals? _data;
  bool _loading = true;
  String? _error;
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await _repo.getAll();
      if (mounted) setState(() { _data = d; _loading = false; });
      TeamApprovalService.instance.refresh();
    } catch (e) {
      if (mounted) setState(() { _error = serverMsg(e); _loading = false; });
    }
  }

  void _toast(String msg, {bool ok = true}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? AppTheme.secondary : AppTheme.error));

  Future<void> _process(String kind, int id, bool approve) async {
    final s = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final note = await showInstantDialog<String>(
      context,
      (ctx) => AlertDialog(
        title: Text(approve ? s.teamApprovalsApproveTitle : s.teamApprovalsRejectTitle),
        content: TextField(
          controller: ctrl,
          maxLength: 500,
          decoration: InputDecoration(labelText: approve ? s.note : s.reason),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            style: approve ? null : FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(approve ? s.approve : s.reject),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (note == null) return;
    setState(() => _busyKey = '$kind$id');
    try {
      final n = note.isEmpty ? null : note;
      approve ? await _repo.approve(kind, id, note: n) : await _repo.reject(kind, id, note: n);
      _toast(approve ? s.teamApprovalsApproved : s.teamApprovalsRejected);
      await _load();
    } catch (e) {
      _toast(serverMsg(e), ok: false);
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)));
    }
    final d = _data!;
    if (!d.enabled) return EmptyState(icon: Icons.how_to_reg_outlined, message: s.teamApprovalsDisabled);
    if (d.reportCount == 0) return EmptyState(icon: Icons.groups_outlined, message: s.teamApprovalsNoReports);
    if (d.total == 0) {
      return EmptyState(
        icon: Icons.task_alt,
        message: s.teamApprovalsEmpty(d.reportCount),
        actionLabel: s.refresh,
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.teamApprovalsHint, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          if (d.leaves.isNotEmpty) ...[
            _SectionTitle(s.leaves, d.leaves.length),
            ...d.leaves.map((m) => _item(
                  s,
                  kind: 'LEAVE',
                  id: (m['id'] as num).toInt(),
                  icon: Icons.beach_access_outlined,
                  who: (m['employeeName'] ?? '').toString(),
                  what: _leaveText(s, m),
                  reason: m['reason'] as String?,
                )),
          ],
          if (d.attendances.isNotEmpty) ...[
            _SectionTitle(s.attendanceRequests, d.attendances.length),
            ...d.attendances.map((r) => _item(
                  s,
                  kind: 'ATTENDANCE',
                  id: r.id,
                  icon: Icons.note_add_outlined,
                  who: r.employeeName,
                  what: [
                    attRequestTypeLabel(s, r.requestType),
                    r.requestDate,
                    if (r.requestedCheckIn != null) r.requestedCheckIn!,
                    if (r.requestedCheckOut != null) r.requestedCheckOut!,
                    if (r.requestedOvertimeMinutes != null) s.teamApprovalsMinutes(r.requestedOvertimeMinutes!),
                  ].join(' · '),
                  reason: r.note,
                )),
          ],
          if (d.swaps.isNotEmpty) ...[
            _SectionTitle(s.swapMenu, d.swaps.length),
            ...d.swaps.map((r) => _item(
                  s,
                  kind: 'SWAP',
                  id: r.id,
                  icon: r.kind == 'GIVE' ? Icons.redo : Icons.swap_horiz,
                  who: r.requesterName,
                  what: [
                    r.kind == 'GIVE'
                        ? s.swapGiveTitle(r.requesterName, r.targetEmployeeName)
                        : s.swapSwapTitle(r.requesterName, r.targetEmployeeName),
                    '${r.requesterDate} · ${r.requesterShift}',
                    if (r.kind == 'SWAP') '${r.targetDate ?? ''} · ${r.targetShift ?? ''}',
                  ].join('\n'),
                  reason: r.reason,
                )),
          ],
        ],
      ),
    );
  }

  String _leaveText(AppLocalizations s, Map<String, dynamic> m) {
    final from = (m['fromDate'] ?? '').toString();
    final to = (m['toDate'] ?? '').toString();
    final range = from == to ? from : '$from → $to';
    final time = m['fromTime'] != null && m['toTime'] != null ? ' ${m['fromTime']}–${m['toTime']}' : '';
    return '${m['leaveTypeName'] ?? ''} · $range$time';
  }

  Widget _item(AppLocalizations s,
      {required String kind,
      required int id,
      required IconData icon,
      required String who,
      required String what,
      String? reason}) {
    final busy = _busyKey == '$kind$id';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(who, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          Text(what),
          if ((reason ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${s.reason}: $reason', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (busy)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              OutlinedButton(onPressed: () => _process(kind, id, false), child: Text(s.reject)),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => _process(kind, id, true), child: Text(s.approve)),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  const _SectionTitle(this.title, this.count);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text('$title ($count)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      );
}
