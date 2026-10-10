import 'package:bosskin/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/work_calendar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/holiday_widgets.dart';

/// Tab "Ngày lễ mẫu" ở trang system admin (bước J): danh sách ngày lễ mặc định theo năm cho mọi công ty.
/// Công ty chưa tự chỉnh năm nào thì dùng danh sách này; đã chỉnh thì giữ bản riêng.
class HolidayTemplatesTab extends StatefulWidget {
  final Dio dio;
  const HolidayTemplatesTab({super.key, required this.dio});

  @override
  State<HolidayTemplatesTab> createState() => _HolidayTemplatesTabState();
}

class _HolidayTemplatesTabState extends State<HolidayTemplatesTab> {
  int _year = DateTime.now().year;
  List<Holiday> _items = [];
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
      final r = await widget.dio.get('/holidays', queryParameters: {'year': _year});
      setState(() => _items = (r.data as List)
          .map((e) => Holiday.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (e) {
      if (mounted) setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));

  Future<void> _edit(Holiday? h) async {
    final result = await showDialog<Holiday>(
      context: context,
      builder: (ctx) => HolidayFormDialog(existing: h, year: _year),
    );
    if (result == null) return;
    try {
      if (h?.id == null) {
        await widget.dio.post('/holidays', data: result.toJson());
      } else {
        await widget.dio.put('/holidays/${h!.id}', data: result.toJson());
      }
      await _load();
    } catch (e) {
      if (mounted) _snack(serverMsg(e));
    }
  }

  Future<void> _delete(Holiday h) async {
    final s = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.holidayDeleteConfirm(h.name, DateFormat('dd/MM/yyyy').format(h.date))),
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
      await widget.dio.delete('/holidays/${h.id}');
      await _load();
    } catch (e) {
      if (mounted) _snack(serverMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
        HolidayYearBar(year: _year, onChanged: (y) {
          setState(() => _year = y);
          _load();
        }),
        FilledButton.icon(
          onPressed: _loading ? null : () => _edit(null),
          icon: const Icon(Icons.add, size: 16),
          label: Text(s.holidayAdd),
        ),
      ]),
      const SizedBox(height: 4),
      Text(s.holidayTemplateAdminHint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      const SizedBox(height: 8),
      if (_error != null) Text(_error!, style: const TextStyle(color: AppTheme.error)),
      if (_loading)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (_items.isEmpty)
        EmptyState(icon: Icons.event_busy_outlined, message: s.holidayEmpty)
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              for (final h in _items)
                HolidayListTile(holiday: h, onEdit: () => _edit(h), onDelete: () => _delete(h)),
            ]),
          ),
        ),
    ]);
  }
}
