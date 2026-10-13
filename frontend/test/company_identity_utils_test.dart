import 'package:bosskin/core/utils/company_identity_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email công ty phải có dạng tên@đuôi', () {
    expect(isValidCompanyEmail('th.com', 'an.nguyen@th.com'), isTrue);
    expect(isValidCompanyEmail('th.com', ' An@TH.com '), isTrue);
    expect(isValidCompanyEmail('th.com', 'abc.abc.abc'), isFalse);
    expect(isValidCompanyEmail('th.com', '@th.com'), isFalse);
    expect(isValidCompanyEmail('th.com', 'an@khac.com'), isFalse);
    expect(isValidCompanyEmail('th.com', 'a b@th.com'), isFalse);
    expect(isValidCompanyEmail(null, 'an@khac.com'), isTrue);
    expect(isValidCompanyEmail(null, 'an@khac'), isFalse);
  });

  test('đuôi email chuẩn hoá và kiểm hợp lệ', () {
    expect(normalizeEmailDomain(' @TH.com '), 'th.com');
    expect(isValidEmailDomain('th.com'), isTrue);
    expect(isValidEmailDomain('th'), isFalse);
    expect(isValidCompanyCode('th'), isTrue);
    expect(isValidCompanyCode('1TH'), isFalse);
  });
}
