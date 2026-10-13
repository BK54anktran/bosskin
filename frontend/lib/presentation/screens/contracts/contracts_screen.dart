import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/file_picker_excel_utils.dart';
import '../../../core/utils/file_saver_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../data/models/labor_contract.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/excel_template_button.dart';
import '../../widgets/import_preview_dialog.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/permission_guard.dart';
import '../../widgets/search_text_field.dart';
import 'contract_dialogs.dart';
import 'contract_shared.dart';

/// Bước L — danh sách hợp đồng lao động, lọc "cần gia hạn", xuất / nhập Excel.
class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

/// Bộ lọc trạng thái; RENEW = cần gia hạn.
const _filters = ['DRAFT', 'ACTIVE', 'EXPIRED', 'TERMINATED', 'RENEW'];

class _ContractsScreenState extends State<ContractsScreen> {
  final _repo = ContractRepository();
  final _searchCtrl = TextEditingController();
  final _dmy = DateFormat('dd/MM/yyyy');
  List<LaborContract> _all = [];
  Set<int> _renewIds = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _filter;
  int _page = 0;
  int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([_repo.getAll(), _repo.expiring()]);
      if (!mounted) return;
      setState(() {
        _all = r[0];
        _renewIds = r[1].map((c) => c.id).toSet();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = serverMsg(e); _loading = false; });
    }
  }

  void _snack(String msg, {bool error = false}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppTheme.error : AppTheme.secondary));

  List<LaborContract> get _filtered {
    final q = foldSearchText(_searchCtrl.text);
    return _all.where((c) {
      if (_filter == 'RENEW' && !_renewIds.contains(c.id)) return false;
      if (_filter != null && _filter != 'RENEW' && c.displayStatus != _filter) return false;
      if (q.isEmpty) return true;
      return foldSearchText('${c.contractNo} ${c.employeeName} ${c.employeeCode} ${c.departmentName ?? ''}')
          .contains(q);
    }).toList();
  }

  Future<void> _open(LaborContract c) async {
    final changed = await showInstantDialog<bool>(context, (ctx) => ContractDetailDialog(contract: c, repo: _repo));
    if (changed == true) await _load();
  }

  Future<void> _add() async {
    final s = AppLocalizations.of(context);
    final saved = await showInstantDialog<LaborContract>(context, (ctx) => ContractFormDialog(repo: _repo));
    if (saved != null) {
      _snack(s.contractSaved);
      await _load();
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final res = await _repo.export();
      final disposition = res.headers.value('content-disposition') ?? '';
      final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
      await saveFileToDevice(Uint8List.fromList(res.data!), match?.group(1) ?? 'contracts.xlsx');
    } catch (e) {
      if (mounted) _snack(serverMsg(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final s = AppLocalizations.of(context);
    final picked = await pickExcelFile();
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final raw = await _repo.previewImport(picked.bytes, picked.filename);
      if (!mounted) return;
      final diffs = raw.map((d) {
        final m = d as Map<String, dynamic>;
        return ImportDiffRow(
          action: m['action'] ?? 'CREATE',
          code: m['code'] ?? '',
          name: m['name'] ?? '',
          changes: ((m['changes'] as List?) ?? const [])
              .map((c) => ImportFieldChange(
                    field: _fieldLabel(s, c['field'] as String? ?? ''),
                    oldValue: _valueLabel(s, c['oldValue'] as String? ?? ''),
                    newValue: _valueLabel(s, c['newValue'] as String? ?? ''),
                  ))
              .toList(),
          warnings: ((m['warnings'] as List?) ?? const []).map((w) => w.toString()).toList(),
        );
      }).toList();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => ImportPreviewDialog(
          diffs: diffs,
          onConfirm: () => _repo.importExcel(picked.bytes, picked.filename),
        ),
      );
      if (confirmed == true && mounted) {
        _snack(s.importSuccess);
        await _load();
      }
    } catch (e) {
      if (mounted) _snack(serverMsg(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fieldLabel(AppLocalizations s, String f) => switch (f) {
        'employeeCode' => s.employeeCode,
        'contractType' => s.contractType,
        'status' => s.status,
        'signDate' => s.contractSignDate,
        'startDate' => s.contractStartDate,
        'endDate' => s.contractEndDate,
        'baseSalary' => s.contractBaseSalary,
        'insuranceSalary' => s.contractInsuranceSalary,
        'positionTitle' => s.contractPositionTitle,
        'note' => s.note,
        'allowances' => s.contractAllowances,
        _ => f,
      };

  String _valueLabel(AppLocalizations s, String v) {
    if (contractTypes.contains(v)) return contractTypeLabel(s, v);
    if (v == 'DRAFT' || v == 'ACTIVE' || v == 'TERMINATED') return contractStatusLabel(s, v);
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline, message: _error!, actionLabel: s.refresh, onAction: _load);
    }
    final rows = _filtered;
    final pages = (rows.length / _pageSize).ceil();
    final page = _page.clamp(0, pages == 0 ? 0 : pages - 1);
    final visible = rows.skip(page * _pageSize).take(_pageSize).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 320,
            child: SearchTextField(
              controller: _searchCtrl,
              hint: s.contractSearchHint,
              onChanged: (_) => setState(() => _page = 0),
              onClear: () => setState(() { _searchCtrl.clear(); _page = 0; }),
            ),
          ),
          SizedBox(
            width: 200,
            child: AppDropdown<String?>(
              value: _filter,
              label: s.status,
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(s.all)),
                ..._filters.map((f) => DropdownMenuItem<String?>(
                      value: f,
                      child: Text(f == 'RENEW' ? s.contractNeedsRenewal : contractStatusLabel(s, f)),
                    )),
              ],
              onChanged: (v) => setState(() { _filter = v; _page = 0; }),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(s.exportExcel),
            onPressed: _busy ? null : _export,
          ),
          PermissionGuard(
            permission: 'CONTRACT_EDIT',
            child: OutlinedButton.icon(
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: Text(s.importExcel),
              onPressed: _busy ? null : _import,
            ),
          ),
          const PermissionGuard(
            permission: 'CONTRACT_EDIT',
            child: ExcelTemplateButton(path: '/contracts/template'),
          ),
          PermissionGuard(
            permission: 'CONTRACT_EDIT',
            child: FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(s.contractAdd),
              onPressed: _busy ? null : _add,
            ),
          ),
        ]),
      ),
      if (_renewIds.isNotEmpty && _filter != 'RENEW')
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              onTap: () => setState(() { _filter = 'RENEW'; _page = 0; }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.event_busy_outlined, size: 18, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.contractRenewalBanner(_renewIds.length))),
                ]),
              ),
            ),
          ),
        ),
      Expanded(
        child: rows.isEmpty
            ? EmptyState(icon: Icons.description_outlined, message: s.contractEmpty)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  itemBuilder: (_, i) => _tile(s, visible[i]),
                ),
              ),
      ),
      if (rows.length > _pageSize)
        PaginationBar(
          total: rows.length,
          page: page,
          pageSize: _pageSize,
          onPageSizeChanged: (v) => setState(() { _pageSize = v; _page = 0; }),
          onPrev: page > 0 ? () => setState(() => _page = page - 1) : null,
          onNext: page < pages - 1 ? () => setState(() => _page = page + 1) : null,
        ),
    ]);
  }

  Widget _tile(AppLocalizations s, LaborContract c) {
    final days = contractDaysText(s, c);
    final period = '${_dmy.format(c.startDate)} – ${c.endDate == null ? s.contractNoEnd : _dmy.format(c.endDate!)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ListTile(
          onTap: () => _open(c),
          leading: const Icon(Icons.description_outlined),
          title: Text('${c.contractNo} · ${c.employeeName} (${c.employeeCode})', overflow: TextOverflow.ellipsis),
          subtitle: Text([
            contractTypeLabel(s, c.contractType),
            period,
            '${s.contractCurrentSalary}: ${formatMoney(c.currentBaseSalary)}',
            if (c.departmentName != null) c.departmentName!,
            if (c.appendices.isNotEmpty) s.contractAppendixCount(c.appendices.length),
          ].join(' · ')),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              contractStatusBadge(s, c),
              if (days != null)
                Text(days,
                    style: TextStyle(
                      fontSize: 11,
                      color: _renewIds.contains(c.id) ? AppTheme.error : AppTheme.textSecondary,
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
