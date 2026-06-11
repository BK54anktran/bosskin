package com.bosskin.util;

import java.util.List;

/**
 * Mô tả 1 trường có thể filter khi export.
 *
 * Frontend dùng để render UI filter (dropdown, date range, text search...).
 * Backend nhận giá trị filter qua ExportRequest.filters.
 */
public record FilterDefinition(
        String key,         // unique key, ví dụ: "departmentCode", "status", "joinDateFrom"
        Type type,          // loại filter
        String labelKey,    // i18n key để hiển thị label
        List<Option> options // chỉ dùng khi type = SELECT; null cho các type khác
) {

    public enum Type {
        SELECT,      // dropdown chọn 1
        MULTI_SELECT,// dropdown chọn nhiều
        TEXT,        // text search
        DATE,        // date picker
        DATE_RANGE,  // from + to (key = "dateFrom", "dateTo" đặt convention)
    }

    public record Option(String value, String labelKey) {}

    // ── Builders ─────────────────────────────────────────────────────────────

    public static FilterDefinition select(String key, String labelKey, List<Option> options) {
        return new FilterDefinition(key, Type.SELECT, labelKey, options);
    }

    public static FilterDefinition multiSelect(String key, String labelKey, List<Option> options) {
        return new FilterDefinition(key, Type.MULTI_SELECT, labelKey, options);
    }

    public static FilterDefinition text(String key, String labelKey) {
        return new FilterDefinition(key, Type.TEXT, labelKey, null);
    }

    public static FilterDefinition dateRange(String keyFrom, String labelKey) {
        return new FilterDefinition(keyFrom, Type.DATE_RANGE, labelKey, null);
    }

    public static Option opt(String value, String labelKey) {
        return new Option(value, labelKey);
    }
}
