package com.bosskin.util;

import java.util.List;

/**
 * Kết quả import 1 sheet: danh sách dòng với status OK/ERROR.
 * Dùng để ghi cột Status + Message vào file Excel kết quả.
 */
public record SheetImportResult(
        String sheetKey,
        List<RowResult> rows
) {
    public long okCount()    { return rows.stream().filter(r -> "OK".equals(r.status())).count(); }
    public long errorCount() { return rows.stream().filter(r -> "ERROR".equals(r.status())).count(); }
    public long skipCount()  { return rows.stream().filter(r -> "SKIP".equals(r.status())).count(); }

    public record RowResult(int rowNum, String status, String message) {
        public static RowResult ok(int rowNum)                     { return new RowResult(rowNum, "OK", ""); }
        public static RowResult skip(int rowNum)                   { return new RowResult(rowNum, "SKIP", ""); }
        public static RowResult error(int rowNum, String message)  { return new RowResult(rowNum, "ERROR", message); }
        public static RowResult of(int rowNum, String status, String message) { return new RowResult(rowNum, status, message); }
    }
}
