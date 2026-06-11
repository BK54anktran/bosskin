import 'package:flutter/material.dart';

/// Dropdown chuẩn dùng cho filter và form — thay thế DropdownButtonFormField lặp lại.
class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;

  const AppDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    this.onChanged,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: isExpanded,
      borderRadius: BorderRadius.circular(12),
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items,
      onChanged: onChanged,
    );
  }
}
