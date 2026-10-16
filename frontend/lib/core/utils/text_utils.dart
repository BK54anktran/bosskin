import 'package:bosskin/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../localization/language_service.dart';

/// Trả về chuỗi kỳ lương: "25/04 – 24/05/2026" nếu có period, fallback "Tháng 5/2026"
String formatPayrollPeriod(AppLocalizations s, DateTime? from, DateTime? to, int month, int year) {
  if (from != null && to != null) {
    String d(DateTime dt) =>
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    return '${d(from)} – ${d(to)}/${to.year}';
  }
  return s.adminStatsMonth(month, year);
}

String foldSearchText(String input) {
  const withDiacritics =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
  const ascii =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

  var out = input;
  for (var i = 0; i < withDiacritics.length; i++) {
    out = out.replaceAll(withDiacritics[i], ascii[i]);
  }
  return out.toLowerCase().trim();
}

/// Số ngày công gọn: 22 → "22", 23.5 → "23.5" (công chuẩn có thể lẻ nửa ngày).
String formatDays(num v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// Ngôn ngữ định dạng số tiền theo ngôn ngữ app: vi → 12.000.000, en → 12,000,000 (luôn giữ ký hiệu đồng).
String moneyLocale() => LanguageService.instance.isEnglish ? 'en_US' : 'vi_VN';

NumberFormat moneyNumberFormat([String pattern = '#,###']) => NumberFormat(pattern, moneyLocale());

NumberFormat get _moneyFmt => moneyNumberFormat();

/// Số tiền có phân cách nghìn: 12000000 → "12.000.000"; null → "—".
String formatMoney(num? v) => v == null ? '—' : _moneyFmt.format(v);
