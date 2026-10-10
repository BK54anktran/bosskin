import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/services/api_service.dart';

/// Bước C — mục "Xác thực 2 lớp" ở màn Hồ sơ: bật (quét QR + nhập mã), tắt (mật khẩu + mã).
class TwoFactorCard extends StatefulWidget {
  const TwoFactorCard({super.key});

  @override
  State<TwoFactorCard> createState() => _TwoFactorCardState();
}

class _TwoFactorCardState extends State<TwoFactorCard> {
  Map<String, dynamic>? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.instance.dio.get('/profile/2fa');
      if (mounted) setState(() => _status = Map<String, dynamic>.from(r.data as Map));
    } catch (_) {
      // Không chặn màn hồ sơ khi không lấy được trạng thái 2FA
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppTheme.error : null),
    );
  }

  Future<void> _enable() async {
    final s = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final r = await ApiService.instance.dio.post('/profile/2fa/setup');
      final setup = Map<String, dynamic>.from(r.data as Map);
      if (!mounted) return;
      final codes = await showDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EnableDialog(setup: setup),
      );
      if (codes != null && mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(s.twoFactorRecoveryTitle),
            content: SizedBox(
              width: 360,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.twoFactorRecoveryDesc),
                const SizedBox(height: 12),
                SelectableText(codes.join('\n'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 15, height: 1.6)),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: codes.join('\n'))),
                child: Text(s.twoFactorCopyCodes),
              ),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(s.twoFactorSavedContinue)),
            ],
          ),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) _snack(serverMsg(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    final s = AppLocalizations.of(context);
    final ok = await showDialog<bool>(context: context, builder: (_) => const _DisableDialog());
    if (ok == true && mounted) {
      _snack(s.twoFactorDisabled);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final st = _status;
    if (st == null) return const SizedBox.shrink();
    final enabled = st['enabled'] == true;
    final required = st['required'] == true;
    final left = (st['recoveryCodesLeft'] as num?)?.toInt() ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(enabled ? Icons.verified_user : Icons.shield_outlined,
                color: enabled ? AppTheme.secondary : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.twoFactorTitle,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ),
            Text(enabled ? s.twoFactorOn : s.twoFactorOff,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: enabled ? AppTheme.secondary : AppTheme.textSecondary)),
          ]),
          const SizedBox(height: 6),
          Text(enabled ? s.twoFactorCodesLeft(left.toString()) : s.twoFactorProfileDesc,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          if (required) ...[
            const SizedBox(height: 4),
            Text(s.twoFactorRequiredByCompany, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: enabled
                ? (required
                    ? const SizedBox.shrink()
                    : OutlinedButton(onPressed: _busy ? null : _disable, child: Text(s.twoFactorDisableButton)))
                : FilledButton.icon(
                    onPressed: _busy ? null : _enable,
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(s.twoFactorEnableButton),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _EnableDialog extends StatefulWidget {
  final Map<String, dynamic> setup;
  const _EnableDialog({required this.setup});

  @override
  State<_EnableDialog> createState() => _EnableDialogState();
}

class _EnableDialogState extends State<_EnableDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty) return;
    setState(() { _busy = true; _error = null; });
    try {
      final r = await ApiService.instance.dio.post('/profile/2fa/enable', data: {'code': _code.text.trim()});
      final codes = ((r.data as Map)['recoveryCodes'] as List).map((e) => e.toString()).toList();
      if (mounted) Navigator.pop(context, codes);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.twoFactorTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.twoFactorSetupDesc, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Center(
              child: Container(
                color: AppTheme.background,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: widget.setup['otpauthUri'] as String, size: 180),
              ),
            ),
            const SizedBox(height: 8),
            Text(s.twoFactorManualKey, style: const TextStyle(fontSize: 12)),
            SelectableText(widget.setup['secret'] as String? ?? '',
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.twoFactorCodeLabel, border: const OutlineInputBorder()),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.error)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(s.twoFactorEnableButton)),
      ],
    );
  }
}

class _DisableDialog extends StatefulWidget {
  const _DisableDialog();

  @override
  State<_DisableDialog> createState() => _DisableDialogState();
}

class _DisableDialogState extends State<_DisableDialog> {
  final _pw = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      await ApiService.instance.dio.post('/profile/2fa/disable',
          data: {'password': _pw.text, 'code': _code.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.twoFactorDisableButton),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _pw,
            obscureText: true,
            decoration: InputDecoration(labelText: s.currentPassword, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            decoration: InputDecoration(
              labelText: s.twoFactorCodeLabel,
              helperText: s.twoFactorRecoveryHint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.error)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: _busy ? null : _submit,
          child: Text(s.twoFactorDisableButton),
        ),
      ],
    );
  }
}
