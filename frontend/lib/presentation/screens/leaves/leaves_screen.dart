import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/employee.dart';
import '../../../data/repositories/company_setting_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/department_service.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_text_field.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/status_badge.dart';

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen>
    with SingleTickerProviderStateMixin {
  final _repo = LeaveRepository();
  final _companySettingRepo = CompanySettingRepository();
  final _empRepo = EmployeeRepository();
  late final TabController _tabs;

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  int? _filterDeptId;
  String? _filterStatus;
  final _searchCtrl = TextEditingController();
  int _reqPage = 0;
  int _reqPageSize = 20;
  List<DepartmentFlat> _depts = [];

  List<Map<String, dynamic>> _requests = [];
  int _reqTotal = 0;
  bool _reqLoading = false;
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _grants = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _rules = [];
  double _hoursPerDay = 8;

  bool get _canApprove =>
      AuthService.instance.currentUser?.can('LEAVE_REQUEST_APPROVE') == true ||
      AuthService.instance.currentUser?.isSystemAdmin == true;
  bool get _canCreate =>
      AuthService.instance.currentUser?.can('LEAVE_REQUEST_CREATE') == true ||
      AuthService.instance.currentUser?.isSystemAdmin == true;
  bool get _canCreateForOthers =>
      AuthService.instance.currentUser?.can('LEAVE_REQUEST_CREATE_FOR_OTHERS') ==
          true ||
      AuthService.instance.currentUser?.isSystemAdmin == true;
  bool get _canManualGrant =>
      AuthService.instance.currentUser?.can('LEAVE_GRANT_MANUAL') == true ||
      AuthService.instance.currentUser?.isSystemAdmin == true;
  bool get _canViewType =>
      AuthService.instance.currentUser?.can('LEAVE_TYPE_VIEW') == true ||
      AuthService.instance.currentUser?.can('LEAVE_TYPE_MANAGE') == true ||
      AuthService.instance.currentUser?.isSystemAdmin == true;
  bool get _canManageType =>
      AuthService.instance.currentUser?.can('LEAVE_TYPE_MANAGE') == true ||
      AuthService.instance.currentUser?.isSystemAdmin == true;
  bool get _canViewRule =>
      AuthService.instance.currentUser?.can('LEAVE_ACCRUAL_VIEW') == true ||
      AuthService.instance.currentUser?.can('LEAVE_ACCRUAL_MANAGE') == true ||
      AuthService.instance.currentUser?.isSystemAdmin == true;
  bool get _canManageRule =>
      AuthService.instance.currentUser?.can('LEAVE_ACCRUAL_MANAGE') == true ||
      AuthService.instance.currentUser?.isSystemAdmin == true;

  List<({Tab tab, Widget view})> _visibleTabs(AppLocalizations s) => [
        (tab: Tab(text: s.leaveRequestsTab), view: _buildRequestsTab()),
        (tab: Tab(text: s.leaveCurrentBalance), view: _buildBalanceTab()),
        if (_canViewType)
          (tab: Tab(text: s.leaveTypesTab), view: _buildTypesTab()),
        if (_canViewRule)
          (tab: Tab(text: s.leaveRulesTab), view: _buildRulesTab()),
      ];

  @override
  void initState() {
    super.initState();
    final tabCount = 2 + (_canViewType ? 1 : 0) + (_canViewRule ? 1 : 0);
    _tabs = TabController(length: tabCount, vsync: this, animationDuration: Duration.zero);
    _loadDepartments();
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts =
          await DepartmentService.instance.getFlat(permission: 'LEAVE_VIEW');
      if (!mounted) return;
      setState(() => _depts = depts);
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = await Future.wait([
        _fetchRequests(),
        _repo.getGrants(departmentId: _filterDeptId),
        _repo.getTypes(),
        _repo.getAccrualRules(),
        _companySettingRepo.get(),
      ]);
      if (!mounted) return;
      setState(() {
        final req = futures[0] as ({List<Map<String, dynamic>> items, int total});
        _requests = req.items;
        _reqTotal = req.total;
        _grants = List<Map<String, dynamic>>.from(futures[1] as List);
        _types = List<Map<String, dynamic>>.from(futures[2] as List);
        _rules = List<Map<String, dynamic>>.from(futures[3] as List);
        final setting = Map<String, dynamic>.from(futures[4] as Map);
        final leaves = Map<String, dynamic>.from(setting['leaves'] as Map);
        _hoursPerDay = _toNum(leaves['hoursPerDay']);
        if (_hoursPerDay <= 0) _hoursPerDay = 8;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<({List<Map<String, dynamic>> items, int total})> _fetchRequests() =>
      _repo.searchRequests(
        status: _filterStatus,
        departmentId: _filterDeptId,
        q: _searchCtrl.text.trim(),
        page: _reqPage,
        size: _reqPageSize,
      );

  /// Chỉ tải lại tab đơn (đổi trang / lọc / tìm kiếm) — F9 phân trang phía server.
  Future<void> _loadRequests() async {
    setState(() => _reqLoading = true);
    try {
      final res = await _fetchRequests();
      if (!mounted) return;
      setState(() {
        _requests = res.items;
        _reqTotal = res.total;
      });
    } catch (e) {
      if (mounted) _snack(serverMsg(e), false);
    } finally {
      if (mounted) setState(() => _reqLoading = false);
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _reqPage = 0;
      _loadRequests();
    });
  }

  Future<void> _run(Future<void> Function() action, {String? okMsg}) async {
    setState(() => _submitting = true);
    try {
      await action();
      await _loadAll();
      if (!mounted) return;
      if (okMsg != null) _snack(okMsg, true);
    } catch (e) {
      if (!mounted) return;
      _snack(serverMsg(e), false);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppTheme.secondary : AppTheme.error,
    ));
  }

  Future<void> _openCreateRequest() async {
    final s = AppLocalizations.of(context);
    final canPickEmployee = _canCreateForOthers;
    final employees = canPickEmployee
        ? await _empRepo.getAllForPicker(departmentId: _filterDeptId)
        : <Employee>[];
    if (!mounted) return;
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateLeaveRequestDialog(
        types: _types,
        employees: employees,
        canPickEmployee: canPickEmployee,
      ),
    );
    if (res == true) {
      await _run(() async {
        final payload = _CreateLeaveRequestDialog.result!;
        await _repo.createRequest(payload);
      }, okMsg: s.leaveRequestCreated);
    }
  }

  Future<void> _openManualGrant() async {
    final s = AppLocalizations.of(context);
    final employees =
        await _empRepo.getAllForPicker(departmentId: _filterDeptId);
    if (!mounted) return;
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => _ManualGrantDialog(types: _types, employees: employees),
    );
    if (res == true) {
      await _run(() async {
        final payload = _ManualGrantDialog.result!;
        await _repo.manualGrant(payload);
      }, okMsg: s.leaveManualGrantCreated);
    }
  }

  Future<void> _approve(Map<String, dynamic> req) async {
    final s = AppLocalizations.of(context);
    await _run(() async {
      await _repo.approveRequest(req['id'] as int);
    }, okMsg: s.leaveRequestApproved);
  }

  Future<void> _cancel(Map<String, dynamic> req) async {
    final s = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.leaveCancelRequest),
        content: Text(s.leaveCancelConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.leaveCancelRequest)),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _repo.cancelRequest(req['id'] as int);
    }, okMsg: s.leaveCancelledSuccess);
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final s = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.leaveRejectRequest),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: s.note),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text(s.reject)),
        ],
      ),
    );
    if (note == null) return;
    await _run(() async {
      await _repo.rejectRequest(req['id'] as int, adminNote: note);
    }, okMsg: s.leaveRequestRejected);
  }

  Future<void> _openTypeDialog([Map<String, dynamic>? item]) async {
    final s = AppLocalizations.of(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => _LeaveTypeDialog(initial: item),
    );
    if (res == true) {
      await _run(() async {
        final payload = _LeaveTypeDialog.result!;
        if (item == null) {
          await _repo.createType(payload);
        } else {
          await _repo.updateType(item['id'] as int, payload);
        }
      }, okMsg: item == null ? s.leaveTypeCreated : s.leaveTypeUpdated);
    }
  }

  Future<void> _openRuleDialog([Map<String, dynamic>? item]) async {
    final s = AppLocalizations.of(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => _AccrualRuleDialog(
        departments: _depts,
        initial: item,
      ),
    );
    if (res == true) {
      await _run(() async {
        final payload = _AccrualRuleDialog.result!;
        if (item == null) {
          await _repo.createAccrualRule(payload);
        } else {
          await _repo.updateAccrualRule(item['id'] as int, payload);
        }
      }, okMsg: item == null ? s.leaveRuleCreated : s.leaveRuleUpdated);
    }
  }

  Future<void> _deleteType(Map<String, dynamic> item) async {
    final s = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.confirm),
        content: Text(s.leaveDeleteTypeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await _repo.deleteType(item['id'] as int);
    }, okMsg: s.leaveTypeDeleted);
  }

  Future<void> _deleteRule(Map<String, dynamic> item) async {
    final s = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.confirm),
        content: Text(s.leaveDeleteRuleConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await _repo.deleteAccrualRule(item['id'] as int);
    }, okMsg: s.leaveRuleDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header: dept filter + buttons ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DepartmentPickerField(
                compact: true,
                departments: _depts,
                value: _filterDeptId,
                allowAll: true,
                label: s.department,
                onChanged: (v) {
                  setState(() => _filterDeptId = v);
                  _loadAll();
                },
              ),
              const Spacer(),
              if (_canCreate || _canManualGrant)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    if (_canManualGrant)
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _openManualGrant,
                        icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                        label: Text(s.leaveManualGrant),
                      ),
                    if (_canCreate)
                      FilledButton.icon(
                        onPressed: _submitting ? null : _openCreateRequest,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(s.leaveCreateRequest),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Body ──
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
          )
        else if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: Builder(builder: (context) {
              final tabs = _visibleTabs(s);
              return Column(
                children: [
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: tabs.map((t) => t.tab).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: tabs.map((t) => t.view).toList(),
                    ),
                  ),
                ],
              );
            }),
          ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    final s = AppLocalizations.of(context);
    final myEmpId = AuthService.instance.currentUser?.employeeId;
    final statusLabels = {
      null: s.all,
      'PENDING': s.pending,
      'APPROVED': s.approved,
      'REJECTED': s.rejected,
      'CANCELLED': s.cancelled,
    };
    final totalPages = _reqTotal == 0 ? 1 : (_reqTotal / _reqPageSize).ceil();
    final paged = _requests;
    return Column(
      children: [
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
        Row(
          children: [
            Expanded(
              child: SearchTextField(
                controller: _searchCtrl,
                onChanged: (_) => _onSearchChanged(),
                onClear: () { _reqPage = 0; _loadRequests(); },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 180,
              child: AppDropdown<String?>(
                value: _filterStatus,
                label: s.status,
                items: statusLabels.entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (v) { _filterStatus = v; _reqPage = 0; _loadRequests(); },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (paged.isEmpty)
          EmptyState(message: s.leaveRequestHistory)
        else
          ...List.generate(paged.length, (i) {
            final r = paged[i];
            final status = (r['status'] ?? '').toString();
            final canAct = _canApprove && status == 'PENDING';
            final isOwner = myEmpId != null && r['employeeId'] == myEmpId;
            final canCancel = status == 'PENDING' && (isOwner || _canApprove);
            final employeeName =
                (r['employeeName'] ?? '').toString();
            final initials = employeeName.isNotEmpty
                ? employeeName[0].toUpperCase()
                : '?';
            return Padding(
              padding: EdgeInsets.only(bottom: i < paged.length - 1 ? 12 : 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employeeName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${r['departmentName'] ?? ''} • ${r['leaveTypeName'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge.requestStatus(status, s),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                        '${s.date}: ${_rangeLabel(r)} • ${r['requestedAmount'] ?? 0} ${(r['leaveUnit'] ?? '').toString().toLowerCase()}'),
                    const SizedBox(height: 4),
                    Text(
                      '${s.createdAt}: ${_fmtDateTime(r['createdAt']?.toString())}',
                      style:
                          const TextStyle(color: AppTheme.textSecondary),
                    ),
                    if ((r['reason'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('${s.note}: ${r['reason']}'),
                    ],
                    if (status != 'PENDING' && r['processedAt'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${status == 'APPROVED' ? s.approvedBy : (status == 'REJECTED' ? s.rejectedBy : s.cancel)}: ${r['processedByName'] ?? ''} • ${_fmtDateTime(r['processedAt']?.toString())}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                    if ((r['adminNote'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${s.response}: ${r['adminNote']}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                    // Children (đơn con từng ngày)
                    if ((r['children'] as List?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      ...((r['children'] as List).map((child) {
                        final cMap = child as Map<String, dynamic>;
                        final cDate = cMap['fromDate']?.toString() ?? '';
                        final cFromTime = cMap['fromTime']?.toString();
                        final cToTime = cMap['toTime']?.toString();
                        final cAmount = cMap['requestedAmount'];
                        final cUnit = (cMap['leaveUnit'] ?? '').toString().toLowerCase();
                        final cTimeInfo = (cFromTime != null && cToTime != null)
                            ? '$cFromTime-$cToTime${cAmount != null ? ' • $cAmount $cUnit' : ''}'
                            : (cAmount != null ? '$cAmount $cUnit' : null);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right, size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  cTimeInfo != null ? '$cDate  $cTimeInfo' : cDate,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      })),
                    ],
                    if (canAct) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  _submitting ? null : () => _approve(r),
                              icon: const Icon(Icons.check),
                              label: Text(s.approve),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _submitting ? null : () => _reject(r),
                              icon: const Icon(Icons.close),
                              label: Text(s.reject),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (canCancel) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _submitting ? null : () => _cancel(r),
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(s.leaveCancelRequest),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          ],
        )),
        if (_reqLoading) const LinearProgressIndicator(minHeight: 2),
        PaginationBar(
          total: _reqTotal,
          page: _reqPage,
          pageSize: _reqPageSize,
          onPageSizeChanged: (s) { _reqPageSize = s; _reqPage = 0; _loadRequests(); },
          onPrev: _reqPage > 0 && !_reqLoading ? () { _reqPage--; _loadRequests(); } : null,
          onNext: _reqPage < totalPages - 1 && !_reqLoading ? () { _reqPage++; _loadRequests(); } : null,
        ),
      ],
    );
  }

  Widget _buildBalanceTab() {
    final s = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        _buildBalanceTable(s),
      ],
    );
  }

  String _fmtDateTime(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  String _formatBalance(double days, double hours, AppLocalizations s) {
    // Quy đổi giờ thừa sang ngày nếu >= hoursPerDay
    if (_hoursPerDay > 0 && hours >= _hoursPerDay) {
      final extraDays = (hours / _hoursPerDay).floor();
      days += extraDays;
      hours -= extraDays * _hoursPerDay;
    }
    String fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
    final d = days > 0 ? '${fmt(days)} ${s.leaveUnitDay}' : null;
    final h = hours > 0 ? '${fmt(hours)} ${s.leaveUnitHour}' : null;
    if (d != null && h != null) return '$d $h';
    return d ?? h ?? '0 ${s.leaveUnitDay}';
  }

  Widget _buildBalanceTable(AppLocalizations s) {
    final Map<int, ({String name, double days, double hours})> byEmployee = {};
    final today = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    for (final g in _grants) {
      final empId = g['employeeId'] as int?;
      if (empId == null) continue;
      final validTo = g['validTo'];
      if (validTo != null) {
        try {
          if (DateTime.parse(validTo.toString()).isBefore(today)) continue;
        } catch (_) {}
      }
      final name = '${g['employeeCode'] ?? ''} - ${g['employeeName'] ?? ''}';
      final remDays = _toNum(g['remainingDays']);
      final remHours = _toNum(g['remainingHours']);
      final prev = byEmployee[empId];
      byEmployee[empId] = (
        name: name,
        days: (prev?.days ?? 0.0) + remDays,
        hours: (prev?.hours ?? 0.0) + remHours,
      );
    }

    final entries = byEmployee.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));

    final colorScheme = Theme.of(context).colorScheme;
    final zebraColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.employee,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: Text(
                    s.leaveRemainingBalance,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(s.noResults,
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
            )
          else
            ...entries.asMap().entries.map((entry) {
              final idx = entry.key;
              final empId = entry.value.key;
              final emp = entry.value.value;
              return Column(
                children: [
                  InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => _EmployeeGrantHistoryDialog(
                        employeeId: empId,
                        employeeName: emp.name,
                        repo: _repo,
                        hoursPerDay: _hoursPerDay,
                      ),
                    ),
                    child: Container(
                      color: idx.isOdd ? zebraColor : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              emp.name,
                              style: const TextStyle(color: AppTheme.primary),
                            ),
                          ),
                          Text(
                            _formatBalance(emp.days, emp.hours, s),
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (idx < entries.length - 1)
                    const Divider(height: 1, thickness: 1),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTypesTab() {
    final s = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        if (_canManageType) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _submitting ? null : () => _openTypeDialog(),
              icon: const Icon(Icons.add),
              label: Text(s.leaveAddType),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_types.isEmpty)
          EmptyState(message: s.leaveTypesTab)
        else
          ...List.generate(_types.length, (i) {
            final t = _types[i];
            final active = t['active'] == true;
            return Padding(
              padding:
                  EdgeInsets.only(bottom: i < _types.length - 1 ? 12 : 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${t['name']} (${t['code']})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (active
                                          ? AppTheme.secondary
                                          : AppTheme.textSecondary)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  active ? s.activate : s.stopped,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? AppTheme.secondary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${s.leaveUnit}: ${t['unit']} • ${s.leaveDeductPerDay}: ${t['deductPerDay'] ?? 1} • ${t['paid'] == true ? s.leavePaid : s.leaveUnpaid}${t['requiresBalance'] == false ? ' • ${s.leaveNoBalance}' : ''}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary),
                          ),
                          if ((t['description'] ?? '').toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              t['description'].toString(),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_canManageType) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed:
                            _submitting ? null : () => _openTypeDialog(t),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: s.edit,
                      ),
                      IconButton(
                        onPressed: _submitting ? null : () => _deleteType(t),
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppTheme.error),
                        tooltip: s.delete,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRulesTab() {
    final s = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        if (_canManageRule) ...[
          Row(
            children: [
              FilledButton.icon(
                onPressed: _submitting ? null : () => _openRuleDialog(),
                icon: const Icon(Icons.add),
                label: Text(s.leaveAddRule),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _run(() async {
                          await _repo.runAccrual();
                        }, okMsg: s.leaveAccrualRunDone),
                icon: const Icon(Icons.play_arrow_outlined),
                label: Text(s.leaveRunNow),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_rules.isEmpty)
          EmptyState(message: s.leaveRulesTab)
        else
          ...List.generate(_rules.length, (i) {
            final r = _rules[i];
            final parts = <String>[];
            if (r['grantDays'] != null) {
              parts.add('${r['grantDays']} ${s.leaveUnitDay}');
            }
            if (r['grantHours'] != null) {
              final h = _toNum(r['grantHours']);
              final extra = _hoursPerDay > 0
                  ? ' (≈${(h / _hoursPerDay).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} ${s.leaveUnitDay})'
                  : '';
              parts.add('$h ${s.leaveUnitHour}$extra');
            }
            final amountStr = parts.isNotEmpty ? parts.join(' + ') : '-';
            return Padding(
              padding:
                  EdgeInsets.only(bottom: i < _rules.length - 1 ? 12 : 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          if (r['leaveTypeName'] != null)
                          Text(
                            r['leaveTypeName'],
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          _ruleChips(s, r, amountStr),
                          const SizedBox(height: 6),
                          Text(
                            '${s.department}: ${r['departmentName'] ?? s.leaveAllCompany}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary),
                          ),
                          if (r['validFrom'] != null ||
                              r['validTo'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${s.leaveValidity}: ${_d(r['validFrom'])} → ${_d(r['validTo'])}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_canManageRule) ...[
                      IconButton(
                        onPressed:
                            _submitting ? null : () => _openRuleDialog(r),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: s.edit,
                      ),
                      IconButton(
                        onPressed: _submitting ? null : () => _deleteRule(r),
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppTheme.error),
                        tooltip: s.delete,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _ruleChips(
      AppLocalizations s, Map<String, dynamic> r, String amountStr) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _chip('${s.leaveGrantAmount}: $amountStr'),
        _chip('${s.leaveFrequency}: ${r['frequency'] ?? '-'}'),
        if (r['dayOfMonth'] != null)
          _chip('${s.leaveDayOfMonth}: ${r['dayOfMonth']}'),
        if (r['monthOfYear'] != null)
          _chip('${s.leaveMonthOfYear}: ${r['monthOfYear']}'),
        if ((r['minTenureYears'] ?? 0) != 0)
          _chip('${s.leaveMinTenure}: ${r['minTenureYears']}'),
        if (r['expireAfterDays'] != null)
          _chip('${s.leaveExpireAfterDays}: ${r['expireAfterDays']}'),
      ],
    );
  }

  Widget _chip(String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontWeight: FontWeight.w500),
        ),
      );

  String _rangeLabel(Map<String, dynamic> r) {
    final mode = (r['mode'] ?? '').toString();
    if (mode == 'HOUR_RANGE') {
      return '${_d(r['fromDate'])} ${r['fromTime'] ?? ''}-${r['toTime'] ?? ''}';
    }
    return '${_d(r['fromDate'])} -> ${_d(r['toDate'])}';
  }

  String _d(dynamic v) {
    final l10n = AppLocalizations.of(context);
    if (v == null) return l10n.leaveUnlimited;
    final text = v.toString();
    if (text.isEmpty) return l10n.leaveUnlimited;
    try {
      final dt = DateTime.parse(text);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return text;
    }
  }

  double _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class _CreateLeaveRequestDialog extends StatefulWidget {
  const _CreateLeaveRequestDialog({
    required this.types,
    required this.employees,
    required this.canPickEmployee,
  });
  final List<Map<String, dynamic>> types;
  final List<Employee> employees;
  final bool canPickEmployee;
  static Map<String, dynamic>? result;

  @override
  State<_CreateLeaveRequestDialog> createState() =>
      _CreateLeaveRequestDialogState();
}

class _CreateLeaveRequestDialogState extends State<_CreateLeaveRequestDialog> {
  final _key = GlobalKey<FormState>();
  int? _employeeId;
  int? _typeId;
  String _mode = 'DAY_RANGE';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  TimeOfDay _fromTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _toTime = const TimeOfDay(hour: 17, minute: 0);
  final _reasonCtrl = TextEditingController();

  String _resolveModeByType(int? typeId) {
    if (typeId == null) return 'DAY_RANGE';
    final type = widget.types.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['id'] == typeId,
          orElse: () => null,
        );
    final unit = (type?['unit'] ?? 'DAY').toString();
    return unit == 'HOUR' ? 'HOUR_RANGE' : 'DAY_RANGE';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.leaveCreateRequest),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.canPickEmployee) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _employeeId,
                    isExpanded: true,
                    items: widget.employees
                        .map((e) => DropdownMenuItem<int>(
                              value: e.id,
                              child: Text('${e.employeeCode} - ${e.fullName}',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _employeeId = v),
                    decoration: InputDecoration(labelText: s.employee),
                    validator: (v) => v == null ? s.requiredField : null,
                  ),
                  const SizedBox(height: 8),
                ],
                DropdownButtonFormField<int>(
                  initialValue: _typeId,
                  isExpanded: true,
                  items: widget.types
                      .map((t) => DropdownMenuItem<int>(
                            value: t['id'] as int,
                            child: Text('${t['name']} (${t['code']})',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _typeId = v;
                    _mode = _resolveModeByType(v);
                  }),
                  decoration: InputDecoration(labelText: s.leaveTypeLabel),
                  validator: (v) => v == null ? s.requiredField : null,
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: InputDecoration(labelText: s.leaveRequestMode),
                  child: Text(_mode == 'HOUR_RANGE'
                      ? s.leaveByHour
                      : s.leaveByDay),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _fromDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) setState(() => _fromDate = p);
                      },
                      child: Text(
                          '${s.fromDate}: ${DateFormat('dd/MM/yyyy').format(_fromDate)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _toDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) setState(() => _toDate = p);
                      },
                      child: Text(
                          '${s.toDate}: ${DateFormat('dd/MM/yyyy').format(_toDate)}'),
                    ),
                  ),
                ]),
                if (_mode == 'HOUR_RANGE') ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final p = await showTimePicker(
                              context: context, initialTime: _fromTime);
                          if (p != null) setState(() => _fromTime = p);
                        },
                        child: Text('${s.leaveFromTime}: ${_fromTime.format(context)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final p = await showTimePicker(
                              context: context, initialTime: _toTime);
                          if (p != null) setState(() => _toTime = p);
                        },
                        child: Text('${s.leaveToTime}: ${_toTime.format(context)}'),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonCtrl,
                  decoration: InputDecoration(labelText: s.reason),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            if (!_key.currentState!.validate()) return;
            _CreateLeaveRequestDialog.result = {
              if (widget.canPickEmployee && _employeeId != null)
                'employeeId': _employeeId,
              'leaveTypeId': _typeId,
              'mode': _mode,
              'fromDate': DateFormat('yyyy-MM-dd').format(_fromDate),
              'toDate': DateFormat('yyyy-MM-dd').format(_toDate),
              if (_mode == 'HOUR_RANGE')
                'fromTime':
                    '${_fromTime.hour.toString().padLeft(2, '0')}:${_fromTime.minute.toString().padLeft(2, '0')}:00',
              if (_mode == 'HOUR_RANGE')
                'toTime':
                    '${_toTime.hour.toString().padLeft(2, '0')}:${_toTime.minute.toString().padLeft(2, '0')}:00',
              'reason': _reasonCtrl.text.trim(),
            };
            Navigator.pop(context, true);
          },
          child: Text(s.create),
        ),
      ],
    );
  }
}

class _ManualGrantDialog extends StatefulWidget {
  const _ManualGrantDialog({required this.types, required this.employees});
  final List<Map<String, dynamic>> types;
  final List<Employee> employees;
  static Map<String, dynamic>? result;

  @override
  State<_ManualGrantDialog> createState() => _ManualGrantDialogState();
}

class _ManualGrantDialogState extends State<_ManualGrantDialog> {
  final _key = GlobalKey<FormState>();
  int? _employeeId;
  int? _leaveTypeId;
  final _grantDaysCtrl = TextEditingController();
  final _grantHoursCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _validFrom;
  DateTime? _validTo;
  final _expireCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.leaveManualGrant),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _employeeId,
                  isExpanded: true,
                  items: widget.employees
                      .map((e) => DropdownMenuItem<int>(
                            value: e.id,
                            child: Text(
                              '${e.employeeCode} - ${e.fullName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _employeeId = v),
                  decoration: InputDecoration(labelText: s.employee),
                  validator: (v) => v == null ? s.requiredField : null,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _grantDaysCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: s.leaveAmount,
                          suffixText: s.leaveUnitDay),
                      validator: (v) {
                        final days = double.tryParse(v ?? '');
                        final hours = double.tryParse(_grantHoursCtrl.text);
                        if ((days == null || days <= 0) &&
                            (hours == null || hours <= 0)) {
                          return s.leaveAmountGtZero;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _grantHoursCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: s.leaveAmount,
                          suffixText: s.leaveUnitHour),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _validFrom ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) setState(() => _validFrom = p);
                      },
                      child: Text(_validFrom == null
                          ? '${s.leaveValidFrom}: ${s.leaveUnlimited}'
                          : '${s.leaveValidFrom}: ${DateFormat('dd/MM/yyyy').format(_validFrom!)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _validTo ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) setState(() => _validTo = p);
                      },
                      child: Text(_validTo == null
                          ? '${s.leaveValidTo}: ${s.leaveUnlimited}'
                          : '${s.leaveValidTo}: ${DateFormat('dd/MM/yyyy').format(_validTo!)}'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _expireCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.leaveExpireAfterDays),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(labelText: s.note),
                  validator: (v) =>
                      (v ?? '').trim().isNotEmpty ? null : s.requiredField,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            if (!_key.currentState!.validate()) return;
            _ManualGrantDialog.result = {
              'employeeId': _employeeId,
              if (_leaveTypeId != null) 'leaveTypeId': _leaveTypeId,
              if (_grantDaysCtrl.text.trim().isNotEmpty)
                'grantDays': double.tryParse(_grantDaysCtrl.text.trim()),
              if (_grantHoursCtrl.text.trim().isNotEmpty)
                'grantHours': double.tryParse(_grantHoursCtrl.text.trim()),
              if (_validFrom != null)
                'validFrom': DateFormat('yyyy-MM-dd').format(_validFrom!),
              if (_validTo != null)
                'validTo': DateFormat('yyyy-MM-dd').format(_validTo!),
              if ((_expireCtrl.text.trim()).isNotEmpty)
                'expireAfterDays': int.tryParse(_expireCtrl.text.trim()),
              'note': _noteCtrl.text.trim(),
            };
            Navigator.pop(context, true);
          },
          child: Text(s.leaveManualGrant),
        ),
      ],
    );
  }
}

class _LeaveTypeDialog extends StatefulWidget {
  const _LeaveTypeDialog({this.initial});
  final Map<String, dynamic>? initial;
  static Map<String, dynamic>? result;

  @override
  State<_LeaveTypeDialog> createState() => _LeaveTypeDialogState();
}

class _LeaveTypeDialogState extends State<_LeaveTypeDialog> {
  final _key = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _deductPerDayCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();
  String _unit = 'DAY';
  bool _paid = true;
  bool _requiresBalance = true;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _codeCtrl.text = (i['code'] ?? '').toString();
      _nameCtrl.text = (i['name'] ?? '').toString();
      _deductPerDayCtrl.text = (i['deductPerDay'] ?? '1').toString();
      _descCtrl.text = (i['description'] ?? '').toString();
      _unit = (i['unit'] ?? 'DAY').toString();
      _paid = i['paid'] == true;
      _requiresBalance = (i['requiresBalance'] ?? _paid) == true;
      _active = i['active'] == true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? s.leaveAddType : s.leaveEditType),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: _codeCtrl,
                  decoration: InputDecoration(labelText: s.leaveTypeCode),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? s.requiredField : null),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: s.leaveTypeName),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? s.requiredField : null),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _unit,
                items: const [
                  DropdownMenuItem(value: 'DAY', child: Text('DAY')),
                  DropdownMenuItem(value: 'HOUR', child: Text('HOUR')),
                ],
                onChanged: (v) => setState(() => _unit = v ?? 'DAY'),
                decoration: InputDecoration(labelText: s.leaveUnit),
              ),
              if (_unit == 'DAY') ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _deductPerDayCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: s.leaveDeductPerDay),
                  validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0
                      ? null
                      : s.leaveAmountGtZero,
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.leavePaid),
                value: _paid,
                onChanged: (v) => setState(() => _paid = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.leaveRequiresBalance),
                subtitle: Text(s.leaveRequiresBalanceHint),
                value: _requiresBalance,
                onChanged: (v) => setState(() => _requiresBalance = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.activate),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(labelText: s.descriptionLabel)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            if (!_key.currentState!.validate()) return;
            _LeaveTypeDialog.result = {
              'code': _codeCtrl.text.trim(),
              'name': _nameCtrl.text.trim(),
              'unit': _unit,
              'deductPerDay': _unit == 'DAY'
                  ? double.parse(_deductPerDayCtrl.text.trim())
                  : 1,
              'paid': _paid,
              'requiresBalance': _requiresBalance,
              'active': _active,
              'description': _descCtrl.text.trim(),
            };
            Navigator.pop(context, true);
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}

