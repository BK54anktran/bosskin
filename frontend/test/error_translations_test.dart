import 'dart:io';

import 'package:bosskin/core/utils/error_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mọi mã lỗi backend ném ra ("error.module.reason") phải có bản dịch vi + en (CLAUDE.md, quy tắc đa ngôn ngữ).
void main() {
  test('mã lỗi backend đều có bản dịch vi và en', () {
    final root = Directory('../backend/src/main/java');
    if (!root.existsSync()) {
      markTestSkipped('không có mã backend cạnh frontend');
      return;
    }
    final re = RegExp(r'"(error\.[a-z0-9_]+(?:\.[a-z0-9_]+)+)(?=[|"])');
    const examples = {'error.x.y'}; // ví dụ trong chú thích
    final keys = <String>{};
    for (final f in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.java'))) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        keys.add(m.group(1)!);
      }
    }
    keys.removeAll(examples);
    expect(keys.length, greaterThan(100));
    final missingVi = keys.where((k) => debugLookupServerKey(k, english: false) == null).toList()..sort();
    final missingEn = keys.where((k) => debugLookupServerKey(k, english: true) == null).toList()..sort();
    expect(missingVi, isEmpty, reason: 'thiếu bản dịch tiếng Việt');
    expect(missingEn, isEmpty, reason: 'thiếu bản dịch tiếng Anh');
  });
}
