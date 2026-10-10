import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/labor_contract.dart';

/// Sửa danh sách phụ cấp của hợp đồng / phụ lục. Mã → biến lương ALLOWANCE_<mã>.
class AllowanceEditor extends StatefulWidget {
  final List<ContractAllowance> initial;
  final ValueChanged<List<ContractAllowance>> onChanged;

  const AllowanceEditor({super.key, required this.initial, required this.onChanged});

  @override
  State<AllowanceEditor> createState() => _AllowanceEditorState();
}

class _Row {
  final TextEditingController code;
  final TextEditingController name;
  final TextEditingController amount;
  bool insurable;
  bool taxable;

  _Row(ContractAllowance? a)
      : code = TextEditingController(text: a?.code ?? ''),
        name = TextEditingController(text: a?.name ?? ''),
        amount = TextEditingController(text: a == null ? '' : a.amount.toStringAsFixed(0)),
        insurable = a?.insurable ?? false,
        taxable = a?.taxable ?? true;

  void dispose() {
    code.dispose();
    name.dispose();
    amount.dispose();
  }

  ContractAllowance toModel() => ContractAllowance(
        code: code.text.trim().toUpperCase(),
        name: name.text.trim(),
        amount: double.tryParse(amount.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
        insurable: insurable,
        taxable: taxable,
      );
}

class _AllowanceEditorState extends State<AllowanceEditor> {
  late final List<_Row> _rows = widget.initial.map(_Row.new).toList();

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(_rows.map((r) => r.toModel()).toList());

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _rows.length; i++) _rowView(s, i),
        Text(s.contractAllowanceCodeHint, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(s.contractAllowanceAdd),
            onPressed: () {
              setState(() => _rows.add(_Row(null)));
              _emit();
            },
          ),
        ),
      ],
    );
  }

  Widget _rowView(AppLocalizations s, int i) {
    final r = _rows[i];
    return Padding(
      key: ObjectKey(r),
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: TextField(
              controller: r.code,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
                LengthLimitingTextInputFormatter(30),
              ],
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: s.contractAllowanceCode, isDense: true),
              onChanged: (_) => _emit(),
            ),
          ),
          SizedBox(
            width: 170,
            child: TextField(
              controller: r.name,
              decoration: InputDecoration(labelText: s.contractAllowanceName, isDense: true),
              onChanged: (_) => _emit(),
            ),
          ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: r.amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: s.contractAllowanceAmount, isDense: true),
              onChanged: (_) => _emit(),
            ),
          ),
          _check(s.contractAllowanceInsurable, r.insurable, (v) => r.insurable = v),
          _check(s.contractAllowanceTaxable, r.taxable, (v) => r.taxable = v),
          IconButton(
            tooltip: s.delete,
            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
            onPressed: () {
              final removed = _rows.removeAt(i);
              setState(() {});
              _emit();
              WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
            },
          ),
        ],
      ),
    );
  }

  Widget _check(String label, bool value, void Function(bool) set) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () {
            setState(() => set(!value));
            _emit();
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IgnorePointer(child: Checkbox(value: value, onChanged: (_) {})),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );
}
