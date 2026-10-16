import 'dart:ui' show Locale;

import 'package:bosskin/l10n/app_localizations.dart';

import '../localization/language_service.dart';

/// Tên / mô tả mặc định do hệ thống tạo sẵn cho công ty (vai trò, loại tài liệu) hiển thị theo ngôn ngữ app đang dùng,
/// kể cả công ty tạo từ trước bằng ngôn ngữ khác. Chỉ đổi khi chữ còn đúng bản mặc định; tên người dùng đã sửa giữ nguyên.
/// Chữ lấy từ l10n (`default*` trong app_vi / app_en.arb) — khớp `default.*` trong `messages_*.properties` ở backend.
List<(String vi, String en)> _pairs() {
  final vi = lookupAppLocalizations(const Locale('vi'));
  final en = lookupAppLocalizations(const Locale('en'));
  return [
    (vi.defaultRoleEmployeeDesc, en.defaultRoleEmployeeDesc),
    (vi.defaultRoleAdminDesc, en.defaultRoleAdminDesc),
    (vi.defaultDocCCCD, en.defaultDocCCCD),
    (vi.defaultDocSYLL, en.defaultDocSYLL),
    (vi.defaultDocBangCap, en.defaultDocBangCap),
    (vi.defaultDocChungChi, en.defaultDocChungChi),
    (vi.defaultDocHdDaKy, en.defaultDocHdDaKy),
    (vi.defaultDocKhamSk, en.defaultDocKhamSk),
  ];
}

late final Map<String, String> _viToEn = {for (final p in _pairs()) p.$1: p.$2};
late final Map<String, String> _enToVi = {for (final p in _pairs()) p.$2: p.$1};

/// Tên vai trò mặc định "Nhân viên": chỉ dịch khi đúng là vai trò mặc định của hệ thống (cờ isDefault) — vai trò người dùng tự tạo giữ nguyên.
String localizeDefaultRoleName(String name, {required bool isDefault}) {
  if (!isDefault) return name;
  final vi = lookupAppLocalizations(const Locale('vi')).defaultRoleEmployeeName;
  final en = lookupAppLocalizations(const Locale('en')).defaultRoleEmployeeName;
  if (LanguageService.instance.isEnglish) return name == vi ? en : name;
  return name == en ? vi : name;
}

/// Dịch chữ mặc định theo ngôn ngữ app; chữ khác giữ nguyên.
String localizeDefaultText(String text) =>
    (LanguageService.instance.isEnglish ? _viToEn[text] : _enToVi[text]) ?? text;

String? localizeDefaultTextOrNull(String? text) => text == null ? null : localizeDefaultText(text);
