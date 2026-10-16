import '../../core/utils/text_utils.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/payroll.dart';

/// Dòng tham khảo dưới phiếu lương: lương đóng BH (đã áp trần) và giảm trừ gia cảnh dùng khi tính thuế (bước I).
/// Phiếu tạo trước V13 không có hai số này thì không hiện. Bước M: số người phụ thuộc; [showEmployerCost]
/// (màn HR) hiện thêm phần BH công ty đóng.
class PayslipTaxInfo extends StatelessWidget {
  final Payroll payroll;
  final bool showEmployerCost;
  const PayslipTaxInfo({super.key, required this.payroll, this.showEmployerCost = false});

  static NumberFormat get _fmt => moneyNumberFormat('#,##0');

  double get _employerTotal =>
      (payroll.employerSocialIns ?? 0) + (payroll.employerHealthIns ?? 0) + (payroll.employerUnemploymentIns ?? 0);

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final base = payroll.insuranceBase, fam = payroll.familyDeduction;
    if (base == null && fam == null) return const SizedBox.shrink();
    final style = TextStyle(fontSize: 12, color: AppTheme.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (base != null) Text('${s.payslipInsuranceBase}: ${_fmt.format(base)}', style: style),
        if (fam != null)
          Text(
              '${s.payslipFamilyDeduction}: ${_fmt.format(fam)}'
              '${(payroll.dependents ?? 0) > 0 ? ' (${s.payslipDependents(payroll.dependents!)})' : ''}',
              style: style),
        if (showEmployerCost && payroll.employerSocialIns != null)
          Text(
              '${s.payslipEmployerInsurance}: ${_fmt.format(_employerTotal)} '
              '(${_fmt.format(payroll.employerSocialIns ?? 0)} / ${_fmt.format(payroll.employerHealthIns ?? 0)}'
              ' / ${_fmt.format(payroll.employerUnemploymentIns ?? 0)})',
              style: style),
      ]),
    );
  }
}
