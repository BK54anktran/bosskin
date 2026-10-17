import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/notification_service.dart';

/// Một dòng thông báo (dùng ở chuông thông báo và màn Thông báo).
class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final Widget? trailing;
  const NotificationTile(this.notification, {super.key, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: _iconColor.withValues(alpha: 0.12),
        child: Icon(_icon, color: _iconColor, size: 20),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontSize: 13,
          fontWeight:
              notification.isRead ? FontWeight.w400 : FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.body.isNotEmpty)
            Text(
              notification.body,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 2),
          Text(
            _relativeTime(AppLocalizations.of(context), notification.time),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon {
    return switch (notification.type) {
      'CHECK_IN_REMINDER'  => Icons.login_outlined,
      'CHECK_OUT_REMINDER' => Icons.logout_outlined,
      'ATTENDANCE_LATE'    => Icons.schedule_outlined,
      'ATTENDANCE_EARLY'   => Icons.directions_run_outlined,
      _                    => Icons.notifications_outlined,
    };
  }

  Color get _iconColor {
    return switch (notification.type) {
      'CHECK_IN_REMINDER'  => AppTheme.success,
      'CHECK_OUT_REMINDER' => AppTheme.warning,
      'ATTENDANCE_LATE'    => AppTheme.warning,
      'ATTENDANCE_EARLY'   => AppTheme.warning,
      _                    => AppTheme.primary,
    };
  }

  String _relativeTime(AppLocalizations s, DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return s.uiJustNow;
    if (diff.inMinutes < 60) return s.uiMinutesAgo('${diff.inMinutes}');
    if (diff.inHours < 24) return s.uiHoursAgo('${diff.inHours}');
    return s.uiDaysAgo('${diff.inDays}');
  }
}