class _AccrualRuleDialog extends StatefulWidget {
  const _AccrualRuleDialog({
    required this.departments,
    this.initial,
  });
  final List<DepartmentFlat> departments;
  final Map<String, dynamic>? initial;
  static Map<String, dynamic>? result;

  @override
  State<_AccrualRuleDialog> createState() => _AccrualRuleDialogState();
}

class _AccrualRuleDialogState extends State<_AccrualRuleDialog> {
  final _key = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _grantDaysCtrl = TextEditingController();
  final _grantHoursCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();
  final _monthCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _expireCtrl = TextEditingController();
  int? _departmentId;
  String _freq = 'MONTHLY';
  bool _active = true;
  DateTime? _validFrom;
  DateTime? _validTo;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _nameCtrl.text = (i['name'] ?? '').toString();
      if (i['grantDays'] != null) _grantDaysCtrl.text = i['grantDays'].toString();
      if (i['grantHours'] != null) _grantHoursCtrl.text = i['grantHours'].toString();
      _dayCtrl.text = (i['dayOfMonth'] ?? '').toString();
      _monthCtrl.text = (i['monthOfYear'] ?? '').toString();
      _tenureCtrl.text = (i['minTenureYears'] ?? '').toString();
      _expireCtrl.text = (i['expireAfterDays'] ?? '').toString();
      _departmentId = i['departmentId'] as int?;
      _freq = (i['frequency'] ?? 'MONTHLY').toString();
      _active = i['active'] == true;
      _validFrom = _parseDate(i['validFrom']);
      _validTo = _parseDate(i['validTo']);
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? s.leaveAddRule : s.leaveEditRule),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(labelText: s.leaveRuleName),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? s.requiredField : null),
                const SizedBox(height: 8),
                DepartmentPickerField(
                  departments: widget.departments,
                  value: _departmentId,
                  onChanged: (v) => setState(() => _departmentId = v),
                  label: s.leaveApplyDepartment,
                  allowAll: true,
                  allLabel: s.leaveAllCompany,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _grantDaysCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: s.leaveGrantAmount,
                          suffixText: s.leaveUnitDay),
                      validator: (v) {
                        final days = double.tryParse(v ?? '');
                        final hours = double.tryParse(_grantHoursCtrl.text);
                        if ((days == null || days <= 0) &&
                            (hours == null || hours <= 0)) {
                          return s.leaveAmountGtZero;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _grantHoursCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: s.leaveGrantAmount,
                          suffixText: s.leaveUnitHour),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _freq,
                  items: const [
                    DropdownMenuItem(value: 'MONTHLY', child: Text('MONTHLY')),
                    DropdownMenuItem(value: 'YEARLY', child: Text('YEARLY')),
                  ],
                  onChanged: (v) => setState(() => _freq = v ?? 'MONTHLY'),
                  decoration: InputDecoration(labelText: s.leaveFrequency),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _dayCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              InputDecoration(labelText: s.leaveDayOfMonth))),
                  const SizedBox(width: 8),
                  if (_freq == 'YEARLY')
                    Expanded(
                        child: TextFormField(
                            controller: _monthCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: s.leaveMonthOfYear))),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _tenureCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.leaveMinTenure)),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _expireCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.leaveExpireAfterDays)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _validFrom ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) setState(() => _validFrom = p);
                      },
                      child: Text(_validFrom == null
                          ? '${s.leaveValidFrom}: ${s.leaveUnlimited}'
                          : '${s.leaveValidFrom}: ${DateFormat('dd/MM/yyyy').format(_validFrom!)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _validTo ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) setState(() => _validTo = p);
                      },
                      child: Text(_validTo == null
                          ? '${s.leaveValidTo}: ${s.leaveUnlimited}'
                          : '${s.leaveValidTo}: ${DateFormat('dd/MM/yyyy').format(_validTo!)}'),
                    ),
                  ),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.activate),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            if (!_key.currentState!.validate()) return;
            _AccrualRuleDialog.result = {
              'name': _nameCtrl.text.trim(),
              'departmentId': _departmentId,
              if (_grantDaysCtrl.text.trim().isNotEmpty)
                'grantDays': double.tryParse(_grantDaysCtrl.text.trim()),
              if (_grantHoursCtrl.text.trim().isNotEmpty)
                'grantHours': double.tryParse(_grantHoursCtrl.text.trim()),
              'frequency': _freq,
              if (_dayCtrl.text.trim().isNotEmpty)
                'dayOfMonth': int.tryParse(_dayCtrl.text.trim()),
              if (_freq == 'YEARLY' && _monthCtrl.text.trim().isNotEmpty)
                'monthOfYear': int.tryParse(_monthCtrl.text.trim()),
              if (_tenureCtrl.text.trim().isNotEmpty)
                'minTenureYears': int.tryParse(_tenureCtrl.text.trim()),
              if (_expireCtrl.text.trim().isNotEmpty)
                'expireAfterDays': int.tryParse(_expireCtrl.text.trim()),
              if (_validFrom != null)
                'validFrom': DateFormat('yyyy-MM-dd').format(_validFrom!),
              if (_validTo != null)
                'validTo': DateFormat('yyyy-MM-dd').format(_validTo!),
              'active': _active,
            };
            Navigator.pop(context, true);
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}

