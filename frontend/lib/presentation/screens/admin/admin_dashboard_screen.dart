import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/config/server_config.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final Dio _dio;

  // Companies tab
  List<Map<String, dynamic>> _companies = [];
  bool _companiesLoading = true;
  String? _companiesError;

  // Stats tab
  Map<String, dynamic>? _stats;
  bool _statsLoading = true;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _dio = Dio(BaseOptions(
      baseUrl: ServerConfig.adminUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AuthService.instance.getAdminToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        options.headers['Accept-Language'] =
            Localizations.localeOf(context).toLanguageTag();
        handler.next(options);
      },
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCompanies();
        _loadStats();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() { _companiesLoading = true; _companiesError = null; });
    try {
      final res = await _dio.get('/companies');
      setState(() => _companies = List<Map<String, dynamic>>.from(res.data as List));
    } catch (e) {
      setState(() => _companiesError = AppLocalizations.of(context).companyLoadError);
    } finally {
      setState(() => _companiesLoading = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() { _statsLoading = true; _statsError = null; });
    try {
      final res = await _dio.get('/stats');
      setState(() => _stats = res.data as Map<String, dynamic>);
    } catch (e) {
      setState(() => _statsError = AppLocalizations.of(context).adminStatsLoadError);
    } finally {
      setState(() => _statsLoading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) context.go(AppRoutes.adminLogin);
  }

  void _showCreateCompanyDialog() {
    final s = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final domainCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final adminEmailCtrl = TextEditingController();
    final adminPassCtrl = TextEditingController();
    bool isLoading = false;

    showInstantDialog(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.business_outlined, size: 22),
            const SizedBox(width: 8),
            Text(s.createCompanyNew, style: const TextStyle(fontSize: 18)),
          ]),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SectionLabel(s.companyInfoSection),
                    const SizedBox(height: 8),
                    _DialogField(ctrl: nameCtrl, label: s.companyName,
                        validator: (v) => (v == null || v.trim().isEmpty) ? s.requiredField : null),
                    const SizedBox(height: 10),
                    _DialogField(ctrl: codeCtrl, label: s.companyCode, hint: s.companyCodeHint,
                        validator: (v) => (v == null || v.trim().isEmpty) ? s.requiredField : null),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _DialogField(ctrl: phoneCtrl, label: s.phoneNumber)),
                      const SizedBox(width: 10),
                      Expanded(child: _DialogField(ctrl: domainCtrl, label: s.domain)),
                    ]),
                    const SizedBox(height: 10),
                    _DialogField(ctrl: emailCtrl, label: s.contactEmail,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 20),
                    _SectionLabel(s.adminAccountSection),
                    const SizedBox(height: 4),
                    Text(s.accountUsedToLoginSystem,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    _DialogField(ctrl: adminEmailCtrl, label: s.adminEmailLabel,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@')) ? s.invalidEmail : null),
                    const SizedBox(height: 10),
                    _DialogField(ctrl: adminPassCtrl, label: s.passwordLabel, obscureText: true,
                        validator: (v) => (v == null || v.length < 6) ? s.atLeast6Chars : null),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text(s.cancel),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setS(() => isLoading = true);
                try {
                  await _dio.post('/companies', data: {
                    'name': nameCtrl.text.trim(),
                    'code': codeCtrl.text.trim().toUpperCase(),
                    'adminEmail': adminEmailCtrl.text.trim(),
                    'adminPassword': adminPassCtrl.text,
                    if (domainCtrl.text.isNotEmpty) 'domain': domainCtrl.text.trim(),
                    if (phoneCtrl.text.isNotEmpty) 'phone': phoneCtrl.text.trim(),
                    if (emailCtrl.text.isNotEmpty) 'companyEmail': emailCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadCompanies();
                  _loadStats();
                } catch (e) {
                  setS(() => isLoading = false);
                  if (ctx.mounted) {
                    String msg = s.genericError;
                    if (e is DioException && e.response?.data != null) {
                      msg = e.response?.data['message'] ?? msg;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg), backgroundColor: Colors.red));
                  }
                }
              },
              child: isLoading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(s.createCompany),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _impersonateCompany(int id) async {
    try {
      await AuthService.instance.impersonateCompany(_dio, id);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        String msg = AppLocalizations.of(context).companyLoginError;
        if (e is DioException && e.response?.data != null) {
          msg = e.response?.data['message'] ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _toggleActive(int id, bool currentActive) async {
    try {
      await _dio.patch('/companies/$id/toggle-active');
      if (mounted) { _loadCompanies(); _loadStats(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final s = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_outlined, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(s.appName, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF818CF8),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(icon: const Icon(Icons.bar_chart_outlined, size: 18), text: s.adminTabOverview),
            Tab(icon: const Icon(Icons.business_outlined, size: 18), text: s.adminTabCompanies),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(children: [
                const Icon(Icons.person_outline, size: 18, color: Colors.white70),
                const SizedBox(width: 6),
                Text(user.fullName ?? user.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(width: 12),
              ]),
            ),
          IconButton(icon: const Icon(Icons.logout), tooltip: s.logout, onPressed: _logout),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildOverviewTab(),
          _buildCompaniesTab(),
        ],
      ),
    );
  }

  // ── Overview Tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    final s = AppLocalizations.of(context)!;
    if (_statsLoading) return const Center(child: CircularProgressIndicator());
    if (_statsError != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
          const SizedBox(height: 12),
          Text(_statsError!, style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadStats, child: Text(s.retry)),
        ],
      ));
    }
    if (_stats == null) return const SizedBox();

    final fmt = NumberFormat('#,###', 'vi_VN');
    final fmtCur = NumberFormat('#,###đ', 'vi_VN');
    final totalCompanies  = _stats!['totalCompanies'] as int? ?? 0;
    final activeCompanies = _stats!['activeCompanies'] as int? ?? 0;
    final inactiveCompanies = _stats!['inactiveCompanies'] as int? ?? 0;
    final totalEmployees  = _stats!['totalEmployees'] as int? ?? 0;
    final totalUsers      = _stats!['totalUsers'] as int? ?? 0;
    final payrollStats    = (_stats!['companyPayrollStats'] as List?) ?? [];
    final growthData      = (_stats!['companyGrowth'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards row
            LayoutBuilder(builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 600 ? 3 : 2);
              return Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  _buildStatCard(s.adminStatsTotalCompanies, fmt.format(totalCompanies),
                      Icons.business_rounded, const Color(0xFF6366F1), constraints.maxWidth, cols),
                  _buildStatCard(s.adminStatsActiveCompanies, fmt.format(activeCompanies),
                      Icons.check_circle_outline, AppTheme.success, constraints.maxWidth, cols),
                  _buildStatCard(s.adminStatsInactiveCompanies, fmt.format(inactiveCompanies),
                      Icons.cancel_outlined, AppTheme.error, constraints.maxWidth, cols),
                  _buildStatCard(s.adminStatsTotalEmployees, fmt.format(totalEmployees),
                      Icons.people_outline, const Color(0xFF0EA5E9), constraints.maxWidth, cols),
                  _buildStatCard(s.adminStatsTotalUsers, fmt.format(totalUsers),
                      Icons.manage_accounts_outlined, const Color(0xFFF59E0B), constraints.maxWidth, cols),
                ],
              );
            }),
            const SizedBox(height: 28),

            // Charts row
            LayoutBuilder(builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 900;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildGrowthChart(growthData)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildCompanyStatusChart(activeCompanies, inactiveCompanies, s)),
                  ],
                );
              }
              return Column(children: [
                _buildGrowthChart(growthData),
                const SizedBox(height: 20),
                _buildCompanyStatusChart(activeCompanies, inactiveCompanies, s),
              ]);
            }),
            const SizedBox(height: 28),

            // Payroll by company table
            _buildPayrollTable(payrollStats, fmtCur, s),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color,
      double totalWidth, int cols) {
    final cardWidth = (totalWidth - (cols - 1) * 16) / cols;
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildGrowthChart(List growthData) {
    final s = AppLocalizations.of(context)!;
    final bars = growthData.asMap().entries.map((e) {
      final d = e.value as Map<String, dynamic>;
      final count = (d['count'] as int?) ?? 0;
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: count.toDouble(), color: const Color(0xFF6366F1), width: 16, borderRadius: BorderRadius.circular(4)),
      ]);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.adminStatsCompanyGrowth,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: growthData.isEmpty
                ? Center(child: Text(s.adminStatsNoPayroll, style: const TextStyle(color: Color(0xFF94A3B8))))
                : BarChart(BarChartData(
                    barGroups: bars,
                    gridData: FlGridData(show: true, drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                          getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))))),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= growthData.length) return const SizedBox();
                            final d = growthData[idx] as Map<String, dynamic>;
                            return Text('T${d['month']}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
                          })),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, _, rod, __) {
                          final d = growthData[group.x] as Map<String, dynamic>;
                          return BarTooltipItem(
                            'T${d['month']}/${d['year']}\n${rod.toY.toInt()} công ty',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        },
                      ),
                    ),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyStatusChart(int active, int inactive, AppLocalizations s) {
    final total = active + inactive;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.adminStatsTotalCompanies,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: total == 0
                ? Center(child: Text(s.noCompaniesYet, style: const TextStyle(color: Color(0xFF94A3B8))))
                : Row(children: [
                    Expanded(
                      child: PieChart(PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: active.toDouble(), color: AppTheme.success,
                            title: '$active', radius: 70,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          if (inactive > 0) PieChartSectionData(
                            value: inactive.toDouble(), color: AppTheme.error,
                            title: '$inactive', radius: 70,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      )),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LegendItem(color: AppTheme.success, label: s.adminStatsActiveCompanies, count: active),
                        const SizedBox(height: 12),
                        _LegendItem(color: AppTheme.error, label: s.adminStatsInactiveCompanies, count: inactive),
                      ],
                    ),
                  ]),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollTable(List payrollStats, NumberFormat fmtCur, AppLocalizations s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Text(s.adminStatsPayrollByCompany,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ),
          const SizedBox(height: 4),
          if (payrollStats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(s.adminStatsNoPayroll,
                  style: const TextStyle(color: Color(0xFF94A3B8)))),
            )
          else ...[
            const Divider(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                Expanded(flex: 3, child: Text(s.companyName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text(s.adminStatsTotalEmployees,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(s.adminStatsPayrolls(0).replaceAll('0 ', ''),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    textAlign: TextAlign.right)),
                Expanded(flex: 3, child: Text(s.adminStatsPayrollThisMonth,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    textAlign: TextAlign.right)),
              ]),
            ),
            const Divider(height: 1),
            ...payrollStats.asMap().entries.map((e) {
              final d = e.value as Map<String, dynamic>;
              final isLast = e.key == payrollStats.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    Expanded(flex: 3, child: Row(children: [
                      Container(width: 32, height: 32,
                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.business, size: 16, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d['companyName'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ])),
                    Expanded(flex: 2, child: Text('${d['employeeCount'] ?? 0}',
                        style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('${d['payrollCount'] ?? 0}',
                        style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                    Expanded(flex: 3, child: Text(
                        fmtCur.format((d['totalNetSalary'] as num?) ?? 0),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                        textAlign: TextAlign.right)),
                  ]),
                ),
                if (!isLast) const Divider(height: 1),
              ]);
            }),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Companies Tab ─────────────────────────────────────────────────────────

  Widget _buildCompaniesTab() {
    final s = AppLocalizations.of(context)!;
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.companyManagementTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            Text(s.companyManagementSubtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ]),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _showCreateCompanyDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text(s.createCompany),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ),
      Expanded(child: _buildCompanyGrid()),
    ]);
  }

  Widget _buildCompanyGrid() {
    final s = AppLocalizations.of(context)!;
    if (_companiesLoading) return const Center(child: CircularProgressIndicator());
    if (_companiesError != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
          const SizedBox(height: 12),
          Text(_companiesError!, style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadCompanies, child: Text(s.retry)),
        ],
      ));
    }
    if (_companies.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.business_outlined, size: 64, color: Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          Text(s.noCompaniesYet, style: const TextStyle(fontSize: 16, color: Color(0xFF64748B))),
        ],
      ));
    }
    return RefreshIndicator(
      onRefresh: _loadCompanies,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 1200 ? 4 : constraints.maxWidth > 800 ? 3 : constraints.maxWidth > 500 ? 2 : 1;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.5,
            ),
            itemCount: _companies.length,
            itemBuilder: (_, i) => _CompanyCard(
              company: _companies[i],
              onToggleActive: _toggleActive,
              onImpersonate: _impersonateCompany,
            ),
          );
        }),
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _LegendItem({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text('$label ($count)', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
    ]);
  }
}

