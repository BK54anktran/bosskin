import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../services/api_service.dart';

// ── Meta models ───────────────────────────────────────────────────────────────

class ExcelColumnMeta {
  final String key;
  final String label;
  final String? group;
  final bool defaultVisible;
  final bool importable;
  final bool required;

  const ExcelColumnMeta({
    required this.key,
    required this.label,
    this.group,
    required this.defaultVisible,
    required this.importable,
    this.required = false,
  });

  factory ExcelColumnMeta.fromJson(Map<String, dynamic> j) => ExcelColumnMeta(
        key:            j['key'] as String,
        label:          j['label'] as String,
        group:          j['group'] as String?,
        defaultVisible: j['defaultVisible'] as bool? ?? true,
        importable:     j['importable'] as bool? ?? true,
        required:       j['required'] as bool? ?? false,
      );
}

class FilterOption {
  final String value;
  final String labelKey;
  const FilterOption({required this.value, required this.labelKey});

  factory FilterOption.fromJson(Map<String, dynamic> j) => FilterOption(
        value:    j['value'] as String,
        labelKey: j['labelKey'] as String,
      );
}

class ExcelFilterDef {
  final String key;
  final String type; // SELECT | MULTI_SELECT | TEXT | DATE | DATE_RANGE
  final String labelKey;
  final List<FilterOption> options;

  const ExcelFilterDef({
    required this.key,
    required this.type,
    required this.labelKey,
    required this.options,
  });

