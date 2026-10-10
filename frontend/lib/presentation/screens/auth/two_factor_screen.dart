import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/services/auth_service.dart';

/// Bước C — bước 2 khi đăng nhập: nhập mã 2FA, hoặc cài 2FA lần đầu khi bị buộc
/// (system admin; quản trị công ty khi công ty bắt buộc). Trả true khi đăng nhập xong.
class TwoFactorScreen extends StatefulWidget {
  final TwoFactorChallenge challenge;
  const TwoFactorScreen({super.key, required this.challenge});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _codeCtrl = TextEditingController();
  Map<String, dynamic>? _setup;
  List<String>? _recoveryCodes;
  bool _busy = false;
  String? _error;

  bool get _isSetup => widget.challenge.setupRequired;

  @override
  void initState() {
    super.initState();
    if (_isSetup) _loadSetup();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSetup() async {
    setState(() { _busy = true; _error = null; });
    try {
      final r = await AuthService.instance.twoFactorSetup(widget.challenge);
      if (mounted) setState(() => _setup = r);
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_isSetup) {
        final codes = await AuthService.instance.twoFactorEnable(widget.challenge, code);
        if (mounted) setState(() => _recoveryCodes = codes);
      } else {
        await AuthService.instance.twoFactorVerify(widget.challenge, code);
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.twoFactorTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _recoveryCodes != null ? _buildRecovery(s) : _buildCodeStep(s),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeStep(AppLocalizations s) {
    final uri = _setup?['otpauthUri'] as String?;
    final secret = _setup?['secret'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_isSetup ? s.twoFactorSetupDesc : s.twoFactorVerifyDesc,
            style: TextStyle(color: AppTheme.textSecondary)),
        if (_isSetup && uri != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              color: AppTheme.background,
              padding: const EdgeInsets.all(8),
              child: QrImageView(data: uri, size: 200),
            ),
          ),
          const SizedBox(height: 8),
          Text(s.twoFactorManualKey, style: const TextStyle(fontSize: 12)),
          SelectableText(secret ?? '',
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _codeCtrl,
          autofocus: true,
          keyboardType: _isSetup ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: s.twoFactorCodeLabel,
            helperText: _isSetup ? null : s.twoFactorRecoveryHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy || (_isSetup && _setup == null) ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isSetup ? s.twoFactorEnableButton : s.twoFactorVerifyButton),
        ),
      ],
    );
  }

  Widget _buildRecovery(AppLocalizations s) {
    final codes = _recoveryCodes!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.verified_user, size: 40, color: AppTheme.secondary),
        const SizedBox(height: 12),
        Text(s.twoFactorRecoveryTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(s.twoFactorRecoveryDesc, style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.textSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(codes.join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 15, height: 1.6)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(text: codes.join('\n'))),
          icon: const Icon(Icons.copy, size: 16),
          label: Text(s.twoFactorCopyCodes),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(s.twoFactorSavedContinue),
        ),
      ],
    );
  }
}
