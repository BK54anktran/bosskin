import 'package:bosskin/core/utils/company_feature_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Set<String> all() => {for (final f in companyFeatureCatalog) f.code};

  test('bật tính năng con tự bật tính năng nó cần', () {
    final m = <String>{};
    toggleCompanyFeature(m, 'PAY_DEPENDENT', true);
    expect(m, {'PAY_DEPENDENT', 'PAY_TAX_INS', 'PAY_BASIC'});
  });

  test('tắt tính năng gốc tắt luôn mọi tính năng cần nó', () {
    final m = all();
    toggleCompanyFeature(m, 'PAY_BASIC', false);
    expect(m.where((c) => c.startsWith('PAY_')), isEmpty);
    expect(m.contains('RPT_PAYROLL'), isFalse);
    expect(m.contains('RPT_INSURANCE'), isFalse);
    expect(m.contains('RPT_OVERVIEW'), isTrue);
  });

  test('tắt Ca làm cơ bản: tự chấm công còn được nếu bật chấm không ca, nếu không thì tắt theo', () {
    final a = all();
    toggleCompanyFeature(a, 'SHIFT_BASIC', false);
    expect(a.contains('ATT_SELF'), isTrue); // còn ATT_NOSHIFT

    final b = all()..remove('ATT_NOSHIFT');
    toggleCompanyFeature(b, 'SHIFT_BASIC', false);
    expect(b.contains('ATT_SELF'), isFalse);
    expect(b.contains('ATT_SHEET'), isTrue);
  });

  test('danh mục: mã duy nhất, mọi tính năng cần đều có và đứng trước, mọi nhóm có mục', () {
    final seen = <String>{};
    for (final f in companyFeatureCatalog) {
      expect(seen.add(f.code), isTrue, reason: 'trùng ${f.code}');
      for (final n in f.requires) {
        expect(seen.contains(n), isTrue, reason: '${f.code} cần $n đứng trước');
      }
      expect(companyFeatureGroups.contains(f.group), isTrue);
    }
    for (final g in companyFeatureGroups) {
      expect(companyFeaturesOfGroup(g), isNotEmpty);
    }
  });
}
