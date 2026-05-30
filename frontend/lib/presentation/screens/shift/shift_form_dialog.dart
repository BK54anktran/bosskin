import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/department.dart';
import '../../../data/models/work_shift.dart';
import '../../../data/services/api_service.dart';

class ShiftFormDialog extends StatefulWidget {
  final WorkShift? shift;
  const ShiftFormDialog({this.shift, super.key});

  @override
  State<ShiftFormDialog> createState() => _ShiftFormDialogState();
}

class _ShiftFormDialogState extends State<ShiftFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  ShiftType _type = ShiftType.work;
  TimeOfDay? _start;
  TimeOfDay? _end;
  TimeOfDay? _breakStart;
  TimeOfDay? _breakEnd;
  String _color = '#1976D2';
  List<Department> _allDepts = [];
  final Set<int> _selectedDeptIds = {};
  bool _saving = false;
  bool _loadingDepts = true;

  static const _colors = [
    '#1976D2', '#388E3C', '#7B1FA2', '#F57C00',
    '#D32F2F', '#0097A7', '#5D4037', '#455A64',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.shift;
    _name = TextEditingController(text: s?.name ?? '');
    _code = TextEditingController(text: s?.code ?? '');
    if (s != null) {
      _type = s.type;
      _color = s.color;
      _start = _parseTime(s.startTime);
      _end = _parseTime(s.endTime);
      _breakStart = _parseTime(s.breakStart);
      _breakEnd = _parseTime(s.breakEnd);
      _selectedDeptIds.addAll(s.departments.map((d) => d.id));
    }
    _loadDepts();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay? t) =>
      t == null ? '' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _loadDepts() async {
    try {
      final list = await ApiService.instance.get<List<Department>>(
        '/departments',
        (data) => (data as List)
            .map((e) => Department.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      if (mounted) {
        setState(() {
          _allDepts = list;
          _loadingDepts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDepts = false);
    }
  }

  Future<void> _pickTime(String label, TimeOfDay? current, void Function(TimeOfDay) onPick) async {
    final t = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: label,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) onPick(t);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'code': _code.text.trim().toUpperCase(),
        'type': _type.apiName,
        if (_start != null) 'startTime': _formatTime(_start),
        if (_end != null) 'endTime': _formatTime(_end),
        if (_breakStart != null) 'breakStart': _formatTime(_breakStart),
        if (_breakEnd != null) 'breakEnd': _formatTime(_breakEnd),
        'color': _color,
        'departmentIds': _selectedDeptIds.toList(),
      };
      if (widget.shift == null) {
        await ApiService.instance.post('/shifts', (_) => null, body);
      } else {
        await ApiService.instance.put('/shifts/${widget.shift!.id}', (_) => null, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final isEdit = widget.shift != null;
    final showTime = _type.isWorkType;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? s.editShiftTitle : s.createShiftTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),

                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _name,
                        decoration: InputDecoration(labelText: s.shiftNameLabel),
                        validator: (v) => (v == null || v.trim().isEmpty) ? s.enterShiftName : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _code,
                        decoration: InputDecoration(labelText: s.shiftCodeLabel),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) => (v == null || v.trim().isEmpty) ? s.enterShiftCode : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<ShiftType>(
                    value: _type,
                    borderRadius: BorderRadius.circular(12),
                    decoration: InputDecoration(labelText: s.shiftTypeLabel),
                    items: ShiftType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                        .toList(),
                    onChanged: (t) => setState(() => _type = t!),
                  ),
                  const SizedBox(height: 16),

                  if (showTime) ...[
                    Row(children: [
                      Expanded(
                        child: _TimeTile(
                          label: s.shiftStartLabel,
                          value: _formatTime(_start),
                          onTap: () => _pickTime(s.shiftStartLabel, _start, (t) => setState(() => _start = t)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeTile(
                          label: s.shiftEndLabel,
                          value: _formatTime(_end),
                          onTap: () => _pickTime(s.shiftEndLabel, _end, (t) => setState(() => _end = t)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _TimeTile(
                          label: s.shiftBreakStartLabel,
                          value: _formatTime(_breakStart),
                          onTap: () => _pickTime(s.shiftBreakStartLabel, _breakStart, (t) => setState(() => _breakStart = t)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeTile(
                          label: s.shiftBreakEndLabel,
                          value: _formatTime(_breakEnd),
                          onTap: () => _pickTime(s.shiftBreakEndLabel, _breakEnd, (t) => setState(() => _breakEnd = t)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    s.displayColor,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _colors.map((hex) {
                      final c = Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
                      final selected = _color == hex;
                      return GestureDetector(
                        onTap: () => setState(() => _color = hex),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: selected ? Border.all(color: Colors.black, width: 2.5) : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    s.applyToDepartments,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  if (_loadingDepts)
                    const SizedBox(
                      height: 32,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_allDepts.isEmpty)
                    Text(
                      s.noDepartments,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _allDepts.map((d) {
                        final sel = _selectedDeptIds.contains(d.id);
                        return FilterChip(
                          label: Text(d.name, style: const TextStyle(fontSize: 12)),
                          selected: sel,
                          onSelected: (v) => setState(() =>
                              v ? _selectedDeptIds.add(d.id) : _selectedDeptIds.remove(d.id)),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.pop(context, false),
                        child: Text(s.cancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isEdit ? s.save : s.createShift),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.access_time, size: 18),
          ),
          child: Text(
            value.isEmpty ? '--:--' : value,
            style: TextStyle(
              color: value.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary,
            ),
          ),
        ),
      );
}
