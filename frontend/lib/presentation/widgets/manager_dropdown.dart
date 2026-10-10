import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../data/models/employee.dart';
import '../../data/repositories/employee_repository.dart';

/// Bước K — chọn quản lý trực tiếp (nhân viên đang làm, trừ chính người đang sửa).
/// Backend kiểm vòng lặp quản lý; ở đây chỉ loại chính mình.
/// Bước L dùng lại để chọn nhân viên cho hợp đồng ([allowNone] = false, [label] = Nhân viên).
class ManagerDropdown extends StatefulWidget {
  final int? value;
  final int? excludeEmployeeId;
  final ValueChanged<int?> onChanged;
  final String? label;
  final bool allowNone;

  const ManagerDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.excludeEmployeeId,
    this.label,
    this.allowNone = true,
  });

  @override
  State<ManagerDropdown> createState() => _ManagerDropdownState();
}

class _ManagerDropdownState extends State<ManagerDropdown> {
  static Future<List<Employee>>? _cache;
  List<Employee>? _items;

  @override
  void initState() {
    super.initState();
    _cache ??= EmployeeRepository().getAllForPicker();
    _cache!.then((list) {
      if (mounted) setState(() => _items = list.where((e) => e.status != EmployeeStatus.inactive).toList());
    }).catchError((_) {
      _cache = null;
      if (mounted) setState(() => _items = const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final label = widget.label ?? s.directManager;
    final items = _items;
    if (items == null) {
      return InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: const LinearProgressIndicator(),
      );
    }
    final options = items.where((e) => e.id != widget.excludeEmployeeId).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final value = options.any((e) => e.id == widget.value) ? widget.value : null;
    return DropdownButtonFormField<int?>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        if (widget.allowNone) DropdownMenuItem<int?>(value: null, child: Text(s.directManagerNone)),
        ...options.map((e) => DropdownMenuItem<int?>(
              value: e.id,
              child: Text('${e.fullName} · ${e.employeeCode} · ${e.departmentName}', overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: widget.onChanged,
    );
  }
}
