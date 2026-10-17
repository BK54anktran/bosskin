import 'package:bosskin/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import '../../../core/utils/company_currency_utils.dart';

final _money = NumberFormat('#,###', 'vi_VN');
final _dateFmt = DateFormat('dd/MM/yyyy');

String _m(num? v) => v == null ? '—' : _money.format(v);

/// Tab "Thuế & BH" ở trang system admin (bước I): thông số thuế TNCN / bảo hiểm theo ngày hiệu lực,
/// dùng chung mọi công ty. Kỳ lương dùng chính sách hiệu lực ở ngày cuối kỳ.
class TaxPoliciesTab extends StatefulWidget {
  final Dio dio;
  const TaxPoliciesTab({super.key, required this.dio});

  @override
  State<TaxPoliciesTab> createState() => _TaxPoliciesTabState();
}

class _TaxPoliciesTabState extends State<TaxPoliciesTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await widget.dio.get('/tax-policies');
      setState(() => _rows = (r.data as List).cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _edit({Map<String, dynamic>? existing, Map<String, dynamic>? template}) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _TaxPolicyDialog(existing: existing, template: template),
    );
    if (body == null) return;
    try {
      if (existing == null) {
        await widget.dio.post('/tax-policies', data: body);
      } else {
        await widget.dio.put('/tax-policies/${existing['id']}', data: body);
      }
      await _load();
    } catch (e) {
      if (mounted) _snack(serverMsg(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final s = AppLocalizations.of(context);
    final date = _dateFmt.format(DateTime.parse(p['effectiveFrom'] as String));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.taxPolicyDeleteConfirm(date)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.dio.delete('/tax-policies/${p['id']}');
      await _load();
    } catch (e) {
      if (mounted) _snack(serverMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return EmptyState(icon: Icons.error_outline, message: _error!, actionLabel: s.retry, onAction: _load);
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        Expanded(child: Text(s.taxPolicyIntro, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: FilledButton.icon(
            onPressed: () => _edit(template: _rows.isNotEmpty ? _rows.first : null),
            icon: const Icon(Icons.add, size: 18),
            label: Text(s.taxPolicyAdd),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      if (_rows.isEmpty) EmptyState(icon: Icons.receipt_long_outlined, message: s.taxPolicyEmpty),
      for (final p in _rows) _PolicyCard(policy: p, onEdit: () => _edit(existing: p), onDelete: () => _delete(p)),
    ]);
  }
}

class _PolicyCard extends StatelessWidget {
  final Map<String, dynamic> policy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PolicyCard({required this.policy, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final p = policy;
    final brackets = (p['brackets'] as List? ?? const []).cast<Map<String, dynamic>>();
    final minWages = (p['minWages'] as List? ?? const []).cast<num>();
    final updatedBy = p['updatedBy'] as String?;
    final label = TextStyle(fontSize: 12, color: AppTheme.textSecondary);
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 210, child: Text(k, style: label)),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
          ]),
        );
    String bracketText() {
      final parts = <String>[];
      num lower = 0;
      for (final b in brackets) {
        final rate = '${((b['rate'] as num) * 100).toStringAsFixed(((b['rate'] as num) * 100) % 1 == 0 ? 0 : 1)}%';
        final upTo = b['upTo'] as num?;
        parts.add(upTo == null ? s.taxBracketAbove(_m(lower), rate) : s.taxBracketUpTo(_m(upTo), rate));
        if (upTo != null) lower = upTo;
      }
      return parts.join(' · ');
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p['current'] == true ? AppTheme.primary : AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(s.taxPolicyFrom(_dateFmt.format(DateTime.parse(p['effectiveFrom'] as String))),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (p['current'] == true) ...[const SizedBox(width: 8), StatusBadge(label: s.taxPolicyCurrent, color: AppTheme.secondary)],
            const Spacer(),
            IconButton(tooltip: s.edit, icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
            IconButton(tooltip: s.delete, icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error), onPressed: onDelete),
          ]),
          const SizedBox(height: 6),
          kv(s.taxPersonalDeduction, _m(p['personalDeduction'] as num?)),
          kv(s.taxDependentDeduction, _m(p['dependentDeduction'] as num?)),
          kv(s.taxBrackets, bracketText()),
          kv(s.taxReferenceWage, '${_m(p['referenceWage'] as num?)} · ${s.taxInsuranceCap(_m(p['insuranceCap'] as num?), '${p['insuranceCapMultiplier']}')}'),
          kv(s.taxMinWages, [for (var i = 0; i < minWages.length; i++) '${s.minWageRegionShort(i + 1)}: ${_m(minWages[i])}'].join(' · ')),
          kv(s.taxUnemploymentCap, s.taxUnemploymentCapValue('${p['unemploymentCapMultiplier']}')),
          if ((p['note'] as String?)?.isNotEmpty == true) kv(s.note, p['note'] as String),
          if (updatedBy != null) Text(s.taxPolicyUpdatedBy(updatedBy), style: label),
        ]),
      ),
    );
  }
}

