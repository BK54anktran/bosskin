import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dashboard.dart';
import '../../../data/models/department_model.dart';
import '../../../data/repositories/company_setting_repository.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../data/services/department_service.dart';
import '../../widgets/department_picker_field.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum _DashTab { overview, attendance, analytics }
enum _AttendancePeriod { week, month, custom }

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _repo = DashboardRepository();
  final _settingRepo = CompanySettingRepository();
  late TabController _tabCtrl;
  int _cutoffDay = 1;

  // Overview
  DashboardData? _dayData;
  bool _dayLoading = true;
  String? _dayError;
  DateTime _date = DateTime.now();

  DashboardKpiData? _kpiData;
  bool _kpiLoading = true;

  DashboardRiskData? _riskData;
  bool _riskLoading = true;

  // Attendance
  _AttendancePeriod _attendancePeriod = _AttendancePeriod.week;
  DashboardRangeData? _attendanceData;
  bool _attendanceLoading = false;
  String? _attendanceError;
  DateTime _rangeFrom = DateTime.now().subtract(const Duration(days: 6));
  DateTime _rangeTo = DateTime.now();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  // Analytics
  DashboardAnalyticsData? _analyticsData;
  bool _analyticsLoading = false;
  String? _analyticsError;
  int _analyticsYear = DateTime.now().year;

  // Shared
  List<DepartmentFlat> _departments = [];
  int? _deptId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    _loadDepts();
    _loadCutoffDay();
    _loadDay();
    _loadKpi();
    _loadRisks();
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final tab = _DashTab.values[_tabCtrl.index];
    if (tab == _DashTab.attendance && _attendanceData == null && !_attendanceLoading) {
      _loadAttendance();
    } else if (tab == _DashTab.analytics && _analyticsData == null && !_analyticsLoading) {
      _loadAnalytics();
    }
  }

  Future<void> _loadCutoffDay() async {
    try {
      final settings = await _settingRepo.get();
      final payroll = settings['payroll'] as Map<String, dynamic>?;
      final cutoff = (payroll?['payrollCutoffDay'] as num?)?.toInt() ?? 1;
      if (mounted) setState(() => _cutoffDay = cutoff);
    } catch (_) {}
  }

  Future<void> _loadDepts() async {
    try {
      final depts = await DepartmentService.instance.getFlat();
      if (mounted) setState(() => _departments = depts);
    } catch (_) {}
  }

  Future<void> _loadDay() async {
    setState(() { _dayLoading = true; _dayError = null; });
    try {
      final data = await _repo.get(departmentId: _deptId, date: _date);
      if (mounted) setState(() => _dayData = data);
    } catch (e) {
      if (mounted) setState(() => _dayError = e.toString());
    } finally {
      if (mounted) setState(() => _dayLoading = false);
    }
  }

  Future<void> _loadKpi() async {
    setState(() => _kpiLoading = true);
    try {
      final data = await _repo.getKpi(departmentId: _deptId, date: _date);
      if (mounted) setState(() => _kpiData = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _kpiLoading = false);
    }
  }

  Future<void> _loadRisks() async {
    setState(() => _riskLoading = true);
    try {
      final data = await _repo.getRisks(departmentId: _deptId);
      if (mounted) setState(() => _riskData = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _riskLoading = false);
    }
  }

  (DateTime, DateTime) _monthPeriod() {
    if (_cutoffDay <= 1) {
      return (
        DateTime(_month.year, _month.month, 1),
        DateTime(_month.year, _month.month + 1, 0),
      );
    }
    final prev = DateTime(_month.year, _month.month - 1);
    final maxPrev = DateTime(prev.year, prev.month + 1, 0).day;
    final from = DateTime(prev.year, prev.month, _cutoffDay.clamp(1, maxPrev));
    final maxCur = DateTime(_month.year, _month.month + 1, 0).day;
    final to = DateTime(_month.year, _month.month, (_cutoffDay - 1).clamp(1, maxCur));
    return (from, to);
  }

  (DateTime, DateTime) _currentAttendanceRange() => switch (_attendancePeriod) {
    _AttendancePeriod.week => (DateTime.now().subtract(const Duration(days: 6)), DateTime.now()),
    _AttendancePeriod.month => _monthPeriod(),
    _AttendancePeriod.custom => (_rangeFrom, _rangeTo),
  };

  Future<void> _loadAttendance() async {
    setState(() { _attendanceLoading = true; _attendanceError = null; });
    try {
      final (from, to) = _currentAttendanceRange();
      final data = await _repo.getRange(from: from, to: to, departmentId: _deptId);
      if (mounted) setState(() => _attendanceData = data);
    } catch (e) {
      if (mounted) setState(() => _attendanceError = e.toString());
    } finally {
      if (mounted) setState(() => _attendanceLoading = false);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() { _analyticsLoading = true; _analyticsError = null; });
    try {
      final data = await _repo.getAnalytics(departmentId: _deptId, year: _analyticsYear);
      if (mounted) setState(() => _analyticsData = data);
    } catch (e) {
      if (mounted) setState(() => _analyticsError = e.toString());
    } finally {
      if (mounted) setState(() => _analyticsLoading = false);
    }
  }

  void _onDeptChanged(int? id) {
    final tab = _DashTab.values[_tabCtrl.index];
    setState(() {
      _deptId = id;
      _dayData = null; _dayLoading = true;
      _kpiData = null; _kpiLoading = true;
      _riskData = null; _riskLoading = true;
      _attendanceData = null; _attendanceLoading = false;
      _analyticsData = null; _analyticsLoading = false;
    });
    _loadDay();
    _loadKpi();
    _loadRisks();
    if (tab == _DashTab.attendance) _loadAttendance();
    if (tab == _DashTab.analytics) _loadAnalytics();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _date) {
      setState(() { _date = picked; _dayData = null; _kpiData = null; });
      _loadDay();
      _loadKpi();
    }
  }

  Future<void> _pickMonth() async {
    final s = AppLocalizations.of(context);
    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _MonthPickerDialog(initialYear: _month.year, initialMonth: _month.month, s: s),
    );
    if (result != null) {
      setState(() { _month = result; _attendanceData = null; });
      _loadAttendance();
    }
  }

  Future<void> _pickRangeFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rangeFrom,
      firstDate: DateTime(2020),
      lastDate: _rangeTo,
    );
    if (picked != null && picked != _rangeFrom) {
      setState(() { _rangeFrom = picked; _attendanceData = null; });
      _loadAttendance();
    }
  }

  Future<void> _pickRangeTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rangeTo,
      firstDate: _rangeFrom,
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _rangeTo) {
      setState(() { _rangeTo = picked; _attendanceData = null; });
      _loadAttendance();
    }
  }

  Future<void> _pickAnalyticsYear() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => _YearPickerDialog(
        initialYear: _analyticsYear,
        minYear: 2020,
        maxYear: DateTime.now().year,
        s: AppLocalizations.of(context),
      ),
    );
    if (picked != null && picked != _analyticsYear) {
      setState(() { _analyticsYear = picked; _analyticsData = null; });
      _loadAnalytics();
    }
  }

  Widget _datePill(String label, VoidCallback onTap) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Text(label, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(s.statistics,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(width: 12),
              AnimatedBuilder(
                animation: _tabCtrl,
                builder: (_, __) {
                  final tab = _DashTab.values[_tabCtrl.index];
                  if (tab == _DashTab.overview) {
                    final isToday = DateUtils.isSameDay(_date, DateTime.now());
                    return _datePill(
                        isToday ? s.today : DateFormat('dd/MM/yyyy').format(_date), _pickDate);
                  }
                  if (tab == _DashTab.analytics) {
                    return _datePill(_analyticsYear.toString(), _pickAnalyticsYear);
                  }
                  return const SizedBox.shrink();
                },
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: DepartmentPickerField(
                  departments: _departments,
                  value: _deptId,
                  onChanged: _onDeptChanged,
                  label: s.dashboardFilterDepartment,
                  allowAll: true,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: s.dashboardTabOverview),
                Tab(text: s.dashboardTabAttendance),
                Tab(text: s.dashboardTabAnalytics),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // OVERVIEW
              RefreshIndicator(
                onRefresh: () async { await Future.wait([_loadDay(), _loadKpi(), _loadRisks()]); },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: _OverviewBody(
                    dayData: _dayData,
                    dayLoading: _dayLoading,
                    dayError: _dayError,
                    kpiData: _kpiData,
                    kpiLoading: _kpiLoading,
                    riskData: _riskData,
                    riskLoading: _riskLoading,
                    s: s,
                    onRetry: () { _loadDay(); _loadKpi(); _loadRisks(); },
                  ),
                ),
              ),
              // ATTENDANCE
              RefreshIndicator(
                onRefresh: _loadAttendance,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: _AttendanceBody(
                    data: _attendanceData,
                    loading: _attendanceLoading,
                    error: _attendanceError,
                    period: _attendancePeriod,
                    rangeFrom: _rangeFrom,
                    rangeTo: _rangeTo,
                    month: _month,
                    cutoffDay: _cutoffDay,
                    s: s,
                    onPeriodChanged: (p) {
                      setState(() { _attendancePeriod = p; _attendanceData = null; });
                      _loadAttendance();
                    },
                    onPickMonth: _pickMonth,
                    onPickRangeFrom: _pickRangeFrom,
                    onPickRangeTo: _pickRangeTo,
                    onRetry: _loadAttendance,
                    onAutoLoad: _loadAttendance,
                  ),
                ),
              ),
              // ANALYTICS
              RefreshIndicator(
                onRefresh: _loadAnalytics,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: _analyticsLoading
                      ? const _LoadingBody()
                      : _analyticsError != null
                          ? _ErrorBody(message: s.dashboardErrorLoad, onRetry: _loadAnalytics)
                          : _analyticsData == null
                              ? _AutoLoad(onLoad: _loadAnalytics)
                              : _AnalyticsBody(data: _analyticsData!, s: s),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────────────────

class _OverviewBody extends StatelessWidget {
  final DashboardData? dayData;
  final bool dayLoading;
  final String? dayError;
  final DashboardKpiData? kpiData;
  final bool kpiLoading;
  final DashboardRiskData? riskData;
  final bool riskLoading;
  final AppLocalizations s;
  final VoidCallback onRetry;

  const _OverviewBody({
    required this.dayData,
    required this.dayLoading,
    required this.dayError,
    required this.kpiData,
    required this.kpiLoading,
    required this.riskData,
    required this.riskLoading,
    required this.s,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (dayLoading && dayData == null) return const _LoadingBody();
    if (dayError != null && dayData == null) {
      return _ErrorBody(message: s.dashboardErrorLoad, onRetry: onRetry);
    }
    if (dayData == null) return const _LoadingBody();
    final data = dayData!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiStrip(kpiData: kpiData, loading: kpiLoading, s: s),
        const SizedBox(height: 16),
        _StatsGrid(stats: data.todayStats, s: s),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 700;
          final right = Column(
            children: [
              _DayDonutChart(stats: data.todayStats, s: s),
              const SizedBox(height: 16),
              _RiskPanel(riskData: riskData, loading: riskLoading, s: s),
              const SizedBox(height: 16),
              _RecentPayrollCard(payroll: data.recentPayroll, s: s),
            ],
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _AttendanceTodayCard(rows: data.todayAttendance, s: s)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: right),
              ],
            );
          }
          return Column(children: [
            _AttendanceTodayCard(rows: data.todayAttendance, s: s),
            const SizedBox(height: 20),
            right,
          ]);
        }),
      ],
    );
  }
}

