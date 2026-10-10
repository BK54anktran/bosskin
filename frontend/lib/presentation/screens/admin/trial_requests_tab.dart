import 'dart:typed_data';

import 'package:bosskin/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/file_saver_utils.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/search_text_field.dart';
import '../../widgets/status_badge.dart';

/// Tab "Yêu cầu dùng thử" ở trang system admin — đơn gửi từ trang giới thiệu (landing/).
class TrialRequestsTab extends StatefulWidget {
  final Dio dio;                       // Dio của trang admin (baseUrl /admin, token system admin)
  final VoidCallback? onChanged;       // báo trang cha cập nhật số yêu cầu mới
  const TrialRequestsTab({super.key, required this.dio, this.onChanged});

  @override
  State<TrialRequestsTab> createState() => _TrialRequestsTabState();
}

const trialStatuses = ['NEW', 'CONTACTED', 'TRIAL', 'REJECTED'];

String trialStatusLabel(String st, AppLocalizations s) => switch (st) {
      'NEW' => s.trialStatusNew,
      'CONTACTED' => s.trialStatusContacted,
      'TRIAL' => s.trialStatusTrial,
      _ => s.trialStatusRejected,
    };

Color trialStatusColor(String st) => switch (st) {
      'NEW' => AppTheme.primary,
      'CONTACTED' => AppTheme.warning,
      'TRIAL' => AppTheme.secondary,
      _ => AppTheme.textSecondary,
    };

class _TrialRequestsTabState extends State<TrialRequestsTab> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  int _total = 0, _page = 0, _pageSize = 20;
  String? _status;
  bool _loading = true;
  String? _error;

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
      final r = await widget.dio.get('/trial-requests', queryParameters: {
        'page': _page, 'size': _pageSize,
        if (_status != null) 'status': _status,
        if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
      });
      final data = r.data as Map<String, dynamic>;
      setState(() {
        _rows = (data['content'] as List).cast<Map<String, dynamic>>();
        _total = (data['totalElements'] as num?)?.toInt() ?? _rows.length;
      });
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    try {
      final r = await widget.dio.get('/trial-requests/export',
          queryParameters: {if (_status != null) 'status': _status},
          options: Options(responseType: ResponseType.bytes));
      await saveFileToDevice(Uint8List.fromList(r.data as List<int>),
          'yeu-cau-dung-thu-${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(serverMsg(e))));
    }
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    final updated = await showDialog<bool>(context: context, builder: (_) => _TrialEditDialog(dio: widget.dio, row: row));
    if (updated == true) { _load(); widget.onChanged?.call(); }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 340,
            child: SearchTextField(
              controller: _searchCtrl,
              hint: s.trialSearchHint,
              onChanged: (_) { _page = 0; _load(); },
              onClear: () { _page = 0; _load(); },
            ),
          ),
          ChoiceChip(label: Text(s.all), selected: _status == null, onSelected: (_) { setState(() { _status = null; _page = 0; }); _load(); }),
          for (final st in trialStatuses)
            ChoiceChip(
              label: Text(trialStatusLabel(st, s)),
              selected: _status == st,
              onSelected: (_) { setState(() { _status = st; _page = 0; }); _load(); },
            ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download, size: 18), label: Text(s.exportExcel)),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? EmptyState(icon: Icons.error_outline, message: _error!, actionLabel: s.retry, onAction: _load)
                : _rows.isEmpty
                    ? EmptyState(icon: Icons.inbox_outlined, message: s.trialEmpty)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _TrialCard(row: _rows[i], onTap: () => _edit(_rows[i])),
                        ),
                      ),
      ),
      PaginationBar(
        total: _total,
        page: _page,
        pageSize: _pageSize,
        onPageSizeChanged: (v) { setState(() { _pageSize = v; _page = 0; }); _load(); },
        onPrev: _page > 0 ? () { setState(() => _page--); _load(); } : null,
        onNext: (_page + 1) * _pageSize < _total ? () { setState(() => _page++); _load(); } : null,
      ),
    ]);
  }
}

class _TrialCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const _TrialCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final st = row['status'] as String? ?? 'NEW';
    final created = DateTime.tryParse(row['createdAt'] as String? ?? '');
    final email = row['email'] as String?;
    final size = row['companySize'] as String?;
    final need = row['need'] as String?;
    final note = row['adminNote'] as String?;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(row['companyName'] as String? ?? '',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
              ),
              StatusBadge(label: trialStatusLabel(st, s), color: trialStatusColor(st)),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 16, runSpacing: 4, children: [
              _Info(Icons.person_outline, row['fullName'] as String? ?? ''),
              _Info(Icons.phone_outlined, row['phone'] as String? ?? '', selectable: true),
              if (email != null) _Info(Icons.mail_outline, email, selectable: true),
              if (size != null) _Info(Icons.groups_outlined, s.trialEmployees(size)),
              if (created != null) _Info(Icons.schedule, DateFormat('dd/MM/yyyy HH:mm').format(created)),
            ]),
            if (need != null) ...[
              const SizedBox(height: 8),
              Text(need, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
            ],
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(s.trialNoteLine(note, row['handledBy'] as String? ?? ''),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool selectable;
  const _Info(this.icon, this.text, {this.selectable = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 13, color: AppTheme.textSecondary);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppTheme.textMuted),
      const SizedBox(width: 4),
      selectable ? SelectableText(text, style: style) : Text(text, style: style),
    ]);
  }
}

class _TrialEditDialog extends StatefulWidget {
  final Dio dio;
  final Map<String, dynamic> row;
  const _TrialEditDialog({required this.dio, required this.row});

  @override
  State<_TrialEditDialog> createState() => _TrialEditDialogState();
}

class _TrialEditDialogState extends State<_TrialEditDialog> {
  late String _status = widget.row['status'] as String? ?? 'NEW';
  late final _noteCtrl = TextEditingController(text: widget.row['adminNote'] as String? ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.dio.patch('/trial-requests/${widget.row['id']}', data: {'status': _status, 'adminNote': _noteCtrl.text});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(serverMsg(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.row['companyName'] as String? ?? ''),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.trialStatusLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final st in trialStatuses)
              ChoiceChip(label: Text(trialStatusLabel(st, s)), selected: _status == st, onSelected: (_) => setState(() => _status = st)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(labelText: s.trialNote, border: const OutlineInputBorder()),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _saving ? null : _save, child: Text(s.save)),
      ],
    );
  }
}
