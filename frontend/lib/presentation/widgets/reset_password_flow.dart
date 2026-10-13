import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../data/services/api_service.dart';

/// Đặt lại mật khẩu cho người khác: hỏi xác nhận → gọi [endpoint] (POST, trả `{password}`) → hiện mật khẩu tạm
/// một lần kèm nút chép. Dùng ở tab Người dùng (`/users/{id}/reset-password`) và màn Nhân viên
/// (`/users/by-employee/{id}/reset-password`). Người được đặt lại phải đổi mật khẩu ở lần đăng nhập tới.
Future<void> resetPasswordFlow(BuildContext context, {required String name, required String endpoint}) async {
  final s = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.userResetPasswordTitle),
      content: Text(s.userResetPasswordConfirm(name)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.confirm)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final r = await ApiService.instance.dio.post(endpoint);
    final pw = (r.data as Map)['password']?.toString() ?? '';
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.userResetPasswordDoneTitle),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.userResetPasswordDoneHint(name)),
          const SizedBox(height: 12),
          SelectableText(pw, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ]),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: Text(s.sysAdminCopyPassword),
            onPressed: () => Clipboard.setData(ClipboardData(text: pw)),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close)),
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
      );
    }
  }
}
