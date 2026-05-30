import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(s.todayStatistics),
              const SizedBox(height: 12),
              _StatsRow(s: s),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _AttendanceTodayCard(s: s)),
                      SizedBox(width: 20),
                      Expanded(flex: 2, child: _RecentPayrollCard(s: s)),
                    ],
                  );
                }
                return Column(children: [
                  _AttendanceTodayCard(s: s),
                  SizedBox(height: 20),
                  _RecentPayrollCard(s: s),
                ]);
              }),
            ],
          ),
        ),
      ),
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

class _StatsRow extends StatelessWidget {
  final AppLocalizations s;
  const _StatsRow({required this.s});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(s.employees, '124', Icons.people_outline, AppTheme.primary),
      _StatItem(
          s.present, '98', Icons.check_circle_outline, AppTheme.secondary),
      _StatItem(s.leave, '8', Icons.beach_access_outlined, AppTheme.warning),
      _StatItem(s.absent, '18', Icons.cancel_outlined, AppTheme.error),
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
        children: stats.map(_buildCard).toList(),
      );
    });
  }

  Widget _buildCard(_StatItem s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: s.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(s.icon, color: s.color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(s.value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: s.color,
                    )),
                Text(s.label,
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
  final AppLocalizations s;
  const _AttendanceTodayCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.todayAttendance,
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                TextButton(onPressed: () {}, child: Text(s.viewAll)),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(5, (i) => _AttendanceRow(index: i)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final int index;
  const _AttendanceRow({required this.index});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final names = List.generate(5, (i) => '${s.employeeShort} ${i + 1}');
    final times = ['08:02', '08:15', '08:05', '08:30', '07:58'];
    final late = [false, true, false, true, false];
    final depts = List.generate(5, (_) => s.department);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            child: Text(names[index][0],
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(names[index],
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary)),
                Text(depts[index],
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(times[index],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          late[index] ? AppTheme.error : AppTheme.secondary)),
              Text(late[index] ? s.late : s.onTime,
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          late[index] ? AppTheme.error : AppTheme.secondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentPayrollCard extends StatelessWidget {
  final AppLocalizations s;
  const _RecentPayrollCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.recentPayroll,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(DateFormat.yMMMM(s.localeName).format(DateTime(2026, 5)),
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            _buildPayrollStat(s.totalSalary, '245,000,000 ₫', AppTheme.primary),
            const Divider(height: 24),
            _buildPayrollStat(s.employeeCount, '124', AppTheme.secondary),
            const Divider(height: 24),
            _buildPayrollStat(s.status, s.paidStatus, AppTheme.secondary),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                child: Text(s.viewDetails),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollStat(String label, String value, Color color) {
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
