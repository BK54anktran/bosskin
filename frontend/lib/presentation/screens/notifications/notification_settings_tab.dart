import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/profile_service.dart';

/// Cài đặt thông báo của tài khoản (lưu ở máy chủ, dùng chung mọi thiết bị): nhắc ca, nhắc check-in / check-out,
/// và — với quản lý trực tiếp — báo nhân viên đi trễ / về sớm.
class NotificationSettingsTab extends StatefulWidget {
  const NotificationSettingsTab({super.key});

  @override
  State<NotificationSettingsTab> createState() => _NotificationSettingsTabState();
}

class _NotificationSettingsTabState extends State<NotificationSettingsTab> {
  static const _reminderOptions = [15, 30, 60, 90, 120];
  static const _checkInOutOptions = [5, 10, 15, 30];

  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _testing = false;

  int _devices = 0;
  bool _manager = false;
  bool _shiftEnabled = false;
  int _shiftMinutes = 30;
  bool _checkInOutEnabled = false;
  int _checkInOutMinutes = 5;
  bool _lateAlert = false;
  bool _earlyLeaveAlert = false;

  /// Nhắc ca / check-in cần gắn nhân viên; tài khoản quản trị công ty không có thì chỉ có mục báo cho quản lý (nếu có).
  bool get _hasEmployee => AuthService.instance.currentUser?.employeeId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final n = await ProfileService.instance.getNotificationSettings();
      if (!mounted) return;
      setState(() {
        _devices = n.deviceCount;
        _manager = n.manager;
        _shiftEnabled = n.shiftReminderMinutes != null;
        _shiftMinutes = n.shiftReminderMinutes ?? 30;
        _checkInOutEnabled = n.checkInOutNotifMinutes != null;
        _checkInOutMinutes = n.checkInOutNotifMinutes ?? 5;
        _lateAlert = n.lateAlert;
        _earlyLeaveAlert = n.earlyLeaveAlert;
      });
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _wantsPush => _shiftEnabled || _checkInOutEnabled || _lateAlert || _earlyLeaveAlert;

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppTheme.secondary : AppTheme.error,
    ));
  }

  /// Gắn thiết bị này vào tài khoản (nếu có bật gì) và lưu cài đặt.
  Future<void> _save() async {
    final s = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final shift = _shiftEnabled ? _shiftMinutes : null;
      final inOut = _checkInOutEnabled ? _checkInOutMinutes : null;
      if (!_wantsPush) {
        await NotificationService.instance.saveSettingsOnly(
          shiftReminderMinutes: null,
          checkInOutNotifMinutes: null,
          lateAlert: false,
          earlyLeaveAlert: false,
        );
      } else {
        // Bản web: trình duyệt chỉ cho xin quyền thông báo ngay sau một lần bấm nút
        if (kIsWeb &&
            NotificationService.instance.available &&
            !await NotificationService.instance.ensurePermission()) {
          if (mounted) _snack(s.notificationPermissionDeniedWeb);
          return;
        }
        await NotificationService.instance.registerToken(
          shiftReminderMinutes: shift,
          checkInOutNotifMinutes: inOut,
          lateAlert: _lateAlert,
          earlyLeaveAlert: _earlyLeaveAlert,
        );
      }
      await _load();
      if (mounted) _snack(s.notificationSaveSuccess, success: true);
    } catch (e) {
      if (mounted) _snack('${s.errorPrefix}: ${serverMsg(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Gửi thông báo thử tới MỌI thiết bị của tài khoản (gắn lại thiết bị này theo cài đặt đang chọn rồi nhờ máy chủ gửi).
  Future<void> _sendTest() async {
    final s = AppLocalizations.of(context);
    if (!_wantsPush) {
      _snack(s.notificationTestNeedEnable);
      return;
    }
    setState(() => _testing = true);
    try {
      if (!await NotificationService.instance.ensurePermission()) {
        if (mounted) _snack(kIsWeb ? s.notificationPermissionDeniedWeb : s.notificationTestPermissionDenied);
        return;
      }
      if (await NotificationService.instance.deviceToken() == null) {
        if (mounted) _snack(s.notificationTestNoDevice);
        return;
      }
      await NotificationService.instance.registerToken(
        shiftReminderMinutes: _shiftEnabled ? _shiftMinutes : null,
        checkInOutNotifMinutes: _checkInOutEnabled ? _checkInOutMinutes : null,
        lateAlert: _lateAlert,
        earlyLeaveAlert: _earlyLeaveAlert,
      );
      await ProfileService.instance.sendTestNotification(
        title: s.notificationTestTitle,
        body: s.notificationTestBody,
      );
      await NotificationService.instance.refreshInbox();
      if (mounted) _snack(s.notificationTestSent, success: true);
    } catch (e) {
      if (mounted) _snack('${s.errorPrefix}: ${serverMsg(e)}');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: TextStyle(color: AppTheme.error)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _load, child: Text(s.retry)),
        ]),
      );
    }
    final busy = _saving || _testing;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.notificationSettings,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text(s.notificationsSharedHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      _devices > 0 ? s.notificationsDevices('$_devices') : s.notificationsNoDevice,
                      style: TextStyle(fontSize: 12, color: _devices > 0 ? AppTheme.secondary : AppTheme.warning),
                    ),
                    const SizedBox(height: 16),
                    if (_hasEmployee) ...[
                      _NotifRow(
                        title: s.shiftReminderTitle,
                        subtitle: s.shiftReminderDesc,
                        value: _shiftEnabled,
                        onChanged: busy ? null : (v) => setState(() => _shiftEnabled = v),
                      ),
                      if (_shiftEnabled) ...[
                        const SizedBox(height: 12),
                        _MinutesDropdown(
                          label: s.shiftReminderMinutesLabel,
                          value: _shiftMinutes,
                          options: _reminderOptions,
                          onChanged: busy ? null : (v) => setState(() => _shiftMinutes = v),
                        ),
                      ],
                      const Divider(height: 28),
                      _NotifRow(
                        title: s.checkInOutNotifTitle,
                        subtitle: s.checkInOutNotifDesc,
                        value: _checkInOutEnabled,
                        onChanged: busy ? null : (v) => setState(() => _checkInOutEnabled = v),
                      ),
                      if (_checkInOutEnabled) ...[
                        const SizedBox(height: 12),
                        _MinutesDropdown(
                          label: s.checkInOutNotifMinutesLabel,
                          value: _checkInOutMinutes,
                          options: _checkInOutOptions,
                          onChanged: busy ? null : (v) => setState(() => _checkInOutMinutes = v),
                        ),
                      ],
                    ],
                    if (_manager) ...[
                      if (_hasEmployee) const Divider(height: 28),
                      Text(s.managerAlertsTitle,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(s.managerAlertsDesc, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      _NotifRow(
                        title: s.lateAlertTitle,
                        subtitle: s.lateAlertDesc,
                        value: _lateAlert,
                        onChanged: busy ? null : (v) => setState(() => _lateAlert = v),
                      ),
                      const SizedBox(height: 12),
                      _NotifRow(
                        title: s.earlyLeaveAlertTitle,
                        subtitle: s.earlyLeaveAlertDesc,
                        value: _earlyLeaveAlert,
                        onChanged: busy ? null : (v) => setState(() => _earlyLeaveAlert = v),
                      ),
                    ],
                    if (NotificationService.instance.available) ...[
                      const SizedBox(height: 16),
                      Text(s.notificationTestHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          if (NotificationService.instance.available)
                            OutlinedButton.icon(
                              onPressed: busy ? null : _sendTest,
                              icon: _testing
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.send_outlined, size: 18),
                              label: Text(s.notificationTestButton),
                            ),
                          FilledButton.icon(
                            onPressed: busy ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.notifications_outlined, size: 18),
                            label: Text(s.save),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MinutesDropdown extends StatelessWidget {
  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int>? onChanged;

  const _MinutesDropdown({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      items: options.map((m) => DropdownMenuItem(value: m, child: Text(s.minutesBefore(m)))).toList(),
      onChanged: onChanged == null ? null : (v) { if (v != null) onChanged!(v); },
      borderRadius: BorderRadius.circular(12),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _NotifRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
