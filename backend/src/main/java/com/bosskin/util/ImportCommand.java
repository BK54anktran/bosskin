package com.bosskin.util;

/** Giá trị cột Command trong file Excel import kiểu Matrixify. */
public enum ImportCommand {
    /** Tạo mới — lỗi nếu đã tồn tại. */
    CREATE,
    /** Cập nhật — lỗi nếu chưa tồn tại. */
    UPDATE,
    /** Upsert — tạo mới nếu chưa có, cập nhật nếu đã có. */
    MERGE,
    /** Xóa mềm. */
    DELETE;

    public static ImportCommand parse(String raw) {
        if (raw == null || raw.isBlank()) return null;
        return switch (raw.trim().toUpperCase()) {
            case "CREATE", "NEW", "ADD"          -> CREATE;
            case "UPDATE", "EDIT"                -> UPDATE;
            case "MERGE", "UPSERT"               -> MERGE;
            case "DELETE", "DEL", "REMOVE", "X"  -> DELETE;
            default -> null;
        };
    }
}
