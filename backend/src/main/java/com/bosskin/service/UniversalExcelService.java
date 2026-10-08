package com.bosskin.service;

import com.bosskin.entity.ExcelHistory;
import com.bosskin.entity.ExcelHistory.HistoryType;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.ExcelHistoryRepository;
import com.bosskin.util.*;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Universal export/import kiểu Matrixify:
 * - Export: 1 file Excel, mỗi entity = 1 sheet, có cột Command để hướng dẫn user
 * - Preview: đọc file → trả về diff JSON per sheet
 * - Import: đọc cột Command → xử lý → trả về file Excel kết quả có cột Status/Message
 *           + header X-Import-Summary: {"ok":N,"error":M,"skip":K}
 */
@Service
@RequiredArgsConstructor
public class UniversalExcelService {

    private final List<ExcelEntityDescriptor<?>> descriptors;
    private final ExcelI18n excelI18n;
    private final DepartmentRepository deptRepo;
    private final ExcelHistoryRepository historyRepo;
    private final ExcelHistoryHelper historyHelper;

    // ─── EXPORT ──────────────────────────────────────────────────────────────

    public ResponseEntity<byte[]> exportAll(Long companyId, Long userId,
                                             java.util.Locale locale,
                                             ExportRequest req,
                                             Set<String> allowedTypes) {
        List<String> types = req != null ? req.types() : null;
        if (types != null && types.stream().anyMatch(t -> !allowedTypes.contains(t))) {
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        List<ExcelEntityDescriptor<?>> targets = filterDescriptors(types).stream()
            .filter(d -> allowedTypes.contains(d.type()))
            .toList();
        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            CellStyle headerStyle   = buildHeaderStyle(wb);
            CellStyle roHeaderStyle = buildReadOnlyHeaderStyle(wb);
            CellStyle cmdStyle      = buildCommandStyle(wb);
            CellStyle dataStyle     = buildDataStyle(wb);
            CellStyle roDataStyle   = buildReadOnlyDataStyle(wb);
            CellStyle wrapStyle     = buildWrapStyle(wb, false);
            CellStyle roWrapStyle   = buildWrapStyle(wb, true);

            for (ExcelEntityDescriptor<?> desc : targets) {
                List<String> selCols  = req != null ? req.columnsFor(desc.type())   : null;
                Map<String, String> filters = req != null ? req.filtersFor(desc.type()) : Map.of();
                writeSheet(wb, desc, companyId, userId, locale,
                           selCols, filters, headerStyle, roHeaderStyle, cmdStyle, dataStyle, roDataStyle, wrapStyle, roWrapStyle);
            }

            String filenameKey = excelI18n.resolve("excel.file.universal", locale);
            byte[] bytes = toBytes(wb);
            ResponseEntity<byte[]> response = ExcelUtils.buildFileResponse(filenameKey, bytes);
            String moduleStr = targets.stream().map(ExcelEntityDescriptor::type)
                    .collect(java.util.stream.Collectors.joining(","));
            historyHelper.save(companyId, userId, HistoryType.EXPORT, moduleStr,
                    filenameKey + ".xlsx", bytes, null, null, null);
            return response;
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    @SuppressWarnings("unchecked")
    private <T> void writeSheet(XSSFWorkbook wb, ExcelEntityDescriptor<T> desc,
                                 Long companyId, Long userId, java.util.Locale locale,
                                 List<String> selectedColumnKeys,
                                 Map<String, String> filters,
                                 CellStyle headerStyle, CellStyle roHeaderStyle,
                                 CellStyle cmdStyle, CellStyle dataStyle, CellStyle roDataStyle,
                                 CellStyle wrapStyle, CellStyle roWrapStyle) {
        String sheetName = sanitize(excelI18n.resolve(desc.sheetKey(), locale));
        Sheet sheet = wb.createSheet(sheetName);

        CellStyle moneyStyle   = buildMoneyStyle(wb);
        CellStyle decimalStyle = buildDecimalStyle(wb);
        CellStyle integerStyle = buildIntegerStyle(wb);

        // Lọc cột theo selectedColumnKeys; null = tất cả defaultVisible
        // Hidden columns luôn được export (không phụ thuộc selection)
        List<ExcelColumn<T>> allCols = desc.columns();
        List<ExcelColumn<T>> hiddenCols = allCols.stream()
            .filter(ExcelColumn::isHidden)
            .collect(Collectors.toList());
        List<ExcelColumn<T>> visibleCols;
        if (selectedColumnKeys != null && !selectedColumnKeys.isEmpty()) {
            Set<String> selected = new HashSet<>(selectedColumnKeys);
            visibleCols = allCols.stream()
                .filter(c -> !c.isHidden() && selected.contains(c.getColumnKey()))
                .collect(Collectors.toList());
            if (visibleCols.isEmpty()) visibleCols = allCols.stream()
                .filter(c -> !c.isHidden() && c.isDefaultVisible())
                .collect(Collectors.toList());
        } else {
            visibleCols = allCols.stream()
                .filter(c -> !c.isHidden() && c.isDefaultVisible())
                .collect(Collectors.toList());
        }
        // Hidden đứng đầu, sau đó mới đến visible
        List<ExcelColumn<T>> cols = new ArrayList<>(hiddenCols);
        cols.addAll(visibleCols);

        String cmdHeader = excelI18n.resolve("excel.col.command", locale);

        // Header row: Command | col1 | col2 | ...
        Row hRow = sheet.createRow(0);
        hRow.setHeight((short) 500);
        Cell cmdCell = hRow.createCell(0);
        cmdCell.setCellValue(cmdHeader);
        cmdCell.setCellStyle(headerStyle);
        sheet.setColumnWidth(0, 14 * 256);

        for (int c = 0; c < cols.size(); c++) {
            Cell cell = hRow.createCell(c + 1);
            ExcelColumn<T> col = cols.get(c);
            cell.setCellValue(col.isI18n()
                ? excelI18n.resolve(col.getHeaderKey(), locale)
                : (col.getHeader() != null ? col.getHeader() : ""));
            cell.setCellStyle(col.isImportable() ? headerStyle : roHeaderStyle);
            sheet.setColumnWidth(c + 1, 22 * 256);
        }

        // Load data với filters
        List<T> rows = desc.loadForExport(companyId, userId, filters);
        for (int r = 0; r < rows.size(); r++) {
            Row row = sheet.createRow(r + 1);
            Cell c0 = row.createCell(0);
            c0.setCellValue("MERGE");
            c0.setCellStyle(cmdStyle);

            T data = rows.get(r);
            for (int c = 0; c < cols.size(); c++) {
                Cell cell = row.createCell(c + 1);
                ExcelColumn<T> col = cols.get(c);
                Object val = col.getValue(data);
                ExcelColumn.ColType colType = col.getColType();
                if (val != null && !val.toString().isBlank()
                        && colType != ExcelColumn.ColType.TEXT) {
                    try {
                        double num = Double.parseDouble(val.toString().replace(",", ""));
                        cell.setCellValue(num);
                        cell.setCellStyle(switch (colType) {
                            case MONEY   -> moneyStyle;
                            case DECIMAL -> decimalStyle;
                            case INTEGER -> integerStyle;
                            default      -> dataStyle;
                        });
                        continue;
                    } catch (NumberFormatException ignored) {}
                }
                String strVal = val != null ? val.toString() : "";
                if (!strVal.isEmpty()) cell.setCellValue(strVal);
                boolean multiline = strVal.contains("\n");
                if (col.isImportable()) {
                    cell.setCellStyle(multiline ? wrapStyle : dataStyle);
                } else {
                    cell.setCellStyle(multiline ? roWrapStyle : roDataStyle);
                }
            }
        }

        sheet.createFreezePane(1, 1);
        addCommandDropdown(wb, sheet, rows.size());
    }

    // ─── SEARCH FOR PICK ─────────────────────────────────────────────────────

    public List<ExcelEntityDescriptor.PickItem> searchForPick(
            Long companyId, Long userId, String module, String q, Set<String> allowedTypes) {
        return descriptors.stream()
            .filter(d -> d.type().equals(module) && allowedTypes.contains(d.type()))
            .findFirst()
            .map(d -> d.searchForPick(companyId, userId, q))
            .orElse(List.of());
    }

    // ─── META (column defs + filters cho UI) ────────────────────────────────

    /**
     * Trả về metadata để frontend render UI chọn cột + filter.
     * Response: { "employee": { columns: [...], filters: [...] }, ... }
     */
    public Map<String, ExportMeta> getExportMeta(Long companyId, java.util.Locale locale, Set<String> allowedTypes) {
        List<DeptItem> departments = deptRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream()
            .map(d -> new DeptItem(d.getId(), d.getName(), d.getCode(),
                d.getParent() != null ? d.getParent().getId() : null, d.getLevel()))
            .collect(Collectors.toList());

        Map<String, ExportMeta> result = new LinkedHashMap<>();
        for (ExcelEntityDescriptor<?> desc : descriptors) {
            if (!allowedTypes.contains(desc.type())) continue;
            // Hidden columns không hiện trong dialog chọn cột
            List<ColumnMeta> cols = desc.columns().stream()
                .filter(col -> !col.isHidden())
                .map(col -> new ColumnMeta(
                    col.getColumnKey(),
                    col.isI18n() ? excelI18n.resolve(col.getHeaderKey(), locale) : col.getHeader(),
                    col.getGroup(),
                    col.isDefaultVisible(),
                    col.isImportable(),
                    col.isRequired()
                )).collect(Collectors.toList());
            List<FilterDefinition> filters = desc.filterDefinitions(companyId);
            result.put(desc.type(), new ExportMeta(cols, filters, departments));
        }
        return result;
    }

    public record ColumnMeta(String key, String label, String group,
                              boolean defaultVisible, boolean importable, boolean required) {}
    public record DeptItem(Long id, String name, String code, Long parentId, int level) {}
    public record ExportMeta(List<ColumnMeta> columns, List<FilterDefinition> filters,
                              List<DeptItem> departments) {}

    // ─── PREVIEW ─────────────────────────────────────────────────────────────

    public Map<String, List<UniversalImportDiff>> previewImport(
            Long companyId, Long userId, byte[] fileBytes, Set<String> allowedTypes) {
        Map<String, List<UniversalImportDiff>> result = new LinkedHashMap<>();
        try (InputStream is = new ByteArrayInputStream(fileBytes);
             XSSFWorkbook wb = new XSSFWorkbook(is)) {

            for (ExcelEntityDescriptor<?> desc : descriptors) {
                if (!desc.importable()) continue;
                String sheetName = findSheet(wb, desc.sheetKey());
                if (sheetName == null) continue;
                requireImportAllowed(desc, allowedTypes);
                Sheet sheet = wb.getSheet(sheetName);
                List<UniversalImportDiff> diffs = previewSheet(sheet, desc, companyId, userId);
                result.put(desc.type(), diffs);
            }
        } catch (IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }
        return result;
    }

    @SuppressWarnings("unchecked")
    private <T> List<UniversalImportDiff> previewSheet(Sheet sheet,
                                                         ExcelEntityDescriptor<T> desc,
                                                         Long companyId, Long userId) {
        List<ExcelEntityDescriptor.RowWithCommand<T>> rows = readRows(sheet, desc);
        List<SheetImportResult.RowResult> results = desc.importRows(companyId, userId, rows, true);
        List<UniversalImportDiff> diffs = new ArrayList<>();
        for (int i = 0; i < results.size(); i++) {
            SheetImportResult.RowResult r = results.get(i);
            ExcelEntityDescriptor.RowWithCommand<T> rw = i < rows.size() ? rows.get(i) : null;
            String id = rw != null ? desc.getIdentifier(rw.data()) : "";
            String action = rw != null && rw.command() != null ? rw.command().name() : r.status();
            boolean isError = r.status().equals("ERROR");
            boolean isWarn  = r.status().equals("WARN");
            String msg = r.message();
            if (!isError && !isWarn && "preview.noChange".equals(msg)) continue;
            if ("SKIP".equals(r.status())) continue;
            String summary  = (!isError && !isWarn && msg != null && !msg.isBlank()) ? msg : null;
            String errorMsg = (isError || isWarn) ? msg : null;
            String diffAction = isWarn ? "WARN" : action;
            diffs.add(new UniversalImportDiff(r.rowNum(), diffAction, id, summary, errorMsg));
        }
        return diffs;
    }

    // ─── IMPORT ──────────────────────────────────────────────────────────────

    public ResponseEntity<byte[]> importAll(Long companyId, Long userId,
                                             byte[] fileBytes, java.util.Locale locale,
                                             Set<String> allowedTypes) {
        Map<String, SheetImportResult> allResults = new LinkedHashMap<>();

        try (InputStream is = new ByteArrayInputStream(fileBytes);
             XSSFWorkbook sourceWb = new XSSFWorkbook(is)) {

            for (ExcelEntityDescriptor<?> desc : descriptors) {
                if (!desc.importable()) continue;
                String sheetName = findSheet(sourceWb, desc.sheetKey());
                if (sheetName == null) continue;
                requireImportAllowed(desc, allowedTypes);
                Sheet sheet = sourceWb.getSheet(sheetName);
                SheetImportResult sheetResult = importSheet(sheet, desc, companyId, userId);
                allResults.put(desc.type(), sheetResult);
            }
        } catch (IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }

        // Build result Excel file — copy input + thêm 2 cột Status/Message
        byte[] resultBytes = buildResultFile(fileBytes, allResults, locale);

        // Summary header
        long totalOk    = allResults.values().stream().mapToLong(SheetImportResult::okCount).sum();
        long totalError = allResults.values().stream().mapToLong(SheetImportResult::errorCount).sum();
        long totalSkip  = allResults.values().stream().mapToLong(SheetImportResult::skipCount).sum();
        String summary = String.format("{\"ok\":%d,\"error\":%d,\"skip\":%d}", totalOk, totalError, totalSkip);

        String ts = java.time.LocalDateTime.now()
                .format(java.time.format.DateTimeFormatter.ofPattern("yyyyMMdd-HHmm"));
        String moduleSlug = allResults.keySet().stream()
                .collect(java.util.stream.Collectors.joining("-"));
        String filenameKey = excelI18n.resolve("excel.file.universal.result", locale)
                + "-" + moduleSlug + "-" + ts;
        String importModuleStr = String.join(",", allResults.keySet());
        historyHelper.save(companyId, userId, HistoryType.IMPORT, importModuleStr,
                filenameKey + ".xlsx", resultBytes,
                (int) totalOk, (int) totalError, (int) totalSkip);

        ResponseEntity<byte[]> base = ExcelUtils.buildFileResponse(filenameKey, resultBytes);
        return ResponseEntity.status(base.getStatusCode())
            .headers(base.getHeaders())
            .header("X-Import-Summary", summary)
            .header("Access-Control-Expose-Headers", "X-Import-Summary")
            .body(base.getBody());
    }

    // ─── HISTORY ─────────────────────────────────────────────────────────────

    public record HistoryWithPerformer(ExcelHistory history, String performedBy) {}

    public List<HistoryWithPerformer> getHistory(Long companyId) {
        return historyRepo.findWithPerformerByCompanyId(companyId, PageRequest.of(0, 20))
                .stream()
                .map(row -> new HistoryWithPerformer((ExcelHistory) row[0], (String) row[1]))
                .toList();
    }

    public record HistoryPage(List<HistoryWithPerformer> items, long total) {}

    public HistoryPage getHistoryPaged(Long companyId, String type, String module,
                                       java.time.LocalDate dateFrom, java.time.LocalDate dateTo,
                                       int page, int size) {
        HistoryType historyType = null;
        if (type != null && !type.isBlank()) {
            try { historyType = HistoryType.valueOf(type.toUpperCase()); } catch (Exception ignored) {}
        }
        String moduleFilter = (module != null && !module.isBlank()) ? module : null;
        Page<Object[]> pageResult = historyRepo.findWithFilters(
            companyId, historyType, moduleFilter, dateFrom, dateTo,
            PageRequest.of(page, size));
        List<HistoryWithPerformer> items = pageResult.getContent().stream()
            .map(row -> new HistoryWithPerformer((ExcelHistory) row[0], (String) row[1]))
            .toList();
        return new HistoryPage(items, pageResult.getTotalElements());
    }

    @SuppressWarnings("unchecked")
    private <T> SheetImportResult importSheet(Sheet sheet, ExcelEntityDescriptor<T> desc,
                                               Long companyId, Long userId) {
        List<ExcelEntityDescriptor.RowWithCommand<T>> rows = readRows(sheet, desc);
        List<SheetImportResult.RowResult> results = desc.importRows(companyId, userId, rows, false);
        return new SheetImportResult(desc.sheetKey(), results);
    }

    // ─── BUILD RESULT FILE ───────────────────────────────────────────────────

    private byte[] buildResultFile(byte[] original, Map<String, SheetImportResult> allResults,
                                    java.util.Locale locale) {
        try (InputStream is = new ByteArrayInputStream(original);
             XSSFWorkbook wb = new XSSFWorkbook(is)) {

            String statusHeader  = excelI18n.resolve("excel.col.status",  locale);
            String messageHeader = excelI18n.resolve("excel.col.message", locale);

            CellStyle okStyle   = buildResultStyle(wb, new byte[]{(byte)0xD1,(byte)0xFA,(byte)0xE8});
            CellStyle errStyle  = buildResultStyle(wb, new byte[]{(byte)0xFE,(byte)0xE2,(byte)0xE2});
            CellStyle warnStyle = buildResultStyle(wb, new byte[]{(byte)0xFF,(byte)0xF3,(byte)0xCD});
            CellStyle skipStyle = buildResultStyle(wb, new byte[]{(byte)0xF3,(byte)0xF4,(byte)0xF6});
            CellStyle hdrStyle = buildHeaderStyle(wb);

            for (SheetImportResult sheetResult : allResults.values()) {
                // Tìm sheet trong workbook (bất kỳ locale nào)
                Sheet sheet = findSheetInWb(wb, sheetResult.sheetKey());
                if (sheet == null) continue;

                // Xác định index cột Status/Message — ghi đè nếu đã tồn tại
                Row headerRow = sheet.getRow(0);
                if (headerRow == null) continue;
                int statusCol  = -1;
                int messageCol = -1;
                for (int ci = 0; ci < headerRow.getLastCellNum(); ci++) {
                    Cell c = headerRow.getCell(ci);
                    if (c == null) continue;
                    String v = c.getStringCellValue();
                    if (statusHeader.equalsIgnoreCase(v)  || "Result".equalsIgnoreCase(v) || "Kết quả".equalsIgnoreCase(v)) statusCol  = ci;
                    if (messageHeader.equalsIgnoreCase(v) || "Note".equalsIgnoreCase(v)   || "Ghi chú".equalsIgnoreCase(v))   messageCol = ci;
                }
                if (statusCol  < 0) statusCol  = headerRow.getLastCellNum();
                if (messageCol < 0) messageCol = statusCol + 1;

                // Thêm/ghi đè header
                Cell sc = headerRow.createCell(statusCol);
                sc.setCellValue(statusHeader);
                sc.setCellStyle(hdrStyle);
                Cell mc = headerRow.createCell(messageCol);
                mc.setCellValue(messageHeader);
                mc.setCellStyle(hdrStyle);
                sheet.setColumnWidth(statusCol,  14 * 256);
                sheet.setColumnWidth(messageCol, 36 * 256);

                // Điền kết quả từng dòng
                for (SheetImportResult.RowResult r : sheetResult.rows()) {
                    Row row = sheet.getRow(r.rowNum() - 1); // rowNum 1-based từ data row
                    if (row == null) row = sheet.createRow(r.rowNum() - 1);
                    CellStyle cs = switch (r.status()) {
                        case "OK"    -> okStyle;
                        case "ERROR" -> errStyle;
                        case "WARN"  -> warnStyle;
                        default      -> skipStyle;
                    };
                    Cell statusCell = row.createCell(statusCol);
                    statusCell.setCellValue(r.status());
                    statusCell.setCellStyle(cs);
                    Cell msgCell = row.createCell(messageCol);
                    msgCell.setCellValue(resolveMessage(r.message(), locale));
                    msgCell.setCellStyle(cs);
                }
            }

            return toBytes(wb);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ─── HELPERS ─────────────────────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    private <T> List<ExcelEntityDescriptor.RowWithCommand<T>> readRows(
            Sheet sheet, ExcelEntityDescriptor<T> desc) {
        if (sheet == null) return List.of();
        Row headerRow = sheet.getRow(0);
        if (headerRow == null) return List.of();

        FormulaEvaluator ev = sheet.getWorkbook().getCreationHelper().createFormulaEvaluator();
        // Build header map
        Map<String, Integer> headerMap = new HashMap<>();
        for (int c = 0; c < headerRow.getLastCellNum(); c++) {
            Cell cell = headerRow.getCell(c);
            if (cell != null) headerMap.put(readCell(ev, cell).trim().toLowerCase(), c);
        }

        // Tìm cột Command (thử tất cả locale)
        int cmdCol = -1;
        for (String cmdName : excelI18n.allValues("excel.col.command")) {
            Integer idx = headerMap.get(cmdName.trim().toLowerCase());
            if (idx != null) { cmdCol = idx; break; }
        }

        // Map cột data
        List<ExcelColumn<T>> cols = desc.columns();
        int[] colIndices = new int[cols.size()];
        for (int c = 0; c < cols.size(); c++) {
            ExcelColumn<T> col = cols.get(c);
            colIndices[c] = -1;
            if (col.isI18n()) {
                for (String name : excelI18n.allValues(col.getHeaderKey())) {
                    Integer idx = headerMap.get(name.trim().toLowerCase());
                    if (idx != null) { colIndices[c] = idx; break; }
                }
            } else if (col.getHeader() != null) {
                colIndices[c] = headerMap.getOrDefault(col.getHeader().trim().toLowerCase(), -1);
            }
        }

        // Build presentColumns: các columnKey có header trong file (importable, colIndex >= 0)
        Set<String> presentColumns = new HashSet<>();
        for (int c = 0; c < cols.size(); c++) {
            if (colIndices[c] >= 0 && cols.get(c).isImportable()) {
                presentColumns.add(cols.get(c).getColumnKey());
            }
        }

        List<ExcelEntityDescriptor.RowWithCommand<T>> result = new ArrayList<>();
        for (int r = 1; r <= sheet.getLastRowNum(); r++) {
            Row row = sheet.getRow(r);
            if (row == null) continue;

            // Đọc command
            String cmdRaw = cmdCol >= 0
                ? readCell(ev, row.getCell(cmdCol, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL))
                : "";
            ImportCommand cmd = ImportCommand.parse(cmdRaw);

            // Đọc data
            T obj = desc.newRow();
            boolean hasData = false;
            for (int c = 0; c < cols.size(); c++) {
                if (colIndices[c] < 0) continue;
                if (!cols.get(c).isImportable()) continue;
                String val = readCell(ev, row.getCell(colIndices[c], Row.MissingCellPolicy.RETURN_BLANK_AS_NULL));
                cols.get(c).applyValue(obj, val);
                if (!val.isBlank()) hasData = true;
            }
            if (!hasData && cmd == null) continue;

            result.add(new ExcelEntityDescriptor.RowWithCommand<>(obj, cmd, r + 1, presentColumns));
        }
        return result;
    }

    private String readCell(FormulaEvaluator ev, Cell cell) {
        if (cell == null) return "";
        CellType type = cell.getCellType() == CellType.FORMULA
            ? ev.evaluateInCell(cell).getCellType() : cell.getCellType();
        return switch (type) {
            case STRING  -> cell.getStringCellValue().trim();
            case NUMERIC -> {
                double d = cell.getNumericCellValue();
                yield d == Math.floor(d) ? String.valueOf((long) d) : String.valueOf(d);
            }
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            default      -> "";
        };
    }

    /** Resolve message key sang text theo locale; nếu không phải key thì trả nguyên. */
    private String resolveMessage(String msg, java.util.Locale locale) {
        if (msg == null || msg.isBlank()) return "";
        String resolved = excelI18n.resolve(msg, locale);
        return resolved.equals(msg) ? msg : resolved;
    }

    /** Tìm tên sheet trong workbook bằng cách thử tất cả locale của key. */
    private String findSheet(XSSFWorkbook wb, String sheetKey) {
        for (String name : excelI18n.allValues(sheetKey)) {
            if (wb.getSheet(name) != null) return name;
        }
        return null;
    }

    private Sheet findSheetInWb(XSSFWorkbook wb, String sheetKey) {
        for (String name : excelI18n.allValues(sheetKey)) {
            Sheet s = wb.getSheet(name);
            if (s != null) return s;
        }
        return null;
    }

    /** File có sheet của module mà người dùng không có quyền nhập → từ chối cả file (S8). */
    private static void requireImportAllowed(ExcelEntityDescriptor<?> desc, Set<String> allowedTypes) {
        if (!allowedTypes.contains(desc.type())) {
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.FORBIDDEN, "error.excel.module_not_permitted");
        }
    }

    private List<ExcelEntityDescriptor<?>> filterDescriptors(List<String> types) {
        if (types == null || types.isEmpty()) return descriptors;
        return descriptors.stream()
            .filter(d -> types.contains(d.type()))
            .collect(Collectors.toList());
    }

    private void addCommandDropdown(XSSFWorkbook wb, Sheet sheet, int rowCount) {
        if (rowCount == 0) return;
        org.apache.poi.ss.util.CellRangeAddressList range =
            new org.apache.poi.ss.util.CellRangeAddressList(1, Math.max(1, rowCount), 0, 0);
        XSSFDataValidationHelper dvHelper = new XSSFDataValidationHelper((XSSFSheet) sheet);
        XSSFDataValidationConstraint constraint = (XSSFDataValidationConstraint)
            dvHelper.createExplicitListConstraint(new String[]{"MERGE", "CREATE", "UPDATE", "DELETE"});
        XSSFDataValidation validation = (XSSFDataValidation) dvHelper.createValidation(constraint, range);
        validation.setShowErrorBox(false);
        validation.setShowPromptBox(false);
        sheet.addValidationData(validation);
    }

    private static String sanitize(String raw) {
        if (raw == null) return "Sheet";
        String s = raw.replaceAll("[\\\\/?*\\[\\]:]", "-").trim();
        return s.length() > 31 ? s.substring(0, 31) : s;
    }

    private static byte[] toBytes(XSSFWorkbook wb) throws IOException {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            wb.write(out);
            return out.toByteArray();
        }
    }

    // ─── STYLES ──────────────────────────────────────────────────────────────

    private static CellStyle buildHeaderStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        XSSFFont font = wb.createFont();
        font.setBold(true);
        font.setColor(new XSSFColor(new byte[]{(byte)0xFF,(byte)0xFF,(byte)0xFF}, null));
        style.setFont(font);
        style.setFillForegroundColor(new XSSFColor(new byte[]{(byte)0x21,(byte)0x5C,(byte)0x98}, null));
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setVerticalAlignment(VerticalAlignment.CENTER);
        style.setBorderBottom(BorderStyle.MEDIUM);
        return style;
    }

    private static CellStyle buildCommandStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        style.setFillForegroundColor(new XSSFColor(new byte[]{(byte)0xFFF,(byte)0xF9,(byte)0xC2}, null));
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setBorderRight(BorderStyle.THIN);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static CellStyle buildDataStyle(XSSFWorkbook wb) {
        CellStyle style = wb.createCellStyle();
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static CellStyle buildReadOnlyHeaderStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        XSSFFont font = wb.createFont();
        font.setBold(true);
        font.setColor(new XSSFColor(new byte[]{(byte)0xFF,(byte)0xFF,(byte)0xFF}, null));
        style.setFont(font);
        style.setFillForegroundColor(new XSSFColor(new byte[]{(byte)0x78,(byte)0x8A,(byte)0x9B}, null));
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setVerticalAlignment(VerticalAlignment.CENTER);
        style.setBorderBottom(BorderStyle.MEDIUM);
        return style;
    }

    private static CellStyle buildReadOnlyDataStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        style.setFillForegroundColor(new XSSFColor(new byte[]{(byte)0xF2,(byte)0xF3,(byte)0xF4}, null));
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static CellStyle buildWrapStyle(XSSFWorkbook wb, boolean readOnly) {
        XSSFCellStyle style = wb.createCellStyle();
        if (readOnly) {
            style.setFillForegroundColor(new XSSFColor(new byte[]{(byte)0xF2,(byte)0xF3,(byte)0xF4}, null));
            style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        }
        style.setWrapText(true);
        style.setVerticalAlignment(VerticalAlignment.TOP);
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static CellStyle buildMoneyStyle(XSSFWorkbook wb) {
        CellStyle style = wb.createCellStyle();
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("#,##0"));
        style.setAlignment(HorizontalAlignment.RIGHT);
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static CellStyle buildDecimalStyle(XSSFWorkbook wb) {
        CellStyle style = wb.createCellStyle();
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("#,##0.0#"));
        style.setAlignment(HorizontalAlignment.RIGHT);
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static CellStyle buildIntegerStyle(XSSFWorkbook wb) {
        CellStyle style = wb.createCellStyle();
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("0"));
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static CellStyle buildResultStyle(XSSFWorkbook wb, byte[] rgb) {
        XSSFCellStyle style = wb.createCellStyle();
        style.setFillForegroundColor(new XSSFColor(rgb, null));
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }
}
