import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../auth/force_change_password_screen.dart' show isStrongPassword;
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/company_identity_utils.dart';
import '../../../core/utils/company_feature_utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/localization/language_service.dart';
import '../../../core/config/server_config.dart';
import 'trial_requests_tab.dart';
import 'system_admins_tab.dart';
import 'tax_policies_tab.dart';
import 'holiday_templates_tab.dart';

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
  late int _selectedYear;
  late int _selectedMonth;

  // Yêu cầu dùng thử: số yêu cầu mới hiện trên tab
  int _newTrials = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear  = now.year;
    _selectedMonth = now.month;
    _tabCtrl = TabController(length: 6, vsync: this);
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
        _loadNewTrials();
      }
    });
  }

  Future<void> _loadNewTrials() async {
    try {
      final r = await _dio.get('/trial-requests/count-new');
      if (mounted) setState(() => _newTrials = ((r.data as Map)['count'] as num).toInt());
    } catch (_) {}
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
      final res = await _dio.get('/stats',
          queryParameters: {'year': _selectedYear, 'month': _selectedMonth});
      setState(() => _stats = res.data as Map<String, dynamic>);
    } catch (e) {
      setState(() => _statsError = AppLocalizations.of(context).adminStatsLoadError);
    } finally {
      setState(() => _statsLoading = false);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    // Hiện dialog chọn tháng/năm
    int tempYear  = _selectedYear;
    int tempMonth = _selectedMonth;
    final s = AppLocalizations.of(context);

    await showInstantDialog(context, (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(s.adminStatsPickMonth),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Year row
            Row(children: [
              IconButton(
                onPressed: tempYear > 2020 ? () => setS(() => tempYear--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(child: Text('$tempYear',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(
                onPressed: tempYear < now.year ? () => setS(() => tempYear++) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ]),
            const SizedBox(height: 12),
            // Month grid
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(12, (i) {
                final mo = i + 1;
                final isFuture = tempYear == now.year && mo > now.month;
                final isSelected = mo == tempMonth && tempYear == _selectedYear;
                return MouseRegion(
                  cursor: isFuture ? SystemMouseCursors.basic : SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: isFuture ? null : () => setS(() => tempMonth = mo),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : mo == tempMonth
                                ? AppTheme.tint(AppTheme.primary)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : AppTheme.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(s.dashMonthShort('$mo'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isFuture
                                ? AppTheme.border
                                : isSelected
                                    ? Colors.white
                                    : const Color(0xFF374151),
                          )),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedYear  = tempYear;
                _selectedMonth = tempMonth;
              });
              _loadStats();
            },
            child: Text(s.apply),
          ),
        ],
      ),
    ));
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) context.go(AppRoutes.adminLogin);
  }

  void _showCreateCompanyDialog() {
    final s = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final domainCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final adminEmailCtrl = TextEditingController();
    final adminPassCtrl = TextEditingController();
    // Ngôn ngữ của dữ liệu mặc định tạo sẵn (tên vai trò, loại tài liệu) — mặc định theo ngôn ngữ app đang dùng
    String seedLang = LanguageService.instance.isEnglish ? 'en' : 'vi';
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
                    // V22: mã công ty là tiền tố mã NV, không đổi được sau khi tạo
                    _DialogField(ctrl: codeCtrl, label: s.companyCode, hint: s.companyCodeHint,
                        helper: s.companyCodeRule,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? s.requiredField
                            : (!isValidCompanyCode(v) ? s.companyCodeInvalid : null)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _DialogField(ctrl: phoneCtrl, label: s.phoneNumber)),
                      const SizedBox(width: 10),
                      // V22: đuôi email bắt buộc của mọi tài khoản trong công ty
                      Expanded(child: _DialogField(ctrl: domainCtrl, label: '${s.emailDomain} *',
                          hint: s.emailDomainExample,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? s.requiredField
                              : (!isValidEmailDomain(normalizeEmailDomain(v)) ? s.emailDomainInvalid : null))),
                    ]),
                    const SizedBox(height: 10),
                    _DialogField(ctrl: emailCtrl, label: s.contactEmail,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 20),
                    _SectionLabel(s.adminAccountSection),
                    const SizedBox(height: 4),
                    Text(s.accountUsedToLoginSystem,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 10),
                    _DialogField(ctrl: adminEmailCtrl, label: s.adminEmailLabel,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final domain = normalizeEmailDomain(domainCtrl.text);
                          if (v == null || !isValidCompanyEmail(domain.isEmpty ? null : domain, v)) {
                            return domain.isNotEmpty ? s.emailDomainMismatch(domain) : s.invalidEmail;
                          }
                          return null;
                        }),
                    const SizedBox(height: 10),
                    _DialogField(ctrl: adminPassCtrl, label: s.passwordLabel, obscureText: true,
                        validator: (v) => (v == null || !isStrongPassword(v)) ? s.passwordPolicyHint : null),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: seedLang,
                      decoration: InputDecoration(labelText: s.language),
                      items: [
                        DropdownMenuItem(value: 'vi', child: Text(s.vietnamese)),
                        DropdownMenuItem(value: 'en', child: Text(s.english)),
                      ],
                      onChanged: (v) => setS(() => seedLang = v ?? 'vi'),
                    ),
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
                    'language': seedLang,
                    'domain': normalizeEmailDomain(domainCtrl.text),
                    if (phoneCtrl.text.isNotEmpty) 'phone': phoneCtrl.text.trim(),
                    if (emailCtrl.text.isNotEmpty) 'companyEmail': emailCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadCompanies();
                  _loadStats();
                } catch (e) {
                  setS(() => isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
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

  /// Sửa công ty: mã chỉ xem (là tiền tố mã NV, không đổi được); đổi đuôi email bị backend chặn
  /// khi trùng công ty khác hoặc còn tài khoản dùng đuôi cũ.
  void _showEditCompanyDialog(Map<String, dynamic> company) {
    final s = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: company['name'] as String? ?? '');
    final codeCtrl = TextEditingController(text: company['code'] as String? ?? '');
    final domainCtrl = TextEditingController(text: company['domain'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: company['phone'] as String? ?? '');
    final emailCtrl = TextEditingController(text: company['email'] as String? ?? '');
    final addressCtrl = TextEditingController(text: company['address'] as String? ?? '');
    // V26: tính năng đang bật (thiếu trường = bật hết)
    final features = <String>{
      ...((company['features'] as List?)?.map((e) => e.toString()) ?? companyFeatureCatalog.map((f) => f.code))
    };
    bool isLoading = false;

    showInstantDialog(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.edit_outlined, size: 22),
            const SizedBox(width: 8),
            Text(s.editCompany, style: const TextStyle(fontSize: 18)),
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
                    _DialogField(ctrl: nameCtrl, label: s.companyName,
                        validator: (v) => (v == null || v.trim().isEmpty) ? s.requiredField : null),
                    const SizedBox(height: 10),
                    _DialogField(ctrl: codeCtrl, label: s.companyCode, readOnly: true,
                        helper: s.companyCodeLocked),
                    const SizedBox(height: 10),
                    _DialogField(ctrl: domainCtrl, label: '${s.emailDomain} *', hint: s.emailDomainExample,
                        helper: s.emailDomainChangeRule,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? s.requiredField
                            : (!isValidEmailDomain(normalizeEmailDomain(v)) ? s.emailDomainInvalid : null)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _DialogField(ctrl: phoneCtrl, label: s.phoneNumber)),
                      const SizedBox(width: 10),
                      Expanded(child: _DialogField(ctrl: emailCtrl, label: s.contactEmail,
                          keyboardType: TextInputType.emailAddress)),
                    ]),
                    const SizedBox(height: 10),
                    _DialogField(ctrl: addressCtrl, label: s.address),
                    const SizedBox(height: 16),
                    Text(s.companyFeaturesTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(s.companyFeaturesHelper, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                    for (final g in companyFeatureGroups) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 2),
                        child: Text(companyFeatureGroupLabel(s, g).toUpperCase(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                                color: Colors.white.withValues(alpha: 0.55))),
                      ),
                      for (final f in companyFeaturesOfGroup(g))
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: features.contains(f.code),
                          title: Text(companyFeatureLabel(s, f.code)),
                          subtitle: f.requires.isNotEmpty
                              ? Text(s.companyFeatureNeeds(f.requires.map((r) => companyFeatureLabel(s, r)).join(', ')),
                                  style: const TextStyle(fontSize: 11))
                              : null,
                          onChanged: (v) => setS(() => toggleCompanyFeature(features, f.code, v == true)),
                        ),
                    ],
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
                  await _dio.put('/companies/${company['id']}', data: {
                    'name': nameCtrl.text.trim(),
                    'domain': normalizeEmailDomain(domainCtrl.text),
                    'phone': phoneCtrl.text.trim(),
                    'companyEmail': emailCtrl.text.trim(),
                    'address': addressCtrl.text.trim(),
                    'features': companyFeatureCatalog.map((f) => f.code).where(features.contains).toList(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadCompanies();
                } catch (e) {
                  setS(() => isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
                  }
                }
              },
              child: isLoading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(s.save),
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
        final s = AppLocalizations.of(context);
        String msg = s.companyLoginError;
        if (e is DioException && e.response?.data != null) {
          final serverKey = e.response?.data['message'] as String?;
          if (serverKey == 'error.company.inactive') {
            msg = s.loginCompanyInactive;
          } else if (serverKey != null && serverKey.isNotEmpty) {
            msg = serverKey;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
      }
    }
  }

  /// Bước C — buộc quản trị (có ROLE_MANAGE) của công ty dùng 2FA.
  Future<void> _toggleRequire2fa(int id, bool current) async {
    try {
      await _dio.put('/companies/$id/require-admin-2fa', data: {'required': !current});
      if (mounted) _loadCompanies();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(serverMsg(e))));
      }
    }
  }

  Future<void> _toggleActive(int id, bool currentActive) async {
    try {
      await _dio.patch('/companies/$id/toggle-active');
      if (mounted) { _loadCompanies(); _loadStats(); }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final s = AppLocalizations.of(context);
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
            Tab(
              icon: Badge(
                isLabelVisible: _newTrials > 0,
                label: Text('$_newTrials'),
                child: const Icon(Icons.mark_email_unread_outlined, size: 18),
              ),
              text: s.adminTabTrialRequests,
            ),
            Tab(icon: const Icon(Icons.admin_panel_settings_outlined, size: 18), text: s.adminTabSystemAdmins),
            Tab(icon: const Icon(Icons.receipt_long_outlined, size: 18), text: s.adminTabTaxPolicies),
            Tab(icon: const Icon(Icons.event_outlined, size: 18), text: s.adminTabHolidays),
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
          TrialRequestsTab(dio: _dio, onChanged: _loadNewTrials),
          SystemAdminsTab(dio: _dio),
          TaxPoliciesTab(dio: _dio),
          HolidayTemplatesTab(dio: _dio),
        ],
      ),
    );
  }

  // ── Overview Tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    final s = AppLocalizations.of(context);
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
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,2))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildGrowthChart(List growthData) {
    final s = AppLocalizations.of(context);
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
        color: AppTheme.background, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.adminStatsCompanyGrowth,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: growthData.isEmpty
                ? Center(child: Text(s.adminStatsNoPayroll, style: TextStyle(color: AppTheme.textMuted)))
                : BarChart(BarChartData(
                    barGroups: bars,
                    gridData: FlGridData(show: true, drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                          getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: AppTheme.textMuted)))),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= growthData.length) return const SizedBox();
                            final d = growthData[idx] as Map<String, dynamic>;
                            return Text(s.dashMonthShort('${d['month']}'), style: TextStyle(fontSize: 10, color: AppTheme.textMuted));
                          })),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, _, rod, __) {
                          final d = growthData[group.x] as Map<String, dynamic>;
                          return BarTooltipItem(
                            '${s.dashMonthYearShort('${d['month']}', '${d['year']}')}\n${s.adminCompanyCount(rod.toY.toInt())}',
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
        color: AppTheme.background, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.adminStatsTotalCompanies,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: total == 0
                ? Center(child: Text(s.noCompaniesYet, style: TextStyle(color: AppTheme.textMuted)))
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
        color: AppTheme.background, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(children: [
              Text(s.adminStatsPayrollByCompany,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pickMonth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_month_outlined, size: 15, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(s.dashMonthYearShort('$_selectedMonth', '$_selectedYear'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF6366F1)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ]),
          ),
          const SizedBox(height: 4),
          if (payrollStats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(s.adminStatsNoPayroll,
                  style: TextStyle(color: AppTheme.textMuted))),
            )
          else ...[
            const Divider(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                Expanded(flex: 3, child: Text(s.companyName,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
                Expanded(flex: 2, child: Text(s.adminStatsTotalEmployees,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(s.adminStatsPayrolls(0).replaceAll('0 ', ''),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    textAlign: TextAlign.right)),
                Expanded(flex: 3, child: Text(s.adminStatsPayrollThisMonth(_selectedMonth, _selectedYear),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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
                        decoration: BoxDecoration(color: AppTheme.tint(AppTheme.primary), borderRadius: BorderRadius.circular(8)),
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
    final s = AppLocalizations.of(context);
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.companyManagementTitle,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text(s.companyManagementSubtitle,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
    final s = AppLocalizations.of(context);
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
          Icon(Icons.business_outlined, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(s.noCompaniesYet, style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
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
              onToggleRequire2fa: _toggleRequire2fa,
              onEdit: _showEditCompanyDialog,
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
  final Future<void> Function(int id, bool current) onToggleRequire2fa;
  final void Function(Map<String, dynamic> company) onEdit;

  const _CompanyCard({required this.company, required this.onToggleActive, required this.onImpersonate,
      required this.onToggleRequire2fa, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isActive = company['active'] as bool? ?? true;
    final empCount = company['employeeCount'] as int? ?? 0;
    final require2fa = company['requireAdmin2fa'] as bool? ?? false;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isActive ? AppTheme.border : const Color(0xFFFECACA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.tint(AppTheme.error),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.business, color: isActive ? AppTheme.primary : AppTheme.error, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(company['name'] as String? ?? '',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(company['code'] as String? ?? '',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                        color: isActive ? AppTheme.primary : AppTheme.border),
                  ),
                ),
              ),
            ),
          ]),
          const Spacer(),
          // employee count + domain
          Row(children: [
            Icon(Icons.people_outline, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(s.adminStatsEmployees(empCount),
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            if (company['domain'] != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.language, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(company['domain'] as String,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                    side: BorderSide(color: isActive ? AppTheme.error.withValues(alpha: 0.5) : AppTheme.success.withValues(alpha: 0.5)),
                    foregroundColor: isActive ? AppTheme.error : AppTheme.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isActive ? s.deactivate : s.activate, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: s.editCompany,
              child: IconButton(
                onPressed: () => onEdit(company),
                icon: Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMuted),
              ),
            ),
            Tooltip(
              message: require2fa ? s.twoFactorCompanyRequiredOn : s.twoFactorCompanyRequiredOff,
              child: IconButton(
                onPressed: () => onToggleRequire2fa(company['id'] as int, require2fa),
                icon: Icon(require2fa ? Icons.verified_user : Icons.shield_outlined,
                    size: 18, color: require2fa ? AppTheme.secondary : AppTheme.textMuted),
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
    final s = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.tint(AppTheme.secondary) : AppTheme.tint(AppTheme.error),
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
      Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
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
  final bool readOnly;
  final String? helper;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.ctrl, required this.label,
    this.hint, this.keyboardType, this.obscureText = false, this.readOnly = false, this.helper, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      validator: validator,
      decoration: InputDecoration(
        labelText: label, hintText: hint, helperText: helper, helperMaxLines: 3, isDense: true,
        filled: readOnly, fillColor: readOnly ? AppTheme.surfaceAlt : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
