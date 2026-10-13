package com.bosskin.util;

import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.List;
import java.util.Locale;

/**
 * File mẫu nhập Excel: các sheet dữ liệu chỉ có dòng tiêu đề (đúng cột nhập — sinh từ chính danh sách cột import nên không
 * lệch khi thêm / đổi cột) + sheet "Hướng dẫn" đặt CUỐI (màn nhập theo từng màn đọc sheet theo thứ tự) và mở sẵn khi mở file.
 * Không có dòng ví dụ trong sheet dữ liệu để lỡ nhập nguyên file cũng không tạo dữ liệu giả; ví dụ nằm ở sheet hướng dẫn.
 *
 * <p>Ví dụ / ghi chú mỗi cột lấy từ excel_*.properties theo key cột: {@code excel.col.X} → {@code excel.example.X},
 * {@code excel.note.X} (thiếu thì để trống). Các bước chung: {@code excel.template.step.*}.
 */
public final class ExcelTemplate {

    private ExcelTemplate() {}

    /** Một sheet dữ liệu của file mẫu. {@code commandColumn} = sheet có cột "Lệnh" ở đầu (Excel chung). */
    public record SheetSpec(String sheetName, List<? extends ExcelColumn<?>> columns, boolean commandColumn) {}

    /** Cột đưa vào file mẫu: cột nhập được, không ẩn (cột ẩn là mã nội bộ khi sửa dữ liệu đã có). */
    public static <T> List<ExcelColumn<T>> importable(List<ExcelColumn<T>> cols) {
        return cols.stream().filter(c -> c.isImportable() && !c.isHidden()).toList();
    }

