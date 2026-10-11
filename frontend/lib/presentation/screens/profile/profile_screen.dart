import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../auth/force_change_password_screen.dart' show isStrongPassword;
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/language_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/file_picker_utils.dart';
import '../../../data/repositories/upload_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/profile_service.dart';
import 'my_dependents_card.dart';
import 'my_documents_card.dart';
import 'appearance_card.dart';
import 'two_factor_card.dart';
import 'package:bosskin/l10n/app_localizations.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileData? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Controllers for editable fields
  final _fullNameCtrl    = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _personalEmailCtrl = TextEditingController();
  final _avatarCtrl      = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDob;

  bool get _isAdmin => AuthService.instance.currentUser?.isAdmin ?? false;

  // ── Notification settings state ──
  bool _notifEnabled = false;
  int _reminderMinutes = 30;
  bool _checkInOutEnabled = false;
  int _checkInOutMinutes = 5;
  bool _notifSaving = false;
  bool _notifTesting = false;

  static const _reminderOptions     = [15, 30, 60, 90, 120];
  static const _checkInOutOptions   = [5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _fullNameCtrl.addListener(_onEditableFieldChanged);
    _phoneCtrl.addListener(_onEditableFieldChanged);
    _personalEmailCtrl.addListener(_onEditableFieldChanged);
    _avatarCtrl.addListener(_onEditableFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfile();
    });
  }

  @override
  void dispose() {
    _fullNameCtrl.removeListener(_onEditableFieldChanged);
    _phoneCtrl.removeListener(_onEditableFieldChanged);
    _personalEmailCtrl.removeListener(_onEditableFieldChanged);
    _avatarCtrl.removeListener(_onEditableFieldChanged);
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _personalEmailCtrl.dispose();
    _avatarCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _onEditableFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    if (AuthService.instance.isImpersonating) {
      setState(() => _loading = false);
      return;
    }
    if (AuthService.instance.currentUser?.employeeId == null) {
      setState(() => _loading = false);
      return;
    }
    final s = AppLocalizations.of(context);
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ProfileService.instance.getMyProfile(),
        ProfileService.instance.getNotificationSettings(),
      ]);
      final p = results[0] as ProfileData;
      final n = results[1] as NotificationSettings;
      await AuthService.instance.syncCurrentUserProfile(p);
      setState(() {
        _profile = p;
        _fullNameCtrl.text      = p.fullName;
        _phoneCtrl.text         = p.phone ?? '';
        _personalEmailCtrl.text = p.personalEmail ?? '';
        _avatarCtrl.text        = p.avatar ?? '';
        _selectedGender         = p.gender;
        _selectedDob = p.dateOfBirth != null
            ? DateTime.tryParse(p.dateOfBirth!)
            : null;
        _notifEnabled        = n.enabled;
        _reminderMinutes     = n.shiftReminderMinutes ?? 30;
        _checkInOutEnabled   = n.checkInOutNotifMinutes != null;
        _checkInOutMinutes   = n.checkInOutNotifMinutes ?? 5;
      });
    } catch (e) {
      setState(() => _error = '${s.profileLoadError}: ${serverMsg(e)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Gửi thông báo thử tới chính thiết bị này: gắn lại token của máy (theo cài đặt đang chọn) rồi nhờ backend gửi.
  Future<void> _sendTestNotification() async {
    final s = AppLocalizations.of(context);
    final shiftMinutes      = _notifEnabled     ? _reminderMinutes   : null;
    final checkInOutMinutes = _checkInOutEnabled ? _checkInOutMinutes : null;
    if (shiftMinutes == null && checkInOutMinutes == null) {
      _showSnack(s.notificationTestNeedEnable);
      return;
    }
    setState(() => _notifTesting = true);
    try {
      if (!await NotificationService.instance.ensurePermission()) {
        if (mounted) _showSnack(s.notificationTestPermissionDenied);
        return;
      }
      if (await NotificationService.instance.deviceToken() == null) {
        if (mounted) _showSnack(s.notificationTestNoDevice);
        return;
      }
      await NotificationService.instance.registerToken(
        shiftReminderMinutes: shiftMinutes,
        checkInOutNotifMinutes: checkInOutMinutes,
      );
      await ProfileService.instance.sendTestNotification(
        title: s.notificationTestTitle,
        body: s.notificationTestBody,
      );
      if (mounted) _showSnack(s.notificationTestSent, success: true);
    } catch (e) {
      if (mounted) _showSnack('${s.errorPrefix}: ${serverMsg(e)}');
    } finally {
      if (mounted) setState(() => _notifTesting = false);
    }
  }

  Future<void> _saveNotificationSettings() async {
    final s = AppLocalizations.of(context);
    setState(() => _notifSaving = true);
    try {
      final shiftMinutes      = _notifEnabled      ? _reminderMinutes   : null;
      final checkInOutMinutes = _checkInOutEnabled  ? _checkInOutMinutes : null;
      if (shiftMinutes == null && checkInOutMinutes == null) {
        await NotificationService.instance.disableNotifications();
      } else {
        await NotificationService.instance.registerToken(
          shiftReminderMinutes: shiftMinutes,
          checkInOutNotifMinutes: checkInOutMinutes,
        );
      }
      if (mounted) _showSnack(s.notificationSaveSuccess, success: true);
    } catch (e) {
      if (mounted) _showSnack('${s.errorPrefix}: ${serverMsg(e)}');
    } finally {
      if (mounted) setState(() => _notifSaving = false);
    }
  }

  Future<void> _updateAvatar() async {
    final picked = await pickImageFile();
    if (picked == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final bytes = picked.bytes;
      final filename = picked.filename;
      final url = await UploadRepository().uploadImage(
        bytes: bytes,
        filename: filename,
        folder: 'avatars',
      );
      final updated = await ProfileService.instance.updateAvatar(url);
      await AuthService.instance.syncCurrentUserProfile(updated);
      if (!mounted) return;
      final s = AppLocalizations.of(context);
      setState(() {
        _profile = updated;
        _avatarCtrl.text = url;
      });
      _showSnack(s.avatarUpdatedSuccess, success: true);
    } catch (e) {
      if (mounted) {
        final s = AppLocalizations.of(context);
        _showSnack('${s.errorPrefix}: ${serverMsg(e)}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _adminSave() async {
    final s = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final updated = await ProfileService.instance.adminUpdateProfile(
        fullName:      _fullNameCtrl.text.trim().isEmpty ? null : _fullNameCtrl.text.trim(),
        gender:        _selectedGender,
        dateOfBirth:   _selectedDob != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDob!)
            : null,
        phone:         _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        personalEmail: _personalEmailCtrl.text.trim().isEmpty ? null : _personalEmailCtrl.text.trim(),
        avatar:        _avatarCtrl.text.trim().isEmpty ? null : _avatarCtrl.text.trim(),
      );
      await AuthService.instance.syncCurrentUserProfile(updated);
      setState(() => _profile = updated);
      if (mounted) _showSnack(s.saveSuccess, success: true);
    } catch (e) {
      if (mounted) _showSnack('${s.errorPrefix}: ${serverMsg(e)}');
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _submitRequest() async {
    final s = AppLocalizations.of(context);
    final hasChange = _hasProfileChanges();

    if (!hasChange) {
      _showSnack(s.noChanges);
      return;
    }

    setState(() => _saving = true);
    try {
      await ProfileService.instance.submitEditRequest(
        fullName: _fullNameCtrl.text.trim() != (_profile?.fullName ?? '')
            ? _fullNameCtrl.text.trim() : null,
        gender: _selectedGender != _profile?.gender ? _selectedGender : null,
        dateOfBirth: _selectedDob != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDob!) : null,
        phone: _phoneCtrl.text.trim() != (_profile?.phone ?? '')
            ? _phoneCtrl.text.trim() : null,
        personalEmail: _personalEmailCtrl.text.trim() != (_profile?.personalEmail ?? '')
            ? _personalEmailCtrl.text.trim() : null,
      );
      if (mounted) {
        _showSnack(s.requestSentSuccess, success: true);
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) _showSnack('${s.errorPrefix}: ${serverMsg(e)}');
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _cancelProfileChanges() async {
    if (_saving) return;
    final p = _profile;
    if (p == null) return;

    setState(() {
      _fullNameCtrl.text = p.fullName;
      _phoneCtrl.text = p.phone ?? '';
      _personalEmailCtrl.text = p.personalEmail ?? '';
      _avatarCtrl.text = p.avatar ?? '';
      _selectedGender = p.gender;
      _selectedDob = p.dateOfBirth != null
          ? DateTime.tryParse(p.dateOfBirth!)
          : null;
    });
  }

  bool _hasProfileChanges() {
    if (_profile == null) return false;

    final fullNameChanged =
        _fullNameCtrl.text.trim() != (_profile?.fullName ?? '');
    final phoneChanged =
        _phoneCtrl.text.trim() != (_profile?.phone ?? '');
    final emailChanged =
        _personalEmailCtrl.text.trim() != (_profile?.personalEmail ?? '');
    final genderChanged = _selectedGender != _profile?.gender;
    final dobChanged = !_sameDate(_selectedDob, _profile?.dateOfBirth);

    return fullNameChanged ||
        phoneChanged ||
        emailChanged ||
        genderChanged ||
        dobChanged;
  }

  bool _sameDate(DateTime? selected, String? isoDate) {
    final currentDate =
        isoDate == null || isoDate.isEmpty ? null : DateTime.tryParse(isoDate);

    if (selected == null && currentDate == null) return true;
    if (selected == null || currentDate == null) return false;

    return selected.year == currentDate.year &&
        selected.month == currentDate.month &&
        selected.day == currentDate.day;
  }

  Future<void> _changePassword() async {
    final s = AppLocalizations.of(context);
    final current = _currentPasswordCtrl.text.trim();
    final next = _newPasswordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _showSnack(s.fillAllPasswordFields);
      return;
    }
    if (!isStrongPassword(next)) {
      _showSnack(s.newPasswordMinLength);
      return;
    }
    if (next != confirm) {
      _showSnack(s.passwordMismatch);
      return;
    }

    setState(() => _saving = true);
    try {
      await ProfileService.instance.changePassword(
        currentPassword: current,
        newPassword: next,
        confirmPassword: confirm,
      );
      if (!mounted) return;
      _showSnack(s.updatePasswordSuccess, success: true);
      await AuthService.instance.logout();
      if (mounted) context.go(AppRoutes.login);
    } catch (e) {
      if (mounted) _showSnack('${s.errorPrefix}: ${serverMsg(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppTheme.secondary : AppTheme.error,
    ));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final s = AppLocalizations.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: now,
      locale: LanguageService.instance.locale,
      helpText: s.chooseDate,
      cancelText: s.dateCancel,
      confirmText: s.dateOk,
    );
    if (picked != null) setState(() => _selectedDob = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.instance.isImpersonating) {
      return _buildImpersonatePlaceholder(context);
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (AuthService.instance.currentUser?.employeeId == null) return _buildAccountOnly();
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)));
    return _buildBody();
  }

  Widget _buildPasswordCard(AppLocalizations s) {
    return _InfoCard(
      title: s.changePassword,
      subtitle: s.passwordNote,
      children: [
        _EditableField(
          label: s.currentPassword,
          controller: _currentPasswordCtrl,
          obscureText: true,
        ),
        const SizedBox(height: 12),
        _EditableField(
          label: s.newPassword,
          controller: _newPasswordCtrl,
          obscureText: true,
        ),
        const SizedBox(height: 12),
        _EditableField(
          label: s.confirmPassword,
          controller: _confirmPasswordCtrl,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _changePassword,
            icon: const Icon(Icons.lock_reset_outlined),
            label: Text(s.changePassword),
          ),
        ),
      ],
    );
  }

  /// Tài khoản quản trị không gắn nhân viên (vd. admin công ty): chỉ có phần tài khoản — 2FA và đổi mật khẩu.
  Widget _buildAccountOnly() {
    final s = AppLocalizations.of(context);
    final user = AuthService.instance.currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoCard(
                title: s.profileAccountTitle,
                subtitle: s.profileNoEmployeeNote,
                children: [
                  Text(user?.email ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              const AppearanceCard(),
              const TwoFactorCard(),
              const SizedBox(height: 16),
              _buildPasswordCard(s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImpersonatePlaceholder(BuildContext context) {
    final s = AppLocalizations.of(context);
    final user = AuthService.instance.currentUser;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 64, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(
            user?.email ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            s.impersonatingCompanyNotice,
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final s = AppLocalizations.of(context);
    final p = _profile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarSection(
                avatarUrl: p.avatar,
                name: p.fullName,
                onEdit: _updateAvatar,
                saving: _saving,
              ),
              const SizedBox(height: 24),
              _InfoCard(
                title: s.workInfo,
                children: [
                  _ReadOnlyField(s.employeeCode, p.employeeCode),
                  _ReadOnlyField(s.department, p.departmentName),
                  _ReadOnlyField(s.position, p.positionName),
                  _ReadOnlyField(s.workEmail, p.workEmail),
                  _ReadOnlyField(
                    s.joinDate,
                    p.joinDate != null
                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(p.joinDate!))
                        : '-',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: _isAdmin
                    ? s.editInfoAdminTitle
                    : s.editInfoTitle,
                subtitle: _isAdmin
                    ? null
                    : s.editInfoSubtitle,
                children: [
                  _EditableField(
                    label: s.fullName,
                    controller: _fullNameCtrl,
                    readOnly: false,
                  ),
                  const SizedBox(height: 12),
                  _GenderDropdown(
                    strings: s,
                    value: _selectedGender,
                    onChanged: (v) => setState(() => _selectedGender = v),
                  ),
                  const SizedBox(height: 12),
                  _DateField(
                    label: s.dateOfBirth,
                    value: _selectedDob,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 12),
                  _EditableField(
                    label: s.phone,
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _EditableField(
                    label: s.personalEmail,
                    controller: _personalEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (_hasProfileChanges()) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _cancelProfileChanges,
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(s.cancel),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              foregroundColor: AppTheme.textPrimary,
                              side: BorderSide(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(
                              _isAdmin ? Icons.save_outlined : Icons.send_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _isAdmin ? s.saveChanges : s.sendRequest,
                            ),
                            onPressed: _saving
                                ? null
                                : (_isAdmin ? _adminSave : _submitRequest),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _NotificationSettingsCard(
                enabled: _notifEnabled,
                reminderMinutes: _reminderMinutes,
                reminderOptions: _reminderOptions,
                checkInOutEnabled: _checkInOutEnabled,
                checkInOutMinutes: _checkInOutMinutes,
                checkInOutOptions: _checkInOutOptions,
                saving: _notifSaving,
                onToggle: (val) => setState(() => _notifEnabled = val),
                onMinutesChanged: (val) => setState(() => _reminderMinutes = val),
                onCheckInOutToggle: (val) => setState(() => _checkInOutEnabled = val),
                onCheckInOutMinutesChanged: (val) => setState(() => _checkInOutMinutes = val),
                onSave: _saveNotificationSettings,
                testing: _notifTesting,
                // Web không nhận thông báo đẩy → chỉ hiện nút thử trên app điện thoại
                onTest: kIsWeb ? null : _sendTestNotification,
              ),
              const SizedBox(height: 16),
              const MyDependentsCard(),
              const MyDocumentsCard(),
              const AppearanceCard(),
              const TwoFactorCard(),
              const SizedBox(height: 16),
              _buildPasswordCard(s),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _NotificationSettingsCard extends StatelessWidget {
  final bool enabled;
  final int reminderMinutes;
  final List<int> reminderOptions;
  final bool checkInOutEnabled;
  final int checkInOutMinutes;
  final List<int> checkInOutOptions;
  final bool saving;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onMinutesChanged;
  final ValueChanged<bool> onCheckInOutToggle;
  final ValueChanged<int> onCheckInOutMinutesChanged;
  final VoidCallback onSave;
  final bool testing;
  final VoidCallback? onTest;

  const _NotificationSettingsCard({
    required this.enabled,
    required this.reminderMinutes,
    required this.reminderOptions,
    required this.checkInOutEnabled,
    required this.checkInOutMinutes,
    required this.checkInOutOptions,
    required this.saving,
    required this.onToggle,
    required this.onMinutesChanged,
    required this.onCheckInOutToggle,
    required this.onCheckInOutMinutesChanged,
    required this.onSave,
    this.testing = false,
    this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.notificationSettings,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 16),

            // ── Nhắc ca ───────────────────────────────────────────────
            _NotifRow(
              title: s.shiftReminderTitle,
              subtitle: s.shiftReminderDesc,
              value: enabled,
              onChanged: saving ? null : onToggle,
            ),
            if (enabled) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: reminderMinutes,
                decoration: InputDecoration(
                    labelText: s.shiftReminderMinutesLabel,
                    labelStyle: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
                items: reminderOptions
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(s.minutesBefore(m))))
                    .toList(),
                onChanged: saving ? null : (v) { if (v != null) onMinutesChanged(v); },
                borderRadius: BorderRadius.circular(12),
              ),
            ],

            const Divider(height: 28),

            // ── Check-in / Check-out nhanh ────────────────────────────
            _NotifRow(
              title: s.checkInOutNotifTitle,
              subtitle: s.checkInOutNotifDesc,
              value: checkInOutEnabled,
              onChanged: saving ? null : onCheckInOutToggle,
            ),
            if (checkInOutEnabled) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: checkInOutMinutes,
                decoration: InputDecoration(
                    labelText: s.checkInOutNotifMinutesLabel,
                    labelStyle: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
                items: checkInOutOptions
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(s.minutesBefore(m))))
                    .toList(),
                onChanged: saving ? null : (v) { if (v != null) onCheckInOutMinutesChanged(v); },
                borderRadius: BorderRadius.circular(12),
              ),
            ],

            if (onTest != null) ...[
              const SizedBox(height: 16),
              Text(s.notificationTestHint,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (onTest != null)
                    OutlinedButton.icon(
                      onPressed: saving || testing ? null : onTest,
                      icon: testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_outlined, size: 18),
                      label: Text(s.notificationTestButton),
                    ),
                  FilledButton.icon(
                    onPressed: saving || testing ? null : onSave,
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.notifications_outlined, size: 18),
                    label: Text(s.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _NotifRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _AvatarSection extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final VoidCallback onEdit;
  final bool saving;

  const _AvatarSection({
    required this.avatarUrl,
    required this.name,
    required this.onEdit,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            backgroundImage:
                avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
            child: (avatarUrl == null || avatarUrl!.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: MouseRegion(
              cursor: saving ? SystemMouseCursors.basic : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: saving ? null : onEdit,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool readOnly;
  final bool obscureText;

  const _EditableField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _GenderDropdown extends StatelessWidget {
  final AppLocalizations strings;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _GenderDropdown({
    required this.strings,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      borderRadius: BorderRadius.circular(12),
      decoration: InputDecoration(labelText: strings.gender),
      items: [
        DropdownMenuItem(value: 'MALE',   child: Text(strings.genderMale)),
        DropdownMenuItem(value: 'FEMALE', child: Text(strings.genderFemale)),
        DropdownMenuItem(value: 'OTHER',  child: Text(strings.genderOther)),
      ],
      onChanged: onChanged,
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          controller: TextEditingController(
            text: value != null
                ? DateFormat('dd/MM/yyyy').format(value!)
                : '',
          ),
        ),
      ),
    );
  }
}
