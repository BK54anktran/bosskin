import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/profile_service.dart';

/// Chính sách mật khẩu — khớp backend `PasswordPolicy` (≥ 8 ký tự, có chữ và số).
bool isStrongPassword(String pw) =>
    pw.length >= 8 &&
    RegExp(r'[A-Za-z]').hasMatch(pw) &&
    RegExp(r'\d').hasMatch(pw);

/// Màn đổi mật khẩu bắt buộc ở lần đăng nhập đầu (tài khoản do admin tạo, V7).
/// Router chuyển mọi màn khác về đây cho tới khi đổi xong.
class ForceChangePasswordScreen extends StatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  State<ForceChangePasswordScreen> createState() =>
      _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends State<ForceChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProfileService.instance.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
        confirmPassword: _confirm.text,
      );
      await AuthService.instance.completeForcedPasswordChange(_next.text);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final email = AuthService.instance.currentUser?.email ?? '';
    InputDecoration deco(String label, {String? helper}) => InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_reset,
                          size: 40, color: AppTheme.primary),
                      const SizedBox(height: 12),
                      Text(s.forceChangePasswordTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(s.forceChangePasswordDesc,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _current,
                        obscureText: _obscure,
                        decoration: deco(s.currentPassword),
                        validator: (v) => (v == null || v.isEmpty)
                            ? s.fillAllPasswordFields
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _next,
                        obscureText: _obscure,
                        decoration:
                            deco(s.newPassword, helper: s.passwordPolicyHint),
                        validator: (v) {
                          final pw = v ?? '';
                          if (!isStrongPassword(pw)) {
                            return s.newPasswordMinLength;
                          }
                          if (pw == _current.text) {
                            return s.passwordSameAsCurrent;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        decoration: deco(s.confirmPassword),
                        validator: (v) =>
                            v != _next.text ? s.passwordMismatch : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: AppTheme.error)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(s.changePassword),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _saving ? null : _logout,
                        child: Text(s.logout),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
