package com.bosskin.core;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.Map;

/** Tiền tệ công ty được dùng: mã ISO 4217, ký hiệu, số chữ số thập phân hiển thị (V32). Bảng này phải khớp {@code company_currency_utils.dart}. */
public final class CompanyCurrency {

    public record Info(String code, String symbol, int decimals) {}

    public static final String DEFAULT = "VND";

    private static final Map<String, Info> CATALOG = new LinkedHashMap<>();
    static {
        add("VND", "₫", 0);
        add("USD", "$", 2);
        add("EUR", "€", 2);
        add("GBP", "£", 2);
        add("JPY", "¥", 0);
        add("CNY", "¥", 2);
        add("KRW", "₩", 0);
        add("THB", "฿", 2);
        add("SGD", "S$", 2);
        add("MYR", "RM", 2);
        add("IDR", "Rp", 0);
        add("PHP", "₱", 2);
        add("LAK", "₭", 0);
        add("KHR", "៛", 0);
        add("AUD", "A$", 2);
    }

    private CompanyCurrency() {}

    private static void add(String code, String symbol, int decimals) {
        CATALOG.put(code, new Info(code, symbol, decimals));
    }

    public static Map<String, Info> catalog() { return CATALOG; }

    /** Chuẩn hoá (chữ hoa, trống = mặc định) và kiểm có trong danh mục. */
    public static String normalize(String code) {
        if (code == null || code.isBlank()) return DEFAULT;
        String c = code.trim().toUpperCase();
        if (!CATALOG.containsKey(c)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.currency_invalid|" + code);
        }
        return c;
    }
}
