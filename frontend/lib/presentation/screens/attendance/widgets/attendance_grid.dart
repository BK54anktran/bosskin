import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../attendance_shared.dart';

/// Lưới chấm công có cột đầu cố định.
///
/// Bên trái: ô chọn + cột cố định (cuộn dọc). Bên phải: tiêu đề cột và phần dữ liệu cuộn ngang **bằng cách vuốt ngay
/// trên bảng** (điện thoại) hoặc thanh cuộn / Shift + lăn chuột (máy tính). Hai nửa cuộn dọc cùng nhau, tiêu đề cuộn
/// ngang theo phần dữ liệu.
class AttendanceGrid extends StatefulWidget {
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

  /// Cuộn ngang của phần dữ liệu (tiêu đề đi theo).
  final ScrollController hScrollController;

  /// Cuộn dọc của phần dữ liệu (cột cố định đi theo).
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

  @override
  State<AttendanceGrid> createState() => _AttendanceGridState();
}

class _AttendanceGridState extends State<AttendanceGrid> {
  final _hHead = ScrollController();
  final _vFixed = ScrollController();
  bool _syncingV = false;

  @override
  void initState() {
    super.initState();
    widget.hScrollController.addListener(_syncHead);
    widget.vScrollController.addListener(_syncFixedFromBody);
    _vFixed.addListener(_syncBodyFromFixed);
  }

  @override
  void didUpdateWidget(AttendanceGrid old) {
    super.didUpdateWidget(old);
    if (old.hScrollController != widget.hScrollController) {
      old.hScrollController.removeListener(_syncHead);
      widget.hScrollController.addListener(_syncHead);
    }
    if (old.vScrollController != widget.vScrollController) {
      old.vScrollController.removeListener(_syncFixedFromBody);
      widget.vScrollController.addListener(_syncFixedFromBody);
    }
  }

  @override
  void dispose() {
    widget.hScrollController.removeListener(_syncHead);
    widget.vScrollController.removeListener(_syncFixedFromBody);
    _hHead.dispose();
    _vFixed.dispose();
    super.dispose();
  }

  void _syncHead() => _follow(widget.hScrollController, _hHead);

  void _syncFixedFromBody() {
    if (_syncingV) return;
    _syncingV = true;
    _follow(widget.vScrollController, _vFixed);
    _syncingV = false;
  }

  void _syncBodyFromFixed() {
    if (_syncingV) return;
    _syncingV = true;
    _follow(_vFixed, widget.vScrollController);
    _syncingV = false;
  }

  /// Đưa [to] về cùng vị trí với [from] (bỏ qua khi một bên chưa gắn vào cây).
  void _follow(ScrollController from, ScrollController to) {
    if (!from.hasClients || !to.hasClients) return;
    final target = from.position.pixels.clamp(0.0, to.position.maxScrollExtent);
    if ((to.position.pixels - target).abs() > 0.5) to.jumpTo(target);
  }

  Color _rowBg(int i) {
    if (widget.isSelected(i)) return AppTheme.primary.withValues(alpha: 0.08);
    if (widget.isWeekend(i)) return AppTheme.tint(AppTheme.warning);
    if (widget.isToday(i)) return AppTheme.tint(AppTheme.primary);
    return AppTheme.background;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final scrollWidth = w.columnWidths.fold(0.0, (s, x) => s + x);
    final fixedWidth = w.fixedColumnWidth + (w.selectionMode ? w.checkboxWidth : 0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Nửa trái: ô chọn + cột cố định ────────────────────────────────────
        SizedBox(
          width: fixedWidth,
          child: Column(children: [
            Row(children: [
              if (w.selectionMode)
                _CheckboxHeader(
                  width: w.checkboxWidth,
                  value: w.allSelected,
                  onChanged: w.onToggleSelectAll,
                ),
              _HeadCell(
                label: w.fixedColumnHeader,
                width: w.fixedColumnWidth,
                isFirst: !w.selectionMode,
              ),
            ]),
            Expanded(
              // Không hiện thanh cuộn ở nửa trái (thanh cuộn dọc nằm bên phần dữ liệu)
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView.builder(
                  controller: _vFixed,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: w.rowCount,
                  itemBuilder: (_, i) {
                    final height = w.rowHeightAt(i);
                    final selected = w.isSelected(i);
                    final bg = _rowBg(i);
                    return SizedBox(
                      height: height,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (w.selectionMode)
                            w.checkboxCellBuilder != null
                                ? w.checkboxCellBuilder!(i, height, bg)
                                : _DefaultCheckboxCell(
                                    width: w.checkboxWidth,
                                    height: height,
                                    bg: bg,
                                    checked: selected,
                                    onTap: () => w.onToggleSelect?.call(i),
                                  ),
                          w.fixedCellBuilder(i, w.fixedColumnWidth, bg, selected),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ]),
        ),
        // ── Nửa phải: tiêu đề + dữ liệu, cuộn ngang ──────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: attHeadHeight,
                child: SingleChildScrollView(
                  controller: _hHead,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: scrollWidth,
                    child: Row(
                      children: List.generate(
                        w.columnHeaders.length,
                        (i) => _HeadCell(label: w.columnHeaders[i], width: w.columnWidths[i]),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: w.hScrollController,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  // Chỉ nhận thông báo cuộn của chính khung cuộn ngang (không phải danh sách dọc bên trong)
                  notificationPredicate: (n) => n.depth == 0,
                  child: SingleChildScrollView(
                    controller: w.hScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: scrollWidth,
                      child: ListView.builder(
                        controller: w.vScrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: w.rowCount,
                        itemBuilder: (_, i) {
                          final selected = w.isSelected(i);
                          final bg = _rowBg(i);
                          return SizedBox(
                            height: w.rowHeightAt(i),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: w.dataCellsBuilder(i, w.columnWidths, bg, selected),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
        color: AppTheme.surfaceAlt,
        border: Border(
          bottom: BorderSide(color: attGridLine, width: 1.1),
          right: BorderSide(color: attGridLine, width: 0.8),
          left: isFirst ? BorderSide(color: attGridLine, width: 0.8) : BorderSide.none,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
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
          border: Border(
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