// ── KPI strip ─────────────────────────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  final DashboardKpiData? kpiData;
  final bool loading;
  final AppLocalizations s;
  const _KpiStrip({required this.kpiData, required this.loading, required this.s});

  @override
  Widget build(BuildContext context) {
    if (loading && kpiData == null) {
      return const SizedBox(height: 72, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    final d = kpiData;
    if (d == null) return const SizedBox.shrink();

    final hiresChange = d.newHiresThisMonth - d.newHiresLastMonth;
    final fmtCompact = NumberFormat.compactCurrency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final attrPct = '${d.attritionRate.toStringAsFixed(1)}%';
    final attendPct = '${d.todayAttendanceRate.toStringAsFixed(0)}%';

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 600;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _KpiCard(
            label: s.dashboardKpiNewHires,
            value: d.newHiresThisMonth.toString(),
            sub: hiresChange == 0
                ? s.dashboardKpiNoChange
                : '${hiresChange > 0 ? '+' : ''}$hiresChange ${s.dashboardKpiVsLastMonth}',
            subColor: hiresChange > 0 ? AppTheme.secondary : hiresChange < 0 ? AppTheme.error : AppTheme.textSecondary,
            icon: Icons.person_add_outlined,
            color: AppTheme.secondary,
            minWidth: isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 48) / 5,
          ),
          _KpiCard(
            label: s.dashboardKpiResigned,
            value: d.resignedThisMonth.toString(),
            sub: s.dashboardKpiThisMonth,
            subColor: d.resignedThisMonth > 0 ? AppTheme.error : AppTheme.textSecondary,
            icon: Icons.logout_outlined,
            color: d.resignedThisMonth > 0 ? AppTheme.error : AppTheme.textSecondary,
            minWidth: isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 48) / 5,
          ),
          _KpiCard(
            label: s.dashboardKpiAttritionRate,
            value: attrPct,
            sub: s.dashboardKpiThisMonth,
            subColor: AppTheme.textSecondary,
            icon: Icons.trending_down_outlined,
            color: d.attritionRate > 5 ? AppTheme.error : AppTheme.warning,
            minWidth: isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 48) / 5,
          ),
          _KpiCard(
            label: s.dashboardKpiAttendanceRate,
            value: attendPct,
            sub: s.today,
            subColor: AppTheme.textSecondary,
            icon: Icons.how_to_reg_outlined,
            color: d.todayAttendanceRate >= 80 ? AppTheme.secondary : AppTheme.warning,
            minWidth: isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 48) / 5,
          ),
          _KpiCard(
            label: s.dashboardKpiCurrentPayroll,
            value: d.currentMonthPayroll > 0 ? fmtCompact.format(d.currentMonthPayroll) : '—',
            // Kỳ gần nhất đã chốt + trạng thái theo ngôn ngữ (trước đây hiện thô "DRAFT")
            sub: d.currentMonthPayrollMonth == null
                ? ''
                : '${d.currentMonthPayrollMonth}/${d.currentMonthPayrollYear} · ${switch (d.currentMonthPayrollStatus) {
                    'PAID' => s.payrollStatusPaid,
                    'APPROVED' => s.payrollStatusApproved,
                    _ => s.payrollStatusDraft,
                  }}',
            subColor: AppTheme.textSecondary,
            icon: Icons.payments_outlined,
            color: AppTheme.primary,
            minWidth: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 48) / 5,
          ),
        ],
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final Color color, subColor;
  final IconData icon;
  final double minWidth;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.subColor,
    required this.icon,
    required this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
                  Text(label,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  if (sub.isNotEmpty)
                    Text(sub, style: TextStyle(fontSize: 10, color: subColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Risk panel ────────────────────────────────────────────────────────────────

class _RiskPanel extends StatelessWidget {
  final DashboardRiskData? riskData;
  final bool loading;
  final AppLocalizations s;
  const _RiskPanel({required this.riskData, required this.loading, required this.s});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.warning),
                const SizedBox(width: 8),
                Text(s.dashboardRisks,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (riskData != null && riskData!.totalWarnings > 0) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${riskData!.totalWarnings}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.error)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (loading && riskData == null)
              const Center(child: SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2)))
            else if (riskData == null || riskData!.totalWarnings == 0)
              Row(children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.secondary),
                const SizedBox(width: 8),
                Text(s.dashboardRisksNoWarnings,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ])
            else ...[
              if (riskData!.repeatedLate.isNotEmpty)
                _RiskSection(
                  icon: Icons.schedule_outlined,
                  color: AppTheme.warning,
                  title: s.dashboardRisksRepeatedLate,
                  count: riskData!.repeatedLate.length,
                  items: riskData!.repeatedLate.take(3).map((r) =>
                      '${r.employeeName} — ${s.dashboardRisksTimeThisMonth(r.lateDaysThisMonth)}').toList(),
                ),
              if (riskData!.missingCheckout.isNotEmpty)
                _RiskSection(
                  icon: Icons.exit_to_app_outlined,
                  color: AppTheme.error,
                  title: s.dashboardRisksMissingCheckout,
                  count: riskData!.missingCheckout.length,
                  items: riskData!.missingCheckout.take(3).map((r) =>
                      r.checkInTime != null
                          ? '${r.employeeName} — ${s.dashboardRisksCheckedInAt(r.checkInTime!)}'
                          : r.employeeName).toList(),
                ),
              if (riskData!.probationEnding.isNotEmpty)
                _RiskSection(
                  icon: Icons.timer_outlined,
                  color: AppTheme.primary,
                  title: s.dashboardRisksProbationEnding,
                  count: riskData!.probationEnding.length,
                  items: riskData!.probationEnding.take(3).map((r) =>
                      '${r.employeeName} — ${s.dashboardRisksDaysLeft(r.daysLeft)}').toList(),
                ),
              if (riskData!.contractExpiring.isNotEmpty)
                _RiskSection(
                  icon: Icons.event_busy_outlined,
                  color: AppTheme.warning,
                  title: s.dashboardRisksContractExpiring,
                  count: riskData!.contractExpiring.length,
                  items: riskData!.contractExpiring.take(3).map((r) =>
                      '${r.employeeName} (${r.contractNo}) — ${r.daysLeft >= 0 ? s.contractDaysLeft(r.daysLeft) : s.contractOverdue(-r.daysLeft)}').toList(),
                ),
              if (riskData!.documentExpiring.isNotEmpty)
                _RiskSection(
                  icon: Icons.folder_shared_outlined,
                  color: AppTheme.warning,
                  title: s.dashboardRisksDocumentExpiring,
                  count: riskData!.documentExpiring.length,
                  items: riskData!.documentExpiring.take(3).map((r) =>
                      '${r.employeeName} (${r.typeName}) — ${r.daysLeft >= 0 ? s.contractDaysLeft(r.daysLeft) : s.contractOverdue(-r.daysLeft)}').toList(),
                ),
              if (riskData!.noSalaryGrade.isNotEmpty)
                _RiskSection(
                  icon: Icons.money_off_outlined,
                  color: AppTheme.error,
                  title: s.dashboardRisksNoSalaryGrade,
                  count: riskData!.noSalaryGrade.length,
                  items: riskData!.noSalaryGrade.take(3).map((r) => r.employeeName).toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RiskSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int count;
  final List<String> items;
  const _RiskSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
          ...items.map((name) => Padding(
                padding: const EdgeInsets.only(left: 20, top: 3),
                child: Text(name,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
        ],
      ),
    );
  }
}

