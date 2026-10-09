package com.bosskin.util;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
        public static RowResult warn(int rowNum, String message)   { return new RowResult(rowNum, "WARN", errorKey(message)); }
        public static RowResult error(int rowNum, String message)  { return new RowResult(rowNum, "ERROR", errorKey(message)); }
        public static RowResult of(int rowNum, String status, String message) { return new RowResult(rowNum, status, message); }

        /** e.getMessage() của ResponseStatusException có dạng {@code 400 BAD_REQUEST "error.x.y|a"} → chỉ giữ mã lỗi để FE dịch. */
        private static final Pattern STATUS_MESSAGE = Pattern.compile("^\\d{3} [A-Z_]+ \"(.*)\"$", Pattern.DOTALL);

        static String errorKey(String message) {
            if (message == null) return null;
            Matcher m = STATUS_MESSAGE.matcher(message);
            return m.matches() ? m.group(1) : message;
        }
    }
}
