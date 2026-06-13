package com.bosskin.util;

import java.util.function.BiConsumer;
import java.util.function.Function;

public class ExcelColumn<T> {

    public enum ColType { TEXT, MONEY, DECIMAL, INTEGER }

    private final String header;
    private final String headerKey;
    private final String columnKey;
    private final String group;
    private final boolean defaultVisible;
    private final boolean required;
    private final ColType colType;
    private final Function<T, Object> getter;
    private final BiConsumer<T, String> setter;

    private ExcelColumn(String header, String headerKey, String columnKey, String group,
                        boolean defaultVisible, boolean required, ColType colType,
                        Function<T, Object> getter, BiConsumer<T, String> setter) {
        this.header         = header;
        this.headerKey      = headerKey;
        this.columnKey      = columnKey != null ? columnKey
                            : (headerKey != null ? headerKey.replaceAll("^excel\\.col\\.", "") : header);
        this.group          = group;
        this.defaultVisible = defaultVisible;
        this.required       = required;
        this.colType        = colType != null ? colType : ColType.TEXT;
        this.getter         = getter;
        this.setter         = setter;
    }

    // ── Literal (backward-compat) ─────────────────────────────────────────────

    public static <T> ExcelColumn<T> readOnly(String header, Function<T, Object> getter) {
        return new ExcelColumn<>(header, null, null, null, true, false, ColType.TEXT, getter, null);
    }

    public static <T> ExcelColumn<T> of(String header,
                                        Function<T, Object> getter,
                                        BiConsumer<T, String> setter) {
        return new ExcelColumn<>(header, null, null, null, true, false, ColType.TEXT, getter, setter);
    }

    // ── i18n ─────────────────────────────────────────────────────────────────

    public static <T> ExcelColumn<T> readOnlyI18n(String headerKey, Function<T, Object> getter) {
        return new ExcelColumn<>(null, headerKey, null, null, true, false, ColType.TEXT, getter, null);
    }

    public static <T> ExcelColumn<T> readOnlyI18n(String headerKey, String group,
                                                   Function<T, Object> getter) {
        return new ExcelColumn<>(null, headerKey, null, group, true, false, ColType.TEXT, getter, null);
    }

    /** readOnly với ColType tuỳ chỉnh (MONEY, DECIMAL, INTEGER). */
    public static <T> ExcelColumn<T> readOnlyI18n(String headerKey, String group,
                                                   ColType colType, Function<T, Object> getter) {
        return new ExcelColumn<>(null, headerKey, null, group, true, false, colType, getter, null);
    }

    public static <T> ExcelColumn<T> ofI18n(String headerKey,
                                             Function<T, Object> getter,
                                             BiConsumer<T, String> setter) {
        return new ExcelColumn<>(null, headerKey, null, null, true, false, ColType.TEXT, getter, setter);
    }

    public static <T> ExcelColumn<T> ofI18n(String headerKey, ColType colType,
                                             Function<T, Object> getter,
                                             BiConsumer<T, String> setter) {
        return new ExcelColumn<>(null, headerKey, null, null, true, false, colType, getter, setter);
    }

    public static <T> ExcelColumn<T> ofI18n(String headerKey, String group,
                                             boolean defaultVisible, boolean required,
                                             Function<T, Object> getter,
                                             BiConsumer<T, String> setter) {
        return new ExcelColumn<>(null, headerKey, null, group, defaultVisible, required, ColType.TEXT, getter, setter);
    }

    public static <T> ExcelColumn<T> ofI18n(String headerKey, String group, boolean defaultVisible,
                                             Function<T, Object> getter,
                                             BiConsumer<T, String> setter) {
        return new ExcelColumn<>(null, headerKey, null, group, defaultVisible, false, ColType.TEXT, getter, setter);
    }

    // ── Accessors ─────────────────────────────────────────────────────────────

    public String getHeader()         { return header; }
    public String getHeaderKey()      { return headerKey; }
    public String getColumnKey()      { return columnKey; }
    public String getGroup()          { return group; }
    public boolean isDefaultVisible() { return defaultVisible; }
    public boolean isRequired()       { return required; }
    public ColType getColType()       { return colType; }
    public boolean isI18n()           { return headerKey != null; }
    public Object getValue(T row)     { return getter.apply(row); }
    public boolean isImportable()     { return setter != null; }

    public void applyValue(T row, String rawValue) {
        if (setter != null) setter.accept(row, rawValue);
    }
}
