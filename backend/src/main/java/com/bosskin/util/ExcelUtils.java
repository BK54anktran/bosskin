package com.bosskin.util;

import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFCellStyle;
import org.apache.poi.xssf.usermodel.XSSFColor;
import org.apache.poi.xssf.usermodel.XSSFFont;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Supplier;

/**
 * Tiện ích export/import Excel chung.
 *
 * Export 1 sheet : {@link #export(String, String, List, List)}
 * Export nhiều sheet: {@link #exportSheets(String, List)}
 * Import sheet 0 : {@link #importRows(MultipartFile, List, Supplier)}
 * Import sheet N : {@link #importRows(MultipartFile, int, List, Supplier)}
 */
public final class ExcelUtils {

    private ExcelUtils() {}

    // ─── EXPORT ──────────────────────────────────────────────────────────────

    /** Export nhiều sheet vào 1 file .xlsx. */
    public static ResponseEntity<byte[]> exportSheets(String filename,
                                                      List<ExcelSheet<?>> sheets) {
        try (Workbook wb = new XSSFWorkbook()) {
            CellStyle headerStyle = buildHeaderStyle(wb);
            CellStyle dateStyle   = buildDateStyle(wb);

            for (ExcelSheet<?> s : sheets) {
                writeSheet(wb, s, headerStyle, dateStyle);
            }

            return buildResponse(filename, toBytes(wb));
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    /** Export 1 sheet — shorthand cho trường hợp thông thường. */
    public static <T> ResponseEntity<byte[]> export(String filename,
                                                    String sheetName,
                                                    List<ExcelColumn<T>> columns,
                                                    List<T> rows) {
        return exportSheets(filename, List.of(ExcelSheet.of(sheetName, columns, rows)));
    }

    // ─── IMPORT ──────────────────────────────────────────────────────────────

    /** Đọc sheet đầu tiên (index 0). */
    public static <T> List<T> importRows(MultipartFile file,
                                         List<ExcelColumn<T>> columns,
                                         Supplier<T> factory) {
        return importRows(file, 0, columns, factory);
    }

    /** Đọc sheet theo index — dùng khi file có nhiều sheet. */
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

    /** Đọc theo tên cột (header row 0) — không phụ thuộc vào thứ tự cột. */
    public static <T> List<T> importRowsByHeader(MultipartFile file,
                                                  int sheetIndex,
                                                  List<ExcelColumn<T>> columns,
                                                  Supplier<T> factory) {
        validateExcelFile(file);
        try (InputStream is = file.getInputStream();
             Workbook wb = new XSSFWorkbook(is)) {

            Sheet sheet = wb.getSheetAt(sheetIndex);
            Row headerRow = sheet.getRow(0);
            if (headerRow == null) return List.of();

            // Map header name -> column index in file
            java.util.Map<String, Integer> headerMap = new java.util.HashMap<>();
            for (int c = 0; c < headerRow.getLastCellNum(); c++) {
                Cell cell = headerRow.getCell(c);
                if (cell != null) {
                    headerMap.put(cell.getStringCellValue().trim(), c);
                }
            }

            List<T> result = new ArrayList<>();
            for (int r = 1; r <= sheet.getLastRowNum(); r++) {
                Row row = sheet.getRow(r);
                if (row == null) continue;
                T obj = factory.get();
                boolean hasData = false;
                for (ExcelColumn<T> col : columns) {
                    if (!col.isImportable()) continue;
                    Integer colIdx = headerMap.get(col.getHeader());
                    if (colIdx == null) continue;
                    Cell cell = row.getCell(colIdx, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
                    String val = readCellAsString(cell);
                    col.applyValue(obj, val);
                    if (!val.isBlank()) hasData = true;
                }
                if (hasData) result.add(obj);
            }
            return result;

        } catch (IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }
    }

    /** Đọc theo tên cột (header row 0) từ sheet theo tên — an toàn hơn khi workbook có sheet ẩn/phụ. */
    public static <T> List<T> importRowsByHeader(MultipartFile file,
                                                 String sheetName,
                                                 List<ExcelColumn<T>> columns,
                                                 Supplier<T> factory) {
        validateExcelFile(file);
        try (InputStream is = file.getInputStream();
             Workbook wb = new XSSFWorkbook(is)) {

            Sheet sheet = wb.getSheet(sheetName);
            if (sheet == null) return List.of();

            Row headerRow = sheet.getRow(0);
            if (headerRow == null) return List.of();

            java.util.Map<String, Integer> headerMap = new java.util.HashMap<>();
            for (int c = 0; c < headerRow.getLastCellNum(); c++) {
                Cell cell = headerRow.getCell(c);
                if (cell != null) {
                    headerMap.put(readCellAsString(cell).trim(), c);
                }
            }

            List<T> result = new ArrayList<>();
            for (int r = 1; r <= sheet.getLastRowNum(); r++) {
                Row row = sheet.getRow(r);
                if (row == null) continue;
                T obj = factory.get();
                boolean hasData = false;
                for (ExcelColumn<T> col : columns) {
                    if (!col.isImportable()) continue;
                    Integer colIdx = headerMap.get(col.getHeader());
                    if (colIdx == null) continue;
                    Cell cell = row.getCell(colIdx, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
                    String val = readCellAsString(cell);
                    col.applyValue(obj, val);
                    if (!val.isBlank()) hasData = true;
                }
                if (hasData) result.add(obj);
            }
            return result;

        } catch (IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }
    }

    // ─── TEMPLATE ────────────────────────────────────────────────────────────

    /** File chỉ có header, không có dữ liệu — dùng để user download về điền. */
    public static <T> ResponseEntity<byte[]> template(String filename,
                                                      String sheetName,
                                                      List<ExcelColumn<T>> columns) {
        return exportSheets(filename + "_template",
                List.of(ExcelSheet.template(sheetName, columns)));
    }

    // ─── PRIVATE HELPERS ─────────────────────────────────────────────────────

    private static <T> void writeSheet(Workbook wb, ExcelSheet<T> excelSheet,
                                       CellStyle headerStyle, CellStyle dateStyle) {
        Sheet sheet = wb.createSheet(excelSheet.getSheetName());
        List<ExcelColumn<T>> columns = excelSheet.getColumns();

        Row headerRow = sheet.createRow(0);
        for (int i = 0; i < columns.size(); i++) {
            Cell cell = headerRow.createCell(i);
            cell.setCellValue(columns.get(i).getHeader());
            cell.setCellStyle(headerStyle);
            sheet.setColumnWidth(i, 22 * 256);
        }

        List<T> rows = excelSheet.getRows();
        for (int r = 0; r < rows.size(); r++) {
            Row row = sheet.createRow(r + 1);
            T data = rows.get(r);
            for (int c = 0; c < columns.size(); c++) {
                Cell cell = row.createCell(c);
                setCellValue(cell, columns.get(c).getValue(data), dateStyle);
            }
        }
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
        return switch (cell.getCellType()) {
            case STRING  -> cell.getStringCellValue().trim();
            case NUMERIC -> {
                double d = cell.getNumericCellValue();
                yield d == Math.floor(d) ? String.valueOf((long) d) : String.valueOf(d);
            }
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            case FORMULA -> {
                FormulaEvaluator ev = cell.getSheet().getWorkbook()
                        .getCreationHelper().createFormulaEvaluator();
                yield readCellAsString(ev.evaluateInCell(cell));
            }
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

    private static ResponseEntity<byte[]> buildResponse(String filename, byte[] bytes) {
        String ts = java.time.LocalDateTime.now()
                .format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd-HH-mm-ss"));
        String safe = filename.replaceAll("[^\\w\\-.]", "_") + "-" + ts + ".xlsx";
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + safe + "\"")
                .contentType(MediaType.parseMediaType(
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(bytes);
    }

    private static CellStyle buildHeaderStyle(Workbook wb) {
        XSSFCellStyle style = (XSSFCellStyle) wb.createCellStyle();
        XSSFFont font = (XSSFFont) wb.createFont();
        font.setBold(true);
        font.setColor(new XSSFColor(new byte[]{(byte)0xFF, (byte)0xFF, (byte)0xFF}, null)); // trắng
        style.setFont(font);
        style.setFillForegroundColor(new XSSFColor(new byte[]{(byte)0x21, (byte)0x5C, (byte)0x98}, null)); // #215C98
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
