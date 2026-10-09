import 'package:bosskin/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

/// Tab "Quản trị viên" ở trang system admin: thêm tài khoản (mật khẩu sinh tự động), khoá, đặt lại mật khẩu / 2FA.
class SystemAdminsTab extends StatefulWidget {
  final Dio dio;
  const SystemAdminsTab({super.key, required this.dio});

  @override
  State<SystemAdminsTab> createState() => _SystemAdminsTabState();
}

class _SystemAdminsTabState extends State<SystemAdminsTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await widget.dio.get('/system-admins');
      setState(() => _rows = (r.data as List).cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _showPassword(String email, String password) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final s = AppLocalizations.of(ctx);
          return AlertDialog(
            title: Text(s.sysAdminPasswordTitle),
            content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.sysAdminPasswordDesc(email), style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                  child: SelectableText(password, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: password)), child: Text(s.sysAdminCopyPassword)),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(s.twoFactorSavedContinue)),
            ],
          );
        },
      );

  Future<void> _add() async {
    final s = AppLocalizations.of(context);
    final emailCtrl = TextEditingController(), nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.sysAdminAdd),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: emailCtrl, autofocus: true, keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: s.email, border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: s.fullName, border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            Text(s.sysAdminAddNote, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.sysAdminCreate)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await widget.dio.post('/system-admins', data: {'email': emailCtrl.text.trim(), 'name': nameCtrl.text.trim()});
      final data = r.data as Map<String, dynamic>;
      await _load();
      if (mounted) await _showPassword(data['email'] as String, data['password'] as String);
    } catch (e) {
      if (mounted) _snack(serverMsg(e));
    }
  }

  Future<bool> _confirm(String text) async {
    final s = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(text),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.confirm)),
            ],
          ),
        ) ==
        true;
  }

  Future<void> _action(Map<String, dynamic> a, String act) async {
    final s = AppLocalizations.of(context);
    final email = a['email'] as String;
    try {
      switch (act) {
        case 'toggle':
          final enable = a['enabled'] != true;
          if (!enable && !await _confirm(s.sysAdminDisableConfirm(email))) return;
          await widget.dio.patch('/system-admins/${a['id']}/enabled', data: {'enabled': enable});
        case 'password':
          if (!await _confirm(s.sysAdminResetPasswordConfirm(email))) return;
          final r = await widget.dio.post('/system-admins/${a['id']}/reset-password');
          if (mounted) await _showPassword(email, (r.data as Map)['password'] as String);
        case '2fa':
          if (!await _confirm(s.sysAdminReset2faConfirm(email))) return;
          await widget.dio.post('/system-admins/${a['id']}/reset-2fa');
      }
      _load();
    } catch (e) {
      if (mounted) _snack(serverMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return EmptyState(icon: Icons.error_outline, message: _error!, actionLabel: s.retry, onAction: _load);
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        Expanded(child: Text(s.sysAdminIntro, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: FilledButton.icon(onPressed: _add, icon: const Icon(Icons.person_add_alt, size: 18), label: Text(s.sysAdminAdd)),
        ),
      ]),
      const SizedBox(height: 16),
      for (final a in _rows)
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.border)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primary),
            ),
            title: Row(children: [
              Flexible(child: Text(a['name'] as String? ?? '', overflow: TextOverflow.ellipsis)),
              if (a['self'] == true) ...[const SizedBox(width: 8), StatusBadge(label: s.sysAdminYou, color: AppTheme.primary)],
            ]),
            subtitle: SelectableText(a['email'] as String? ?? ''),
            trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              StatusBadge(label: a['totpEnabled'] == true ? s.sysAdmin2faOn : s.sysAdmin2faPending,
                  color: a['totpEnabled'] == true ? AppTheme.secondary : AppTheme.warning),
              StatusBadge(label: a['enabled'] == true ? s.employeeStatusActive : s.stopped,
                  color: a['enabled'] == true ? AppTheme.secondary : AppTheme.error),
              if (a['self'] != true)
                PopupMenuButton<String>(
                  onSelected: (v) => _action(a, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'toggle', child: Text(a['enabled'] == true ? s.deactivate : s.activate)),
                    PopupMenuItem(value: 'password', child: Text(s.sysAdminResetPassword)),
                    PopupMenuItem(value: '2fa', enabled: a['totpEnabled'] == true, child: Text(s.twoFactorResetTooltip)),
                  ],
                ),
            ]),
          ),
        ),
    ]);
  }
}
