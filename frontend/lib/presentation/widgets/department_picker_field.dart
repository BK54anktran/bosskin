import 'package:flutter/material.dart';

import '../../data/models/department_model.dart';
import '../../l10n/app_localizations.dart';

class DepartmentPickerField extends StatelessWidget {
  final List<DepartmentFlat> departments;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String label;
  final bool allowAll;
  final String? allLabel;
  final bool compact;

  const DepartmentPickerField({
    super.key,
    required this.departments,
    required this.value,
    required this.onChanged,
    required this.label,
    this.allowAll = false,
    this.allLabel,
    this.compact = false,
  });

  String _selectedText(AppLocalizations s) {
    if (value == null) return allLabel ?? s.all;
    final matches = departments.where((e) => e.id == value);
    if (matches.isEmpty) return '-';
    final d = matches.first;
    return '${d.name} (${d.code})';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final selected = await showDialog<int?>(
          context: context,
          builder: (_) => _DepartmentPickerDialog(
            departments: departments,
            selected: value,
            allowAll: allowAll,
            allLabel: allLabel ?? s.all,
          ),
        );
        if (selected != null || allowAll) onChanged(selected);
      },
      child: compact
          ? IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160),
                child: InputDecorator(
                isEmpty: false,
                decoration: InputDecoration(
                  labelText: label,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedText(s),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
              ),
            )
          : InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedText(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
    );
  }
}

class _DepartmentPickerDialog extends StatefulWidget {
  final List<DepartmentFlat> departments;
  final int? selected;
  final bool allowAll;
  final String allLabel;

  const _DepartmentPickerDialog({
    required this.departments,
    required this.selected,
    required this.allowAll,
    required this.allLabel,
  });

  @override
  State<_DepartmentPickerDialog> createState() =>
      _DepartmentPickerDialogState();
}

class _DepartmentPickerDialogState extends State<_DepartmentPickerDialog> {
  late int? _selected;
  late Map<int?, List<DepartmentFlat>> _byParent;
  late Set<int> _expanded;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _byParent = {};
    for (final d in widget.departments) {
      _byParent.putIfAbsent(d.parentId, () => []).add(d);
    }
    for (final list in _byParent.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    _expanded = widget.departments.map((d) => d.id).toSet();
  }

  List<DepartmentFlat> _visible() {
    final result = <DepartmentFlat>[];
    void walk(int? p) {
      final children = _byParent[p] ?? const <DepartmentFlat>[];
      for (final d in children) {
        result.add(d);
        if (_expanded.contains(d.id)) walk(d.id);
      }
    }

    walk(null);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible();
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.department),
      content: SizedBox(
        width: 460,
        height: 420,
        child: ListView(
          children: [
            if (widget.allowAll)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () => Navigator.pop(context, null),
                title: Text(widget.allLabel),
              ),
            ...visible.map((d) {
              final hasChild =
                  (_byParent[d.id] ?? const <DepartmentFlat>[]).isNotEmpty;
              final isExpanded = _expanded.contains(d.id);
              final isSelected = _selected == d.id;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                selected: isSelected,
                selectedTileColor:
                    theme.colorScheme.primary.withValues(alpha: 0.10),
                onTap: () => Navigator.pop(context, d.id),
                title: Row(
                  children: [
                    SizedBox(width: d.level * 18.0),
                    SizedBox(
                      width: 18,
                      child: hasChild
                          ? InkWell(
                              onTap: () => setState(() {
                                if (isExpanded) {
                                  _expanded.remove(d.id);
                                } else {
                                  _expanded.add(d.id);
                                }
                              }),
                              child: Text(
                                isExpanded ? '-' : '+',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.grey[800],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 6),
                    if (d.level > 0) ...[
                      Icon(Icons.subdirectory_arrow_right,
                          size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        '${d.name} (${d.code})',
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
