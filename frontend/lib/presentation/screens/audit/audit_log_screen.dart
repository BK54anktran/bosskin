import 'dart:convert';

import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/services/api_service.dart';

/// Bước 2 — Nhật ký thao tác: ai sửa công, duyệt lương, đổi quyền, impersonate… (quyền AUDIT_VIEW).
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

const auditActions = <String>['ATTENDANCE_APPROVE', 'ATTENDANCE_BULK_APPROVE', 'ATTENDANCE_UNAPPROVE', 'ATTENDANCE_OVERRIDE', 'ATTENDANCE_DELETE', 'ATTENDANCE_MANUAL_CHECK_IN', 'ATTENDANCE_MANUAL_CHECK_OUT', 'ATTENDANCE_IMPORT', 'ATTENDANCE_IMPORT_TIMESHEET', 'ATTENDANCE_REQUEST_APPROVE', 'ATTENDANCE_REQUEST_REJECT', 'PERIOD_LOCK', 'PERIOD_UNLOCK', 'PAYROLL_GENERATE', 'PAYROLL_UPDATE', 'PAYROLL_RECALCULATE', 'PAYROLL_APPROVE', 'PAYROLL_PAY', 'PAYROLL_DELETE', 'ROLE_CREATE', 'ROLE_UPDATE', 'ROLE_PERMISSIONS', 'ROLE_DELETE', 'USER_CREATE', 'USER_SYNC_FROM_EMPLOYEES', 'USER_ROLES', 'USER_PERMISSIONS', 'USER_DEPT_SCOPES', 'USER_ENABLE', 'USER_DISABLE', 'USER_RESET_PASSWORD', 'USER_ISSUE_INITIAL_PASSWORDS', 'PROFILE_EDIT_APPROVE', 'PROFILE_EDIT_REJECT', 'DEVICE_UNBIND', 'IMPERSONATE_START', 'COMPANY_CREATE', 'COMPANY_UPDATE', 'COMPANY_TOGGLE_ACTIVE', '2FA_ENABLE', '2FA_DISABLE', '2FA_RESET', 'COMPANY_REQUIRE_2FA', 'TRIAL_REQUEST_UPDATE', 'SYSADMIN_CREATE', 'SYSADMIN_ENABLE', 'SYSADMIN_DISABLE', 'SYSADMIN_RESET_PASSWORD', 'SYSADMIN_RESET_2FA', 'TAX_POLICY_CREATE', 'TAX_POLICY_UPDATE', 'TAX_POLICY_DELETE', 'HOLIDAY_CREATE', 'HOLIDAY_UPDATE', 'HOLIDAY_DELETE', 'HOLIDAY_IMPORT', 'HOLIDAY_TEMPLATE_CREATE', 'HOLIDAY_TEMPLATE_UPDATE', 'HOLIDAY_TEMPLATE_DELETE', 'WORK_CALENDAR_CREATE', 'WORK_CALENDAR_UPDATE', 'WORK_CALENDAR_DELETE', 'JOB_HISTORY_CREATE', 'JOB_HISTORY_DELETE', 'MANAGER_APPROVE', 'MANAGER_REJECT', 'CONTRACT_CREATE', 'CONTRACT_UPDATE', 'CONTRACT_ACTIVATE', 'CONTRACT_TERMINATE', 'CONTRACT_DELETE', 'CONTRACT_APPENDIX_CREATE', 'CONTRACT_APPENDIX_UPDATE', 'CONTRACT_APPENDIX_DELETE', 'CONTRACT_IMPORT', 'DEPENDENT_CREATE', 'DEPENDENT_UPDATE', 'DEPENDENT_DELETE', 'DOCUMENT_TYPE_CREATE', 'DOCUMENT_TYPE_UPDATE', 'DOCUMENT_TYPE_DELETE', 'DOCUMENT_UPLOAD', 'DOCUMENT_UPDATE', 'DOCUMENT_DELETE', 'DOCUMENT_APPROVE', 'DOCUMENT_REJECT', 'DOCUMENT_VIEW'];

