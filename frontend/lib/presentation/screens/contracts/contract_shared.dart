import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/labor_contract.dart';
import '../../widgets/status_badge.dart';

/// Nhãn loại hợp đồng.
String contractTypeLabel(AppLocalizations s, String type) => switch (type) {
      'PROBATION' => s.contractTypeProbation,
      'FIXED_TERM' => s.contractTypeFixedTerm,
      'INDEFINITE' => s.contractTypeIndefinite,
      'SEASONAL' => s.contractTypeSeasonal,
      'SERVICE' => s.contractTypeService,
      _ => type,
    };

/// Nhãn trạng thái hiển thị (DRAFT | ACTIVE | EXPIRED | TERMINATED).
String contractStatusLabel(AppLocalizations s, String status) => switch (status) {
      'DRAFT' => s.contractStatusDraft,
      'ACTIVE' => s.contractStatusActive,
      'EXPIRED' => s.contractStatusExpired,
      'TERMINATED' => s.contractStatusTerminated,
      _ => status,
    };

Color contractStatusColor(String status) => switch (status) {
      'ACTIVE' => AppTheme.secondary,
      'EXPIRED' => AppTheme.error,
      'TERMINATED' => AppTheme.textSecondary,
      _ => AppTheme.warning,
    };

Widget contractStatusBadge(AppLocalizations s, LaborContract c) =>
    StatusBadge(label: contractStatusLabel(s, c.displayStatus), color: contractStatusColor(c.displayStatus));

/// "Còn 20 ngày" / "Quá hạn 3 ngày"; null khi không thời hạn hoặc không còn hiệu lực.
String? contractDaysText(AppLocalizations s, LaborContract c) {
  final d = c.daysToEnd;
  if (d == null || !c.isActive) return null;
  return d >= 0 ? s.contractDaysLeft(d) : s.contractOverdue(-d);
}