class _EmployeeGrantHistoryDialog extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  final LeaveRepository repo;
  final double hoursPerDay;

  const _EmployeeGrantHistoryDialog({
    required this.employeeId,
    required this.employeeName,
    required this.repo,
    required this.hoursPerDay,
  });

  @override
  State<_EmployeeGrantHistoryDialog> createState() =>
      _EmployeeGrantHistoryDialogState();
}

class _EmployeeGrantHistoryDialogState
    extends State<_EmployeeGrantHistoryDialog> {
  List<Map<String, dynamic>> _grants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.repo.getGrants(employeeId: widget.employeeId);
    if (mounted) setState(() { _grants = _sortGrants(data); _loading = false; });
  }

  List<Map<String, dynamic>> _sortGrants(List<Map<String, dynamic>> grants) {
    final today = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v.toString()); } catch (_) { return null; }
    }

    double remaining(Map<String, dynamic> g) =>
        ((g['remainingDays'] as num?)?.toDouble() ?? 0) +
        ((g['remainingHours'] as num?)?.toDouble() ?? 0);

    double used(Map<String, dynamic> g) =>
        ((g['usedDays'] as num?)?.toDouble() ?? 0) +
        ((g['usedHours'] as num?)?.toDouble() ?? 0);

    int boolRank(bool v) => v ? 1 : 0;

    return grants..sort((a, b) {
      final aTo = parseDate(a['validTo']);
      final bTo = parseDate(b['validTo']);
      final aExpired = aTo != null && aTo.isBefore(today);
      final bExpired = bTo != null && bTo.isBefore(today);
      int c = boolRank(aExpired).compareTo(boolRank(bExpired));
      if (c != 0) return c;

      final aEmpty = remaining(a) <= 0;
      final bEmpty = remaining(b) <= 0;
      c = boolRank(aEmpty).compareTo(boolRank(bEmpty));
      if (c != 0) return c;

      final aToNull = aTo == null ? 1 : 0;
      final bToNull = bTo == null ? 1 : 0;
      c = aToNull.compareTo(bToNull);
      if (c != 0) return c;

      if (aTo != null && bTo != null) {
        c = aTo.compareTo(bTo);
        if (c != 0) return c;
      }

      final aFrom = parseDate(a['validFrom']);
      final bFrom = parseDate(b['validFrom']);
      if (aFrom != null && bFrom != null) {
        c = aFrom.compareTo(bFrom);
        if (c != 0) return c;
      }

      c = remaining(a).compareTo(remaining(b));
      if (c != 0) return c;

      return used(a).compareTo(used(b));
    });
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '-';
    try {
      final d = DateTime.parse(v.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return v.toString();
    }
  }

  bool _isExpired(Map<String, dynamic> g) {
    final v = g['validTo'];
    if (v == null) return false;
    try {
      return DateTime.parse(v.toString()).isBefore(
          DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0));
    } catch (_) {
      return false;
    }
  }

  bool _isDepleted(Map<String, dynamic> g) {
    final d = (g['remainingDays'] as num?)?.toDouble() ?? 0;
    final h = (g['remainingHours'] as num?)?.toDouble() ?? 0;
    return d <= 0 && h <= 0;
  }

  String _fmtAmt(dynamic days, dynamic hours, AppLocalizations s) {
    double d = (days as num?)?.toDouble() ?? 0;
    double h = (hours as num?)?.toDouble() ?? 0;
    final hpd = widget.hoursPerDay;
    if (hpd > 0 && h >= hpd) {
      final extra = (h / hpd).floor();
      d += extra;
      h -= extra * hpd;
    }
    String fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
    final parts = <String>[];
    if (d > 0) parts.add('${fmt(d)} ${s.leaveUnitDay}');
    if (h > 0) parts.add('${fmt(h)} ${s.leaveUnitHour}');
    return parts.isEmpty ? '0 ${s.leaveUnitDay}' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final s = AppLocalizations.of(context);
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 760,
          maxHeight: isMobile ? screenW * 1.5 : 520,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.uiLeaveHistoryTitle(widget.employeeName),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _grants.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(s.noResults,
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant)),
                        )
                      : isMobile
                          ? _buildMobileList(colorScheme)
                          : _buildDesktopTable(colorScheme),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(ColorScheme colorScheme) {
    final s = AppLocalizations.of(context);
    final zebraColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    const colWidths = [90.0, 120.0, 110.0, 110.0, 110.0, 170.0];
    final headers = [s.uiGrantDate, s.uiSource, s.uiGranted, s.uiUsed, s.uiRemaining, s.leaveValidity];

    return Column(
      children: [
        Container(
          color: colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              for (int i = 0; i < headers.length; i++)
                SizedBox(
                  width: colWidths[i],
                  child: Text(
                    headers[i],
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    textAlign: TextAlign.left,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _grants.length,
            separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
            itemBuilder: (_, idx) {
              final g = _grants[idx];
              final expired = _isExpired(g);
              final depleted = _isDepleted(g);
              final dimmed = expired || depleted;
              final sourceLabel =
                  (g['source'] ?? '') == 'MANUAL' ? s.uiManual : s.uiAutomatic;
              return Opacity(
                opacity: dimmed ? 0.45 : 1.0,
                child: Container(
                color: idx.isOdd ? zebraColor : null,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: colWidths[0],
                      child: Text(_fmtDate(g['grantedAt']),
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                    SizedBox(
                      width: colWidths[1],
                      child: Row(
                        children: [
                          Text(sourceLabel,
                              style: const TextStyle(fontSize: 13)),
                          if (expired) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(s.leaveExpired,
                                  style: const TextStyle(fontSize: 10, color: AppTheme.error)),
                            ),
                          ] else if (depleted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.textSecondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(s.leaveDepleted,
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      width: colWidths[2],
                      child: Text(_fmtAmt(g['grantDays'], g['grantHours'], s),
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    SizedBox(
                      width: colWidths[3],
                      child: Text(_fmtAmt(g['usedDays'], g['usedHours'], s),
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    SizedBox(
                      width: colWidths[4],
                      child: Text(
                          depleted ? s.leaveDepleted : _fmtAmt(g['remainingDays'], g['remainingHours'], s),
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: depleted ? AppTheme.textSecondary : null)),
                    ),
                    SizedBox(
                      width: colWidths[5],
                      child: Text(
                          '${_fmtDate(g['validFrom'])} → ${_fmtDate(g['validTo'])}',
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList(ColorScheme colorScheme) {
    final s = AppLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _grants.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
      itemBuilder: (_, idx) {
        final g = _grants[idx];
        final expired = _isExpired(g);
        final depleted = _isDepleted(g);
        final dimmed = expired || depleted;
        final sourceLabel =
            (g['source'] ?? '') == 'MANUAL' ? s.uiManual : s.uiAutomatic;
        return Opacity(
          opacity: dimmed ? 0.45 : 1.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(sourceLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        if (expired) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(s.leaveExpired,
                                style: const TextStyle(fontSize: 10, color: AppTheme.error)),
                          ),
                        ] else if (depleted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(s.leaveDepleted,
                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          ),
                        ],
                      ],
                    ),
                    Text(_fmtDate(g['grantedAt']),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _mobileCell(s.uiGranted, _fmtAmt(g['grantDays'], g['grantHours'], s)),
                    _mobileCell(s.uiUsed, _fmtAmt(g['usedDays'], g['usedHours'], s)),
                    _mobileCell(
                      s.uiRemaining,
                      depleted ? s.leaveDepleted : _fmtAmt(g['remainingDays'], g['remainingHours'], s),
                      bold: true,
                      color: depleted ? AppTheme.textSecondary : AppTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.leaveValidity}: ${_fmtDate(g['validFrom'])} → ${_fmtDate(g['validTo'])}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mobileCell(String label, String value,
      {bool bold = false, Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }
}