String auditActionLabel(AppLocalizations s, String action) => switch (action) {
      'ATTENDANCE_APPROVE' => s.auditActAttendanceApprove,
      'ATTENDANCE_BULK_APPROVE' => s.auditActAttendanceBulkApprove,
      'ATTENDANCE_UNAPPROVE' => s.auditActAttendanceUnapprove,
      'ATTENDANCE_OVERRIDE' => s.auditActAttendanceOverride,
      'ATTENDANCE_DELETE' => s.auditActAttendanceDelete,
      'ATTENDANCE_MANUAL_CHECK_IN' => s.auditActAttendanceManualCheckIn,
      'ATTENDANCE_MANUAL_CHECK_OUT' => s.auditActAttendanceManualCheckOut,
      'ATTENDANCE_IMPORT' => s.auditActAttendanceImport,
      'ATTENDANCE_IMPORT_TIMESHEET' => s.auditActAttendanceImportTimesheet,
      'ATTENDANCE_REQUEST_APPROVE' => s.auditActAttendanceRequestApprove,
      'ATTENDANCE_REQUEST_REJECT' => s.auditActAttendanceRequestReject,
      'PERIOD_LOCK' => s.auditActPeriodLock,
      'PERIOD_UNLOCK' => s.auditActPeriodUnlock,
      'PAYROLL_GENERATE' => s.auditActPayrollGenerate,
      'PAYROLL_UPDATE' => s.auditActPayrollUpdate,
      'PAYROLL_RECALCULATE' => s.auditActPayrollRecalculate,
      'PAYROLL_APPROVE' => s.auditActPayrollApprove,
      'PAYROLL_PAY' => s.auditActPayrollPay,
      'PAYROLL_DELETE' => s.auditActPayrollDelete,
      'ROLE_CREATE' => s.auditActRoleCreate,
      'ROLE_UPDATE' => s.auditActRoleUpdate,
      'ROLE_PERMISSIONS' => s.auditActRolePermissions,
      'ROLE_DELETE' => s.auditActRoleDelete,
      'USER_CREATE' => s.auditActUserCreate,
      'USER_SYNC_FROM_EMPLOYEES' => s.auditActUserSyncFromEmployees,
      'USER_ROLES' => s.auditActUserRoles,
      'USER_PERMISSIONS' => s.auditActUserPermissions,
      'USER_DEPT_SCOPES' => s.auditActUserDeptScopes,
      'USER_ENABLE' => s.auditActUserEnable,
      'USER_DISABLE' => s.auditActUserDisable,
      'DEVICE_UNBIND' => s.auditActDeviceUnbind,
      'IMPERSONATE_START' => s.auditActImpersonateStart,
      'COMPANY_CREATE' => s.auditActCompanyCreate,
      'COMPANY_UPDATE' => s.auditActCompanyUpdate,
      'COMPANY_TOGGLE_ACTIVE' => s.auditActCompanyToggleActive,
      '2FA_ENABLE' => s.auditAct2faEnable,
      '2FA_DISABLE' => s.auditAct2faDisable,
      '2FA_RESET' => s.auditAct2faReset,
      'COMPANY_REQUIRE_2FA' => s.auditActCompanyRequire2fa,
      'TRIAL_REQUEST_UPDATE' => s.auditActTrialRequestUpdate,
      'SYSADMIN_CREATE' => s.auditActSysadminCreate,
      'SYSADMIN_ENABLE' => s.auditActSysadminEnable,
      'SYSADMIN_DISABLE' => s.auditActSysadminDisable,
      'SYSADMIN_RESET_PASSWORD' => s.auditActSysadminResetPassword,
      'USER_RESET_PASSWORD' => s.auditActUserResetPassword,
      'USER_ISSUE_INITIAL_PASSWORDS' => s.auditActUserIssueInitialPasswords,
      'PROFILE_EDIT_APPROVE' => s.auditActProfileEditApprove,
      'PROFILE_EDIT_REJECT' => s.auditActProfileEditReject,
      'SYSADMIN_RESET_2FA' => s.auditActSysadminReset2fa,
      'TAX_POLICY_CREATE' => s.auditActTaxPolicyCreate,
      'TAX_POLICY_UPDATE' => s.auditActTaxPolicyUpdate,
      'TAX_POLICY_DELETE' => s.auditActTaxPolicyDelete,
      'HOLIDAY_CREATE' => s.auditActHolidayCreate,
      'HOLIDAY_UPDATE' => s.auditActHolidayUpdate,
      'HOLIDAY_DELETE' => s.auditActHolidayDelete,
      'HOLIDAY_IMPORT' => s.auditActHolidayImport,
      'HOLIDAY_TEMPLATE_CREATE' => s.auditActHolidayTemplateCreate,
      'HOLIDAY_TEMPLATE_UPDATE' => s.auditActHolidayTemplateUpdate,
      'HOLIDAY_TEMPLATE_DELETE' => s.auditActHolidayTemplateDelete,
      'WORK_CALENDAR_CREATE' => s.auditActWorkCalendarCreate,
      'WORK_CALENDAR_UPDATE' => s.auditActWorkCalendarUpdate,
      'WORK_CALENDAR_DELETE' => s.auditActWorkCalendarDelete,
      'JOB_HISTORY_CREATE' => s.auditActJobHistoryCreate,
      'JOB_HISTORY_DELETE' => s.auditActJobHistoryDelete,
      'MANAGER_APPROVE' => s.auditActManagerApprove,
      'MANAGER_REJECT' => s.auditActManagerReject,
      'CONTRACT_CREATE' => s.auditActContractCreate,
      'CONTRACT_UPDATE' => s.auditActContractUpdate,
      'CONTRACT_ACTIVATE' => s.auditActContractActivate,
      'CONTRACT_TERMINATE' => s.auditActContractTerminate,
      'CONTRACT_DELETE' => s.auditActContractDelete,
      'CONTRACT_APPENDIX_CREATE' => s.auditActContractAppendixCreate,
      'CONTRACT_APPENDIX_UPDATE' => s.auditActContractAppendixUpdate,
      'CONTRACT_APPENDIX_DELETE' => s.auditActContractAppendixDelete,
      'CONTRACT_IMPORT' => s.auditActContractImport,
      'DEPENDENT_CREATE' => s.auditActDependentCreate,
      'DEPENDENT_UPDATE' => s.auditActDependentUpdate,
      'DEPENDENT_DELETE' => s.auditActDependentDelete,
      'DOCUMENT_TYPE_CREATE' => s.auditActDocumentTypeCreate,
      'DOCUMENT_TYPE_UPDATE' => s.auditActDocumentTypeUpdate,
      'DOCUMENT_TYPE_DELETE' => s.auditActDocumentTypeDelete,
      'DOCUMENT_UPLOAD' => s.auditActDocumentUpload,
      'DOCUMENT_UPDATE' => s.auditActDocumentUpdate,
      'DOCUMENT_DELETE' => s.auditActDocumentDelete,
      'DOCUMENT_APPROVE' => s.auditActDocumentApprove,
      'DOCUMENT_REJECT' => s.auditActDocumentReject,
      'DOCUMENT_VIEW' => s.auditActDocumentView,
      _ => action,
    };
