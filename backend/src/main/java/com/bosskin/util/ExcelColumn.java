package com.bosskin.util;

import java.util.function.BiConsumer;
import java.util.function.Function;

/**
 * Mô tả một cột Excel.
 *
 * <p>Có hai chế độ:
 * <ul>
 *   <li>i18n: dùng {@code headerKey} (key trong excel_*.properties) — header text được resolve
 *       theo locale khi export; import nhận bất kỳ ngôn ngữ nào.</li>
 *   <li>literal: dùng {@code header} (string cứng) — giữ backward-compat, không i18n.</li>
 * </ul>
 */
public class ExcelColumn<T> {

    private final String header;      // literal header (null nếu dùng i18n)
    private final String headerKey;   // i18n key (null nếu dùng literal)
    private final Function<T, Object> getter;
    private final BiConsumer<T, String> setter;

    private ExcelColumn(String header, String headerKey,
                        Function<T, Object> getter, BiConsumer<T, String> setter) {
        this.header    = header;
        this.headerKey = headerKey;
        this.getter    = getter;
        this.setter    = setter;
    }

    // ── Literal (backward-compat) ─────────────────────────────────────────────

    public static <T> ExcelColumn<T> readOnly(String header, Function<T, Object> getter) {
        return new ExcelColumn<>(header, null, getter, null);
    }

    public static <T> ExcelColumn<T> of(String header,
                                        Function<T, Object> getter,
                                        BiConsumer<T, String> setter) {
        return new ExcelColumn<>(header, null, getter, setter);
    }

    // ── i18n ─────────────────────────────────────────────────────────────────

    public static <T> ExcelColumn<T> readOnlyI18n(String headerKey, Function<T, Object> getter) {
        return new ExcelColumn<>(null, headerKey, getter, null);
    }

    public static <T> ExcelColumn<T> ofI18n(String headerKey,
                                             Function<T, Object> getter,
                                             BiConsumer<T, String> setter) {
        return new ExcelColumn<>(null, headerKey, getter, setter);
    }

    // ── Accessors ─────────────────────────────────────────────────────────────

    /** Trả về header string cứng (null nếu đây là cột i18n). */
    public String getHeader() { return header; }

    /** Trả về i18n key (null nếu đây là cột literal). */
    public String getHeaderKey() { return headerKey; }

    public boolean isI18n() { return headerKey != null; }

    public Object getValue(T row) { return getter.apply(row); }

    public boolean isImportable() { return setter != null; }

    public void applyValue(T row, String rawValue) {
        if (setter != null) setter.accept(row, rawValue);
    }
}
