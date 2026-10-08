import 'package:bosskin/l10n/app_localizations.dart';

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