// ── Attendance tab ────────────────────────────────────────────────────────────

class _AttendanceBody extends StatelessWidget {
  final DashboardRangeData? data;
  final bool loading;
  final String? error;
  final _AttendancePeriod period;
  final DateTime rangeFrom, rangeTo, month;
  final int cutoffDay;
  final AppLocalizations s;
  final ValueChanged<_AttendancePeriod> onPeriodChanged;
  final VoidCallback onPickMonth, onPickRangeFrom, onPickRangeTo, onRetry, onAutoLoad;

  const _AttendanceBody({
    required this.data,
    required this.loading,
    required this.error,
    required this.period,
    required this.rangeFrom,
    required this.rangeTo,
    required this.month,
    required this.cutoffDay,
    required this.s,
    required this.onPeriodChanged,
    required this.onPickMonth,
    required this.onPickRangeFrom,
    required this.onPickRangeTo,
    required this.onRetry,
    required this.onAutoLoad,
  });

  String _monthLabel() {
    if (cutoffDay <= 1) return DateFormat('MM/yyyy').format(month);
    final prev = DateTime(month.year, month.month - 1);
    final maxPrev = DateTime(prev.year, prev.month + 1, 0).day;
    final from = DateTime(prev.year, prev.month, cutoffDay.clamp(1, maxPrev));
    final maxCur = DateTime(month.year, month.month + 1, 0).day;
    final to = DateTime(month.year, month.month, (cutoffDay - 1).clamp(1, maxCur));
    return '${DateFormat('dd/MM').format(from)} → ${DateFormat('dd/MM/yyyy').format(to)}';
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary : Colors.transparent,
              border: Border.all(color: selected ? AppTheme.primary : Colors.grey.shade400),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppTheme.textPrimary)),
          ),
        ),
      );

  Widget _datePill(String label, VoidCallback onTap) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14),
                const SizedBox(width: 5),
                Text(label, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period selector
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _pill(s.dashboardAttendancePeriodWeek, period == _AttendancePeriod.week,
                () => onPeriodChanged(_AttendancePeriod.week)),
            _pill(_monthLabel(), period == _AttendancePeriod.month,
                period == _AttendancePeriod.month ? onPickMonth : () => onPeriodChanged(_AttendancePeriod.month)),
            _pill(s.dashboardAttendancePeriodCustom, period == _AttendancePeriod.custom,
                () => onPeriodChanged(_AttendancePeriod.custom)),
            if (period == _AttendancePeriod.custom) ...[
              _datePill(DateFormat('dd/MM/yyyy').format(rangeFrom), onPickRangeFrom),
              const Text('→', style: TextStyle(color: AppTheme.textSecondary)),
              _datePill(DateFormat('dd/MM/yyyy').format(rangeTo), onPickRangeTo),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // Content
        if (loading && data == null)
          const _LoadingBody()
        else if (error != null && data == null)
          _ErrorBody(message: s.dashboardErrorLoad, onRetry: onRetry)
        else if (data == null)
          _AutoLoad(onLoad: onAutoLoad)
        else
          _RangeBody(data: data!, s: s),
      ],
    );
  }
}

