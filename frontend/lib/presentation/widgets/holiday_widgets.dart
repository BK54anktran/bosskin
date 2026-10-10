import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/work_calendar.dart';
import 'app_dropdown.dart';
import 'status_badge.dart';

/// Ngày lễ dùng chung cho tab "Lịch làm việc" (công ty) và tab "Ngày lễ mẫu" (system admin).

const holidayTypes = ['HOLIDAY', 'COMPENSATORY', 'SWAP_WORKDAY'];

/// Màu nền ô ngày lễ / ngày nghỉ theo lịch trên lưới phân ca và bảng công.
const holidayCellColor = Color(0xFFFFF4E0);
const holidayTextColor = Color(0xFFB45309);

String holidayTypeLabel(AppLocalizations s, String type) => switch (type) {
      'COMPENSATORY' => s.holidayTypeCompensatory,
      'SWAP_WORKDAY' => s.holidayTypeSwapWorkday,
      _ => s.holidayTypeHoliday,
    };

Color holidayTypeColor(String type) => switch (type) {
      'COMPENSATORY' => AppTheme.primary,
      'SWAP_WORKDAY' => AppTheme.textSecondary,
      _ => holidayTextColor,
    };

/// Thanh chọn năm ‹ 2026 ›.
class HolidayYearBar extends StatelessWidget {
  final int year;
  final ValueChanged<int> onChanged;
  const HolidayYearBar({super.key, required this.year, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: s.calPrevYear,
        icon: const Icon(Icons.chevron_left),
        onPressed: () => onChanged(year - 1),
      ),
      Text('${s.year} $year', style: const TextStyle(fontWeight: FontWeight.w700)),
      IconButton(
        tooltip: s.calNextYear,
        icon: const Icon(Icons.chevron_right),
        onPressed: () => onChanged(year + 1),
      ),
    ]);
  }
}

/// Một dòng ngày lễ: ngày + thứ, tên, loại, có/không lương, nút sửa/xoá (khi có quyền).
class HolidayListTile extends StatelessWidget {
  final Holiday holiday;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const HolidayListTile({super.key, required this.holiday, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final h = holiday;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 92,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('dd/MM/yyyy').format(h.date), style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(DateFormat.EEEE(locale).format(h.date),
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
      ),
      title: Text(h.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(spacing: 6, runSpacing: 4, children: [
          StatusBadge(label: holidayTypeLabel(s, h.type), color: holidayTypeColor(h.type)),
          if (h.isDayOff)
            StatusBadge(
              label: h.paid ? s.holidayPaid : s.holidayUnpaid,
              color: h.paid ? AppTheme.secondary : AppTheme.textSecondary,
            ),
        ]),
      ),
      trailing: (onEdit == null && onDelete == null)
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (onEdit != null)
                IconButton(tooltip: s.edit, icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
              if (onDelete != null)
                IconButton(
                  tooltip: s.delete,
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                  onPressed: onDelete,
                ),
            ]),
    );
  }
}

/// Hộp thêm / sửa ngày lễ — trả về [Holiday] (chưa có id) hoặc null khi huỷ.
class HolidayFormDialog extends StatefulWidget {
  final Holiday? existing;
  final int year;
  const HolidayFormDialog({super.key, this.existing, required this.year});

  @override
  State<HolidayFormDialog> createState() => _HolidayFormDialogState();
}

class _HolidayFormDialogState extends State<HolidayFormDialog> {
  late DateTime _date;
  late final TextEditingController _nameCtrl;
  late String _type;
  late bool _paid;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _date = e?.date ?? (now.year == widget.year ? DateTime(now.year, now.month, now.day) : DateTime(widget.year, 1, 1));
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _type = e?.type ?? 'HOLIDAY';
    _paid = e?.paid ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final s = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = s.holidayNameRequired);
      return;
    }
    Navigator.pop(context, Holiday(date: _date, name: name, type: _type, paid: _type == 'SWAP_WORKDAY' || _paid));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? s.holidayAdd : s.holidayEdit),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: s.holidayDate, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
                child: Text(DateFormat('dd/MM/yyyy').format(_date)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            maxLength: 150,
            decoration: InputDecoration(labelText: s.holidayName, errorText: _nameError),
          ),
          const SizedBox(height: 4),
          AppDropdown<String>(
            value: _type,
            label: s.holidayType,
            items: [
              for (final t in holidayTypes) DropdownMenuItem(value: t, child: Text(holidayTypeLabel(s, t))),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'HOLIDAY'),
          ),
          const SizedBox(height: 4),
          Text(_typeHint(s), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          if (_type != 'SWAP_WORKDAY')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _paid,
              onChanged: (v) => setState(() => _paid = v),
              title: Text(s.holidayPaidLabel),
              subtitle: Text(s.holidayPaidHint, style: const TextStyle(fontSize: 12)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }

  String _typeHint(AppLocalizations s) => switch (_type) {
        'COMPENSATORY' => s.holidayTypeCompensatoryHint,
        'SWAP_WORKDAY' => s.holidayTypeSwapWorkdayHint,
        _ => s.holidayTypeHolidayHint,
      };
}
