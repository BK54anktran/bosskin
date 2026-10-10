import 'package:flutter/foundation.dart';

import '../repositories/team_approval_repository.dart';
import 'auth_service.dart';

/// Bước K — menu "Duyệt cho nhóm": chỉ hiện khi công ty bật quản lý trực tiếp duyệt trước
/// và người dùng có cấp dưới trực tiếp. [count] = số đơn đang chờ mình (badge).
class TeamApprovalService extends ChangeNotifier {
  TeamApprovalService._();
  static final TeamApprovalService instance = TeamApprovalService._();

  final _repo = TeamApprovalRepository();
  bool _visible = false;
  int _count = 0;

  bool get visible => _visible;
  int get count => _count;

  Future<void> refresh() async {
    final user = AuthService.instance.currentUser;
    bool visible = false;
    int count = 0;
    if (user != null && !user.isSystemAdmin && user.employeeId != null) {
      try {
        final r = await _repo.count();
        visible = r.enabled && r.reportCount > 0;
        count = r.count;
      } catch (_) {
        // Lỗi mạng / backend cũ → ẩn menu, không chặn giao diện
      }
    }
    if (visible != _visible || count != _count) {
      _visible = visible;
      _count = count;
      notifyListeners();
    }
  }
}