// ── Loading / Error ───────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _AutoLoad extends StatefulWidget {
  final VoidCallback onLoad;
  const _AutoLoad({required this.onLoad});
  @override
  State<_AutoLoad> createState() => _AutoLoadState();
}

class _AutoLoadState extends State<_AutoLoad> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLoad());
  }

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
              Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
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

// ── Donut chart (overview) ────────────────────────────────────────────────────

class _DayDonutChart extends StatelessWidget {
  final DashboardTodayStats stats;
  final AppLocalizations s;
  const _DayDonutChart({required this.stats, required this.s});

  @override
  Widget build(BuildContext context) {
    final present = stats.present.toDouble();
    final onLeave = stats.onLeave.toDouble();
    final absent  = stats.absent.toDouble();
    final total   = present + onLeave + absent;
    if (total == 0) return const SizedBox.shrink();

    final sections = [
      if (present > 0) PieChartSectionData(
        value: present, color: AppTheme.secondary,
        title: present.toInt().toString(),
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        radius: 52,
      ),
      if (onLeave > 0) PieChartSectionData(
        value: onLeave, color: AppTheme.warning,
        title: onLeave.toInt().toString(),
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        radius: 52,
      ),
      if (absent > 0) PieChartSectionData(
        value: absent, color: AppTheme.error,
        title: absent.toInt().toString(),
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        radius: 52,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.statistics, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(PieChartData(
                      sections: sections, centerSpaceRadius: 36, sectionsSpace: 2)),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legend(AppTheme.secondary, s.present),
                      const SizedBox(height: 8),
                      _legend(AppTheme.warning, s.dashboardOnLeave),
                      const SizedBox(height: 8),
                      _legend(AppTheme.error, s.absent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      );
}

// ── Daily trend line chart (attendance tab) ───────────────────────────────────

class _RangeDailyLineChart extends StatelessWidget {
  final List<DashboardRangeDailyPoint> trend;
  final AppLocalizations s;
  const _RangeDailyLineChart({required this.trend, required this.s});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();
    final maxY = trend
        .map((d) => d.present + d.late + d.absent + d.onLeave)
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();
    if (maxY == 0) return const SizedBox.shrink();

    final presentSpots = trend.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value.present + e.value.late).toDouble()))
        .toList();
    final lateSpots = trend.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.late.toDouble()))
        .toList();
    final absentSpots = trend.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.absent.toDouble()))
        .toList();

    LineChartBarData makeLine(List<FlSpot> spots, Color color, {bool dashed = false}) =>
        LineChartBarData(
          spots: spots, isCurved: true, curveSmoothness: 0.3, color: color, barWidth: 2,
          dashArray: dashed ? [5, 3] : null,
          dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: false),
        );

    Widget legendDot(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dashboardRangeTotalWorkDays,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final step = ((trend.length / ((constraints.maxWidth - 28) / 28)).ceil()).clamp(1, trend.length);
              return SizedBox(
                height: 200,
                child: LineChart(LineChartData(
                  minX: 0, maxX: (trend.length - 1).toDouble(),
                  minY: 0, maxY: (maxY * 1.25).ceilToDouble(),
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 28, interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= trend.length || i % step != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(DateFormat('dd/MM').format(trend[i].date),
                              style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                        );
                      },
                    )),
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                          style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        if (spot.barIndex != 0) return null;
                        final i = spot.spotIndex;
                        if (i < 0 || i >= trend.length) return null;
                        final d = trend[i];
                        return LineTooltipItem(
                          '${DateFormat('dd/MM/yyyy').format(d.date)}\n'
                          '${s.present}: ${d.present + d.late}\n'
                          '${s.dashboardRangeTotalLate}: ${d.late}\n'
                          '${s.dashboardRangeTotalAbsent}: ${d.absent}',
                          const TextStyle(color: Colors.white, fontSize: 11, height: 1.5),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    makeLine(presentSpots, AppTheme.secondary),
                    makeLine(lateSpots, AppTheme.warning, dashed: true),
                    makeLine(absentSpots, AppTheme.error, dashed: true),
                  ],
                )),
              );
            }),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                legendDot(AppTheme.secondary, s.present),
                const SizedBox(width: 16),
                legendDot(AppTheme.warning, s.dashboardRangeTotalLate),
                const SizedBox(width: 16),
                legendDot(AppTheme.error, s.dashboardRangeTotalAbsent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Range body (attendance tab content) ──────────────────────────────────────

class _RangeBody extends StatelessWidget {
  final DashboardRangeData data;
  final AppLocalizations s;
  const _RangeBody({required this.data, required this.s});

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final items = [
      _StatItem(s.employees, stats.totalEmployees.toString(), Icons.people_outline, AppTheme.primary),
      _StatItem(s.dashboardRangeTotalWorkDays, stats.totalWorkDays.toString(), Icons.check_circle_outline, AppTheme.secondary),
      _StatItem(s.dashboardRangeTotalLate, stats.totalLateDays.toString(), Icons.schedule_outlined, AppTheme.warning),
      _StatItem(s.dashboardRangeTotalAbsent, stats.totalAbsentDays.toString(), Icons.cancel_outlined, AppTheme.error),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsGridRaw(items: items),
        const SizedBox(height: 24),
        _RangeDailyLineChart(trend: data.dailyTrend, s: s),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.rows.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(s.dashboardRangeNoData,
                          style: const TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else ...[
                  _RangeTableHeader(s: s),
                  const Divider(height: 8),
                  ...data.rows.map((r) => _RangeTableRow(row: r, s: s)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RangeTableHeader extends StatelessWidget {
  final AppLocalizations s;
  const _RangeTableHeader({required this.s});

  Widget _headerCell(String text) => Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary));

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(flex: 3,
                child: Text(s.employees,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
            Expanded(flex: 1, child: _headerCell(s.dashboardRangePresent)),
            Expanded(flex: 1, child: _headerCell(s.dashboardRangeTotalLate)),
            Expanded(flex: 1, child: _headerCell(s.dashboardRangeTotalAbsent)),
            Expanded(flex: 1, child: _headerCell(s.dashboardRangeTotalLeave)),
          ],
        ),
      );
}

class _RangeTableRow extends StatelessWidget {
  final DashboardRangeEmployeeRow row;
  final AppLocalizations s;
  const _RangeTableRow({required this.row, required this.s});

  @override
  Widget build(BuildContext context) {
    final nameInitial = row.employeeName.isNotEmpty ? row.employeeName[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(nameInitial,
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.employeeName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (row.departmentName != null)
                        Text(row.departmentName!,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 1, child: _numCell(row.presentDays.toString(), AppTheme.secondary)),
          Expanded(flex: 1, child: _numCell(row.lateDays.toString(), row.lateDays > 0 ? AppTheme.warning : AppTheme.textSecondary)),
          Expanded(flex: 1, child: _numCell(row.absentDays.toString(), row.absentDays > 0 ? AppTheme.error : AppTheme.textSecondary)),
          Expanded(flex: 1, child: _numCell(row.leaveDays.toString(), AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _numCell(String text, Color color) => Text(text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color));
}

// ── Stats grids ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final DashboardTodayStats stats;
  final AppLocalizations s;
  const _StatsGrid({required this.stats, required this.s});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(s.employees, stats.totalEmployees.toString(), Icons.people_outline, AppTheme.primary),
      _StatItem(s.present, stats.present.toString(), Icons.check_circle_outline, AppTheme.secondary),
      _StatItem(s.dashboardOnLeave, stats.onLeave.toString(), Icons.beach_access_outlined, AppTheme.warning),
      _StatItem(s.absent, stats.absent.toString(), Icons.cancel_outlined, AppTheme.error),
    ];
    return _StatsGridRaw(items: items);
  }
}

class _StatsGridRaw extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsGridRaw({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 500;
      final crossCount = isNarrow ? 2 : 4;
      final cardWidth = (constraints.maxWidth - 12 * (crossCount - 1)) / crossCount;
      const cardHeight = 88.0;
      return GridView.count(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12, mainAxisSpacing: 12,
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: cardWidth / cardHeight,
        children: items.map(_buildCard).toList(),
      );
    });
  }

  Widget _buildCard(_StatItem item) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
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
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: item.color)),
                  Text(item.label,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      );
}

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