class _AuditLogScreenState extends State<AuditLogScreen> {
  final _rows = <Map<String, dynamic>>[];
  final _actorCtrl = TextEditingController();
  String? _action;
  late DateTimeRange _range;
  int _page = 0;
  bool _last = false;
  bool _loading = false;
  String? _error;

  static final _dateFmt = DateFormat('yyyy-MM-dd');
  static final _timeFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _range = DateTimeRange(
        start: today.subtract(const Duration(days: 30)), end: today);
    _load(reset: true);
  }

  @override
  void dispose() {
    _actorCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _rows.clear();
        _page = 0;
        _last = false;
      }
    });
    try {
      final data = await ApiService.instance.get<Map<String, dynamic>>(
        '/audit-logs',
        (d) => Map<String, dynamic>.from(d as Map),
        queryParams: {
          'page': _page,
          'size': 50,
          'from': _dateFmt.format(_range.start),
          'to': _dateFmt.format(_range.end),
          if (_action != null) 'action': _action,
          if (_actorCtrl.text.trim().isNotEmpty) 'actor': _actorCtrl.text.trim(),
        },
      );
      final content = (data['content'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _rows.addAll(content);
        _last = data['last'] == true || content.isEmpty;
        _page++;
      });
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (r != null) {
      setState(() => _range = r);
      _load(reset: true);
    }
  }

  String _prettyDetail(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final d = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String?>(
                  initialValue: _action,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    DropdownMenuItem<String?>(
                        value: null, child: Text(s.auditAllActions)),
                    ...auditActions.map((a) => DropdownMenuItem<String?>(
                        value: a,
                        child: Text(auditActionLabel(s, a),
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) {
                    setState(() => _action = v);
                    _load(reset: true);
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _actorCtrl,
                  decoration: InputDecoration(
                      isDense: true,
                      labelText: s.auditActorFilter,
                      prefixIcon: const Icon(Icons.search, size: 18)),
                  onSubmitted: (_) => _load(reset: true),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                    '${d.format(_range.start)} – ${d.format(_range.end)}'),
              ),
              IconButton(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
            ),
          Expanded(
            child: _rows.isEmpty && !_loading
                ? Center(
                    child: Text(s.auditEmpty,
                        style: TextStyle(color: AppTheme.textSecondary)))
                : ListView.separated(
                    itemCount: _rows.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (i == _rows.length) {
                        if (_loading) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _last
                            ? const SizedBox(height: 16)
                            : Center(
                                child: TextButton(
                                    onPressed: _load,
                                    child: Text(s.auditLoadMore)));
                      }
                      return _buildRow(s, _rows[i]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(AppLocalizations s, Map<String, dynamic> r) {
    final created = DateTime.tryParse('${r['createdAt'] ?? ''}');
    final impersonated = r['actorType'] == 'IMPERSONATE' || r['actorType'] == 'SYSTEM_ADMIN';
    final detail = _prettyDetail(r['detail'] as String?);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(auditActionLabel(s, '${r['action']}'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((r['summary'] ?? '').toString().isNotEmpty)
            Text('${r['summary']}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 2),
          Row(children: [
            Flexible(
              child: Text(
                '${created != null ? _timeFmt.format(created) : ''} · ${r['actorEmail'] ?? '-'}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            if (impersonated) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(s.auditImpersonated,
                    style: const TextStyle(fontSize: 10, color: AppTheme.warning)),
              ),
            ],
          ]),
        ],
      ),
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(detail,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        const SizedBox(height: 6),
        SelectableText(
          [
            if (r['ip'] != null) s.auditIp('${r['ip']}'),
            if (r['requestId'] != null) s.auditRequestId('${r['requestId']}'),
          ].join('   '),
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