class _CompanyCard extends StatelessWidget {
  final Map<String, dynamic> company;
  final Future<void> Function(int id, bool currentActive) onToggleActive;
  final Future<void> Function(int id) onImpersonate;

  const _CompanyCard({required this.company, required this.onToggleActive, required this.onImpersonate});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final isActive = company['active'] as bool? ?? true;
    final empCount = company['employeeCount'] as int? ?? 0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary.withOpacity(0.1) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.business, color: isActive ? AppTheme.primary : AppTheme.error, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(company['name'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(company['code'] as String? ?? '',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ])),
            _StatusBadge(isActive: isActive),
            const SizedBox(width: 4),
            SizedBox(
              width: 28, height: 28,
              child: Tooltip(
                message: s.loginToCompany,
                child: MouseRegion(
                  cursor: isActive ? SystemMouseCursors.click : SystemMouseCursors.basic,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: isActive ? () => onImpersonate(company['id'] as int) : null,
                    child: Icon(Icons.login, size: 16,
                        color: isActive ? AppTheme.primary : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ),
          ]),
          const Spacer(),
          // employee count + domain
          Row(children: [
            const Icon(Icons.people_outline, size: 13, color: Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(s.adminStatsEmployees(empCount),
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            if (company['domain'] != null) ...[
              const SizedBox(width: 12),
              const Icon(Icons.language, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(child: Text(company['domain'] as String,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ] else const Spacer(),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: OutlinedButton(
                  onPressed: () => onToggleActive(company['id'] as int, isActive),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    side: BorderSide(color: isActive ? AppTheme.error.withOpacity(0.5) : AppTheme.success.withOpacity(0.5)),
                    foregroundColor: isActive ? AppTheme.error : AppTheme.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isActive ? s.deactivate : s.activate, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? s.employeeStatusActive : s.stopped,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: isActive ? AppTheme.success : AppTheme.error),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
      const SizedBox(width: 8),
      const Expanded(child: Divider()),
    ]);
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.ctrl, required this.label,
    this.hint, this.keyboardType, this.obscureText = false, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label, hintText: hint, isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