// ── Attendance today card ─────────────────────────────────────────────────────

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
            Text(s.todayAttendance, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text(s.dashboardNoAttendance,
                    style: const TextStyle(color: AppTheme.textSecondary))),
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
    final checkInStr = row.checkIn != null ? timeFmt.format(row.checkIn!) : null;
    final checkOutStr = row.checkOut != null ? timeFmt.format(row.checkOut!) : null;
    final nameInitial = row.employeeName.isNotEmpty ? row.employeeName[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Text(nameInitial,
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.employeeName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                Text(row.departmentName ?? '',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (checkInStr != null)
                Text(s.dashboardCheckIn(checkInStr),
                    style: TextStyle(fontSize: 12, color: row.late ? AppTheme.error : AppTheme.secondary))
              else
                Text(s.dashboardNotCheckedIn,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              if (checkOutStr != null)
                Text(s.dashboardCheckOut(checkOutStr),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Recent payroll card ───────────────────────────────────────────────────────

class _RecentPayrollCard extends StatelessWidget {
  final DashboardRecentPayroll? payroll;
  final AppLocalizations s;
  const _RecentPayrollCard({required this.payroll, required this.s});

  String _statusLabel(String status) => switch (status) {
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
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.recentPayroll, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (payroll != null)
              Text(DateFormat.yMMMM(s.localeName).format(DateTime(payroll!.year, payroll!.month)),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            if (payroll == null)
              Center(child: Text(s.dashboardNoPayroll,
                  style: const TextStyle(color: AppTheme.textSecondary)))
            else ...[
              _buildStat(s.totalSalary, currencyFmt.format(payroll!.totalNetSalary), AppTheme.primary),
              const Divider(height: 24),
              _buildStat(s.employeeCount, payroll!.employeeCount.toString(), AppTheme.secondary),
              const Divider(height: 24),
              _buildStat(s.status, _statusLabel(payroll!.status), _statusColor(payroll!.status)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      );
}

// ── Month / Year pickers ──────────────────────────────────────────────────────

class _MonthPickerDialog extends StatefulWidget {
  final int initialYear, initialMonth;
  final AppLocalizations s;
  const _MonthPickerDialog({required this.initialYear, required this.initialMonth, required this.s});
  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year, _month;
  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _year--)),
          Text('$_year', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _year < now.year ? () => setState(() => _year++) : null,
          ),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: GridView.builder(
          shrinkWrap: true, itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, childAspectRatio: 1.4, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemBuilder: (_, i) {
            final m = i + 1;
            final isFuture = _year == now.year && m > now.month;
            final isSelected = m == _month;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: isFuture ? null : () => setState(() => _month = m),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    DateFormat.MMM().format(DateTime(2000, m)),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? Colors.white : isFuture ? AppTheme.textSecondary : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, DateTime(_year, _month)), child: Text(widget.s.apply)),
      ],
    );
  }
}

class _YearPickerDialog extends StatefulWidget {
  final int initialYear, minYear, maxYear;
  final AppLocalizations s;
  const _YearPickerDialog({required this.initialYear, required this.minYear, required this.maxYear, required this.s});
  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _year;
  @override
  void initState() { super.initState(); _year = widget.initialYear; }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.s.year),
      content: SizedBox(
        width: 280,
        child: GridView.builder(
          shrinkWrap: true,
          itemCount: widget.maxYear - widget.minYear + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, childAspectRatio: 1.6, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemBuilder: (_, i) {
            final y = widget.maxYear - i;
            final isSelected = y == _year;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _year = y),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(y.toString(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      )),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _year), child: Text(widget.s.apply)),
      ],
    );
  }
}

