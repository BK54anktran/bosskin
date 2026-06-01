package com.bosskin.util;

import java.util.List;

/**
 * Mô tả một sheet trong file Excel: tên sheet, danh sách cột và dữ liệu.
 */
public class ExcelSheet<T> {

    private final String sheetName;
    private final List<ExcelColumn<T>> columns;
    private final List<T> rows;

    private ExcelSheet(String sheetName, List<ExcelColumn<T>> columns, List<T> rows) {
        this.sheetName = sheetName;
        this.columns   = columns;
        this.rows      = rows;
    }

    public static <T> ExcelSheet<T> of(String sheetName,
                                       List<ExcelColumn<T>> columns,
                                       List<T> rows) {
        return new ExcelSheet<>(sheetName, columns, rows);
    }

    /** Sheet chỉ có header, không có dữ liệu — dùng làm template. */
    public static <T> ExcelSheet<T> template(String sheetName,
                                             List<ExcelColumn<T>> columns) {
        return new ExcelSheet<>(sheetName, columns, List.of());
    }

    public String getSheetName() { return sheetName; }
    public List<ExcelColumn<T>> getColumns() { return columns; }
    public List<T> getRows() { return rows; }
}
