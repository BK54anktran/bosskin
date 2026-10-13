import 'dart:typed_data';

import 'package:bosskin/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../core/utils/file_saver_utils.dart';
import '../../data/services/api_service.dart';

/// Nút "Tải file mẫu" đặt cạnh "Nhập Excel": tải file mẫu nhập (GET [path], chỉ tiêu đề cột nhập + sheet Hướng dẫn)
/// do backend sinh từ chính danh sách cột nhập. Bọc trong PermissionGuard cùng quyền với nút nhập.
class ExcelTemplateButton extends StatefulWidget {
  final String path;
  final Map<String, dynamic>? query;
  final bool compact;

  const ExcelTemplateButton({super.key, required this.path, this.query, this.compact = false});

  @override
  State<ExcelTemplateButton> createState() => _ExcelTemplateButtonState();
}

class _ExcelTemplateButtonState extends State<ExcelTemplateButton> {
  bool _isLoading = false;

  Future<void> _download() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.instance.dio.get<List<int>>(
        widget.path,
        queryParameters: widget.query,
        options: Options(responseType: ResponseType.bytes),
      );
      await saveFileToDevice(Uint8List.fromList(res.data ?? const <int>[]),
          filenameFromDisposition(res.headers.value('content-disposition'), 'template.xlsx'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final icon = _isLoading
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.description_outlined, size: 18);
    if (widget.compact) {
      return IconButton(
        tooltip: s.excelDownloadTemplateHint,
        icon: icon,
        onPressed: _isLoading ? null : _download,
      );
    }
    return Tooltip(
      message: s.excelDownloadTemplateHint,
      child: OutlinedButton.icon(
        icon: icon,
        label: Text(s.excelDownloadTemplate),
        onPressed: _isLoading ? null : _download,
      ),
    );
  }
}

/// Tên file từ Content-Disposition: ưu tiên `filename*=UTF-8''…` (có dấu), rồi `filename="…"`.
String filenameFromDisposition(String? disposition, String fallback) {
  final d = disposition ?? '';
  final star = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false).firstMatch(d);
  if (star != null) return Uri.decodeComponent(star.group(1)!.trim());
  final plain = RegExp(r'filename="([^"]+)"').firstMatch(d);
  return plain?.group(1) ?? fallback;
}
