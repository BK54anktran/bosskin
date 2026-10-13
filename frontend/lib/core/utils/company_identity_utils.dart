/// V22 — định danh theo công ty: đuôi email bắt buộc của tài khoản, mã công ty là tiền tố mã NV.
/// Cùng quy tắc với backend `core/CompanyIdentity`.
library;

final _domainPattern = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$');
final _codePattern = RegExp(r'^[A-Z][A-Z0-9]{1,11}$');

/// Chuẩn hoá đuôi email: bỏ khoảng trắng, "@" đầu, chữ thường. Trống → ''.
String normalizeEmailDomain(String raw) {
  var d = raw.trim().toLowerCase();
  while (d.startsWith('@')) {
    d = d.substring(1);
  }
  return d;
}

bool isValidEmailDomain(String domain) => domain.length <= 100 && _domainPattern.hasMatch(domain);

bool isValidCompanyCode(String code) => _codePattern.hasMatch(code.trim().toUpperCase());

/// Email có đúng đuôi `@domain` không (công ty chưa đặt đuôi → luôn đúng).
bool emailMatchesDomain(String? domain, String email) {
  if (domain == null || domain.isEmpty) return true;
  return email.trim().toLowerCase().endsWith('@${domain.toLowerCase()}');
}

final _localPartPattern = RegExp(r'^[^\s@]+$');

/// Email đăng nhập hợp lệ cho công ty: đúng một "@", phần trước "@" không rỗng / không khoảng trắng,
/// và theo đuôi công ty (nếu công ty đã đặt đuôi).
bool isValidCompanyEmail(String? domain, String email) {
  final e = email.trim();
  final at = e.indexOf('@');
  if (at <= 0 || at != e.lastIndexOf('@') || !_localPartPattern.hasMatch(e.substring(0, at))) return false;
  if (domain == null || domain.isEmpty) return e.substring(at + 1).contains('.');
  return emailMatchesDomain(domain, e);
}
