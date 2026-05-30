import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Thanh phân trang chuẩn: Rows/page + X–Y / total + < page/total >.
class PaginationBar extends StatelessWidget {
  final int total;
  final int page;
  final int pageSize;
  final void Function(int) onPageSizeChanged;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const PaginationBar({
    super.key,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.onPageSizeChanged,
    required this.onPrev,
    required this.onNext,
  });

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final first = total == 0 ? 0 : page * pageSize + 1;
    final last = ((page + 1) * pageSize).clamp(0, total);

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F4F7),
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Text('${s.rowsPerPage}:',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(width: 6),
        PopupMenuButton<int>(
          initialValue: pageSize,
          onSelected: onPageSizeChanged,
          tooltip: '',
          position: PopupMenuPosition.over,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$pageSize',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 16),
            ]),
          ),
          itemBuilder: (_) => [10, 20, 50, 100]
              .map((n) => PopupMenuItem(
                    value: n,
                    height: 36,
                    child: Text('$n', style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
        ),
        const Spacer(),
        Text('$first–$last / $total',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 18),
          onPressed: onPrev,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: s.previousPage,
        ),
        Text('${page + 1} / $totalPages',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 18),
          onPressed: onNext,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: s.nextPage,
        ),
      ]),
    );
  }
}
