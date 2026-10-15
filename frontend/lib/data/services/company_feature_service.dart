import 'package:flutter/foundation.dart';

import '../repositories/company_setting_repository.dart';
import 'auth_service.dart';

/// Tính năng công ty bật / tắt mà menu cần biết (hiện có: đăng ký lịch làm việc — V23).
/// Đọc từ cài đặt công ty; lỗi mạng → coi như tắt, không chặn giao diện.
class CompanyFeatureService extends ChangeNotifier {
  CompanyFeatureService._();
  static final CompanyFeatureService instance = CompanyFeatureService._();

  final _repo = CompanySettingRepository();
  bool _shiftRegistration = false;

  bool get shiftRegistration => _shiftRegistration;

  Future<void> refresh() async {
    final user = AuthService.instance.currentUser;
    bool enabled = false;
    if (user != null && !user.isSystemAdmin) {
      try {
        final data = await _repo.get();
        // V26: cài đặt bật nhưng tính năng đăng ký lịch của công ty tắt → coi như tắt
        enabled = (data['shiftRegistration'] as Map?)?['enabled'] == true && user.hasFeature('SHIFT_REGISTRATION');
      } catch (_) {}
    }
    if (enabled != _shiftRegistration) {
      _shiftRegistration = enabled;
      notifyListeners();
    }
  }
}
