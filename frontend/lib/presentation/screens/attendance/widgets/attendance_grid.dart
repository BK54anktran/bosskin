import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../attendance_shared.dart';

/// Frozen-column attendance grid.
///
/// One [SingleChildScrollView] per row (horizontal, NeverScrollable) + one
/// scrollable header. All share the same [hScrollController] so Flutter keeps
/// them in sync without any listener/setState overhead on vertical scroll.
class AttendanceGrid extends StatelessWidget {
  final String fixedColumnHeader;
  final double fixedColumnWidth;
  final List<String> columnHeaders;
  final List<double> columnWidths;
  final int rowCount;
  final double Function(int index) rowHeightAt;
  final bool Function(int index) isWeekend;
  final bool Function(int index) isToday;
  final bool selectionMode;
  final bool Function(int index) isSelected;
  final bool? allSelected;
  final VoidCallback? onToggleSelectAll;
  final void Function(int index)? onToggleSelect;
  final double checkboxWidth;
  final Widget Function(int index, double width, Color bg, bool selected) fixedCellBuilder;
  final List<Widget> Function(int index, List<double> widths, Color bg, bool selected) dataCellsBuilder;
  final Widget Function(int index, double height, Color bg)? checkboxCellBuilder;
  final ScrollController hScrollController;
  final ScrollController vScrollController;

  const AttendanceGrid({
    super.key,
    required this.fixedColumnHeader,
    required this.fixedColumnWidth,
    required this.columnHeaders,
    required this.columnWidths,
    required this.rowCount,
    required this.rowHeightAt,
    required this.isWeekend,
    required this.isToday,
    required this.fixedCellBuilder,
    required this.dataCellsBuilder,
    required this.hScrollController,
    required this.vScrollController,
    this.selectionMode = false,
    this.isSelected = _defaultFalse,
    this.allSelected,
    this.onToggleSelectAll,
    this.onToggleSelect,
    this.checkboxWidth = 40.0,
    this.checkboxCellBuilder,
  });

  static bool _defaultFalse(int _) => false;

  Color _rowBg(int i) {
    if (isSelected(i)) return AppTheme.primary.withValues(alpha: 0.08);
    if (isWeekend(i)) return const Color(0xFFFFF3E0);
    if (isToday(i)) return const Color(0xFFE3F2FD);
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final scrollWidth = columnWidths.fold(0.0, (s, w) => s + w);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────────────────
        Row(children: [
          if (selectionMode)
            _CheckboxHeader(
              width: checkboxWidth,
              value: allSelected,
              onChanged: onToggleSelectAll,
            ),
          _HeadCell(
            label: fixedColumnHeader,
            width: fixedColumnWidth,
            isFirst: !selectionMode,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: hScrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: scrollWidth,
                child: Row(
                  children: List.generate(
                    columnHeaders.length,
                    (i) => _HeadCell(label: columnHeaders[i], width: columnWidths[i]),
                  ),
                ),
              ),
            ),
          ),
        ]),
        // ── Rows ──────────────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: vScrollController,
            physics: const ClampingScrollPhysics(),
            itemCount: rowCount,
            itemBuilder: (_, i) {
              final height = rowHeightAt(i);
              final selected = isSelected(i);
              final bg = _rowBg(i);
              return SizedBox(
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selectionMode)
                      checkboxCellBuilder != null
                          ? checkboxCellBuilder!(i, height, bg)
                          : _DefaultCheckboxCell(
                              width: checkboxWidth,
                              height: height,
                              bg: bg,
                              checked: selected,
                              onTap: () => onToggleSelect?.call(i),
                            ),
                    fixedCellBuilder(i, fixedColumnWidth, bg, selected),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: hScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: scrollWidth,
                          child: Row(
                            children: dataCellsBuilder(i, columnWidths, bg, selected),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

class _HeadCell extends StatelessWidget {
  final String label;
  final double width;
  final bool isFirst;

  const _HeadCell({required this.label, required this.width, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: attHeadHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(
          bottom: const BorderSide(color: attGridLine, width: 1.1),
          right: const BorderSide(color: attGridLine, width: 0.8),
          left: isFirst ? const BorderSide(color: attGridLine, width: 0.8) : BorderSide.none,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        textAlign: TextAlign.center,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CheckboxHeader extends StatelessWidget {
  final double width;
  final bool? value;
  final VoidCallback? onChanged;

  const _CheckboxHeader({required this.width, this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged,
      child: Container(
        width: width,
        height: attHeadHeight,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F5),
          border: Border(
            bottom: BorderSide(color: attGridLine, width: 1.1),
            right: BorderSide(color: attGridLine, width: 0.8),
          ),
        ),
        child: IgnorePointer(
          child: Checkbox(
            tristate: true,
            value: value,
            onChanged: (_) {},
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

class _DefaultCheckboxCell extends StatelessWidget {
  final double width, height;
  final Color bg;
  final bool checked;
  final VoidCallback? onTap;

  const _DefaultCheckboxCell({
    required this.width,
    required this.height,
    required this.bg,
    required this.checked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          border: const Border(
            bottom: BorderSide(color: attGridLineLight, width: 0.9),
            right: BorderSide(color: attGridLine, width: 0.8),
          ),
        ),
        child: Checkbox(
          value: checked,
          onChanged: (_) => onTap?.call(),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
