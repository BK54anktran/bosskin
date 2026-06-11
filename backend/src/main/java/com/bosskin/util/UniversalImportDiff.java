package com.bosskin.util;

/**
 * Kết quả preview 1 dòng trong universal import.
 *
 * <p>{@code action}: CREATE | UPDATE | DELETE | SKIP | ERROR
 * <p>{@code rowNum}: số thứ tự dòng trong sheet (1-based, không tính header)
 */
public record UniversalImportDiff(
        int rowNum,
        String action,      // CREATE | UPDATE | DELETE | SKIP | ERROR
        String identifier,  // giá trị định danh (mã NV, mã PB, ...)
        String summary,     // mô tả ngắn thay đổi (dùng cho preview)
        String error        // null nếu không lỗi
) {
    public boolean isError() { return error != null && !error.isBlank(); }

    public static UniversalImportDiff ok(int rowNum, String action, String identifier, String summary) {
        return new UniversalImportDiff(rowNum, action, identifier, summary, null);
    }

    public static UniversalImportDiff error(int rowNum, String identifier, String error) {
        return new UniversalImportDiff(rowNum, "ERROR", identifier, null, error);
    }

    public static UniversalImportDiff skip(int rowNum, String identifier) {
        return new UniversalImportDiff(rowNum, "SKIP", identifier, "Không có thay đổi", null);
    }
}
