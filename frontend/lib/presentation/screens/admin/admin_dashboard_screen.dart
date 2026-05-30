import 'package:dio/dio.dart';
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

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>> _companies = [];
  bool _isLoading = true;
  String? _error;

  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: ServerConfig.adminUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AuthService.instance.getAdminToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Accept-Language'] =
            Localizations.localeOf(context).toLanguageTag();
        handler.next(options);
      },
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCompanies(context);
    });
  }

  Future<void> _loadCompanies(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _dio.get('/admin/companies');
      setState(() {
        _companies = List<Map<String, dynamic>>.from(res.data as List);
      });
    } catch (e) {
      final s = AppLocalizations.of(context)!;
      setState(() => _error = s.companyLoadError);
    } finally {
      setState(() => _isLoading = false);
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
          title: Row(
            children: [
              Icon(Icons.business_outlined, size: 22),
              SizedBox(width: 8),
              Text(s.createCompanyNew, style: const TextStyle(fontSize: 18)),
            ],
          ),
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
                    _DialogField(
                        ctrl: nameCtrl,
                        label: s.companyName,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? s.requiredField
                            : null),
                    const SizedBox(height: 10),
                    _DialogField(
                        ctrl: codeCtrl,
                        label: s.companyCode,
                        hint: s.companyCodeHint,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? s.requiredField
                            : null),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _DialogField(
                              ctrl: phoneCtrl, label: s.phoneNumber)),
                      const SizedBox(width: 10),
                      Expanded(
                          child:
                              _DialogField(ctrl: domainCtrl, label: s.domain)),
                    ]),
                    const SizedBox(height: 10),
                    _DialogField(
                        ctrl: emailCtrl,
                        label: s.contactEmail,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 20),
                    _SectionLabel(s.adminAccountSection),
                    const SizedBox(height: 4),
                    Text(s.accountUsedToLoginSystem,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    _DialogField(
                      ctrl: adminEmailCtrl,
                      label: s.adminEmailLabel,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? s.invalidEmail
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _DialogField(
                      ctrl: adminPassCtrl,
                      label: s.passwordLabel,
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.length < 6) ? s.atLeast6Chars : null,
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
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => isLoading = true);
                      try {
                        await _dio.post('/admin/companies', data: {
                          'name': nameCtrl.text.trim(),
                          'code': codeCtrl.text.trim().toUpperCase(),
                          'adminEmail': adminEmailCtrl.text.trim(),
                          'adminPassword': adminPassCtrl.text,
                          if (domainCtrl.text.isNotEmpty)
                            'domain': domainCtrl.text.trim(),
                          if (phoneCtrl.text.isNotEmpty)
                            'phone': phoneCtrl.text.trim(),
                          if (emailCtrl.text.isNotEmpty)
                            'companyEmail': emailCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadCompanies(context);
                      } catch (e) {
                        setS(() => isLoading = false);
                        if (ctx.mounted) {
                          String msg = s.genericError;
                          if (e is DioException && e.response?.data != null) {
                            msg = e.response?.data['message'] ?? msg;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(msg), backgroundColor: Colors.red));
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
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
        final s = AppLocalizations.of(context)!;
        String msg = s.companyLoginError;
        if (e is DioException && e.response?.data != null) {
          msg = e.response?.data['message'] ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _toggleActive(int id, bool currentActive) async {
    try {
      await _dio.patch('/admin/companies/$id/toggle-active');
      if (mounted) _loadCompanies(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e))),
        );
      }
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(s.appName, style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 18, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(user.fullName ?? user.email,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: s.logout,
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final s = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.companyManagementTitle,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              SizedBox(height: 4),
              Text(s.companyManagementSubtitle,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _showCreateCompanyDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text(s.createCompany),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final s = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: () => _loadCompanies(context), child: Text(s.retry)),
          ],
        ),
      );
    }
    if (_companies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Color(0xFF94A3B8)),
            SizedBox(height: 16),
            Text(s.noCompaniesYet,
                style: const TextStyle(fontSize: 16, color: Color(0xFF64748B))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadCompanies(context),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxis = constraints.maxWidth > 1200
                ? 4
                : constraints.maxWidth > 800
                    ? 3
                    : constraints.maxWidth > 500
                        ? 2
                        : 1;
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxis,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.6,
              ),
              itemCount: _companies.length,
              itemBuilder: (_, i) => _CompanyCard(
                company: _companies[i],
                onToggleActive: _toggleActive,
                onImpersonate: _impersonateCompany,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final Map<String, dynamic> company;
  final Future<void> Function(int id, bool currentActive) onToggleActive;
  final Future<void> Function(int id) onImpersonate;

  const _CompanyCard({
    required this.company,
    required this.onToggleActive,
    required this.onImpersonate,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = company['active'] as bool? ?? true;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color:
                isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primary.withOpacity(0.1)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.business,
                    color: isActive ? AppTheme.primary : AppTheme.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company['name'] as String? ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        company['code'] as String? ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(isActive: isActive),
                const SizedBox(width: 4),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Tooltip(
                    message: AppLocalizations.of(context)!.loginToCompany,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: isActive
                          ? () => onImpersonate(company['id'] as int)
                          : null,
                      child: Icon(
                        Icons.login,
                        size: 16,
                        color: isActive
                            ? AppTheme.primary
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (company['domain'] != null) ...[
              Row(
                children: [
                  const Icon(Icons.language,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    company['domain'] as String,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onToggleActive(
                      company['id'] as int,
                      isActive,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(
                          color: isActive
                              ? AppTheme.error.withOpacity(0.5)
                              : AppTheme.success.withOpacity(0.5)),
                      foregroundColor:
                          isActive ? AppTheme.error : AppTheme.success,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                        isActive
                            ? AppLocalizations.of(context)!.deactivate
                            : AppLocalizations.of(context)!.activate,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive
            ? AppLocalizations.of(context)!.employeeStatusActive
            : AppLocalizations.of(context)!.stopped,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppTheme.success : AppTheme.error,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF0F172A))),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
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
    required this.ctrl,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
