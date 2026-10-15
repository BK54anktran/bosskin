import 'package:flutter/material.dart';

import '../../../data/services/auth_service.dart';

import 'payroll_screen.dart';
import 'salary_grade_tab.dart';
import 'salary_formula_tab.dart';
import 'variables_tab.dart';
import 'package:bosskin/l10n/app_localizations.dart';

class PayrollTabScreen extends StatefulWidget {
  const PayrollTabScreen({super.key});

  @override
  State<PayrollTabScreen> createState() => _PayrollTabScreenState();
}

class _PayrollTabScreenState extends State<PayrollTabScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  /// V26: tab Biến & Công thức thuộc tính năng PAY_FORMULA; tắt thì chỉ còn Bảng lương + Bậc lương.
  late final bool _withFormula =
      AuthService.instance.currentUser?.hasFeature('PAY_FORMULA') ?? true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _withFormula ? 4 : 2, vsync: this, animationDuration: Duration.zero);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 0,
          child: TabBar(
            controller: _tab,
            tabs: [
              Tab(text: s.formulaTabPayroll),
              Tab(text: s.formulaTabGrade),
              if (_withFormula) Tab(text: s.formulaTabVariables),
              if (_withFormula) Tab(text: s.formulaTabFormula),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              const PayrollScreen(),
              const SalaryGradeTab(),
              if (_withFormula) const VariablesTab(),
              if (_withFormula) const SalaryFormulaTab(),
            ],
          ),
        ),
      ],
    );
  }
}