// ── Analytics body ────────────────────────────────────────────────────────────

class _AnalyticsBody extends StatelessWidget {
  final DashboardAnalyticsData data;
  final AppLocalizations s;
  const _AnalyticsBody({required this.data, required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OverallStatsGrid(stats: data.overallStats, year: data.year, s: s),
        const SizedBox(height: 20),
        _SalaryTrendChart(trend: data.salaryTrend, s: s),
        const SizedBox(height: 20),
        _DailyTimelineChart(trend: data.attendanceTrend, s: s),
        const SizedBox(height: 20),
        _TopLateCard(rows: data.topLate, s: s),
      ],
    );
  }
}

class _OverallStatsGrid extends StatelessWidget {
  final DashboardRangeStats stats;
  final int year;
  final AppLocalizations s;
  const _OverallStatsGrid({required this.stats, required this.year, required this.s});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(s.employees, stats.totalEmployees.toString(), Icons.people_outline, AppTheme.primary),
      _StatItem(s.dashboardRangeTotalWorkDays, stats.totalWorkDays.toString(), Icons.check_circle_outline, AppTheme.secondary),
      _StatItem(s.dashboardRangeTotalLate, stats.totalLateDays.toString(), Icons.schedule_outlined, AppTheme.warning),
      _StatItem(s.dashboardRangeTotalAbsent, stats.totalAbsentDays.toString(), Icons.cancel_outlined, AppTheme.error),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${s.dashboardAnalyticsOverall} $year',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        _StatsGridRaw(items: items),
      ],
    );
  }
}

