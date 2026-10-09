import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/payroll.dart';

/// Dòng tham khảo dưới phiếu lương: lương đóng BH (đã áp trần) và giảm trừ gia cảnh dùng khi tính thuế (bước I).
/// Phiếu tạo trước V13 không có hai số này thì không hiện.
class PayslipTaxInfo extends StatelessWidget {
  final Payroll payroll;
  const PayslipTaxInfo({super.key, required this.payroll});

  static final _fmt = NumberFormat('#,###', 'vi_VN');

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final base = payroll.insuranceBase, fam = payroll.familyDeduction;
    if (base == null && fam == null) return const SizedBox.shrink();
    const style = TextStyle(fontSize: 12, color: AppTheme.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (base != null) Text('${s.payslipInsuranceBase}: ${_fmt.format(base)}', style: style),
        if (fam != null) Text('${s.payslipFamilyDeduction}: ${_fmt.format(fam)}', style: style),
      ]),
    );
  }
}
