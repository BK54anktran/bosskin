import 'package:flutter/material.dart';

/// Màu & theme của app.
///
/// Bước F — chế độ tối: màu thương hiệu / trạng thái (primary, error, warning…) giữ nguyên ở cả hai chế độ;
/// màu nền, chữ, viền là getter đổi theo [isDark]. [ThemeController] đặt [isDark] trước khi dựng lại cây widget,
/// nên các màn đọc `AppTheme.textSecondary`… nhận đúng màu (không dùng `const` với các màu này).
class AppTheme {
  /// Đang vẽ ở chế độ tối (do [ThemeController] đặt).
  static bool isDark = false;
  static bool get _dark => isDark;

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color secondary = Color(0xFF10B981);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  /// Nền trang / ô nhập.
  static Color get surface => _dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  /// Nền thẻ, hộp thoại, ô bảng (sáng: trắng).
  static Color get background => _dark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

  /// Nền xen kẽ / khối phụ (dòng lẻ của bảng, khung xám nhạt).
  static Color get surfaceAlt => _dark ? const Color(0xFF273449) : const Color(0xFFF8F9FA);

  static Color get textPrimary => _dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  static Color get textSecondary => _dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  /// Chữ mờ hơn [textSecondary] (gợi ý, nhãn phụ).
  static Color get textMuted => _dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  static Color get border => _dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  /// Nền nhạt (đục) theo một màu trạng thái, thay cho các mã màu "-50" cố định; đọc được ở cả hai chế độ.
  /// Trộn sẵn với [background] nên chồng nhiều lớp (hàng + ô) không đậm thêm.
  static Color tint(Color c) => Color.alphaBlend(c.withValues(alpha: _dark ? 0.16 : 0.10), background);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDarkTheme = brightness == Brightness.dark;
    final surfaceC = isDarkTheme ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardC = isDarkTheme ? const Color(0xFF1E293B) : Colors.white;
    final textC = isDarkTheme ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final borderC = isDarkTheme ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: isDarkTheme ? cardC : surfaceC,
      error: error,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDarkTheme ? surfaceC : null,
      // fontFamily: 'Inter',  // thêm lại khi có file font trong assets/fonts/
      appBarTheme: AppBarTheme(
        backgroundColor: cardC,
        foregroundColor: textC,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          // fontFamily: 'Inter',  // thêm lại khi có file font trong assets/fonts/
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textC,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderC),
        ),
        color: cardC,
      ),
      // Điện thoại: lề hộp thoại 16 (mặc định 40) để hộp rộng thêm ~48dp, ít phải cuộn ngang / bị cắt
      dialogTheme: DialogThemeData(
          backgroundColor: cardC, insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24)),
      dividerColor: borderC,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            // fontFamily: 'Inter',  // thêm lại khi có file font trong assets/fonts/
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      canvasColor: cardC,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceC,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderC),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderC),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
