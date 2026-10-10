package com.bosskin.util;

import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFCellStyle;
import org.apache.poi.xssf.usermodel.XSSFColor;
import org.apache.poi.xssf.usermodel.XSSFFont;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.function.Supplier;

/**
 * Tiện ích export/import Excel chung.
 *
 * Export i18n  : {@link #exportSheets(String, List, ExcelI18n, Locale)}
 * Export 1 sheet: {@link #export(String, String, List, List)}
 * Import       : {@link #importRows}, {@link #importRowsByHeader}
 */
public final class ExcelUtils {

    private ExcelUtils() {}

    // ─── EXPORT ──────────────────────────────────────────────────────────────

    /**
     * Export nhiều sheet — i18n: tên file, tên cột, tên sheet theo locale request.
     * {@code filenameKey} là key trong excel_*.properties, ví dụ {@code "excel.file.employee"}.
     */
    public static ResponseEntity<byte[]> exportSheets(String filenameKey,
                                                      List<ExcelSheet<?>> sheets,
                                                      ExcelI18n i18n,
                                                      Locale locale) {
        try (Workbook wb = new XSSFWorkbook()) {
            CellStyle headerStyle = buildHeaderStyle(wb);
            CellStyle dateStyle   = buildDateStyle(wb);
            for (ExcelSheet<?> s : sheets) {
                writeSheet(wb, s, headerStyle, dateStyle, i18n, locale);
            }
            String filename = (i18n != null && locale != null)
                    ? i18n.resolve(filenameKey, locale)
                    : filenameKey;
            return buildResponse(filename, toBytes(wb));
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    /** Export nhiều sheet — literal filename, không i18n (backward-compat). */
    public static ResponseEntity<byte[]> exportSheets(String filename,
                                                      List<ExcelSheet<?>> sheets) {
        return exportSheets(filename, sheets, null, null);
    }

    /** Export 1 sheet — shorthand. */
    public static <T> ResponseEntity<byte[]> export(String filename,
                                                    String sheetName,
                                                    List<ExcelColumn<T>> columns,
                                                    List<T> rows) {
        return exportSheets(filename, List.of(ExcelSheet.of(sheetName, columns, rows)));
    }

    // ─── IMPORT ──────────────────────────────────────────────────────────────

    /** Đọc sheet đầu tiên theo thứ tự cột (không dùng header). */
    public static <T> List<T> importRows(MultipartFile file,
                                         List<ExcelColumn<T>> columns,
                                         Supplier<T> factory) {
        return importRows(file, 0, columns, factory);
    }

    /** Đọc sheet theo index theo thứ tự cột (không dùng header). */
    public static <T> List<T> importRows(MultipartFile file,
                                         int sheetIndex,
                                         List<ExcelColumn<T>> columns,
                                         Supplier<T> factory) {
        validateExcelFile(file);
        try (InputStream is = file.getInputStream();
             Workbook wb = new XSSFWorkbook(is)) {

            Sheet sheet = wb.getSheetAt(sheetIndex);
            List<T> result = new ArrayList<>();

            for (int r = 1; r <= sheet.getLastRowNum(); r++) {
                Row row = sheet.getRow(r);
                if (row == null || isRowBlank(row, columns.size())) continue;

                T obj = factory.get();
                for (int c = 0; c < columns.size(); c++) {
                    ExcelColumn<T> col = columns.get(c);
                    if (!col.isImportable()) continue;
                    Cell cell = row.getCell(c, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
                    col.applyValue(obj, readCellAsString(cell));
                }
                result.add(obj);
            }
            return result;

        } catch (IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }
    }

    /**
     * Đọc theo tên cột (header row 0) — match bất kỳ ngôn ngữ nào khi cột là i18n.
     * {@code i18n} có thể null nếu tất cả cột đều là literal.
     */
    public static <T> List<T> importRowsByHeader(MultipartFile file,
                                                  int sheetIndex,
                                                  List<ExcelColumn<T>> columns,
                                                  Supplier<T> factory,
                                                  ExcelI18n i18n) {
        validateExcelFile(file);
        try (InputStream is = file.getInputStream();
             Workbook wb = new XSSFWorkbook(is)) {

            Sheet sheet = wb.getSheetAt(sheetIndex);
            Row headerRow = sheet.getRow(0);
            if (headerRow == null) return List.of();

            FormulaEvaluator ev = wb.getCreationHelper().createFormulaEvaluator();
            Map<String, Integer> headerMap = buildHeaderMap(headerRow, ev);

            return readRowsByHeaderMap(sheet, columns, headerMap, ev, factory, i18n);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }
    }

    /** Backward-compat — không i18n. */
    public static <T> List<T> importRowsByHeader(MultipartFile file,
                                                  int sheetIndex,
                                                  List<ExcelColumn<T>> columns,
                                                  Supplier<T> factory) {
        return importRowsByHeader(file, sheetIndex, columns, factory, null);
    }

    /**
     * Đọc theo tên sheet — match bất kỳ ngôn ngữ nào khi cột là i18n.
     */
    public static <T> List<T> importRowsByHeader(MultipartFile file,
                                                 String sheetName,
                                                 List<ExcelColumn<T>> columns,
                                                 Supplier<T> factory,
                                                 ExcelI18n i18n) {
        validateExcelFile(file);
        try (InputStream is = file.getInputStream();
             Workbook wb = new XSSFWorkbook(is)) {

            Sheet sheet = wb.getSheet(sheetName);
            if (sheet == null) return List.of();

            Row headerRow = sheet.getRow(0);
            if (headerRow == null) return List.of();

            FormulaEvaluator ev = wb.getCreationHelper().createFormulaEvaluator();
            Map<String, Integer> headerMap = buildHeaderMap(headerRow, ev);

            return readRowsByHeaderMap(sheet, columns, headerMap, ev, factory, i18n);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }
    }

    /** Backward-compat — không i18n. */
    public static <T> List<T> importRowsByHeader(MultipartFile file,
                                                 String sheetName,
                                                 List<ExcelColumn<T>> columns,
                                                 Supplier<T> factory) {
        return importRowsByHeader(file, sheetName, columns, factory, null);
    }

    // ─── TEMPLATE ────────────────────────────────────────────────────────────

    public static <T> ResponseEntity<byte[]> template(String filename,
                                                      String sheetName,
                                                      List<ExcelColumn<T>> columns) {
        return exportSheets(filename + "_template",
                List.of(ExcelSheet.template(sheetName, columns)));
    }

    // ─── PRIVATE HELPERS ─────────────────────────────────────────────────────

    private static <T> void writeSheet(Workbook wb, ExcelSheet<T> excelSheet,
                                       CellStyle headerStyle, CellStyle dateStyle,
                                       ExcelI18n i18n, Locale locale) {
        String resolvedSheetName = resolveSheetName(excelSheet, i18n, locale);
        Sheet sheet = wb.createSheet(resolvedSheetName);
        List<ExcelColumn<T>> columns = excelSheet.getColumns();

        Row headerRow = sheet.createRow(0);
        for (int i = 0; i < columns.size(); i++) {
            Cell cell = headerRow.createCell(i);
            cell.setCellValue(resolveHeader(columns.get(i), i18n, locale));
            cell.setCellStyle(headerStyle);
            sheet.setColumnWidth(i, 22 * 256);
        }

        // D9: cột chữ định dạng Text — ô gõ thêm (SĐT, CCCD, số TK) không mất số 0 đầu
        CellStyle textStyle = wb.createCellStyle();
        textStyle.setDataFormat(wb.createDataFormat().getFormat(ExcelText.TEXT_FORMAT));
        for (int i = 0; i < columns.size(); i++) {
            if (columns.get(i).getColType() == ExcelColumn.ColType.TEXT) sheet.setDefaultColumnStyle(i, textStyle);
        }

        List<T> rows = excelSheet.getRows();
        for (int r = 0; r < rows.size(); r++) {
            Row row = sheet.createRow(r + 1);
            T data = rows.get(r);
            for (int c = 0; c < columns.size(); c++) {
                Cell cell = row.createCell(c);
                Object val = columns.get(c).getValue(data);
                setCellValue(cell, val, dateStyle);
                if (val instanceof CharSequence) cell.setCellStyle(textStyle);
            }
        }
    }

    private static String resolveSheetName(ExcelSheet<?> sheet, ExcelI18n i18n, Locale locale) {
        if (sheet.isI18n() && i18n != null && locale != null) {
            return i18n.resolve(sheet.getSheetNameKey(), locale);
        }
        return sheet.getSheetName() != null ? sheet.getSheetName() : "";
    }

    private static String resolveHeader(ExcelColumn<?> col, ExcelI18n i18n, Locale locale) {
        if (col.isI18n() && i18n != null && locale != null) {
            return i18n.resolve(col.getHeaderKey(), locale);
        }
        return col.getHeader() != null ? col.getHeader() : "";
    }

    /**
     * Build headerMap từ header row của file: tên cột (trimmed) → column index.
     */
    private static Map<String, Integer> buildHeaderMap(Row headerRow, FormulaEvaluator ev) {
        Map<String, Integer> map = new HashMap<>();
        for (int c = 0; c < headerRow.getLastCellNum(); c++) {
            Cell cell = headerRow.getCell(c);
            if (cell != null) {
                map.put(readCellAsString(ev, cell).trim(), c);
            }
        }
        return map;
    }

    /**
     * Resolve column index từ headerMap: thử tất cả bản dịch của col nếu là i18n,
     * thử header literal nếu không.
     */
    private static Integer resolveColIndex(ExcelColumn<?> col,
                                           Map<String, Integer> headerMap,
                                           ExcelI18n i18n) {
        if (col.isI18n() && i18n != null) {
            for (String name : i18n.allValues(col.getHeaderKey())) {
                Integer idx = headerMap.get(name);
                if (idx != null) return idx;
            }
            return null;
        }
        return headerMap.get(col.getHeader());
    }

    private static <T> List<T> readRowsByHeaderMap(Sheet sheet,
                                                    List<ExcelColumn<T>> columns,
                                                    Map<String, Integer> headerMap,
                                                    FormulaEvaluator ev,
                                                    Supplier<T> factory,
                                                    ExcelI18n i18n) {
        List<T> result = new ArrayList<>();
        for (int r = 1; r <= sheet.getLastRowNum(); r++) {
            Row row = sheet.getRow(r);
            if (row == null) continue;
            T obj = factory.get();
            boolean hasData = false;
            for (ExcelColumn<T> col : columns) {
                if (!col.isImportable()) continue;
                Integer colIdx = resolveColIndex(col, headerMap, i18n);
                if (colIdx == null) continue;
                Cell cell = row.getCell(colIdx, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
                String val = readCellAsString(ev, cell);
                col.applyValue(obj, val);
                if (!val.isBlank()) hasData = true;
            }
            if (hasData) result.add(obj);
        }
        return result;
    }

    private static void setCellValue(Cell cell, Object val, CellStyle dateStyle) {
        if (val == null) {
            cell.setBlank();
        } else if (val instanceof Number n) {
            cell.setCellValue(n.doubleValue());
        } else if (val instanceof Boolean b) {
            cell.setCellValue(b);
        } else if (val instanceof java.time.LocalDate ld) {
            cell.setCellValue(ld.toString());
        } else if (val instanceof java.time.LocalDateTime ldt) {
            cell.setCellValue(ldt.toString());
        } else {
            cell.setCellValue(val.toString());
        }
    }

    private static String readCellAsString(Cell cell) {
        if (cell == null) return "";
        if (cell.getCellType() == CellType.FORMULA) {
            FormulaEvaluator ev = cell.getSheet().getWorkbook()
                    .getCreationHelper().createFormulaEvaluator();
            return readCellAsString(ev, cell);
        }
        return readCellAsStringDirect(cell);
    }

    private static String readCellAsString(FormulaEvaluator ev, Cell cell) {
        if (cell == null) return "";
        if (cell.getCellType() == CellType.FORMULA) {
            return readCellAsStringDirect(ev.evaluateInCell(cell));
        }
        return readCellAsStringDirect(cell);
    }

    private static String readCellAsStringDirect(Cell cell) {
        if (cell == null) return "";
        return switch (cell.getCellType()) {
            case STRING  -> cell.getStringCellValue().trim();
            case NUMERIC -> ExcelText.numeric(cell);
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            default -> "";
        };
    }

    private static boolean isRowBlank(Row row, int colCount) {
        for (int c = 0; c < colCount; c++) {
            Cell cell = row.getCell(c, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
            if (cell != null && cell.getCellType() != CellType.BLANK) return false;
        }
        return true;
    }

    private static void validateExcelFile(MultipartFile file) {
        if (file == null || file.isEmpty())
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST, "error.excel.file_empty");
        String name = file.getOriginalFilename();
        if (name == null || !name.toLowerCase().endsWith(".xlsx"))
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST, "error.excel.invalid_format");
    }

    /** Build HTTP response với Content-Disposition hỗ trợ Unicode (RFC 5987). */
    public static ResponseEntity<byte[]> buildFileResponse(String filename, byte[] bytes) {
        return buildResponse(filename, bytes);
    }

    private static ResponseEntity<byte[]> buildResponse(String filename, byte[] bytes) {
        String ts = java.time.LocalDateTime.now()
                .format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd-HH-mm-ss"));
        String base = filename.replaceAll("[\\\\/:*?\"<>|]", "-").strip();
        String withTs = base + "-" + ts + ".xlsx";
        // RFC 5987: filename* cho phép Unicode; filename= ASCII fallback cho client cũ
        String encoded = URLEncoder.encode(withTs, StandardCharsets.UTF_8).replace("+", "%20");
        String asciiSafe = base.replaceAll("[^\\w\\-.]", "_") + "-" + ts + ".xlsx";
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"" + asciiSafe + "\"; filename*=UTF-8''" + encoded)
                .contentType(MediaType.parseMediaType(
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(bytes);
    }

    private static CellStyle buildHeaderStyle(Workbook wb) {
        XSSFCellStyle style = (XSSFCellStyle) wb.createCellStyle();
        XSSFFont font = (XSSFFont) wb.createFont();
        font.setBold(true);
        font.setColor(new XSSFColor(new byte[]{(byte)0xFF, (byte)0xFF, (byte)0xFF}, null));
        style.setFont(font);
        style.setFillForegroundColor(new XSSFColor(new byte[]{(byte)0x21, (byte)0x5C, (byte)0x98}, null));
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setBorderBottom(BorderStyle.THIN);
        style.setAlignment(HorizontalAlignment.CENTER);
        return style;
    }

    private static CellStyle buildDateStyle(Workbook wb) {
        CellStyle style = wb.createCellStyle();
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("yyyy-mm-dd"));
        return style;
    }

    private static byte[] toBytes(Workbook wb) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        wb.write(out);
        return out.toByteArray();
    }
}
