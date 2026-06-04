import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dashboard.dart';
import '../../../data/repositories/dashboard_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = DashboardRepository();

  DashboardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.get();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _loading
                ? const _LoadingBody()
                : _error != null
                    ? _ErrorBody(message: s.dashboardErrorLoad, onRetry: _load)
                    : _Body(data: _data!, s: s, onRefresh: _load),
          ),
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(message,
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  final DashboardData data;
  final AppLocalizations s;
  final VoidCallback onRefresh;
  const _Body({required this.data, required this.s, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(s.todayStatistics),
        const SizedBox(height: 12),
        _StatsGrid(stats: data.todayStats, s: s),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 3,
                    child: _AttendanceTodayCard(
                        rows: data.todayAttendance, s: s)),
                const SizedBox(width: 20),
                Expanded(
                    flex: 2,
                    child:
                        _RecentPayrollCard(payroll: data.recentPayroll, s: s)),
              ],
            );
          }
          return Column(children: [
            _AttendanceTodayCard(rows: data.todayAttendance, s: s),
            const SizedBox(height: 20),
            _RecentPayrollCard(payroll: data.recentPayroll, s: s),
          ]);
        }),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      );
}

class _StatsGrid extends StatelessWidget {
  final DashboardTodayStats stats;
  final AppLocalizations s;
  const _StatsGrid({required this.stats, required this.s});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(s.employees, stats.totalEmployees.toString(),
          Icons.people_outline, AppTheme.primary),
      _StatItem(s.present, stats.present.toString(),
          Icons.check_circle_outline, AppTheme.secondary),
      _StatItem(s.dashboardOnLeave, stats.onLeave.toString(),
          Icons.beach_access_outlined, AppTheme.warning),
      _StatItem(s.absent, stats.absent.toString(), Icons.cancel_outlined,
          AppTheme.error),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 500;
      return GridView.count(
        crossAxisCount: isNarrow ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: isNarrow ? 1.6 : 2.0,
        children: items.map(_buildCard).toList(),
      );
    });
  }

  Widget _buildCard(_StatItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: item.color,
                    )),
                Text(item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTodayCard extends StatelessWidget {
  final List<DashboardAttendanceRow> rows;
  final AppLocalizations s;
  const _AttendanceTodayCard({required this.rows, required this.s});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.todayAttendance,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(s.dashboardNoAttendance,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ),
              )
            else
              ...rows.map((r) => _AttendanceRow(row: r, s: s)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final DashboardAttendanceRow row;
  final AppLocalizations s;
  const _AttendanceRow({required this.row, required this.s});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final checkInStr = row.checkIn != null
        ? timeFmt.format(row.checkIn!)
        : null;
    final checkOutStr = row.checkOut != null
        ? timeFmt.format(row.checkOut!)
        : null;

    final nameInitial =
        row.employeeName.isNotEmpty ? row.employeeName[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Text(nameInitial,
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.employeeName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary)),
                Text(row.departmentName ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (checkInStr != null)
                Text(s.dashboardCheckIn(checkInStr),
                    style: TextStyle(
                        fontSize: 12,
                        color: row.late ? AppTheme.error : AppTheme.secondary))
              else
                Text(s.dashboardNotCheckedIn,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              if (checkOutStr != null)
                Text(s.dashboardCheckOut(checkOutStr),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentPayrollCard extends StatelessWidget {
  final DashboardRecentPayroll? payroll;
  final AppLocalizations s;
  const _RecentPayrollCard({required this.payroll, required this.s});

  String _statusLabel(String status, AppLocalizations s) => switch (status) {
        'PAID' => s.dashboardPayrollPaid,
        'APPROVED' => s.dashboardPayrollApproved,
        _ => s.dashboardPayrollDraft,
      };

  Color _statusColor(String status) => switch (status) {
        'PAID' => AppTheme.secondary,
        'APPROVED' => AppTheme.primary,
        _ => AppTheme.warning,
      };

  @override
  Widget build(BuildContext context) {
    final currencyFmt =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.recentPayroll,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (payroll != null)
              Text(
                DateFormat.yMMMM(s.localeName)
                    .format(DateTime(payroll!.year, payroll!.month)),
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            const SizedBox(height: 16),
            if (payroll == null)
              Center(
                child: Text(s.dashboardNoPayroll,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              )
            else ...[
              _buildStat(s.totalSalary,
                  currencyFmt.format(payroll!.totalNetSalary), AppTheme.primary),
              const Divider(height: 24),
              _buildStat(s.employeeCount, payroll!.employeeCount.toString(),
                  AppTheme.secondary),
              const Divider(height: 24),
              _buildStat(s.status, _statusLabel(payroll!.status, s),
                  _statusColor(payroll!.status)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}
