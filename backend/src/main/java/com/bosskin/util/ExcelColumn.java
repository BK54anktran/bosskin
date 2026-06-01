package com.bosskin.util;

import java.util.function.BiConsumer;
import java.util.function.Function;

/**
 * Mô tả một cột Excel: header, cách lấy giá trị từ T (export), cách set giá trị vào T (import).
 *
 * @param <T> kiểu dữ liệu của từng hàng
 */
public class ExcelColumn<T> {

    private final String header;
    private final Function<T, Object> getter;       // export: T → cell value
    private final BiConsumer<T, String> setter;     // import: (T, rawString) → void  (null = cột read-only)

    private ExcelColumn(String header, Function<T, Object> getter, BiConsumer<T, String> setter) {
        this.header = header;
        this.getter = getter;
        this.setter = setter;
    }

    /** Cột chỉ export (không import). */
    public static <T> ExcelColumn<T> readOnly(String header, Function<T, Object> getter) {
        return new ExcelColumn<>(header, getter, null);
    }

    /** Cột export + import. */
    public static <T> ExcelColumn<T> of(String header,
                                        Function<T, Object> getter,
                                        BiConsumer<T, String> setter) {
        return new ExcelColumn<>(header, getter, setter);
    }

    public String getHeader() { return header; }

    public Object getValue(T row) { return getter.apply(row); }

    public boolean isImportable() { return setter != null; }

    public void applyValue(T row, String rawValue) {
        if (setter != null) setter.accept(row, rawValue);
    }
}
