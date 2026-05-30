import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 0,
          child: TabBar(
            controller: _tab,
            tabs: [
              Tab(text: s.formulaTabGrade),
              Tab(text: s.formulaTabVariables),
              Tab(text: s.formulaTabFormula),
              Tab(text: s.formulaTabPayroll),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              SalaryGradeTab(),
              VariablesTab(),
              SalaryFormulaTab(),
              PayrollScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
