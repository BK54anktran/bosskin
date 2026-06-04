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

enum _DashTab { day, month, range, analytics }

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _repo = DashboardRepository();
  final _settingRepo = CompanySettingRepository();
  late TabController _tabCtrl;
  int _cutoffDay = 1;

  // Day tab
  DashboardData? _dayData;
  bool _dayLoading = true;
  String? _dayError;
  DateTime _date = DateTime.now();

  // Month tab
  DashboardRangeData? _monthData;
  bool _monthLoading = false;
  String? _monthError;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  // Range tab
  DashboardRangeData? _rangeData;
  bool _rangeLoading = false;
  String? _rangeError;
  DateTime _rangeFrom = DateTime.now().subtract(const Duration(days: 6));
  DateTime _rangeTo = DateTime.now();

  // Analytics tab
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
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    _loadDepts();
    _loadCutoffDay();
    _loadDay();
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // Goi ca khi dang va sau khi doi tab de khong bo sot
    final tab = _DashTab.values[_tabCtrl.index];
    if (tab == _DashTab.month && _monthData == null && !_monthLoading) {
      _loadMonth();
    } else if (tab == _DashTab.range && _rangeData == null && !_rangeLoading) {
      _loadRange();
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
    setState(() {
      _dayLoading = true;
      _dayError = null;
    });
    try {
      final data = await _repo.get(departmentId: _deptId, date: _date);
      if (mounted) setState(() => _dayData = data);
    } catch (e) {
      if (mounted) setState(() => _dayError = e.toString());
    } finally {
      if (mounted) setState(() => _dayLoading = false);
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

  Future<void> _loadMonth() async {
    setState(() {
      _monthLoading = true;
      _monthError = null;
    });
    try {
      final (from, to) = _monthPeriod();
      final data = await _repo.getRange(from: from, to: to, departmentId: _deptId);
      if (mounted) setState(() => _monthData = data);
    } catch (e) {
      if (mounted) setState(() => _monthError = e.toString());
    } finally {
      if (mounted) setState(() => _monthLoading = false);
    }
  }

  Future<void> _loadRange() async {
    setState(() {
      _rangeLoading = true;
      _rangeError = null;
    });
    try {
      final data = await _repo.getRange(from: _rangeFrom, to: _rangeTo, departmentId: _deptId);
      if (mounted) setState(() => _rangeData = data);
    } catch (e) {
      if (mounted) setState(() => _rangeError = e.toString());
    } finally {
      if (mounted) setState(() => _rangeLoading = false);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _analyticsLoading = true;
      _analyticsError = null;
    });
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
      _dayData = null;        _dayLoading = true;
      _monthData = null;      _monthLoading = false;
      _rangeData = null;      _rangeLoading = false;
      _analyticsData = null;  _analyticsLoading = tab == _DashTab.analytics;
    });
    if (tab == _DashTab.day) _loadDay();
    else if (tab == _DashTab.month) _loadMonth();
    else if (tab == _DashTab.range) _loadRange();
    else _loadAnalytics();
  }

  Future<void> _pickAnalyticsYear() async {
    final now = DateTime.now();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => _YearPickerDialog(
        initialYear: _analyticsYear,
        minYear: 2020,
        maxYear: now.year,
        s: AppLocalizations.of(context),
      ),
    );
    if (picked != null && picked != _analyticsYear) {
      setState(() { _analyticsYear = picked; _analyticsData = null; });
      _loadAnalytics();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
      _loadDay();
    }
  }

  Future<void> _pickMonth() async {
    final s = AppLocalizations.of(context);
    int year = _month.year;
    int month = _month.month;
    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _MonthPickerDialog(
        initialYear: year,
        initialMonth: month,
        s: s,
      ),
    );
    if (result != null) {
      setState(() { _month = result; _monthData = null; });
      _loadMonth();
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
      setState(() { _rangeFrom = picked; _rangeData = null; });
      _loadRange();
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
      setState(() { _rangeTo = picked; _rangeData = null; });
      _loadRange();
    }
  }

  Widget _datePill(String label, VoidCallback onTap) {
    return MouseRegion(
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
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(
      children: [
        // Header row: title + filters
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(s.statistics,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(width: 12),
              // Date controls per tab
              AnimatedBuilder(
                animation: _tabCtrl,
                builder: (_, __) {
                  final tab = _DashTab.values[_tabCtrl.index];
                  if (tab == _DashTab.day) {
                    final isToday = DateUtils.isSameDay(_date, DateTime.now());
                    return _datePill(
                        isToday ? s.today : DateFormat('dd/MM/yyyy').format(_date),
                        _pickDate);
                  }
                  if (tab == _DashTab.month) {
                    final (mFrom, mTo) = _monthPeriod();
                    final label = _cutoffDay <= 1
                        ? DateFormat('MM/yyyy').format(_month)
                        : '${DateFormat('dd/MM').format(mFrom)} → ${DateFormat('dd/MM/yyyy').format(mTo)}';
                    return _datePill(label, _pickMonth);
                  }
                  if (tab == _DashTab.analytics) {
                    return _datePill(_analyticsYear.toString(), _pickAnalyticsYear);
                  }
                  // range
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _datePill(DateFormat('dd/MM/yyyy').format(_rangeFrom), _pickRangeFrom),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('→', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      _datePill(DateFormat('dd/MM/yyyy').format(_rangeTo), _pickRangeTo),
                    ],
                  );
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
        // TabBar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: s.dashboardTabDay),
                Tab(text: s.dashboardTabMonth),
                Tab(text: s.dashboardTabRange),
                Tab(text: s.dashboardTabAnalytics),
              ],
            ),
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // --- DAY ---
              RefreshIndicator(
                onRefresh: _loadDay,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: _dayLoading
                      ? const _LoadingBody()
                      : _dayError != null
                          ? _ErrorBody(message: s.dashboardErrorLoad, onRetry: _loadDay)
                          : _DayBody(data: _dayData!, s: s),
                ),
              ),
              // --- MONTH ---
              RefreshIndicator(
                onRefresh: _loadMonth,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: _monthLoading
                      ? const _LoadingBody()
                      : _monthError != null
                          ? _ErrorBody(message: s.dashboardErrorLoad, onRetry: _loadMonth)
                          : _monthData == null
                              ? const _LoadingBody()
                              : _RangeBody(data: _monthData!, s: s),
                ),
              ),
              // --- RANGE ---
              RefreshIndicator(
                onRefresh: _loadRange,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: _rangeLoading
                      ? const _LoadingBody()
                      : _rangeError != null
                          ? _ErrorBody(message: s.dashboardErrorLoad, onRetry: _loadRange)
                          : _rangeData == null
                              ? const _LoadingBody()
                              : _RangeBody(data: _rangeData!, s: s),
                ),
              ),
              // --- ANALYTICS ---
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

// ── Day tab ───────────────────────────────────────────────────────────────────

class _DayBody extends StatelessWidget {
  final DashboardData data;
  final AppLocalizations s;
  const _DayBody({required this.data, required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsGrid(stats: data.todayStats, s: s),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _AttendanceTodayCard(rows: data.todayAttendance, s: s)),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _DayDonutChart(stats: data.todayStats, s: s),
                      const SizedBox(height: 16),
                      _RecentPayrollCard(payroll: data.recentPayroll, s: s),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(children: [
            _AttendanceTodayCard(rows: data.todayAttendance, s: s),
            const SizedBox(height: 20),
            _DayDonutChart(stats: data.todayStats, s: s),
            const SizedBox(height: 20),
            _RecentPayrollCard(payroll: data.recentPayroll, s: s),
          ]);
        }),
      ],
    );
  }
}

