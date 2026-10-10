import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';

/// Bước F — mục "Giao diện" ở Hồ sơ: theo hệ thống / sáng / tối (lưu trên máy này).
class AppearanceCard extends StatelessWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.dark_mode_outlined, size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(s.appearanceTitle,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ]),
            const SizedBox(height: 6),
            Text(s.appearanceHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(s.appearanceSystem)),
                ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined),
                    label: Text(s.appearanceLight)),
                ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(s.appearanceDark)),
              ],
              selected: {ThemeController.instance.mode},
              onSelectionChanged: (v) => ThemeController.instance.setMode(v.first),
            ),
          ]),
        ),
      ),
    );
  }
}