class _SalaryTrendChart extends StatelessWidget {
  final List<DashboardMonthlySalaryStat> trend;
  final AppLocalizations s;
  const _SalaryTrendChart({required this.trend, required this.s});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();
    final fmt = NumberFormat.compactCurrency(locale: 'vi_VN', symbol: '', decimalDigits: 0);
    final maxY = trend.map((e) => e.totalNetSalary).fold(0.0, (a, b) => a > b ? a : b);
    if (maxY == 0) return const SizedBox.shrink();

    final spots = trend.map((e) => FlSpot(e.month.toDouble(), e.totalNetSalary)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dashboardAnalyticsSalaryTrend,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(LineChartData(
                minX: 1, maxX: 12, minY: 0, maxY: maxY * 1.2,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 24, interval: 1,
                    getTitlesWidget: (v, _) {
                      final month = v.toInt();
                      if (month < 1 || month > 12) return const SizedBox.shrink();
                      return Text(DateFormat.MMM().format(DateTime(2000, month)),
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary));
                    },
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(fmt.format(v),
                        style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(s.y),
                      const TextStyle(color: Colors.white, fontSize: 11),
                    )).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots, isCurved: true, color: AppTheme.primary, barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3.5, color: AppTheme.primary, strokeColor: Colors.white, strokeWidth: 1.5),
                    ),
                    belowBarData: BarAreaData(show: true, color: AppTheme.primary.withValues(alpha: 0.08)),
                  ),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyTimelineChart extends StatefulWidget {
  final List<DashboardDailyAttendanceStat> trend;
  final AppLocalizations s;
  const _DailyTimelineChart({required this.trend, required this.s});
  @override
  State<_DailyTimelineChart> createState() => _DailyTimelineChartState();
}

