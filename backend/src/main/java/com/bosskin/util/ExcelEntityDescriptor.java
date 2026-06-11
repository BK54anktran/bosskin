package com.bosskin.util;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Mô tả 1 entity có thể export/import qua Universal Excel.
 *
 * <p>Mỗi module implement interface này và đăng ký vào {@code UniversalExcelService}.
 *
 * @param <T> kiểu ImportRow của entity
 */
public interface ExcelEntityDescriptor<T> {

    /** Key i18n cho tên sheet, ví dụ "excel.sheet.employee.basic". */
    String sheetKey();

    /** Tên định danh module, dùng trong X-Import-Summary và query param. Ví dụ: "employee". */
    String type();

    /** Danh sách cột — không gồm cột Command/Status/Message (thêm tự động). */
    List<ExcelColumn<T>> columns();

    /** Factory tạo ImportRow rỗng. */
    T newRow();

    /**
     * Load data để export (không filter).
     * Mặc định delegate sang overload có filters với empty map.
     */
    default List<T> loadForExport(Long companyId, Long userId) {
        return loadForExport(companyId, userId, Map.of());
    }

    /**
     * Load data để export với filters tuỳ chỉnh.
     * Key = FilterDefinition.key, value = giá trị user chọn.
     * Ví dụ: {"departmentId": "5", "status": "ACTIVE"}
     */
    List<T> loadForExport(Long companyId, Long userId, Map<String, String> filters);

    /**
     * Danh sách filter fields mà module này hỗ trợ.
     * Trả về empty list nếu không có filter.
     */
    default List<FilterDefinition> filterDefinitions(Long companyId) { return List.of(); }

    /**
     * Preview hoặc thực hiện import 1 danh sách row kèm command.
     *
     * @param dryRun true = chỉ preview, false = thực sự import
     * @return kết quả từng dòng
     */
    List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<T>> rows,
            boolean dryRun);

    /** Lấy giá trị định danh từ 1 row (mã NV, mã PB, ...) để hiển thị trong kết quả. */
    String getIdentifier(T row);

    /** true nếu module này hỗ trợ import (false = export-only, ví dụ Payroll). */
    default boolean importable() { return true; }

    /**
     * @param presentColumns set các columnKey có header trong file Excel
     *                       (dùng để phân biệt "cột trống" vs "cột không có trong file")
     */
    record RowWithCommand<T>(T data, ImportCommand command, int rowNum, Set<String> presentColumns) {}
}
