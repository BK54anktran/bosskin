import 'package:intl/intl.dart';

import '../../data/services/auth_service.dart';
import 'text_utils.dart' show moneyLocale;

/// V32: tiền tệ và múi giờ theo công ty. Bảng tiền tệ phải khớp `core/CompanyCurrency.java`.
class CurrencyInfo {
  final String code;
  final String symbol;
  final int decimals;
  const CurrencyInfo(this.code, this.symbol, this.decimals);
}

const companyCurrencies = <CurrencyInfo>[
  CurrencyInfo('VND', '₫', 0),
  CurrencyInfo('USD', r'$', 2),
  CurrencyInfo('EUR', '€', 2),
  CurrencyInfo('GBP', '£', 2),
  CurrencyInfo('JPY', '¥', 0),
  CurrencyInfo('CNY', '¥', 2),
  CurrencyInfo('KRW', '₩', 0),
  CurrencyInfo('THB', '\u0e3f', 2),
  CurrencyInfo('SGD', r'S$', 2),
  CurrencyInfo('MYR', 'RM', 2),
  CurrencyInfo('IDR', 'Rp', 0),
  CurrencyInfo('PHP', '₱', 2),
  CurrencyInfo('LAK', '₭', 0),
  CurrencyInfo('KHR', '\u17db', 0),
  CurrencyInfo('AUD', r'A$', 2),
];

CurrencyInfo currencyInfoOf(String? code) =>
    companyCurrencies.firstWhere((c) => c.code == code, orElse: () => companyCurrencies.first);

/// Tiền tệ của công ty đang đăng nhập (mặc định VND).
CurrencyInfo get companyCurrency => currencyInfoOf(AuthService.instance.currentUser?.companyCurrency);

String currencySymbol() => companyCurrency.symbol;

int currencyDecimals() => companyCurrency.decimals;

/// Hậu tố sau số tiền ở danh sách / thẻ: VND giữ "đ" như cũ, tiền tệ khác dùng ký hiệu của nó.
String currencySuffix() => companyCurrency.code == 'VND' ? '\u0111' : companyCurrency.symbol;

/// `NumberFormat` số tiền không ký hiệu: VND `12.000.000`, USD `12,000.50` (theo ngôn ngữ app).
NumberFormat moneyAmountFormat() =>
    NumberFormat(currencyDecimals() == 0 ? '#,###' : '#,##0.00', moneyLocale());

/// Số tiền kèm ký hiệu tiền tệ công ty.
NumberFormat moneyCurrencyFormat() =>
    NumberFormat.currency(locale: moneyLocale(), symbol: currencySymbol(), decimalDigits: currencyDecimals());

/// Số tiền rút gọn (Tr / M…) kèm ký hiệu; [symbol] = false để chỉ lấy số.
NumberFormat moneyCompactFormat({bool symbol = true}) => NumberFormat.compactCurrency(
    locale: moneyLocale(), symbol: symbol ? currencySymbol() : '', decimalDigits: currencyDecimals() == 0 ? 0 : 1);

/// "Bây giờ" theo múi giờ công ty (ngày giờ địa phương của công ty, không phải của điện thoại). Dùng cho ngày công, hôm nay, tháng hiện tại.
DateTime companyNow() {
  final off = AuthService.instance.currentUser?.companyUtcOffsetMinutes;
  if (off == null) return DateTime.now();
  final t = DateTime.now().toUtc().add(Duration(minutes: off));
  // Giữ dạng "ngày giờ không múi giờ" để so sánh / hiển thị như giờ địa phương công ty
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond);
}

DateTime companyToday() {
  final n = companyNow();
  return DateTime(n.year, n.month, n.day);
}
