import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../data/services/notification_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/notification_tile.dart';
import 'notification_settings_tab.dart';

/// Màn Thông báo: hộp thư (lưu ở máy chủ, mọi thiết bị thấy giống nhau) + cài đặt thông báo của tài khoản.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.refreshInbox();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: s.notificationsInboxTab),
                Tab(text: s.notificationsSettingsTab),
              ],
            ),
          ),
          const Divider(height: 1),
          const Expanded(
            child: TabBarView(children: [_InboxTab(), NotificationSettingsTab()]),
          ),
        ],
      ),
    );
  }
}

class _InboxTab extends StatelessWidget {
  const _InboxTab();

  Future<void> _clearAll(BuildContext context) async {
    final s = AppLocalizations.of(context);
    final ok = await confirmDialog(context, message: s.notificationsClearConfirm);
    if (ok) await NotificationService.instance.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationService.instance.inbox,
      builder: (context, list, _) {
        if (list.isEmpty) {
          return RefreshIndicator(
            onRefresh: NotificationService.instance.refreshInbox,
            child: ListView(children: [
              const SizedBox(height: 80),
              EmptyState(icon: Icons.notifications_none_outlined, message: s.noNotificationsYet),
            ]),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.notificationsSharedHint,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                  TextButton(
                    onPressed: NotificationService.instance.markAllRead,
                    child: Text(s.notificationsMarkAllRead, style: const TextStyle(fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: () => _clearAll(context),
                    child: Text(s.notificationsClearAll, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: NotificationService.instance.refreshInbox,
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final n = list[i];
                    return NotificationTile(
                      n,
                      onTap: () => NotificationService.instance.markRead(n),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: AppTheme.textSecondary,
                        onPressed: () => NotificationService.instance.deleteNotification(n),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
