import '../localization/language_service.dart';

/// Tên / mô tả mặc định do hệ thống tạo sẵn cho công ty (vai trò, loại tài liệu) hiển thị theo ngôn ngữ app đang dùng,
/// kể cả công ty tạo từ trước bằng ngôn ngữ khác. Chỉ đổi khi chữ còn đúng bản mặc định; tên người dùng đã sửa giữ nguyên.
/// Khớp `messages_vi/en.properties` (`default.*`) ở backend.
const _defaultPairs = <(String vi, String en)>[
  ('Vai trò mặc định của nhân viên mới — tự chấm công, xin nghỉ phép', 'Default role for new employees — self check-in, leave requests'),
  ('Quản trị viên công ty — toàn quyền', 'Company administrator — full access'),
  ('Căn cước công dân (2 mặt)', 'National ID card (both sides)'),
  ('Sơ yếu lý lịch', 'Curriculum vitae'),
  ('Bằng cấp', 'Degrees'),
  ('Chứng chỉ', 'Certificates'),
  ('Hợp đồng / phụ lục đã ký', 'Signed contract / appendix'),
  ('Giấy khám sức khoẻ', 'Health check certificate'),
];

final _viToEn = {for (final p in _defaultPairs) p.$1: p.$2};
final _enToVi = {for (final p in _defaultPairs) p.$2: p.$1};

/// Tên vai trò mặc định "Nhân viên": chỉ dịch khi đúng là vai trò mặc định của hệ thống (cờ isDefault) — vai trò người dùng tự tạo giữ nguyên.
String localizeDefaultRoleName(String name, {required bool isDefault}) {
  if (!isDefault) return name;
  final en = LanguageService.instance.isEnglish;
  if (en && name == 'Nhân viên') return 'Employee';
  if (!en && name == 'Employee') return 'Nhân viên';
  return name;
}

/// Dịch chữ mặc định theo ngôn ngữ app; chữ khác giữ nguyên.
String localizeDefaultText(String text) =>
    (LanguageService.instance.isEnglish ? _viToEn[text] : _enToVi[text]) ?? text;

String? localizeDefaultTextOrNull(String? text) => text == null ? null : localizeDefaultText(text);
