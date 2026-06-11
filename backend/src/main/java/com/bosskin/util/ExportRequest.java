package com.bosskin.util;

import java.util.List;
import java.util.Map;

/**
 * Request body cho POST /api/v1/excel/export.
 *
 * <pre>
 * {
 *   "types": ["employee", "department"],          // null = tất cả
 *   "selectedColumns": {                           // null = tất cả cột defaultVisible
 *     "employee": ["employee.code", "employee.fullName", "employee.departmentCode"],
 *     "department": null                           // null = tất cả cột của module đó
 *   },
 *   "filters": {
 *     "employee": {"status": "ACTIVE", "departmentId": "5"},
 *     "department": {}
 *   }
 * }
 * </pre>
 */
public record ExportRequest(
        List<String> types,
        Map<String, List<String>> selectedColumns,
        Map<String, Map<String, String>> filters
) {
    public List<String> columnsFor(String type) {
        if (selectedColumns == null) return null;
        return selectedColumns.get(type);
    }

    public Map<String, String> filtersFor(String type) {
        if (filters == null) return Map.of();
        return filters.getOrDefault(type, Map.of());
    }
}
