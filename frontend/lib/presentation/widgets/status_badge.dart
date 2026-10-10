import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Generic badge: label + color. Dùng cho mọi trạng thái trong app.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 11,
  });

  /// Preset cho leave/attendance/payroll request status.
  factory StatusBadge.requestStatus(String status, AppLocalizations s) {
    final (label, color) = switch (status) {
      'APPROVED' => (s.approved, AppTheme.secondary),
      'REJECTED' => (s.rejected, AppTheme.error),
      'CANCELLED' => (s.cancelled, AppTheme.textSecondary),
      _ => (s.pending, AppTheme.warning),
    };
    return StatusBadge(label: label, color: color);
  }

  /// Bước K: nhãn bước quản lý trực tiếp trên đơn chờ duyệt — "Chờ QL: tên" hoặc "QL đã duyệt: tên".
  /// Không có bước quản lý → null.
  static Widget? managerStep(AppLocalizations s, {String? awaitingManagerName, String? managerApprovedByName}) {
    if (awaitingManagerName != null && awaitingManagerName.isNotEmpty) {
      return StatusBadge(label: s.approvalAwaitingManager(awaitingManagerName), color: AppTheme.warning);
    }
    if (managerApprovedByName != null && managerApprovedByName.isNotEmpty) {
      return StatusBadge(label: s.approvalManagerApproved(managerApprovedByName), color: AppTheme.secondary);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