  factory ExcelFilterDef.fromJson(Map<String, dynamic> j) => ExcelFilterDef(
        key:      j['key'] as String,
        type:     j['type'] as String,
        labelKey: j['labelKey'] as String,
        options:  (j['options'] as List<dynamic>? ?? [])
            .map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ExcelDeptItem {
  final int id;
  final String name;
  final String code;
  final int? parentId;
  final int level;

  const ExcelDeptItem({
    required this.id,
    required this.name,
    required this.code,
    this.parentId,
    required this.level,
  });

  factory ExcelDeptItem.fromJson(Map<String, dynamic> j) => ExcelDeptItem(
        id:       (j['id'] as num).toInt(),
        name:     j['name'] as String,
        code:     j['code'] as String,
        parentId: (j['parentId'] as num?)?.toInt(),
        level:    (j['level'] as num?)?.toInt() ?? 0,
      );
}

class ExportMeta {
  final List<ExcelColumnMeta> columns;
  final List<ExcelFilterDef> filters;
  final List<ExcelDeptItem> departments;

  const ExportMeta({
    required this.columns,
    required this.filters,
    this.departments = const [],
  });

  factory ExportMeta.fromJson(Map<String, dynamic> j) => ExportMeta(
        columns: (j['columns'] as List<dynamic>)
            .map((e) => ExcelColumnMeta.fromJson(e as Map<String, dynamic>))
            .toList(),
        filters: (j['filters'] as List<dynamic>? ?? [])
            .map((e) => ExcelFilterDef.fromJson(e as Map<String, dynamic>))
            .toList(),
        departments: (j['departments'] as List<dynamic>? ?? [])
            .map((e) => ExcelDeptItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Pick item (autocomplete search result) ────────────────────────────────────

class ExcelPickItem {
  final String code;
  final String label;
  const ExcelPickItem({required this.code, required this.label});

  factory ExcelPickItem.fromJson(Map<String, dynamic> j) => ExcelPickItem(
        code:  j['code']  as String,
        label: j['label'] as String,
      );
}

// ── Import diff / result ──────────────────────────────────────────────────────

class UniversalImportDiff {
  final int rowNum;
  final String action;
  final String identifier;
  final String? summary;
  final String? error;

  const UniversalImportDiff({
    required this.rowNum,
    required this.action,
    required this.identifier,
    this.summary,
    this.error,
  });

  bool get isWarn  => action == 'WARN';
  bool get isError => error != null && error!.isNotEmpty && action != 'WARN';

  factory UniversalImportDiff.fromJson(Map<String, dynamic> j) {
    final rawError = j['error'];
    final String? errorStr = (rawError is String && rawError.isNotEmpty)
        ? rawError
        : null;
    return UniversalImportDiff(
      rowNum:     (j['rowNum'] as num?)?.toInt() ?? 0,
      action:     j['action'] as String? ?? '',
      identifier: j['identifier'] as String? ?? '',
      summary:    j['summary'] as String?,
      error:      errorStr,
    );
  }
}

class UniversalImportResult {
  final Uint8List resultBytes;
  final String filename;
  final int ok;
  final int error;
  final int skip;

  const UniversalImportResult({
    required this.resultBytes,
    required this.filename,
    required this.ok,
    required this.error,
    required this.skip,
  });
}

// ── History ───────────────────────────────────────────────────────────────────

class ExcelHistoryEntry {
  final int id;
  final String type;   // EXPORT | IMPORT | REPORT
  final String module; // universal | payroll | attendance | shift
  final String filename;
  final String? fileUrl;
  final int? okCount;
  final int? errorCount;
  final int? skipCount;
  final DateTime createdAt;
  final String? performedBy;

  const ExcelHistoryEntry({
    required this.id,
    required this.type,
    required this.module,
    required this.filename,
    this.fileUrl,
    this.okCount,
    this.errorCount,
    this.skipCount,
    required this.createdAt,
    this.performedBy,
  });

  factory ExcelHistoryEntry.fromJson(Map<String, dynamic> j) => ExcelHistoryEntry(
        id:          (j['id'] as num).toInt(),
        type:        j['type'] as String,
        module:      j['module'] as String? ?? 'universal',
        filename:    j['filename'] as String,
        fileUrl:     j['fileUrl'] as String?,
        okCount:     (j['okCount'] as num?)?.toInt(),
        errorCount:  (j['errorCount'] as num?)?.toInt(),
        skipCount:   (j['skipCount'] as num?)?.toInt(),
        createdAt:   DateTime.parse(j['createdAt'] as String),
        performedBy: j['performedBy'] as String?,
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class UniversalExcelRepository {
  final _api = ApiService.instance;

  /// Tìm kiếm gợi ý để pick khi filter export.
  Future<List<ExcelPickItem>> searchForPick(String module, String q) async {
    final res = await _api.dio.get<List<dynamic>>(
      '/excel/search',
      queryParameters: {'module': module, 'q': q},
    );
    return (res.data ?? [])
        .map((e) => ExcelPickItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lấy metadata cột + filter definitions cho từng module.
  Future<Map<String, ExportMeta>> getMeta() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/excel/meta');
    return (res.data ?? {}).map((key, value) =>
        MapEntry(key, ExportMeta.fromJson(value as Map<String, dynamic>)));
  }

  /// Export ra 1 file Excel với cột và filter tuỳ chọn.
  Future<({Uint8List bytes, String filename})> exportAll({
    List<String>? types,
    Map<String, List<String>>? selectedColumns,
    Map<String, Map<String, String>>? filters,
  }) async {
    final body = <String, dynamic>{};
    if (types != null && types.isNotEmpty) body['types'] = types;
    if (selectedColumns != null) body['selectedColumns'] = selectedColumns;
    if (filters != null && filters.isNotEmpty) body['filters'] = filters;

    final res = await _api.dio.post<List<int>>(
      '/excel/export',
      data: body.isEmpty ? null : body,
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r"filename\*?=(?:UTF-8'')?([^;]+)").firstMatch(disposition);
    final filename = Uri.decodeComponent(
        match?.group(1)?.trim().replaceAll('"', '') ?? 'du-lieu-he-thong.xlsx');
    return (bytes: Uint8List.fromList(res.data ?? const <int>[]), filename: filename);
  }

  /// Preview import — không ghi DB.
  Future<Map<String, List<UniversalImportDiff>>> previewImport(
    Uint8List bytes,
    String filename,
  ) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/excel/preview-import',
      data: form,
    );
    final data = res.data ?? {};
    return data.map((key, value) {
      final list = (value as List<dynamic>)
          .map((e) => UniversalImportDiff.fromJson(e as Map<String, dynamic>))
          .toList();
      return MapEntry(key, list);
    });
  }

  Future<({List<ExcelHistoryEntry> items, int total})> getHistoryPaged({
    String? type,
    String? module,
    String? dateFrom,
    String? dateTo,
    int page = 0,
    int size = 10,
  }) async {
    final res = await _api.dio.get<Map<String, dynamic>>('/excel/history',
        queryParameters: {
          if (type != null && type.isNotEmpty) 'type': type,
          if (module != null && module.isNotEmpty) 'module': module,
          if (dateFrom != null) 'dateFrom': dateFrom,
          if (dateTo != null) 'dateTo': dateTo,
          'page': page,
          'size': size,
        });
    final data = res.data!;
    final items = (data['items'] as List<dynamic>)
        .map((e) => ExcelHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, total: (data['total'] as num).toInt());
  }

  /// Tải lại file qua backend (tránh CORS/auth issue khi download trực tiếp S3).
  Future<Uint8List> downloadHistoryFile(int id) async {
    final res = await _api.dio.get<List<int>>(
      '/excel/history/$id/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const <int>[]);
  }

  /// Import thực sự — ghi DB, trả về file kết quả + summary.
  Future<UniversalImportResult> importAll(
    Uint8List bytes,
    String filename,
  ) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.dio.post<List<int>>(
      '/excel/import',
      data: form,
      options: Options(responseType: ResponseType.bytes),
    );

    int ok = 0, error = 0, skip = 0;
    final summary = res.headers.value('x-import-summary');
    if (summary != null) {
      ok    = int.tryParse(RegExp(r'"ok"\s*:\s*(\d+)').firstMatch(summary)?.group(1) ?? '') ?? 0;
      error = int.tryParse(RegExp(r'"error"\s*:\s*(\d+)').firstMatch(summary)?.group(1) ?? '') ?? 0;
      skip  = int.tryParse(RegExp(r'"skip"\s*:\s*(\d+)').firstMatch(summary)?.group(1) ?? '') ?? 0;
    }

    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r"filename\*?=(?:UTF-8'')?([^;]+)").firstMatch(disposition);
    final resultFilename = Uri.decodeComponent(
        match?.group(1)?.trim().replaceAll('"', '') ?? 'ket-qua-import.xlsx');

    return UniversalImportResult(
      resultBytes: Uint8List.fromList(res.data ?? const <int>[]),
      filename: resultFilename,
      ok: ok,
      error: error,
      skip: skip,
    );
  }
}
