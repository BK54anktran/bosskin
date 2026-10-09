import 'package:flutter/material.dart';
import '../../../data/services/auth_service.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import 'attendance_shared.dart';
import 'tabs/attendance_timesheet_tab.dart';
import 'tabs/attendance_day_tab.dart';
import 'widgets/bulk_approve_dialog.dart';
import 'widgets/period_lock_dialog.dart';
export 'tabs/attendance_day_tab.dart' show AttendanceDayTabKey;

// ── Screen ────────────────────────────────────────────────────────────────────

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _dayKey    = AttendanceDayTabKey();
  final _monthKey  = AttendanceTimesheetTabKey();
  final _weekKey   = AttendanceTimesheetTabKey();
  final _customKey = AttendanceTimesheetTabKey();

  AttendanceTimesheetTabKey? get _activeTimesheetKey => switch (_tab.index) {
    1 => _weekKey, 2 => _monthKey, 3 => _customKey, _ => null,
  };

  bool _exporting = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isSysAdmin = AuthService.instance.currentUser?.isSystemAdmin ?? false;
    final canView   = isSysAdmin || (AuthService.instance.currentUser?.can('ATTENDANCE_VIEW')   ?? false);
    final canManage = isSysAdmin || (AuthService.instance.currentUser?.can('ATTENDANCE_MANAGE') ?? false);
    final canApprove = canView &&
        (isSysAdmin || (AuthService.instance.currentUser?.can('ATTENDANCE_APPROVE') ?? false));
    final canLockPeriod = canView &&
        (isSysAdmin || (AuthService.instance.currentUser?.can('ATTENDANCE_PERIOD_LOCK') ?? false));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, right: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Flexible(
                child: TabBar(
                  controller: _tab,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: s.byDay),
                    Tab(text: s.viewRangeWeek),
                    Tab(text: s.byMonth),
                    Tab(text: s.viewRangeCustom),
                  ],
                  onTap: (_) => setState(() {}),
                ),
              ),
              if (canView || canManage) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (canApprove) ...[
                      OutlinedButton.icon(
                        onPressed: () async {
                          final changed = await showBulkApproveDialog(context);
                          if (changed == true) {
                            if (_tab.index == 0) {
                              await _dayKey.reload();
                            } else {
                              await _activeTimesheetKey?.reload();
                            }
                          }
                        },
                        icon: const Icon(Icons.done_all, size: 16),
                        label: Text(s.bulkApproveMonthButton),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (canLockPeriod) ...[
                      OutlinedButton.icon(
                        onPressed: () => showPeriodLockDialog(context),
                        icon: const Icon(Icons.lock_clock_outlined, size: 16),
                        label: Text(s.periodLockButton),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: _exporting ? null : () async {
                        setState(() => _exporting = true);
                        if (_tab.index == 0) {
                          await _dayKey.exportExcel();
                        } else {
                          await _activeTimesheetKey?.exportExcel();
                        }
                        if (mounted) setState(() => _exporting = false);
                      },
                      icon: _exporting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_outlined, size: 16),
                      label: Text(s.exportExcel),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _importing ? null : () async {
                          setState(() => _importing = true);
                          if (_tab.index == 0) {
                            await _dayKey.importExcel();
                          } else {
                            await _activeTimesheetKey?.importExcel();
                          }
                          if (mounted) setState(() => _importing = false);
                        },
                        icon: _importing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_outlined, size: 16),
                        label: Text(s.importExcel),
                      ),
                    ],
                  ]),
                ),
              ],
            ]),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              AttendanceDayTab(key: _dayKey),
              AttendanceTimesheetTab(key: _weekKey,   initialMode: AttViewRangeMode.week),
              AttendanceTimesheetTab(key: _monthKey,  initialMode: AttViewRangeMode.payroll),
              AttendanceTimesheetTab(key: _customKey, initialMode: AttViewRangeMode.custom),
            ],
          ),
        ),
      ],
    );
  }
}