// ── Donut chart (day tab) ─────────────────────────────────────────────────────

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
            Text(s.statistics,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(PieChartData(
                      sections: sections,
                      centerSpaceRadius: 36,
                      sectionsSpace: 2,
                    )),
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

// ── Daily trend line chart (range/month tab) ─────────────────────────────────

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
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: color,
          barWidth: 2,
          dashArray: dashed ? [5, 3] : null,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
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
              final step = ((trend.length / ((constraints.maxWidth - 28) / 28))
                  .ceil()).clamp(1, trend.length);
              return SizedBox(
                height: 200,
                child: LineChart(LineChartData(
                  minX: 0,
                  maxX: (trend.length - 1).toDouble(),
                  minY: 0,
                  maxY: (maxY * 1.25).ceilToDouble(),
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                          if (i % step != 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('dd/MM').format(trend[i].date),
                              style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
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
                        }).toList();
                      },
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

// ── Range / Month tab ─────────────────────────────────────────────────────────

class _RangeBody extends StatelessWidget {
  final DashboardRangeData data;
  final AppLocalizations s;
  const _RangeBody({required this.data, required this.s});

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final items = [
      _StatItem(s.employees, stats.totalEmployees.toString(),
          Icons.people_outline, AppTheme.primary),
      _StatItem(s.dashboardRangeTotalWorkDays, stats.totalWorkDays.toString(),
          Icons.check_circle_outline, AppTheme.secondary),
      _StatItem(s.dashboardRangeTotalLate, stats.totalLateDays.toString(),
          Icons.schedule_outlined, AppTheme.warning),
      _StatItem(s.dashboardRangeTotalAbsent, stats.totalAbsentDays.toString(),
          Icons.cancel_outlined, AppTheme.error),
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(s.employees,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
          Expanded(flex: 1, child: _headerCell(s.dashboardRangePresent)),
          Expanded(flex: 1, child: _headerCell(s.dashboardRangeTotalLate)),
          Expanded(flex: 1, child: _headerCell(s.dashboardRangeTotalAbsent)),
          Expanded(flex: 1, child: _headerCell(s.dashboardRangeTotalLeave)),
        ],
      ),
    );
  }
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
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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
            Text(s.todayAttendance,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
    final currencyFmt =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.recentPayroll,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (payroll != null)
              Text(
                DateFormat.yMMMM(s.localeName)
                    .format(DateTime(payroll!.year, payroll!.month)),
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            const SizedBox(height: 16),
            if (payroll == null)
              Center(
                child: Text(s.dashboardNoPayroll,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              )
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

// ── Month picker dialog ───────────────────────────────────────────────────────

class _MonthPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final AppLocalizations s;
  const _MonthPickerDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.s,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late int _month;

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
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year--),
          ),
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
          shrinkWrap: true,
          itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
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
                      color: isSelected
                          ? Colors.white
                          : isFuture
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
          child: Text(widget.s.apply),
        ),
      ],
    );
  }
}

