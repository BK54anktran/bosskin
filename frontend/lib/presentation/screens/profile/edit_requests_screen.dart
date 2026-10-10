import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/department_service.dart';
import '../../../data/services/profile_service.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../widgets/department_picker_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pagination_bar.dart';

class EditRequestsScreen extends StatefulWidget {
  const EditRequestsScreen({super.key});

  @override
  State<EditRequestsScreen> createState() => _EditRequestsScreenState();
}

class _EditRequestsScreenState extends State<EditRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<EditRequest> _pending = [];
  List<EditRequest> _resolved = [];
  List<DepartmentFlat> _depts = [];
  int? _filterDept;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, animationDuration: Duration.zero);
    _loadDepartments();
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts =
          await DepartmentService.instance.getFlat(permission: 'EMPLOYEE_UPDATE');
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
      final all =
          await ProfileService.instance.getEditRequests(departmentId: _filterDept);
      setState(() {
        _pending = all.where((r) => r.status == 'PENDING').toList();
        _resolved = all.where((r) => r.status != 'PENDING').toList();
      });
    } catch (e) {
      final s = AppLocalizations.of(context);
      setState(() => _error = '${s.errorPrefix}: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _approve(EditRequest req) async {
    final s = AppLocalizations.of(context);
    try {
      await ProfileService.instance.approveRequest(req.id);
      await AuthService.instance.refreshCurrentUserProfile();
      _showSnack(s.approveRequestFor(req.employeeName), success: true);
      await _loadAll();
    } catch (e) {
      _showSnack('${s.errorPrefix}: $e');
    }
  }

  Future<void> _reject(EditRequest req) async {
    final s = AppLocalizations.of(context);
    final noteCtrl = TextEditingController();
    final note = await showInstantDialog<String>(
      context,
      (dialogContext) => AlertDialog(
        title: Text(s.rejectRequestTitle(req.employeeName)),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: s.rejectionReasonLabel,
            hintText: s.enterReason,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(),
              child: Text(s.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true)
                .pop(noteCtrl.text.trim()),
            child: Text(s.reject),
          ),
        ],
      ),
    );
    if (note == null) return;
    try {
      await ProfileService.instance
          .rejectRequest(req.id, note: note.isEmpty ? null : note);
      _showSnack(s.rejectRequestFor(req.employeeName));
      await _loadAll();
    } catch (e) {
      _showSnack('${s.errorPrefix}: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppTheme.secondary : AppTheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              DepartmentPickerField(
                departments: _depts,
                value: _filterDept,
                allowAll: true,
                allLabel: s.all,
                label: s.department,
                compact: true,
                onChanged: (v) async {
                  setState(() => _filterDept = v);
                  await _loadAll();
                },
              ),
            ],
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 0,
          child: TabBar(
            controller: _tabs,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.pendingTab),
                    if (_pending.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _Badge(_pending.length),
                    ],
                  ],
                ),
              ),
              Tab(text: s.processedTabLabel),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(_error!,
                          style: const TextStyle(color: AppTheme.error)))
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _RequestList(
                          requests: _pending,
                          onApprove: _approve,
                          onReject: _reject,
                          emptyMessage: s.noPendingRequests,
                        ),
                        _RequestList(
                          requests: _resolved,
                          emptyMessage: s.noProcessedRequests,
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _RequestList extends StatefulWidget {
  final List<EditRequest> requests;
  final Future<void> Function(EditRequest)? onApprove;
  final Future<void> Function(EditRequest)? onReject;
  final String emptyMessage;

  const _RequestList({
    required this.requests,
    this.onApprove,
    this.onReject,
    required this.emptyMessage,
  });

  @override
  State<_RequestList> createState() => _RequestListState();
}

class _RequestListState extends State<_RequestList> {
  int _page = 0;
  int _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    if (widget.requests.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        message: widget.emptyMessage,
      );
    }
    final paged = widget.requests.skip(_page * _pageSize).take(_pageSize).toList();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: paged.length,
            itemBuilder: (_, i) => _RequestCard(
              request: paged[i],
              onApprove: widget.onApprove,
              onReject: widget.onReject,
            ),
          ),
        ),
        PaginationBar(
          total: widget.requests.length,
          page: _page,
          pageSize: _pageSize,
          onPageSizeChanged: (v) => setState(() { _pageSize = v; _page = 0; }),
          onPrev: _page > 0 ? () => setState(() => _page--) : null,
          onNext: (_page + 1) * _pageSize < widget.requests.length ? () => setState(() => _page++) : null,
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final EditRequest request;
  final Future<void> Function(EditRequest)? onApprove;
  final Future<void> Function(EditRequest)? onReject;

  const _RequestCard({
    required this.request,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final r = request;
    final isPending = r.status == 'PENDING';
    final statusColor = switch (r.status) {
      'APPROVED' => AppTheme.secondary,
      'REJECTED' => AppTheme.error,
      'CANCELLED' => AppTheme.textSecondary,
      _ => AppTheme.warning,
    };
    final statusLabel = switch (r.status) {
      'APPROVED' => s.approved,
      'REJECTED' => s.rejected,
      'CANCELLED' => s.cancelled,
      _ => s.pending,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(r.employeeName[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.employeeName,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.textPrimary)),
                      Text('${r.employeeCode} · ${r.departmentName}',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Changes table
            _ChangesTable(r),
            if (r.adminNote != null && r.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(s.adminNoteReason(r.adminNote!),
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.error)),
              ),
            ],
            if (r.createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '${s.sentAtLabel} ${_fmt(r.createdAt!)}',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
            if (isPending && onApprove != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close,
                          size: 16, color: AppTheme.error),
                      label: Text(s.reject,
                          style: const TextStyle(color: AppTheme.error)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.error)),
                      onPressed: () => onReject?.call(r),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(s.approve),
                      onPressed: () => onApprove?.call(r),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(String iso) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

class _ChangesTable extends StatelessWidget {
  final EditRequest r;
  const _ChangesTable(this.r);

  String _fmtDate(String? d) {
    if (d == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    String genderLabel(String? v) => switch (v) {
          'MALE' => s.genderMale,
          'FEMALE' => s.genderFemale,
          'OTHER' => s.genderOther,
          _ => '—',
        };
    final rows = <_ChangeRow>[];

    if (r.requestedFullName != null) {
      rows.add(_ChangeRow(
          s.fullName, r.currentFullName ?? '—', r.requestedFullName!));
    }
    if (r.requestedGender != null) {
      rows.add(_ChangeRow(s.gender, genderLabel(r.currentGender),
          genderLabel(r.requestedGender)));
    }
    if (r.requestedDateOfBirth != null) {
      rows.add(_ChangeRow(s.dateOfBirth, _fmtDate(r.currentDateOfBirth),
          _fmtDate(r.requestedDateOfBirth)));
    }
    if (r.requestedPhone != null) {
      rows.add(_ChangeRow(s.phone, r.currentPhone ?? '—', r.requestedPhone!));
    }
    if (r.requestedPersonalEmail != null) {
      rows.add(_ChangeRow(s.personalEmail, r.currentPersonalEmail ?? '—',
          r.requestedPersonalEmail!));
    }

    if (rows.isEmpty) {
      return Text(AppLocalizations.of(context).noChangesContent,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
    }

    return Column(
      children: rows
          .map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(row.field,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                    Expanded(
                      child: Text(row.current,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textPrimary)),
                    ),
                    Icon(Icons.arrow_forward,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(row.requested,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _ChangeRow {
  final String field, current, requested;
  const _ChangeRow(this.field, this.current, this.requested);
}
