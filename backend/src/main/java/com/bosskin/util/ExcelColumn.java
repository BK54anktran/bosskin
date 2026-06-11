package com.bosskin.util;

import java.util.function.BiConsumer;
import java.util.function.Function;

public class ExcelColumn<T> {

    private final String header;
    private final String headerKey;
    private final String columnKey;
    private final String group;
    private final boolean defaultVisible;
    private final boolean required;
    private final Function<T, Object> getter;
    private final BiConsumer<T, String> setter;

    private ExcelColumn(String header, String headerKey, String columnKey, String group,
                        boolean defaultVisible, boolean required,
                        Function<T, Object> getter, BiConsumer<T, String> setter) {
        this.header         = header;
        this.headerKey      = headerKey;
        this.columnKey      = columnKey != null ? columnKey
                            : (headerKey != null ? headerKey.replaceAll("^excel\\.col\\.", "") : header);
        this.group          = group;
        this.defaultVisible = defaultVisible;
        this.required       = required;
        this.getter         = getter;
        this.setter         = setter;
    }

    // ── Literal (backward-compat) ─────────────────────────────────────────────

    public static <T> ExcelColumn<T> readOnly(String header, Function<T, Object> getter) {
        return new ExcelColumn<>(header, null, null, null, true, false, getter, null);
    }

    public static <T> ExcelColumn<T> of(String header,
                                        Function<T, Object> getter,
                                        BiConsumer<T, String> setter) {
        return new ExcelColumn<>(header, null, null, null, true, false, getter, setter);
    }

    // ── i18n ─────────────────────────────────────────────────────────────────

    public static <T> ExcelColumn<T> readOnlyI18n(String headerKey, Function<T, Object> getter) {
        return new ExcelColumn<>(null, headerKey, null, null, true, false, getter, null);
    }

    public static <T> ExcelColumn<T> ofI18n(String headerKey,
                                             Function<T, Object> getter,
                                             BiConsumer<T, String> setter) {
        return new ExcelColumn<>(null, headerKey, null, null, true, false, getter, setter);
    }

    /** i18n cột với group, defaultVisible, required tuỳ chỉnh. */
    public static <T> ExcelColumn<T> ofI18n(String headerKey, String group,
                                             boolean defaultVisible, boolean required,
                                             Function<T, Object> getter,
                                             BiConsumer<T, String> setter) {
        return new ExcelColumn<>(null, headerKey, null, group, defaultVisible, required, getter, setter);
    }

    /** Backward-compat overload không có required (mặc định false). */
    public static <T> ExcelColumn<T> ofI18n(String headerKey, String group, boolean defaultVisible,
                                             Function<T, Object> getter,
                                             BiConsumer<T, String> setter) {
        return new ExcelColumn<>(null, headerKey, null, group, defaultVisible, false, getter, setter);
    }

    public static <T> ExcelColumn<T> readOnlyI18n(String headerKey, String group,
                                                   Function<T, Object> getter) {
        return new ExcelColumn<>(null, headerKey, null, group, true, false, getter, null);
    }

    // ── Accessors ─────────────────────────────────────────────────────────────

    public String getHeader()      { return header; }
    public String getHeaderKey()   { return headerKey; }
    public String getColumnKey()   { return columnKey; }
    public String getGroup()       { return group; }
    public boolean isDefaultVisible() { return defaultVisible; }
    public boolean isRequired()    { return required; }
    public boolean isI18n()        { return headerKey != null; }
    public Object getValue(T row)  { return getter.apply(row); }
    public boolean isImportable()  { return setter != null; }

    public void applyValue(T row, String rawValue) {
        if (setter != null) setter.accept(row, rawValue);
    }
}