/// Hộp thêm / sửa chính sách. Trả về body gửi API, hoặc null nếu huỷ.
class _TaxPolicyDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Map<String, dynamic>? template;
  const _TaxPolicyDialog({this.existing, this.template});

  @override
  State<_TaxPolicyDialog> createState() => _TaxPolicyDialogState();
}

class _BracketRow {
  final upToCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  void dispose() { upToCtrl.dispose(); rateCtrl.dispose(); }
}

class _TaxPolicyDialogState extends State<_TaxPolicyDialog> {
  late DateTime _from;
  final _personalCtrl = TextEditingController();
  final _dependentCtrl = TextEditingController();
  final _refWageCtrl = TextEditingController();
  final _capMulCtrl = TextEditingController();
  final _uCapMulCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _minWageCtrls = List.generate(4, (_) => TextEditingController());
  final List<_BracketRow> _brackets = [];
  String? _error;

  static String _plain(num? v) => v == null ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

  @override
  void initState() {
    super.initState();
    final src = widget.existing ?? widget.template;
    _from = widget.existing != null
        ? DateTime.parse(widget.existing!['effectiveFrom'] as String)
        : DateTime(companyNow().year + 1, 1, 1);
    _personalCtrl.text = _plain(src?['personalDeduction'] as num?);
    _dependentCtrl.text = _plain(src?['dependentDeduction'] as num?);
    _refWageCtrl.text = _plain(src?['referenceWage'] as num?);
    _capMulCtrl.text = '${src?['insuranceCapMultiplier'] ?? 20}';
    _uCapMulCtrl.text = '${src?['unemploymentCapMultiplier'] ?? 20}';
    _noteCtrl.text = widget.existing?['note'] as String? ?? '';
    final mw = (src?['minWages'] as List? ?? const []).cast<num>();
    for (var i = 0; i < 4; i++) {
      _minWageCtrls[i].text = i < mw.length ? _plain(mw[i]) : '';
    }
    for (final b in (src?['brackets'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final r = _BracketRow();
      r.upToCtrl.text = _plain(b['upTo'] as num?);
      r.rateCtrl.text = _plain(((b['rate'] as num) * 100));
      _brackets.add(r);
    }
    if (_brackets.isEmpty) _brackets.add(_BracketRow());
  }

  @override
  void dispose() {
    for (final c in [_personalCtrl, _dependentCtrl, _refWageCtrl, _capMulCtrl, _uCapMulCtrl, _noteCtrl, ..._minWageCtrls]) {
      c.dispose();
    }
    for (final b in _brackets) {
      b.dispose();
    }
    super.dispose();
  }

  num? _num(TextEditingController c) => num.tryParse(c.text.trim().replaceAll('.', '').replaceAll(',', '.'));

  void _submit() {
    final s = AppLocalizations.of(context);
    final brackets = <Map<String, dynamic>>[];
    for (var i = 0; i < _brackets.length; i++) {
      final last = i == _brackets.length - 1;
      final rate = num.tryParse(_brackets[i].rateCtrl.text.trim().replaceAll(',', '.'));
      final upTo = last ? null : _num(_brackets[i].upToCtrl);
      if (rate == null || (!last && upTo == null)) {
        setState(() => _error = s.taxPolicyFormInvalid);
        return;
      }
      brackets.add({'upTo': upTo, 'rate': rate / 100});
    }
    final vals = [_num(_personalCtrl), _num(_dependentCtrl), _num(_refWageCtrl), _num(_capMulCtrl), _num(_uCapMulCtrl),
      ..._minWageCtrls.map(_num)];
    if (vals.any((v) => v == null)) {
      setState(() => _error = s.taxPolicyFormInvalid);
      return;
    }
    Navigator.pop(context, {
      'effectiveFrom': DateFormat('yyyy-MM-dd').format(_from),
      'personalDeduction': vals[0],
      'dependentDeduction': vals[1],
      'referenceWage': vals[2],
      'insuranceCapMultiplier': vals[3]!.toInt(),
      'unemploymentCapMultiplier': vals[4]!.toInt(),
      'minWages': vals.sublist(5),
      'brackets': brackets,
      'note': _noteCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    InputDecoration dec(String l, {String? suffix}) =>
        InputDecoration(labelText: l, suffixText: suffix, border: const OutlineInputBorder(), isDense: true);
    Widget money(TextEditingController c, String l) =>
        TextField(controller: c, keyboardType: TextInputType.number, inputFormatters: digits, decoration: dec(l, suffix: s.currencyVndSuffix));
    return AlertDialog(
      title: Text(widget.existing == null ? s.taxPolicyAdd : s.taxPolicyEdit),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 18),
                label: Text(s.taxPolicyFrom(_dateFmt.format(_from))),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _from,
                      firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setState(() => _from = d);
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: money(_personalCtrl, s.taxPersonalDeduction)),
              const SizedBox(width: 12),
              Expanded(child: money(_dependentCtrl, s.taxDependentDeduction)),
            ]),
            const SizedBox(height: 16),
            Text(s.taxBrackets, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(s.taxBracketsHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            for (var i = 0; i < _brackets.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: i == _brackets.length - 1
                        ? InputDecorator(decoration: dec(s.taxBracketUpToLabel), child: Text(s.taxBracketRest))
                        : TextField(controller: _brackets[i].upToCtrl, keyboardType: TextInputType.number,
                            inputFormatters: digits, decoration: dec(s.taxBracketUpToLabel, suffix: s.currencyVndSuffix)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(controller: _brackets[i].rateCtrl, keyboardType: TextInputType.number,
                        inputFormatters: digits, decoration: dec(s.taxBracketRate, suffix: '%')),
                  ),
                  IconButton(
                    tooltip: s.delete,
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: _brackets.length <= 1 ? null : () => setState(() => _brackets.removeAt(i).dispose()),
                  ),
                ]),
              ),
            TextButton.icon(
              onPressed: () => setState(() => _brackets.insert(_brackets.length - 1 < 0 ? 0 : _brackets.length - 1, _BracketRow())),
              icon: const Icon(Icons.add, size: 18),
              label: Text(s.taxBracketAdd),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 2, child: money(_refWageCtrl, s.taxReferenceWage)),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _capMulCtrl, keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: dec(s.taxCapMultiplier, suffix: s.multiplierSuffix))),
            ]),
            const SizedBox(height: 12),
            Text(s.taxMinWages, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: money(_minWageCtrls[i], s.minWageRegionShort(i + 1))),
              ],
            ]),
            const SizedBox(height: 12),
            TextField(controller: _uCapMulCtrl, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: dec(s.taxUnemploymentCapMultiplier, suffix: s.multiplierSuffix)),
            const SizedBox(height: 12),
            TextField(controller: _noteCtrl, maxLength: 500, decoration: dec(s.taxPolicyNote)),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}
