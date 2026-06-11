package com.bosskin.util;

import java.util.List;

/**
 * Mô tả một sheet trong file Excel.
 *
 * <p>Tên sheet có hai chế độ:
 * <ul>
 *   <li>literal: {@code sheetName} — string cứng, backward-compat.</li>
 *   <li>i18n: {@code sheetNameKey} — key trong excel_*.properties, resolve theo locale khi export.</li>
 * </ul>
 */
public class ExcelSheet<T> {

    private final String sheetName;     // literal (null nếu i18n)
    private final String sheetNameKey;  // i18n key (null nếu literal)
    private final List<ExcelColumn<T>> columns;
    private final List<T> rows;

    private ExcelSheet(String sheetName, String sheetNameKey,
                       List<ExcelColumn<T>> columns, List<T> rows) {
        this.sheetName    = sheetName;
        this.sheetNameKey = sheetNameKey;
        this.columns      = columns;
        this.rows         = rows;
    }

    // ── Literal (backward-compat) ─────────────────────────────────────────────

    public static <T> ExcelSheet<T> of(String sheetName,
                                       List<ExcelColumn<T>> columns,
                                       List<T> rows) {
        return new ExcelSheet<>(sheetName, null, columns, rows);
    }

    public static <T> ExcelSheet<T> template(String sheetName,
                                             List<ExcelColumn<T>> columns) {
        return new ExcelSheet<>(sheetName, null, columns, List.of());
    }

    // ── i18n ─────────────────────────────────────────────────────────────────

    public static <T> ExcelSheet<T> ofI18n(String sheetNameKey,
                                            List<ExcelColumn<T>> columns,
                                            List<T> rows) {
        return new ExcelSheet<>(null, sheetNameKey, columns, rows);
    }

    public static <T> ExcelSheet<T> templateI18n(String sheetNameKey,
                                                  List<ExcelColumn<T>> columns) {
        return new ExcelSheet<>(null, sheetNameKey, columns, List.of());
    }

    // ── Accessors ─────────────────────────────────────────────────────────────

    public String getSheetName()    { return sheetName; }
    public String getSheetNameKey() { return sheetNameKey; }
    public boolean isI18n()         { return sheetNameKey != null; }
    public List<ExcelColumn<T>> getColumns() { return columns; }
    public List<T> getRows()        { return rows; }
}