    public static byte[] build(List<SheetSpec> sheets, List<String> stepKeys, ExcelI18n i18n, Locale locale) {
        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            CellStyle header = headerStyle(wb, IndexedColors.DARK_BLUE);
            CellStyle text = wb.createCellStyle();
            text.setDataFormat(wb.createDataFormat().getFormat(ExcelText.TEXT_FORMAT));
            String cmdHeader = i18n.resolve("excel.col.command", locale);

            for (SheetSpec spec : sheets) {
                Sheet sh = wb.createSheet(sanitize(spec.sheetName()));
                Row h = sh.createRow(0);
                h.setHeight((short) 500);
                int c = 0;
                if (spec.commandColumn()) {
                    cell(h, c, cmdHeader, header);
                    sh.setColumnWidth(c++, 14 * 256);
                }
                for (ExcelColumn<?> col : spec.columns()) {
                    cell(h, c, header(col, i18n, locale), header);
                    sh.setColumnWidth(c, 24 * 256);
                    if (col.getColType() == ExcelColumn.ColType.TEXT) sh.setDefaultColumnStyle(c, text);
                    c++;
                }
                sh.createFreezePane(0, 1);
            }
            writeGuide(wb, sheets, stepKeys, i18n, locale);
            wb.setActiveSheet(wb.getNumberOfSheets() - 1);
            wb.setSelectedTab(wb.getNumberOfSheets() - 1);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            wb.write(out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    /** Tên file mẫu: tên file xuất + hậu tố "mau" / "template". */
    public static String filename(String filenameKey, ExcelI18n i18n, Locale locale) {
        return i18n.resolve(filenameKey, locale) + "-" + i18n.resolve("excel.file.templateSuffix", locale);
    }

    private static void writeGuide(XSSFWorkbook wb, List<SheetSpec> sheets, List<String> stepKeys,
                                   ExcelI18n i18n, Locale locale) {
        Sheet g = wb.createSheet(sanitize(i18n.resolve("excel.sheet.templateGuide", locale)));
        CellStyle title = wb.createCellStyle();
        Font tf = wb.createFont(); tf.setBold(true); tf.setFontHeightInPoints((short) 14); title.setFont(tf);
        CellStyle bold = wb.createCellStyle();
        Font bf = wb.createFont(); bf.setBold(true); bf.setFontHeightInPoints((short) 12); bold.setFont(bf);
        CellStyle wrap = wb.createCellStyle();
        wrap.setWrapText(true); wrap.setVerticalAlignment(VerticalAlignment.TOP);
        wrap.setDataFormat(wb.createDataFormat().getFormat(ExcelText.TEXT_FORMAT));
        CellStyle th = headerStyle(wb, IndexedColors.GREY_50_PERCENT);
        CellStyle req = wb.createCellStyle();
        req.cloneStyleFrom(wrap);
        Font rf = wb.createFont(); rf.setBold(true); rf.setColor(IndexedColors.RED.getIndex()); req.setFont(rf);

        g.setColumnWidth(0, 34 * 256);
        g.setColumnWidth(1, 12 * 256);
        g.setColumnWidth(2, 26 * 256);
        g.setColumnWidth(3, 70 * 256);

        int r = 0;
        cell(g.createRow(r++), 0, i18n.resolve("excel.template.title", locale), title);
        r++;
        for (String k : stepKeys) cell(g.createRow(r++), 0, i18n.resolve(k, locale), null);
        r++;

        String yes = i18n.resolve("excel.template.required", locale);
        for (SheetSpec spec : sheets) {
            cell(g.createRow(r++), 0, i18n.resolve("excel.template.sheet", locale) + ": " + spec.sheetName(), bold);
            Row h = g.createRow(r++);
            String[] heads = {"excel.template.colName", "excel.template.colRequired", "excel.template.colExample",
                "excel.template.colNote"};
            for (int i = 0; i < heads.length; i++) cell(h, i, i18n.resolve(heads[i], locale), th);
            if (spec.commandColumn()) {
                Row row = g.createRow(r++);
                cell(row, 0, i18n.resolve("excel.col.command", locale), wrap);
                cell(row, 1, yes, req);
                cell(row, 2, "MERGE", wrap);
                cell(row, 3, i18n.resolve("excel.note.command", locale), wrap);
            }
            for (ExcelColumn<?> col : spec.columns()) {
                Row row = g.createRow(r++);
                boolean required = isRequired(col, i18n, locale);
                cell(row, 0, header(col, i18n, locale), wrap);
                cell(row, 1, required ? yes : "", required ? req : wrap);
                cell(row, 2, extra(col, "excel.example.", i18n, locale), wrap);
                cell(row, 3, extra(col, "excel.note.", i18n, locale), wrap);
            }
            r++;
        }
    }

    private static boolean isRequired(ExcelColumn<?> col, ExcelI18n i18n, Locale locale) {
        // excel.optional.X=1: cột có (*) nhưng để trống được khi thêm mới (vd. Mã NV — hệ thống tự cấp)
        if (!extra(col, "excel.optional.", i18n, locale).isEmpty()) return false;
        String h = header(col, i18n, locale);
        return col.isRequired() || h.contains("(*)") || h.endsWith(" *");
    }

    /** {@code excel.col.employee.phone} → {@code <prefix>employee.phone}; không có bản dịch → "". */
    private static String extra(ExcelColumn<?> col, String prefix, ExcelI18n i18n, Locale locale) {
        if (!col.isI18n() || !col.getHeaderKey().startsWith("excel.col.")) return "";
        String key = prefix + col.getHeaderKey().substring("excel.col.".length());
        String v = i18n.resolve(key, locale);
        return v.equals(key) ? "" : v;
    }

    private static String header(ExcelColumn<?> col, ExcelI18n i18n, Locale locale) {
        if (col.isI18n()) return i18n.resolve(col.getHeaderKey(), locale);
        return col.getHeader() != null ? col.getHeader() : "";
    }

    private static void cell(Row row, int c, String v, CellStyle style) {
        Cell cell = row.createCell(c);
        cell.setCellValue(v);
        if (style != null) cell.setCellStyle(style);
    }

    private static CellStyle headerStyle(Workbook wb, IndexedColors bg) {
        CellStyle s = wb.createCellStyle();
        Font f = wb.createFont(); f.setBold(true); f.setColor(IndexedColors.WHITE.getIndex()); s.setFont(f);
        s.setFillForegroundColor(bg.getIndex());
        s.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        s.setVerticalAlignment(VerticalAlignment.CENTER);
        s.setWrapText(true);
        return s;
    }

    private static String sanitize(String name) {
        String s = name.replaceAll("[/\\\\?*\\[\\]:]", "-");
        return s.length() > 31 ? s.substring(0, 31) : s;
    }
}
