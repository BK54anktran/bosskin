import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/work_shift.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/department_service.dart';
import '../../widgets/department_picker_field.dart';

class ShiftFormDialog extends StatefulWidget {
  final WorkShift? shift;
  final List<String> existingGroups;
  const ShiftFormDialog({this.shift, this.existingGroups = const [], super.key});

  @override
  State<ShiftFormDialog> createState() => _ShiftFormDialogState();
}

class _ShiftFormDialogState extends State<ShiftFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _group;
  TimeOfDay? _start;
  TimeOfDay? _end;
  TimeOfDay? _breakStart;
  TimeOfDay? _breakEnd;
  String _color = '#1976D2';
  bool _flexible = false;
  late final TextEditingController _requiredHours;
  List<DepartmentFlat> _allDepts = [];
  final Set<int> _selectedDeptIds = {};
  bool _saving = false;
  bool _loadingDepts = true;

  static const _colors = [
    '#1976D2', '#1565C0', '#0288D1', '#00838F',
    '#388E3C', '#558B2F', '#F57C00', '#E65100',
    '#7B1FA2', '#AD1457', '#D32F2F', '#B71C1C',
    '#0097A7', '#00695C', '#5D4037', '#455A64',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.shift;
    _name = TextEditingController(text: s?.name ?? '');
    _code = TextEditingController(text: s?.code ?? '');
    _group = TextEditingController(text: s?.groupName ?? '');
    _flexible = s?.isFlexible ?? false;
    _requiredHours = TextEditingController(
        text: s?.requiredMinutes != null ? _hoursText(s!.requiredMinutes!) : '8');
    if (s != null) {
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
    _group.dispose();
    _requiredHours.dispose();
    super.dispose();
  }

  static String _hoursText(int minutes) {
    final h = minutes / 60;
    return h == h.roundToDouble() ? h.toStringAsFixed(0) : h.toStringAsFixed(1);
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
      final list = await DepartmentService.instance.getFlat();
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

  Future<void> _pickCustomColor(AppLocalizations s) async {
    Color current = Color(
        int.parse(_color.replaceFirst('#', 'FF'), radix: 16));
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        Color picking = current;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text(s.displayColor),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: picking,
                onColorChanged: (c) => setS(() => picking = c),
                enableAlpha: false,
                labelTypes: const [],
                pickerAreaHeightPercent: 0.7,
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(s.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, picking),
                  child: Text(s.apply)),
            ],
          ),
        );
      },
    );
    if (result != null) {
      final r = (result.r * 255).round();
      final g = (result.g * 255).round();
      final b = (result.b * 255).round();
      final hex = '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
      setState(() => _color = hex);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'code': _code.text.trim().toUpperCase(),
        if (_start != null) 'startTime': _formatTime(_start),
        if (_end != null) 'endTime': _formatTime(_end),
        if (_breakStart != null) 'breakStart': _formatTime(_breakStart),
        if (_breakEnd != null) 'breakEnd': _formatTime(_breakEnd),
        'color': _color,
        if (_group.text.trim().isNotEmpty) 'groupName': _group.text.trim(),
        'departmentIds': _selectedDeptIds.toList(),
        'shiftType': _flexible ? 'FLEXIBLE' : 'FIXED',
        if (_flexible)
          'requiredMinutes':
              ((double.tryParse(_requiredHours.text.replaceAll(',', '.')) ?? 0) * 60).round(),
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
    final s = AppLocalizations.of(context);
    final isEdit = widget.shift != null;

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
                  const SizedBox(height: 12),

                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _group.text),
                    optionsBuilder: (v) {
                      final q = v.text.trim().toLowerCase();
                      if (q.isEmpty) return widget.existingGroups;
                      return widget.existingGroups
                          .where((g) => g.toLowerCase().contains(q));
                    },
                    onSelected: (val) {
                      _group.text = val;
                    },
                    fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                      // keep _group in sync with autocomplete's internal controller
                      ctrl.text = _group.text;
                      ctrl.addListener(() => _group.text = ctrl.text);
                      return TextFormField(
                        controller: ctrl,
                        focusNode: focus,
                        decoration: InputDecoration(
                          labelText: s.shiftGroup,
                          hintText: s.shiftGroupHint,
                          hintStyle: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                    optionsViewBuilder: (ctx, onSelected, options) =>
                        Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 160),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (_, i) {
                                  final opt = options.elementAt(i);
                                  return ListTile(
                                    dense: true,
                                    title: Text(opt,
                                        style: const TextStyle(fontSize: 13)),
                                    onTap: () => onSelected(opt),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 16),

                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text(s.shiftTypeFixed), icon: const Icon(Icons.schedule, size: 16)),
                      ButtonSegment(value: true, label: Text(s.shiftTypeFlexible), icon: const Icon(Icons.timelapse, size: 16)),
                    ],
                    selected: {_flexible},
                    onSelectionChanged: (v) => setState(() => _flexible = v.first),
                  ),
                  if (_flexible) ...[
                    const SizedBox(height: 8),
                    Text(s.shiftFlexibleHint,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _requiredHours,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: s.shiftRequiredHoursLabel,
                        suffixText: s.hourSuffix,
                      ),
                      validator: (v) {
                        if (!_flexible) return null;
                        final h = double.tryParse((v ?? '').replaceAll(',', '.'));
                        return (h == null || h <= 0 || h > 24) ? s.shiftRequiredHoursInvalid : null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (true) ...[
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
                    runSpacing: 8,
                    children: [
                      ..._colors.map((hex) {
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
                      }),
                      // Custom color swatch (shown when _color is not in preset list)
                      if (!_colors.contains(_color)) ...[
                        GestureDetector(
                          onTap: () => _pickCustomColor(s),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(int.parse(_color.replaceFirst('#', 'FF'), radix: 16)),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2.5),
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                      // "+" button to enter custom hex
                      GestureDetector(
                        onTap: () => _pickCustomColor(s),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.border, width: 1.5),
                          ),
                          child: const Icon(Icons.add, size: 16, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_loadingDepts)
                    const SizedBox(
                      height: 32,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    DepartmentMultiPickerField(
                      departments: _allDepts,
                      values: _selectedDeptIds,
                      label: s.applyToDepartments,
                      onChanged: (v) => setState(() {
                        _selectedDeptIds
                          ..clear()
                          ..addAll(v);
                      }),
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
