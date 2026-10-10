import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/dependent.dart';
import '../../../data/repositories/dependent_repository.dart';
import '../employee/dependents_dialog.dart' show dependentRelationshipLabel, dependentStatusLabel;

/// Bước M — nhân viên xem người phụ thuộc của mình ở Hồ sơ (chỉ xem; nhờ HR thêm / sửa). Không có thì ẩn.
class MyDependentsCard extends StatefulWidget {
  const MyDependentsCard({super.key});

  @override
  State<MyDependentsCard> createState() => _MyDependentsCardState();
}

class _MyDependentsCardState extends State<MyDependentsCard> {
  List<Dependent> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await DependentRepository().getSelf();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // Không tải được thì ẩn thẻ, không chặn Hồ sơ
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final s = AppLocalizations.of(context);
    final monthFmt = DateFormat('MM/yyyy');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.dependentsTitle,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(s.dependentsHint, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            for (final d in _items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.family_restroom_outlined),
                title: Text('${d.fullName} · ${dependentRelationshipLabel(s, d.relationship)}'),
                subtitle: Text('${s.dependentPeriod}: ${monthFmt.format(d.deductionFrom)} – '
                    '${d.deductionTo == null ? s.dependentNoEnd : monthFmt.format(d.deductionTo!)}'
                    ' · ${dependentStatusLabel(s, d.registrationStatus)}'),
              ),
          ]),
        ),
      ),
    );
  }
}
