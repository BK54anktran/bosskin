import 'package:flutter/material.dart';

import 'package:bosskin/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';

/// Giờ kèm chú thích nhỏ "+N" phía trên khi giờ đó lệch ngày công (vd. ca đêm vào 22:00, ra 06:00 hôm sau → "+1").
/// [dayOffset] = số ngày giờ đó cách ngày công: 0 = cùng ngày (không hiện gì), 1 = hôm sau, -1 = hôm trước.
class DayOffsetText extends StatelessWidget {
  final String text;
  final int dayOffset;
  final TextStyle? style;

  const DayOffsetText(this.text, {this.dayOffset = 0, this.style, super.key});

  static String label(int dayOffset) => dayOffset > 0 ? '+$dayOffset' : '$dayOffset';

  @override
  Widget build(BuildContext context) {
    final t = Text(text, style: style);
    if (dayOffset == 0 || text.isEmpty) return t;
    final s = AppLocalizations.of(context);
    return Tooltip(
      message: s.attendanceDayOffsetTooltip(label(dayOffset)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          t,
          Positioned(
            top: -8,
            right: -6,
            child: Text(
              label(dayOffset),
              style: const TextStyle(fontSize: 8, height: 1, fontWeight: FontWeight.w700, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