class _DailyTimelineChartState extends State<_DailyTimelineChart> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final trend = widget.trend;
    final s = widget.s;
    if (trend.isEmpty) return const SizedBox.shrink();

    final maxHours = trend.map((d) => d.totalHours).fold(0.0, (a, b) => a > b ? a : b);
    final maxCost  = trend.map((d) => d.estimatedCost).fold(0.0, (a, b) => a > b ? a : b);
    if (maxHours == 0 && maxCost == 0) return const SizedBox.shrink();
    final display = trend.length > 30 ? trend.sublist(trend.length - 30) : trend;
    final scale = maxCost > 0 && maxHours > 0 ? maxCost / maxHours : 1.0;

    final hoursSpots = display.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.totalHours)).toList();
    final costSpots  = display.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.estimatedCost / scale)).toList();

    final tooltipIndex = _hoverIndex != null && _hoverIndex! >= 0 && _hoverIndex! < display.length ? _hoverIndex! : null;
    final selectedDay = tooltipIndex == null ? null : display[tooltipIndex];

    final hoursBar = LineChartBarData(
      spots: hoursSpots, isCurved: true, curveSmoothness: 0.3, color: AppTheme.primary, barWidth: 2.5,
      dotData: FlDotData(getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
          radius: 3, color: AppTheme.primary, strokeColor: Colors.white, strokeWidth: 1.5)),
      belowBarData: BarAreaData(show: true, color: AppTheme.primary.withValues(alpha: 0.06)),
    );
    final costBar = LineChartBarData(
      spots: costSpots, isCurved: true, curveSmoothness: 0.3,
      color: Colors.purple.shade400, barWidth: 2.5, dashArray: [5, 3],
      dotData: FlDotData(getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
          radius: 3, color: Colors.purple.shade400, strokeColor: Colors.white, strokeWidth: 1.5)),
    );

    final fmtCompact  = NumberFormat.compactCurrency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final fmtCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dashboardAnalyticsDailyTimeline,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(s.dashboardAnalyticsDailyTimelineSubtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              const tooltipWidth = 285.0;
              final left = selectedDay == null
                  ? 12.0
                  : ((tooltipIndex! / (display.length > 1 ? (display.length - 1) : 1)) *
                          (constraints.maxWidth - tooltipWidth - 24))
                      .clamp(12.0, constraints.maxWidth - tooltipWidth - 12.0)
                      .toDouble();
              return SizedBox(
                height: 240,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    LineChart(LineChartData(
                      minY: 0, maxY: maxHours * 1.25,
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true, reservedSize: 32, interval: 1,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= display.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(DateFormat('dd/MM/yyyy').format(display[i].date),
                                  style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary)),
                            );
                          },
                        )),
                        leftTitles: AxisTitles(
                          axisNameWidget: Text(s.dashboardAnalyticsHours,
                              style: const TextStyle(fontSize: 9, color: AppTheme.primary)),
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 64,
                            getTitlesWidget: (v, meta) => SideTitleWidget(
                              axisSide: meta.axisSide, space: 2,
                              child: Text('${v.toInt()}h',
                                  style: const TextStyle(fontSize: 9, color: AppTheme.primary)),
                            ),
                          ),
                        ),
                        rightTitles: AxisTitles(
                          axisNameWidget: Text(s.totalSalary,
                              style: TextStyle(fontSize: 9, color: Colors.purple.shade400)),
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 64,
                            getTitlesWidget: (v, meta) => SideTitleWidget(
                              axisSide: meta.axisSide, space: 8,
                              child: Text(
                                v.abs() < 0.001 ? '0 ₫' : fmtCompact.format(v * scale),
                                style: TextStyle(fontSize: 9, color: Colors.purple.shade400),
                              ),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: false,
                        mouseCursorResolver: (event, response) {
                          if (response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
                            return SystemMouseCursors.basic;
                          }
                          return SystemMouseCursors.click;
                        },
                        touchCallback: (event, response) {
                          if (event is FlPointerExitEvent) {
                            if (_hoverIndex != null) setState(() => _hoverIndex = null);
                            return;
                          }
                          final spots = response?.lineBarSpots;
                          if (spots == null || spots.isEmpty) return;
                          final index = spots.first.spotIndex;
                          if (index != _hoverIndex) setState(() => _hoverIndex = index);
                        },
                      ),
                      lineBarsData: [hoursBar, costBar],
                    )),
                    if (selectedDay != null)
                      Positioned(
                        top: -156, left: left,
                        child: IgnorePointer(
                          child: _DailyTimelineHoverTooltip(
                            day: selectedDay, width: tooltipWidth, fmtCurrency: fmtCurrency, s: s),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendLine(AppTheme.primary, s.dashboardAnalyticsHours, false),
                const SizedBox(width: 24),
                _legendLine(Colors.purple.shade400, s.totalSalary, true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendLine(Color color, String label, bool dashed) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24, height: 2,
            child: CustomPaint(painter: _DashedLinePainter(color: color, dashed: dashed)),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      );
}

class _DailyTimelineHoverTooltip extends StatelessWidget {
  final DashboardDailyAttendanceStat day;
  final double width;
  final NumberFormat fmtCurrency;
  final AppLocalizations s;
  const _DailyTimelineHoverTooltip({required this.day, required this.width, required this.fmtCurrency, required this.s});

  @override
  Widget build(BuildContext context) {
    const titleStyle  = TextStyle(color: Color(0xFF111827), fontSize: 12, fontWeight: FontWeight.w700, height: 1.25);
    const bodyStyle   = TextStyle(color: Color(0xFF111827), fontSize: 11, fontWeight: FontWeight.w600, height: 1.3);
    const mutedStyle  = TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w500, height: 1.25);
    const accentStyle = TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w700, height: 1.3);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(day.date), style: titleStyle),
              const SizedBox(height: 4),
              Text('${day.totalHours.toStringAsFixed(1)}h', style: bodyStyle),
              const SizedBox(height: 2),
              Text(fmtCurrency.format(day.estimatedCost), style: accentStyle),
              if (day.gradeBreakdown.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(s.dashboardTooltipGrade, style: mutedStyle)),
                    SizedBox(width: 56, child: Text(s.dashboardTooltipHours, style: mutedStyle, textAlign: TextAlign.right)),
                    const SizedBox(width: 8),
                    SizedBox(width: 92, child: Text(s.dashboardTooltipAmount, style: mutedStyle, textAlign: TextAlign.right)),
                  ],
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: day.gradeBreakdown.map((item) {
                        final title = [
                          if ((item.salaryGradeCode ?? '').isNotEmpty) item.salaryGradeCode,
                          if ((item.salaryGradeName ?? '').isNotEmpty) item.salaryGradeName,
                        ].join(' - ');
                        final unit = item.payType == 'HOURLY' ? s.unitHour : s.unitDay;
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(title.isNotEmpty ? title : 'N/A',
                                    style: const TextStyle(color: Color(0xFF111827), fontSize: 10.5, fontWeight: FontWeight.w500, height: 1.2),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text('${item.totalHours.toStringAsFixed(1)}h / $unit',
                                    style: const TextStyle(color: Color(0xFF111827), fontSize: 10.5, fontWeight: FontWeight.w500, height: 1.2),
                                    textAlign: TextAlign.right),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 92,
                                child: Text(fmtCurrency.format(item.estimatedCost),
                                    style: const TextStyle(color: Color(0xFF111827), fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.2),
                                    textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  const Spacer(),
                  Text(s.dashboardTooltipTotal, style: accentStyle),
                  const SizedBox(width: 8),
                  Text(fmtCurrency.format(day.estimatedCost), style: accentStyle, textAlign: TextAlign.right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;
  const _DashedLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    if (!dashed) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
      return;
    }
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset((x + 5).clamp(0, size.width), size.height / 2), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => false;
}

class _TopLateCard extends StatelessWidget {
  final List<DashboardTopLateEmployee> rows;
  final AppLocalizations s;
  const _TopLateCard({required this.rows, required this.s});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxDays = rows.first.lateDays;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dashboardAnalyticsTopLate,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...rows.map((r) {
              final pct = maxDays > 0 ? r.lateDays / maxDays : 0.0;
              final nameInitial = r.employeeName.isNotEmpty ? r.employeeName[0].toUpperCase() : '?';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
                      child: Text(nameInitial,
                          style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(r.employeeName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              Text('${r.lateDays} ${s.dashboardAnalyticsLateDays}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warning)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct, backgroundColor: Colors.grey.shade100,
                              color: AppTheme.warning, minHeight: 5),
                          ),
                          if (r.departmentName != null)
                            Text(r.departmentName!,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
