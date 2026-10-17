import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

Future<T?> showInstantDialog<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: '',
    barrierColor: Colors.black54,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) => builder(ctx),
  );
}

Future<T?> showInstantBottomSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: builder,
  );
}

/// Hộp xác nhận Huỷ / Xác nhận; trả true khi người dùng xác nhận.
Future<bool> confirmDialog(BuildContext context, {required String message, String? confirmLabel}) async {
  final s = AppLocalizations.of(context);
  final ok = await showInstantDialog<bool>(
    context,
    (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel ?? s.confirm)),
      ],
    ),
  );
  return ok ?? false;
}
