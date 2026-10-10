import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Ô chọn ngày dạng dd/MM/yyyy (bấm mở lịch). [onChanged] null = chỉ xem; [clearable] cho phép xoá về null.
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool clearable;

  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.clearable = false,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 20);
    final last = lastDate ?? DateTime(now.year + 20);
    var initial = value ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (d != null) onChanged?.call(d);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: enabled ? () => _pick(context) : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            enabled: enabled,
            suffixIcon: clearable && value != null && enabled
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => onChanged!(null),
                  )
                : const Icon(Icons.event_outlined, size: 18),
          ),
          child: Text(value == null ? '—' : DateFormat('dd/MM/yyyy').format(value!)),
        ),
      ),
    );
  }
}