// ── Year picker dialog ────────────────────────────────────────────────────────

class _YearPickerDialog extends StatefulWidget {
  final int initialYear;
  final int minYear;
  final int maxYear;
  final AppLocalizations s;
  const _YearPickerDialog({
    required this.initialYear,
    required this.minYear,
    required this.maxYear,
    required this.s,
  });

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
  }

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
            crossAxisCount: 4,
            childAspectRatio: 1.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
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
                  child: Text(
                    y.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _year),
          child: Text(widget.s.apply),
        ),
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
                minX: 1, maxX: 12,
                minY: 0, maxY: maxY * 1.2,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final month = v.toInt();
                      if (month < 1 || month > 12) return const SizedBox.shrink();
                      return Text(
                        DateFormat.MMM().format(DateTime(2000, month)),
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      );
                    },
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(
                      fmt.format(v),
                      style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                    ),
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
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3.5,
                        color: AppTheme.primary,
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withValues(alpha: 0.08),
                    ),
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

    final maxHours  = trend.map((d) => d.totalHours).fold(0.0, (a, b) => a > b ? a : b);
    final maxCost   = trend.map((d) => d.estimatedCost).fold(0.0, (a, b) => a > b ? a : b);
    if (maxHours == 0 && maxCost == 0) return const SizedBox.shrink();
    // Hien thi toi da 30 ngay, neu nhieu hon thi lay 30 gan nhat
    final display = trend.length > 30 ? trend.sublist(trend.length - 30) : trend;
    final scale = maxCost > 0 && maxHours > 0 ? maxCost / maxHours : 1.0;
    final hoursSpots = display.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.totalHours))
        .toList();
    final costSpots = display.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.estimatedCost / scale))
        .toList();
    final tooltipIndex = _hoverIndex != null && _hoverIndex! >= 0 && _hoverIndex! < display.length ? _hoverIndex! : null;
    final selectedDay = tooltipIndex == null ? null : display[tooltipIndex];
    final hoursBar = LineChartBarData(
      spots: hoursSpots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: AppTheme.primary,
      barWidth: 2.5,
      dotData: FlDotData(
        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
          radius: 3,
          color: AppTheme.primary,
          strokeColor: Colors.white,
          strokeWidth: 1.5,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: AppTheme.primary.withValues(alpha: 0.06),
      ),
    );
    final costBar = LineChartBarData(
      spots: costSpots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: Colors.purple.shade400,
      barWidth: 2.5,
      dashArray: [5, 3],
      dotData: FlDotData(
        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
          radius: 3,
          color: Colors.purple.shade400,
          strokeColor: Colors.white,
          strokeWidth: 1.5,
        ),
      ),
    );

    final fmtCompact = NumberFormat.compactCurrency(locale: 'vi_VN', symbol: '\u20AB', decimalDigits: 0);
    final fmtCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: '\u20AB', decimalDigits: 0);

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
            LayoutBuilder(
              builder: (context, constraints) {
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
                      LineChart(
                        LineChartData(
                  minY: 0,
                  maxY: maxHours * 1.25,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= display.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(display[i].date),
                              style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(s.dashboardAnalyticsHours,
                          style: const TextStyle(fontSize: 9, color: AppTheme.primary)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 64,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 2,
                          child: Text(
                            '${v.toInt()}h',
                            style: const TextStyle(fontSize: 9, color: AppTheme.primary),
                          ),
                        ),
                      ),
                    ),
                    rightTitles: AxisTitles(
                      axisNameWidget: Text(s.totalSalary,
                          style: TextStyle(fontSize: 9, color: Colors.purple.shade400)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 64,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 8,
                          child: Text(
                            v.abs() < 0.001 ? '0 \u20AB' : fmtCompact.format(v * scale),
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
                      if (index != _hoverIndex) {
                        setState(() => _hoverIndex = index);
                      }
                    },
                  ),
                  lineBarsData: [hoursBar, costBar],
                ),
              ),
                      if (selectedDay != null)
                        Positioned(
                          top: -156,
                          left: left,
                          child: IgnorePointer(
                            child: _DailyTimelineHoverTooltip(
                              day: selectedDay,
                              width: tooltipWidth,
                              fmtCurrency: fmtCurrency,
                              s: s,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
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

  Widget _legendLine(Color color, String label, bool dashed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 2,
          child: CustomPaint(
            painter: _DashedLinePainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _DailyTimelineHoverTooltip extends StatelessWidget {
  final DashboardDailyAttendanceStat day;
  final double width;
  final NumberFormat fmtCurrency;
  final AppLocalizations s;

  const _DailyTimelineHoverTooltip({
    required this.day,
    required this.width,
    required this.fmtCurrency,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(
      color: Color(0xFF111827),
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    final bodyStyle = const TextStyle(
      color: Color(0xFF111827),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    final mutedStyle = TextStyle(
      color: const Color(0xFF6B7280),
      fontSize: 10,
      fontWeight: FontWeight.w500,
      height: 1.25,
    );
    final accentStyle = TextStyle(
      color: const Color(0xFF7C3AED),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1.3,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
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
                ...day.gradeBreakdown.map((item) {
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
                          child: Text(
                            title.isNotEmpty ? title : 'N/A',
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '${item.totalHours.toStringAsFixed(1)}h / $unit',
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 92,
                          child: Text(
                            fmtCurrency.format(item.estimatedCost),
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  const Spacer(),
                  Text(s.dashboardTooltipTotal, style: accentStyle),
                  const SizedBox(width: 8),
                  Text(
                    fmtCurrency.format(day.estimatedCost),
                    style: accentStyle,
                    textAlign: TextAlign.right,
                  ),
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
                              value: pct,
                              backgroundColor: Colors.grey.shade100,
                              color: AppTheme.warning,
                              minHeight: 5,
                            ),
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


