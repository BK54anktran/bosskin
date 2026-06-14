package com.bosskin.service;

import com.bosskin.dto.ShiftDTO;
import com.bosskin.entity.Department;
import com.bosskin.entity.ShiftAssignment;
import com.bosskin.entity.WorkShift;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import com.bosskin.repository.WorkShiftRepository;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelI18n;
import com.bosskin.util.ExcelUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ShiftExcelService {

    private final WorkShiftRepository shiftRepo;
    private final DepartmentRepository deptRepo;
    private final WorkShiftService shiftService;
    private final ShiftAssignmentRepository assignRepo;
    private final com.bosskin.repository.EmployeeRepository employeeRepo;
    private final DeptScopeService deptScopeService;
    private final ExcelI18n excelI18n;

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    // Import columns — i18n: match bất kỳ ngôn ngữ nào
    private static final List<ExcelColumn<ShiftRow>> IMPORT_COLUMNS = List.of(
        ExcelColumn.ofI18n("excel.col.shift.code",      r -> r.code,       (r, v) -> r.code = v),
        ExcelColumn.ofI18n("excel.col.shift.name",      r -> r.name,       (r, v) -> r.name = v),
        ExcelColumn.ofI18n("excel.col.shift.startTime", r -> r.startTime,  (r, v) -> r.startTime = v),
        ExcelColumn.ofI18n("excel.col.shift.endTime",   r -> r.endTime,    (r, v) -> r.endTime = v),
        ExcelColumn.ofI18n("excel.col.shift.breakStart",r -> r.breakStart, (r, v) -> r.breakStart = v),
        ExcelColumn.ofI18n("excel.col.shift.breakEnd",  r -> r.breakEnd,   (r, v) -> r.breakEnd = v),
        ExcelColumn.ofI18n("excel.col.shift.groupName", r -> r.groupName,  (r, v) -> r.groupName = v),
        ExcelColumn.ofI18n("excel.col.shift.color",     r -> r.color,      (r, v) -> r.color = v),
        ExcelColumn.ofI18n("excel.col.shift.deptCodes", r -> r.deptCodes,  (r, v) -> r.deptCodes = v)
    );

    public static class ShiftRow {
        public String code, name, startTime, endTime, breakStart, breakEnd, groupName, color, deptCodes;
    }

    private static final DateTimeFormatter SHEET_DATE_FMT = DateTimeFormatter.ofPattern("MM-yyyy");
    private static final String[] WEEKDAY_VI = {"CN", "T2", "T3", "T4", "T5", "T6", "T7"};

    @Transactional(readOnly = true)
    public ResponseEntity<byte[]> export(Long companyId, LocalDate from, LocalDate to, List<Long> departmentIds, java.util.Locale locale) {
        List<WorkShift> shifts = shiftRepo.findByCompanyIdAndActiveTrue(companyId);
        List<ShiftAssignment> assignments = assignRepo.findByCompanyAndDateRange(companyId, from, to);

        // Build date list
        List<LocalDate> dates = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) dates.add(d);

        // All employees sorted by name, filtered by department if specified
        List<com.bosskin.entity.Employee> allEmps = employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            .stream()
            .filter(e -> e.getStatus() == com.bosskin.entity.Employee.Status.ACTIVE)
            .filter(e -> departmentIds == null || departmentIds.isEmpty() || departmentIds.contains(e.getDepartment() != null ? e.getDepartment().getId() : null))
            .sorted(Comparator.comparing(com.bosskin.entity.Employee::getFullName))
            .collect(Collectors.toList());

        // Group assignments by employeeId -> date -> list of shift labels (nhiều ca/ngày)
        Map<Long, Map<LocalDate, List<String>>> grid = new LinkedHashMap<>();
        Map<Long, String> empNames = new LinkedHashMap<>();
        Map<Long, String> empDepts = new LinkedHashMap<>();
        Map<Long, String> empCodes = new LinkedHashMap<>();
        Map<String, Integer> customShiftMinutes = new LinkedHashMap<>();

        // Pre-populate with all employees (empty grid)
        for (com.bosskin.entity.Employee e : allEmps) {
            empCodes.put(e.getId(), e.getEmployeeCode());
            empNames.put(e.getId(), e.getFullName());
            empDepts.put(e.getId(), e.getDepartment() != null ? e.getDepartment().getName() : "");
            grid.put(e.getId(), new HashMap<>());
        }

        // Fill assignments into grid
        assignments.forEach(a -> {
            Long empId = a.getEmployee().getId();
            String cellVal;
            if (a.getSnapshotCode() != null) {
                cellVal = a.getSnapshotCode();
            } else if (a.getCustomStartTime() != null && a.getCustomEndTime() != null) {
                cellVal = formatCustomTime(a.getCustomStartTime(), a.getCustomEndTime(),
                    a.getCustomBreakStart(), a.getCustomBreakEnd());
                customShiftMinutes.putIfAbsent(cellVal,
                    calcWorkMinutes(a.getCustomStartTime(), a.getCustomEndTime(),
                        a.getCustomBreakStart(), a.getCustomBreakEnd()));
            } else {
                cellVal = "?";
            }
            grid.computeIfAbsent(empId, k -> new HashMap<>())
                .computeIfAbsent(a.getWorkDate(), k -> new ArrayList<>())
                .add(cellVal);
        });

        try (org.apache.poi.xssf.usermodel.XSSFWorkbook wb = new org.apache.poi.xssf.usermodel.XSSFWorkbook()) {
            wb.setCellFormulaValidation(false); // bypass POI parser cho Excel 365 functions
            // ── Sheet 1: Phân công ca (bảng ngang) ──
            org.apache.poi.ss.usermodel.Sheet s1 = wb.createSheet("Phan cong ca " + from.format(SHEET_DATE_FMT));

            // Styles — màu chủ đạo: xanh đậm nền, chữ trắng; cuối tuần: đỏ tươi
            org.apache.poi.xssf.usermodel.XSSFColor blue = new org.apache.poi.xssf.usermodel.XSSFColor(
                new byte[]{(byte)0x21, (byte)0x5C, (byte)0x98}, null);
            org.apache.poi.xssf.usermodel.XSSFColor red = new org.apache.poi.xssf.usermodel.XSSFColor(
                new byte[]{(byte)0xDC, (byte)0x26, (byte)0x26}, null);
            org.apache.poi.xssf.usermodel.XSSFColor redBg = new org.apache.poi.xssf.usermodel.XSSFColor(
                new byte[]{(byte)0xFE, (byte)0xE2, (byte)0xE2}, null);

            org.apache.poi.xssf.usermodel.XSSFFont whiteFont = wb.createFont();
            whiteFont.setBold(true);
            whiteFont.setColor(new org.apache.poi.xssf.usermodel.XSSFColor(
                new byte[]{(byte)0xFF, (byte)0xFF, (byte)0xFF}, null));

            org.apache.poi.xssf.usermodel.XSSFFont redFont = wb.createFont();
            redFont.setBold(true);
            redFont.setColor(red);

            org.apache.poi.xssf.usermodel.XSSFCellStyle hStyle = wb.createCellStyle(); // fixed col header
            hStyle.setFont(whiteFont);
            hStyle.setFillForegroundColor(blue);
            hStyle.setFillPattern(org.apache.poi.ss.usermodel.FillPatternType.SOLID_FOREGROUND);
            hStyle.setAlignment(org.apache.poi.ss.usermodel.HorizontalAlignment.CENTER);
            hStyle.setVerticalAlignment(org.apache.poi.ss.usermodel.VerticalAlignment.CENTER);
            hStyle.setBorderBottom(org.apache.poi.ss.usermodel.BorderStyle.MEDIUM);
            hStyle.setBorderRight(org.apache.poi.ss.usermodel.BorderStyle.THIN);

            org.apache.poi.xssf.usermodel.XSSFCellStyle dayStyle = wb.createCellStyle(); // weekday header
            dayStyle.setFont(whiteFont);
            dayStyle.setFillForegroundColor(blue);
            dayStyle.setFillPattern(org.apache.poi.ss.usermodel.FillPatternType.SOLID_FOREGROUND);
            dayStyle.setAlignment(org.apache.poi.ss.usermodel.HorizontalAlignment.CENTER);
            dayStyle.setVerticalAlignment(org.apache.poi.ss.usermodel.VerticalAlignment.CENTER);
            dayStyle.setBorderBottom(org.apache.poi.ss.usermodel.BorderStyle.MEDIUM);
            dayStyle.setBorderRight(org.apache.poi.ss.usermodel.BorderStyle.HAIR);
            dayStyle.setWrapText(false);

            org.apache.poi.xssf.usermodel.XSSFCellStyle wStyle = wb.createCellStyle(); // weekend header
            wStyle.setFont(redFont);
            wStyle.setFillForegroundColor(redBg);
            wStyle.setFillPattern(org.apache.poi.ss.usermodel.FillPatternType.SOLID_FOREGROUND);
            wStyle.setAlignment(org.apache.poi.ss.usermodel.HorizontalAlignment.CENTER);
            wStyle.setVerticalAlignment(org.apache.poi.ss.usermodel.VerticalAlignment.CENTER);
            wStyle.setBorderBottom(org.apache.poi.ss.usermodel.BorderStyle.MEDIUM);
            wStyle.setBorderRight(org.apache.poi.ss.usermodel.BorderStyle.HAIR);

            org.apache.poi.ss.usermodel.CellStyle cellStyle = wb.createCellStyle(); // data cell
            cellStyle.setAlignment(org.apache.poi.ss.usermodel.HorizontalAlignment.CENTER);
            cellStyle.setVerticalAlignment(org.apache.poi.ss.usermodel.VerticalAlignment.CENTER);
            cellStyle.setBorderRight(org.apache.poi.ss.usermodel.BorderStyle.HAIR);
            cellStyle.setBorderBottom(org.apache.poi.ss.usermodel.BorderStyle.HAIR);

            org.apache.poi.ss.usermodel.CellStyle wCellStyle = wb.createCellStyle(); // weekend data cell
            wCellStyle.setAlignment(org.apache.poi.ss.usermodel.HorizontalAlignment.CENTER);
            wCellStyle.setVerticalAlignment(org.apache.poi.ss.usermodel.VerticalAlignment.CENTER);
            wCellStyle.setFillForegroundColor(org.apache.poi.ss.usermodel.IndexedColors.ROSE.getIndex());
            wCellStyle.setFillPattern(org.apache.poi.ss.usermodel.FillPatternType.SOLID_FOREGROUND);
            wCellStyle.setBorderRight(org.apache.poi.ss.usermodel.BorderStyle.HAIR);
            wCellStyle.setBorderBottom(org.apache.poi.ss.usermodel.BorderStyle.HAIR);

            // Row 0: header — Mã NV | Họ tên | Phòng ban | [day numbers]
            org.apache.poi.ss.usermodel.Row hRow = s1.createRow(0);
            hRow.setHeight((short)(600));
            String[] fixedCols = {"Mã NV", "Họ và tên", "Phòng ban"};
            int[] fixedWidths = {14, 28, 20};
            for (int c = 0; c < fixedCols.length; c++) {
                org.apache.poi.ss.usermodel.Cell cell = hRow.createCell(c);
                cell.setCellValue(fixedCols[c]);
                cell.setCellStyle(hStyle);
                s1.setColumnWidth(c, fixedWidths[c] * 256);
            }
            for (int c = 0; c < dates.size(); c++) {
                LocalDate d = dates.get(c);
                boolean weekend = d.getDayOfWeek() == java.time.DayOfWeek.SATURDAY || d.getDayOfWeek() == java.time.DayOfWeek.SUNDAY;
                int dow = d.getDayOfWeek().getValue() % 7;
                org.apache.poi.ss.usermodel.Cell cell = hRow.createCell(fixedCols.length + c);
                cell.setCellValue(d.getDayOfMonth() + "/" + d.getMonthValue() + "\n" + WEEKDAY_VI[dow]);
                org.apache.poi.ss.usermodel.CellStyle cs = wb.createCellStyle();
                cs.cloneStyleFrom(weekend ? wStyle : dayStyle);
                cs.setWrapText(true);
                cell.setCellStyle(cs);
                s1.setColumnWidth(fixedCols.length + c, 6 * 256);
            }

            // Style cho 3 cột cố định — căn giữa dọc
            org.apache.poi.ss.usermodel.CellStyle fixedStyle = wb.createCellStyle();
            fixedStyle.setVerticalAlignment(org.apache.poi.ss.usermodel.VerticalAlignment.CENTER);
            fixedStyle.setBorderRight(org.apache.poi.ss.usermodel.BorderStyle.THIN);
            fixedStyle.setBorderBottom(org.apache.poi.ss.usermodel.BorderStyle.HAIR);

            // Data rows
            int rowIdx = 1;
            for (Long empId : grid.keySet()) {
                Map<LocalDate, List<String>> dayMap = grid.get(empId);
                // Tính chiều cao row: max số ca trong 1 ngày
                int maxCa = dayMap.values().stream().mapToInt(List::size).max().orElse(1);
                org.apache.poi.ss.usermodel.Row row = s1.createRow(rowIdx++);
                row.setHeight((short)(400 * maxCa));
                for (int fc = 0; fc < 3; fc++) {
                    String val = fc == 0 ? empCodes.getOrDefault(empId, "")
                               : fc == 1 ? empNames.getOrDefault(empId, "")
                               : empDepts.getOrDefault(empId, "");
                    org.apache.poi.ss.usermodel.Cell c = row.createCell(fc);
                    c.setCellValue(val);
                    c.setCellStyle(fixedStyle);
                }
                for (int c = 0; c < dates.size(); c++) {
                    LocalDate d = dates.get(c);
                    boolean weekend = d.getDayOfWeek() == java.time.DayOfWeek.SATURDAY || d.getDayOfWeek() == java.time.DayOfWeek.SUNDAY;
                    List<String> vals = dayMap.getOrDefault(d, List.of());
                    String val = String.join("\n", vals);
                    org.apache.poi.ss.usermodel.Cell cell = row.createCell(fixedCols.length + c);
                    if (!val.isEmpty()) cell.setCellValue(val); // ô trống → BLANK, COUNTIF không đếm
                    // wrapText nếu có nhiều ca
                    if (vals.size() > 1) {
                        org.apache.poi.ss.usermodel.CellStyle cs = wb.createCellStyle();
                        cs.cloneStyleFrom(weekend ? wCellStyle : cellStyle);
                        cs.setWrapText(true);
                        cs.setVerticalAlignment(org.apache.poi.ss.usermodel.VerticalAlignment.CENTER);
                        cell.setCellStyle(cs);
                    } else {
                        cell.setCellStyle(weekend ? wCellStyle : cellStyle);
                    }
                }
            }

            // ── Summary rows (Số người + Số giờ) ──
            int firstDataRow = 2; // row index 1-based: header=1, data từ 2
            int lastDataRow  = rowIdx; // rowIdx đã tăng sau vòng lặp data

            org.apache.poi.ss.usermodel.CellStyle summaryLabelStyle = wb.createCellStyle();
            summaryLabelStyle.cloneStyleFrom(fixedStyle);
            org.apache.poi.xssf.usermodel.XSSFFont summaryFont = wb.createFont();
            summaryFont.setBold(true);
            summaryLabelStyle.setFont(summaryFont);
            summaryLabelStyle.setFillForegroundColor(new org.apache.poi.xssf.usermodel.XSSFColor(
                new byte[]{(byte)0xE8, (byte)0xF0, (byte)0xFE}, null));
            summaryLabelStyle.setFillPattern(org.apache.poi.ss.usermodel.FillPatternType.SOLID_FOREGROUND);

            org.apache.poi.ss.usermodel.CellStyle summaryValStyle = wb.createCellStyle();
            summaryValStyle.setAlignment(org.apache.poi.ss.usermodel.HorizontalAlignment.CENTER);
            summaryValStyle.setVerticalAlignment(org.apache.poi.ss.usermodel.VerticalAlignment.CENTER);
            summaryValStyle.setBorderRight(org.apache.poi.ss.usermodel.BorderStyle.HAIR);
            summaryValStyle.setBorderTop(org.apache.poi.ss.usermodel.BorderStyle.MEDIUM);
            summaryValStyle.setFillForegroundColor(new org.apache.poi.xssf.usermodel.XSSFColor(
                new byte[]{(byte)0xE8, (byte)0xF0, (byte)0xFE}, null));
            summaryValStyle.setFillPattern(org.apache.poi.ss.usermodel.FillPatternType.SOLID_FOREGROUND);
            summaryValStyle.setFont(summaryFont);

            // Row: Số người
            org.apache.poi.ss.usermodel.Row rowCount = s1.createRow(rowIdx++);
            org.apache.poi.ss.usermodel.Cell countLabel = rowCount.createCell(0);
            countLabel.setCellValue("Số người");
            countLabel.setCellStyle(summaryLabelStyle);
            rowCount.createCell(1).setCellStyle(summaryLabelStyle);
            rowCount.createCell(2).setCellStyle(summaryLabelStyle);
            for (int c = 0; c < dates.size(); c++) {
                String colLetter = colLetter(fixedCols.length + c + 1);
                String formula = String.format("COUNTIF(%s%d:%s%d,\"<>\")",
                    colLetter, firstDataRow, colLetter, lastDataRow);
                org.apache.poi.ss.usermodel.Cell cell = rowCount.createCell(fixedCols.length + c);
                cell.setCellFormula(formula);
                cell.setCellStyle(summaryValStyle);
            }

            // Row: Số giờ — dùng placeholder, sẽ patch XML sau
            org.apache.poi.ss.usermodel.Row rowHours = s1.createRow(rowIdx++);
            org.apache.poi.ss.usermodel.Cell hoursLabel = rowHours.createCell(0);
            hoursLabel.setCellValue("Số giờ");
            hoursLabel.setCellStyle(summaryLabelStyle);
            rowHours.createCell(1).setCellStyle(summaryLabelStyle);
            rowHours.createCell(2).setCellStyle(summaryLabelStyle);
            org.apache.poi.ss.usermodel.CellStyle hoursValStyle = wb.createCellStyle();
            hoursValStyle.cloneStyleFrom(summaryValStyle);
            hoursValStyle.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("0.0"));
            String s2Name = excelI18n.resolve("excel.sheet.shift.list", locale);
            String s3Name = "_calc_hours";
            org.apache.poi.ss.usermodel.Sheet s3 = wb.createSheet(s3Name);
            java.util.Map<String, String> formulaPatches = new java.util.LinkedHashMap<>();
            int hoursRowNum = rowHours.getRowNum() + 1;
            for (int c = 0; c < dates.size(); c++) {
                String colLetter = colLetter(fixedCols.length + c + 1);
                String cellRef = colLetter + hoursRowNum;
                org.apache.poi.xssf.usermodel.XSSFCell cell =
                    (org.apache.poi.xssf.usermodel.XSSFCell) rowHours.createCell(fixedCols.length + c);
                cell.setCellValue(0.0);
                cell.setCellStyle(hoursValStyle);
                String realFormula = String.format("SUM('%s'!%s%d:%s%d)/60",
                    s3Name, colLetter, firstDataRow, colLetter, lastDataRow);
                formulaPatches.put(cellRef, realFormula);
            }

            // Freeze 3 cột đầu, freeze hàng header
            s1.createFreezePane(3, 1);

            // ── Sheet 2: Danh sách ca ──
            org.apache.poi.ss.usermodel.Sheet s2 = wb.createSheet(s2Name);
            org.apache.poi.ss.usermodel.Row s2Header = s2.createRow(0);
            // Cột J (index 9): Phút làm — dùng để SUMIF từ sheet phân công
            String[] shiftCols = shiftListHeaders(locale);
            for (int c = 0; c < shiftCols.length; c++) {
                org.apache.poi.ss.usermodel.Cell cell = s2Header.createCell(c);
                cell.setCellValue(shiftCols[c]);
                cell.setCellStyle(hStyle);
                s2.setColumnWidth(c, 20 * 256);
            }
            // Ẩn cột J (Phút làm)
            //s2.setColumnHidden(9, true); // tạm bỏ để debug

            int si = 1;
            for (WorkShift sh : shifts) {
                org.apache.poi.ss.usermodel.Row row = s2.createRow(si++);
                row.createCell(0).setCellValue(sh.getCode());
                row.createCell(1).setCellValue(sh.getName());
                row.createCell(2).setCellValue(sh.getStartTime() != null ? sh.getStartTime().format(TIME_FMT) : "");
                row.createCell(3).setCellValue(sh.getEndTime() != null ? sh.getEndTime().format(TIME_FMT) : "");
                row.createCell(4).setCellValue(sh.getBreakStart() != null ? sh.getBreakStart().format(TIME_FMT) : "");
                row.createCell(5).setCellValue(sh.getBreakEnd() != null ? sh.getBreakEnd().format(TIME_FMT) : "");
                row.createCell(6).setCellValue(sh.getGroupName() != null ? sh.getGroupName() : "");
                row.createCell(7).setCellValue(sh.getColor());
                row.createCell(8).setCellValue(sh.getDepartments().stream().map(Department::getCode).collect(Collectors.joining(",")));
                // Cột J: phút làm tính sẵn từ backend (để SUMIF lấy được ngay)
                int workMinutes = 0;
                if (sh.getStartTime() != null && sh.getEndTime() != null) {
                    workMinutes = (int) java.time.Duration.between(sh.getStartTime(), sh.getEndTime()).toMinutes();
                    if (sh.getBreakStart() != null && sh.getBreakEnd() != null) {
                        workMinutes -= (int) java.time.Duration.between(sh.getBreakStart(), sh.getBreakEnd()).toMinutes();
                    }
                    workMinutes = Math.max(0, workMinutes);
                }
                row.createCell(9).setCellValue(workMinutes);
            }

            int helperTokenStartCol = fixedCols.length + dates.size();
            for (int r = firstDataRow; r <= lastDataRow; r++) {
                org.apache.poi.ss.usermodel.Row helperRow = s3.createRow(r - 1);
                for (int c = 0; c < dates.size(); c++) {
                    int colIndex = fixedCols.length + c;
                    String visibleRef = "'" + s1.getSheetName() + "'!" + colLetter(colIndex + 1) + r;
                    int tokenBaseCol = helperTokenStartCol + (c * 5);
                    for (int tokenIndex = 1; tokenIndex <= 5; tokenIndex++) {
                        org.apache.poi.ss.usermodel.Cell tokenCell = helperRow.createCell(tokenBaseCol + tokenIndex - 1);
                        tokenCell.setCellFormula(buildHoursTokenTerm(s2Name, visibleRef, tokenIndex));
                    }
                    org.apache.poi.ss.usermodel.Cell helperTotalCell = helperRow.createCell(colIndex);
                    helperTotalCell.setCellFormula(String.format("SUM(%s%d:%s%d)",
                        colLetter(tokenBaseCol + 1), r, colLetter(tokenBaseCol + 5), r));
                }
            }
            wb.setSheetHidden(wb.getSheetIndex(s3), true);

            for (java.util.Map.Entry<String, String> p : formulaPatches.entrySet()) {
                String ref = p.getKey();
                String col = ref.replaceAll("[0-9]", "");
                int rowN = Integer.parseInt(ref.replaceAll("[A-Z]", "")) - 1;
                int colN = 0;
                for (char ch : col.toCharArray()) colN = colN * 26 + (ch - 'A' + 1);
                colN--;
                org.apache.poi.ss.usermodel.Row r = s1.getRow(rowN);
                if (r != null) {
                    org.apache.poi.ss.usermodel.Cell fc = r.getCell(colN);
                    if (fc != null) fc.setCellFormula(p.getValue());
                }
            }
            wb.setForceFormulaRecalculation(true);            java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
            wb.write(out);
            // Patch workbook.xml để Excel nhận diện file Excel 365 (hỗ trợ LAMBDA/MAP/LET)
            byte[] bytes = patchWorkbook(out.toByteArray());

            String filenameBase = excelI18n.resolve("excel.file.shift", locale);
            return com.bosskin.util.ExcelUtils.buildFileResponse(filenameBase, bytes);
        } catch (java.io.IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    @Transactional(readOnly = true)
    public ResponseEntity<byte[]> exportShiftListOnly(Long companyId, java.util.Locale locale) {
        List<WorkShift> shifts = shiftRepo.findByCompanyIdAndActiveTrue(companyId);
        try (org.apache.poi.xssf.usermodel.XSSFWorkbook wb = new org.apache.poi.xssf.usermodel.XSSFWorkbook()) {
            wb.setCellFormulaValidation(false);

            org.apache.poi.xssf.usermodel.XSSFColor blue = new org.apache.poi.xssf.usermodel.XSSFColor(
                new byte[]{(byte)0x21, (byte)0x5C, (byte)0x98}, null);
            org.apache.poi.xssf.usermodel.XSSFFont whiteFont = wb.createFont();
            whiteFont.setBold(true);
            whiteFont.setColor(new org.apache.poi.xssf.usermodel.XSSFColor(
                new byte[]{(byte)0xFF, (byte)0xFF, (byte)0xFF}, null));
            org.apache.poi.xssf.usermodel.XSSFCellStyle hStyle = wb.createCellStyle();
            hStyle.setFont(whiteFont);
            hStyle.setFillForegroundColor(blue);
            hStyle.setFillPattern(org.apache.poi.ss.usermodel.FillPatternType.SOLID_FOREGROUND);
            hStyle.setAlignment(org.apache.poi.ss.usermodel.HorizontalAlignment.CENTER);
            hStyle.setVerticalAlignment(org.apache.poi.ss.usermodel.VerticalAlignment.CENTER);

            String sheetListName = excelI18n.resolve("excel.sheet.shift.list", locale);
            org.apache.poi.ss.usermodel.Sheet sheet = wb.createSheet(sheetListName);
            org.apache.poi.ss.usermodel.Row header = sheet.createRow(0);
            String[] cols = shiftListHeaders(locale);
            for (int c = 0; c < cols.length; c++) {
                org.apache.poi.ss.usermodel.Cell cell = header.createCell(c);
                cell.setCellValue(cols[c]);
                cell.setCellStyle(hStyle);
                sheet.setColumnWidth(c, 20 * 256);
            }

            int si = 1;
            for (WorkShift sh : shifts) {
                org.apache.poi.ss.usermodel.Row row = sheet.createRow(si++);
                row.createCell(0).setCellValue(sh.getCode());
                row.createCell(1).setCellValue(sh.getName());
                row.createCell(2).setCellValue(sh.getStartTime() != null ? sh.getStartTime().format(TIME_FMT) : "");
                row.createCell(3).setCellValue(sh.getEndTime() != null ? sh.getEndTime().format(TIME_FMT) : "");
                row.createCell(4).setCellValue(sh.getBreakStart() != null ? sh.getBreakStart().format(TIME_FMT) : "");
                row.createCell(5).setCellValue(sh.getBreakEnd() != null ? sh.getBreakEnd().format(TIME_FMT) : "");
                row.createCell(6).setCellValue(sh.getGroupName() != null ? sh.getGroupName() : "");
                row.createCell(7).setCellValue(sh.getColor());
                row.createCell(8).setCellValue(sh.getDepartments().stream().map(Department::getCode).collect(Collectors.joining(",")));
                int workMinutes = 0;
                if (sh.getStartTime() != null && sh.getEndTime() != null) {
                    workMinutes = (int) java.time.Duration.between(sh.getStartTime(), sh.getEndTime()).toMinutes();
                    if (sh.getBreakStart() != null && sh.getBreakEnd() != null)
                        workMinutes -= (int) java.time.Duration.between(sh.getBreakStart(), sh.getBreakEnd()).toMinutes();
                    workMinutes = Math.max(0, workMinutes);
                }
                row.createCell(9).setCellValue(workMinutes);
            }

            wb.setForceFormulaRecalculation(true);
            java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
            wb.write(out);
            byte[] bytes = out.toByteArray();
            String filenameBase = excelI18n.resolve("excel.file.shift.list", locale);
            return com.bosskin.util.ExcelUtils.buildFileResponse(filenameBase, bytes);
        } catch (java.io.IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ─── Preview import ca làm ───────────────────────────────────────────────

    @lombok.Data @lombok.Builder
    public static class ShiftDiff {
        private String action; // CREATE | UPDATE | NO_CHANGE
        private String code;
        private String name;
        private java.util.List<FieldChange> changes;
        private java.util.List<String> warnings;
    }

    @lombok.Data @lombok.Builder
    public static class ImportPreviewBundle {
        private java.util.List<ShiftDiff> diffs;
        private java.util.List<String> sectionLabels;
        private java.util.List<Integer> sectionCounts;
    }

    @lombok.Data @lombok.AllArgsConstructor
    public static class FieldChange {
        private String field;
        private String oldValue;
        private String newValue;
    }

    @Transactional(readOnly = true)
    public List<ShiftDiff> previewImport(Long companyId, MultipartFile file) {
        String listSheet = findShiftListSheetName(file);
        if (listSheet == null) return List.of();
        List<ShiftRow> rows = ExcelUtils.importRowsByHeader(file, listSheet, IMPORT_COLUMNS, ShiftRow::new, excelI18n);
        Map<String, WorkShift> existingMap = shiftRepo.findByCompanyIdAndActiveTrue(companyId)
            .stream().collect(Collectors.toMap(WorkShift::getCode, s -> s, (a, b) -> a));

        List<ShiftDiff> result = new ArrayList<>();
        for (ShiftRow row : rows) {
            if (row.code == null || row.code.isBlank()) continue;
            if (row.name == null || row.name.isBlank()) continue;
            String code = row.code.trim();
            WorkShift existing = existingMap.get(code);
            List<FieldChange> changes = new ArrayList<>();
            List<String> warnings = new ArrayList<>();

            if (existing == null) {
                result.add(ShiftDiff.builder().action("CREATE").code(code).name(row.name.trim())
                    .changes(changes).warnings(warnings).build());
            } else {
                addChange(changes, "Tên ca", existing.getName(), row.name);
                addChange(changes, "Giờ bắt đầu", fmt(existing.getStartTime()), row.startTime);
                addChange(changes, "Giờ kết thúc", fmt(existing.getEndTime()), row.endTime);
                addChange(changes, "Nghỉ giải lao từ", fmt(existing.getBreakStart()), row.breakStart);
                addChange(changes, "Nghỉ giải lao đến", fmt(existing.getBreakEnd()), row.breakEnd);
                addChange(changes, "Nhóm ca", nvl(existing.getGroupName()), nvl(row.groupName));
                addChange(changes, "Màu", nvl(existing.getColor()), nvl(row.color));
                addChange(changes, "Phòng ban",
                    existing.getDepartments().stream()
                        .map(Department::getCode)
                        .filter(Objects::nonNull)
                        .sorted(String.CASE_INSENSITIVE_ORDER)
                        .collect(Collectors.joining(",")),
                    normalizeDeptCodes(row.deptCodes));
                result.add(ShiftDiff.builder()
                    .action(changes.isEmpty() ? "NO_CHANGE" : "UPDATE")
                    .code(code).name(row.name.trim())
                    .changes(changes).warnings(warnings).build());
            }
        }
        return result;
    }

    @Transactional
    public Map<String, Integer> importFromExcel(Long companyId, MultipartFile file) {
        String listSheet = findShiftListSheetName(file);
        if (listSheet == null) return Map.of("created", 0, "updated", 0);
        List<ShiftRow> rows = ExcelUtils.importRowsByHeader(file, listSheet, IMPORT_COLUMNS, ShiftRow::new, excelI18n);
        Map<String, Department> deptMap = deptRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(Department::getCode, d -> d, (a, b) -> a));
        Map<String, WorkShift> existingMap = shiftRepo.findByCompanyIdAndActiveTrue(companyId)
            .stream().collect(Collectors.toMap(WorkShift::getCode, s -> s, (a, b) -> a));

        int created = 0, updated = 0;
        for (ShiftRow row : rows) {
            if (row.code == null || row.code.isBlank()) continue;
            if (row.name == null || row.name.isBlank()) continue;

            List<Long> deptIds = parseDeptIds(row.deptCodes, deptMap);
            ShiftDTO.ShiftRequest req = new ShiftDTO.ShiftRequest(
                row.name.trim(), row.code.trim(),
                parseTime(row.startTime), parseTime(row.endTime),
                parseTime(row.breakStart), parseTime(row.breakEnd),
                row.groupName != null && !row.groupName.isBlank() ? row.groupName.trim() : null,
                row.color != null && !row.color.isBlank() ? row.color.trim() : "#1976D2",
                deptIds
            );

            WorkShift existing = existingMap.get(row.code.trim());
            if (existing != null) { shiftService.updateShift(existing.getId(), companyId, req); updated++; }
            else { shiftService.createShift(companyId, req); created++; }
        }
        return Map.of("created", created, "updated", updated);
    }

    // ─── Import trực tiếp từ List<ShiftRow> (dùng bởi UniversalExcelService) ──

    @Transactional
    public List<com.bosskin.util.SheetImportResult.RowResult> importRowsDirect(
            Long companyId,
            List<ShiftRow> rows,
            List<com.bosskin.util.ImportCommand> commands,
            boolean dryRun) {

        Map<String, Department> deptMap = deptRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(Department::getCode, d -> d, (a, b) -> a));
        Map<String, WorkShift> existingMap = shiftRepo.findByCompanyIdAndActiveTrue(companyId)
            .stream().collect(Collectors.toMap(WorkShift::getCode, s -> s, (a, b) -> a));

        List<com.bosskin.util.SheetImportResult.RowResult> results = new ArrayList<>();
        for (int i = 0; i < rows.size(); i++) {
            ShiftRow row = rows.get(i);
            com.bosskin.util.ImportCommand cmd = commands.get(i);
            int rowNum = i + 2;

            if (row.code == null || row.code.isBlank()) {
                results.add(com.bosskin.util.SheetImportResult.RowResult.error(rowNum, "error.shift.code_required"));
                continue;
            }

            try {
                WorkShift existing = existingMap.get(row.code.trim());

                if (cmd == com.bosskin.util.ImportCommand.DELETE) {
                    if (!dryRun && existing != null) {
                        shiftService.deleteShift(existing.getId(), companyId);
                    }
                    results.add(com.bosskin.util.SheetImportResult.RowResult.ok(rowNum));
                    continue;
                }

                if (row.name == null || row.name.isBlank()) {
                    results.add(com.bosskin.util.SheetImportResult.RowResult.error(rowNum, "error.shift.name_required"));
                    continue;
                }

                List<Long> deptIds = parseDeptIds(row.deptCodes, deptMap);
                ShiftDTO.ShiftRequest req = new ShiftDTO.ShiftRequest(
                    row.name.trim(), row.code.trim(),
                    parseTime(row.startTime), parseTime(row.endTime),
                    parseTime(row.breakStart), parseTime(row.breakEnd),
                    row.groupName != null && !row.groupName.isBlank() ? row.groupName.trim() : null,
                    row.color != null && !row.color.isBlank() ? row.color.trim() : "#1976D2",
                    deptIds
                );

                // NO_CHANGE check
                if (existing != null) {
                    boolean sameName  = req.getName().equals(existing.getName());
                    boolean sameStart = java.util.Objects.equals(req.getStartTime(), existing.getStartTime());
                    boolean sameEnd   = java.util.Objects.equals(req.getEndTime(),   existing.getEndTime());
                    boolean sameGroup = java.util.Objects.equals(req.getGroupName(), existing.getGroupName());
                    boolean sameColor = java.util.Objects.equals(req.getColor(),     existing.getColor());
                    if (sameName && sameStart && sameEnd && sameGroup && sameColor) {
                        results.add(com.bosskin.util.SheetImportResult.RowResult.of(rowNum, "OK", "preview.noChange"));
                        continue;
                    }
                    if (dryRun) {
                        java.util.List<String> parts = new java.util.ArrayList<>();
                        if (!sameName)  parts.add("name: " + existing.getName() + " → " + req.getName());
                        if (!sameStart) parts.add("startTime: " + existing.getStartTime() + " → " + req.getStartTime());
                        if (!sameEnd)   parts.add("endTime: "   + existing.getEndTime()   + " → " + req.getEndTime());
                        if (!sameGroup) parts.add("group: " + existing.getGroupName() + " → " + req.getGroupName());
                        if (!sameColor) parts.add("color: " + existing.getColor() + " → " + req.getColor());
                        results.add(com.bosskin.util.SheetImportResult.RowResult.of(rowNum, "OK", String.join(" | ", parts)));
                        continue;
                    }
                }

                if (!dryRun) {
                    if (existing != null) shiftService.updateShift(existing.getId(), companyId, req);
                    else shiftService.createShift(companyId, req);
                }
                results.add(com.bosskin.util.SheetImportResult.RowResult.ok(rowNum));
            } catch (Exception e) {
                results.add(com.bosskin.util.SheetImportResult.RowResult.error(rowNum, e.getMessage()));
            }
        }
        return results;
    }

    // ─── Import phân công ca từ sheet 0 (bảng ngang) ─────────────────────────

    @lombok.Value
    public static class AssignCell {
        String empCode; String empName;
        /** null = ô trống → xóa assignment nếu có */
        String shiftCode;
        java.time.LocalDate date;
    }

    @lombok.Value
    private static class AssignDayKey {
        String empCode;
        String empName;
        java.time.LocalDate date;
    }

    private List<AssignCell> readAssignSheet(MultipartFile file, Long companyId) {
        try (java.io.InputStream is = file.getInputStream();
             org.apache.poi.xssf.usermodel.XSSFWorkbook wb = new org.apache.poi.xssf.usermodel.XSSFWorkbook(is)) {

            org.apache.poi.ss.usermodel.Sheet sheet = wb.getSheetAt(0);
            org.apache.poi.ss.usermodel.DataFormatter formatter = new org.apache.poi.ss.usermodel.DataFormatter();
            org.apache.poi.ss.usermodel.Row headerRow = sheet.getRow(0);
            if (headerRow == null) return List.of();

            // Parse năm từ tên sheet "Phan cong ca MM-yyyy"
            String sheetName = sheet.getSheetName();
            int sheetYear;
            try {
                String[] parts = sheetName.replace("Phan cong ca ", "").split("-");
                if (parts.length < 2) throw new IllegalArgumentException();
                sheetYear = Integer.parseInt(parts[1]);
            } catch (Exception e) {
                throw new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.BAD_REQUEST,
                        "error.shift.invalid_sheet_name");
            }

            // Header cell format: "day/month\nWeekday" — đọc day và month trực tiếp
            List<java.time.LocalDate> dates = new ArrayList<>();
            List<Integer> dateCols = new ArrayList<>();
            for (int c = 3; c < headerRow.getLastCellNum(); c++) {
                org.apache.poi.ss.usermodel.Cell cell = headerRow.getCell(c);
                if (cell == null) continue;
                String raw = formatter.formatCellValue(cell).trim();
                // Lấy phần trước "\n": "26/5"
                String dayMonthPart = raw.contains("\n") ? raw.substring(0, raw.indexOf('\n')).trim() : raw.trim();
                if (dayMonthPart.isBlank()) continue;
                try {
                    String[] dm = dayMonthPart.split("/");
                    int day   = Integer.parseInt(dm[0].trim());
                    int month = Integer.parseInt(dm[1].trim());
                    // Tháng 12 trong kỳ tháng 1 thuộc năm trước
                    int year = (month == 12 && sheetYear > 2000) ? sheetYear - 1 : sheetYear;
                    dates.add(java.time.LocalDate.of(year, month, day));
                    dateCols.add(c);
                } catch (Exception ignored) {}
            }

            List<AssignCell> cells = new ArrayList<>();
            int lastDataRow = Math.max(1, sheet.getLastRowNum() - 2);
            for (int r = 1; r <= lastDataRow; r++) {
                org.apache.poi.ss.usermodel.Row row = sheet.getRow(r);
                if (row == null) continue;
                org.apache.poi.ss.usermodel.Cell empCell = row.getCell(0);
                org.apache.poi.ss.usermodel.Cell nameCell = row.getCell(1);
                if (empCell == null) continue;
                String empCode = formatter.formatCellValue(empCell).trim();
                String empName = nameCell != null ? formatter.formatCellValue(nameCell).trim() : empCode;
                if (empCode.isBlank()) continue;
                for (int ci = 0; ci < dateCols.size(); ci++) {
                    org.apache.poi.ss.usermodel.Cell cell = row.getCell(dateCols.get(ci));
                    String raw = (cell == null) ? null : formatter.formatCellValue(cell).trim();
                    if (raw == null || raw.isBlank()) {
                        // Ô trống → xóa tất cả ca ngày đó
                        cells.add(new AssignCell(empCode, empName, null, dates.get(ci)));
                    } else {
                        // Nhiều ca ngăn cách bằng \n
                        for (String part : raw.split("\n")) {
                            String code = part.trim();
                            if (!code.isBlank())
                                cells.add(new AssignCell(empCode, empName, code, dates.get(ci)));
                        }
                    }
                }
            }
            return cells;
        } catch (java.io.IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }
    }

    @Transactional(readOnly = true)
    public ImportPreviewBundle previewAssignments(Long companyId, Long userId, MultipartFile file) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "SHIFT_VIEW");
        List<ShiftDiff> shiftDiffs = new ArrayList<>();
        Map<String, ShiftRow> importedShiftRows = new LinkedHashMap<>();
        String listSheet = findShiftListSheetName(file);
        if (listSheet != null) {
            for (ShiftRow row : ExcelUtils.importRowsByHeader(file, listSheet, IMPORT_COLUMNS, ShiftRow::new, excelI18n)) {
                if (row.code == null || row.code.isBlank()) continue;
                importedShiftRows.put(row.code.trim(), row);
            }
            shiftDiffs.addAll(previewImport(companyId, file));
        }

        List<AssignCell> cells = readAssignSheet(file, companyId);
        if (cells.isEmpty()) {
            return ImportPreviewBundle.builder()
                .diffs(shiftDiffs)
                .sectionLabels(new ArrayList<>(java.util.List.of("Danh sách ca", "Phân công ca")))
                .sectionCounts(new ArrayList<>(java.util.List.of(shiftDiffs.size(), 0)))
                .build();
        }

        Map<AssignDayKey, List<String>> grouped = groupAssignCells(cells);
        Map<String, WorkShift> shiftMap = shiftRepo.findByCompanyIdAndActiveTrue(companyId)
            .stream().collect(Collectors.toMap(WorkShift::getCode, s -> s, (a, b) -> a));
        Map<String, com.bosskin.entity.Employee> empMap = employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            .stream()
            .filter(e -> scopeIds.isEmpty() || (e.getDepartment() != null && scopeIds.contains(e.getDepartment().getId())))
            .collect(Collectors.toMap(com.bosskin.entity.Employee::getEmployeeCode, e -> e, (a, b) -> a));
        // empId -> date -> Set<label> (hỗ trợ nhiều ca/ngày)
        Map<Long, Map<java.time.LocalDate, java.util.Set<String>>> existingLabelMap = new HashMap<>();
        assignRepo.findByCompanyAndDateRange(companyId,
            grouped.keySet().stream().map(AssignDayKey::getDate).min(Comparator.naturalOrder()).orElse(java.time.LocalDate.now()),
            grouped.keySet().stream().map(AssignDayKey::getDate).max(Comparator.naturalOrder()).orElse(java.time.LocalDate.now()))
            .forEach(a -> {
                Long empId = a.getEmployee().getId();
                String label;
                if (a.getShift() != null) {
                    label = a.getShift().getCode();
                } else if (a.getCustomStartTime() != null && a.getCustomEndTime() != null) {
                    label = formatCustomTime(a.getCustomStartTime(), a.getCustomEndTime(),
                        a.getCustomBreakStart(), a.getCustomBreakEnd());
                } else {
                    label = "?";
                }
                existingLabelMap.computeIfAbsent(empId, k -> new HashMap<>())
                    .computeIfAbsent(a.getWorkDate(), k -> new java.util.LinkedHashSet<>())
                    .add(label);
            });

        java.time.format.DateTimeFormatter ddMM = java.time.format.DateTimeFormatter.ofPattern("dd/MM");
        List<ShiftDiff> assignmentDiffs = new ArrayList<>();
        for (Map.Entry<AssignDayKey, List<String>> entry : grouped.entrySet()) {
            AssignDayKey day = entry.getKey();
            com.bosskin.entity.Employee emp = empMap.get(day.getEmpCode());
            List<String> warnings = new ArrayList<>();
            if (emp == null) warnings.add("Không tìm thấy nhân viên: " + day.getEmpCode());

            String action = "NO_CHANGE";
            List<FieldChange> changes = new ArrayList<>();
            java.util.LinkedHashSet<String> desiredSet = new java.util.LinkedHashSet<>();
            List<String> desiredDisplay = new ArrayList<>();
            for (String raw : entry.getValue()) {
                if (raw == null || raw.isBlank()) continue;
                WorkShift shift = shiftMap.get(raw);
                if (shift != null || importedShiftRows.containsKey(raw)) {
                    desiredSet.add(shift != null ? shift.getCode() : raw);
                    desiredDisplay.add(raw);
                    continue;
                }
                LocalTime[] custom = parseCustomTime(raw);
                if (custom == null) {
                    warnings.add("Không tìm thấy ca: " + raw);
                    continue;
                }
                desiredSet.add(formatCustomTime(custom[0], custom[1], custom[2], custom[3]));
                desiredDisplay.add(raw);
            }

            if (emp != null) {
                Map<java.time.LocalDate, java.util.Set<String>> dateMap = existingLabelMap.getOrDefault(emp.getId(), Map.of());
                java.util.Set<String> existingSet = dateMap.getOrDefault(day.getDate(), java.util.Set.of());
                boolean hasExisting = !existingSet.isEmpty();

                if (desiredSet.isEmpty()) {
                    if (hasExisting) action = "DELETE";
                    else if (warnings.isEmpty()) continue;
                } else {
                    if (existingSet.equals(desiredSet)) action = "NO_CHANGE";
                    else action = hasExisting ? "UPDATE" : "CREATE";
                }

                if (!existingSet.equals(desiredSet)) {
                    changes.add(new FieldChange(
                        "Ca làm",
                        String.join(", ", existingSet),
                        String.join(", ", desiredDisplay)
                    ));
                }
            }

            // Bỏ qua NO_CHANGE không có warnings
            if (action.equals("NO_CHANGE") && warnings.isEmpty()) continue;

            java.util.Set<String> existingSet2 = emp != null
                ? existingLabelMap.getOrDefault(emp.getId(), Map.of()).getOrDefault(day.getDate(), java.util.Set.of())
                : java.util.Set.of();
            String label = day.getEmpName() + " — " + day.getDate().format(ddMM)
                + (desiredSet.isEmpty()
                ? " (xóa ca " + String.join(", ", existingSet2) + ")"
                : " → " + String.join(", ", desiredDisplay));
            assignmentDiffs.add(ShiftDiff.builder()
                .action(action).code(day.getEmpCode()).name(label)
                .changes(changes).warnings(warnings).build());
        }
        List<ShiftDiff> combined = new ArrayList<>(shiftDiffs.size() + assignmentDiffs.size());
        combined.addAll(shiftDiffs);
        combined.addAll(assignmentDiffs);
        return ImportPreviewBundle.builder()
            .diffs(combined)
            .sectionLabels(new ArrayList<>(java.util.List.of("Danh sách ca", "Phân công ca")))
            .sectionCounts(new ArrayList<>(java.util.List.of(shiftDiffs.size(), assignmentDiffs.size())))
            .build();
    }

    public Map<String, Integer> importAssignments(Long companyId, Long userId, MultipartFile file) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "SHIFT_VIEW");
        int createdShifts = 0;
        int updatedShifts = 0;
        if (findShiftListSheetName(file) != null) {
            Map<String, Integer> shiftResult = importFromExcel(companyId, file);
            createdShifts = shiftResult.getOrDefault("created", 0);
            updatedShifts = shiftResult.getOrDefault("updated", 0);
        }

        List<AssignCell> cells = readAssignSheet(file, companyId);
        if (cells.isEmpty()) {
            return Map.of(
                "created", createdShifts,
                "updated", updatedShifts,
                "assigned", 0,
                "deleted", 0,
                "skipped", 0
            );
        }

        Map<AssignDayKey, List<String>> grouped = groupAssignCells(cells);
        Map<String, com.bosskin.entity.Employee> empMap = employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            .stream()
            .filter(e -> scopeIds.isEmpty() || (e.getDepartment() != null && scopeIds.contains(e.getDepartment().getId())))
            .collect(Collectors.toMap(com.bosskin.entity.Employee::getEmployeeCode, e -> e, (a, b) -> a));
        Map<String, WorkShift> shiftMap = shiftRepo.findByCompanyIdAndActiveTrue(companyId)
            .stream().collect(Collectors.toMap(WorkShift::getCode, s -> s, (a, b) -> a));

        int created = 0, deleted = 0, skipped = 0;
        for (Map.Entry<AssignDayKey, List<String>> entry : grouped.entrySet()) {
            AssignDayKey day = entry.getKey();
            com.bosskin.entity.Employee emp = empMap.get(day.getEmpCode());
            if (emp == null) { skipped++; continue; }
            try {
                List<String> desired = entry.getValue().stream()
                    .filter(Objects::nonNull)
                    .map(String::trim)
                    .filter(s -> !s.isBlank())
                    .toList();
                List<ShiftDTO.AssignRequest> requests = new ArrayList<>();
                boolean invalid = false;
                for (String raw : desired) {
                    WorkShift shift = shiftMap.get(raw);
                    if (shift != null) {
                        requests.add(new ShiftDTO.AssignRequest(
                            emp.getId(), shift.getId(), day.getDate(), null, null, null, null, null));
                        continue;
                    }
                    LocalTime[] custom = parseCustomTime(raw);
                    if (custom == null) { invalid = true; break; }
                    requests.add(new ShiftDTO.AssignRequest(
                        emp.getId(), null, day.getDate(), null,
                        custom[0], custom[1], custom[2], custom[3]));
                }
                if (invalid) { skipped++; continue; }

                List<ShiftAssignment> existing = assignRepo.findByEmployeeIdAndWorkDate(emp.getId(), day.getDate());

                deleteOneInNewTx(emp.getId(), day.getDate(), companyId);
                deleted += existing.size();

                for (ShiftDTO.AssignRequest req : requests) {
                    assignOneInNewTx(companyId, req);
                    created++;
                }
            } catch (Exception ignored) { skipped++; }
        }
        return Map.of(
            "created", createdShifts,
            "updated", updatedShifts,
            "assigned", created,
            "deleted", deleted,
            "skipped", skipped
        );
    }

    /** Tên cột sheet "Danh sach ca" theo locale — gồm cả cột Phút làm (internal). */
    private String[] shiftListHeaders(java.util.Locale locale) {
        return new String[]{
            excelI18n.resolve("excel.col.shift.code",      locale),
            excelI18n.resolve("excel.col.shift.name",      locale),
            excelI18n.resolve("excel.col.shift.startTime", locale),
            excelI18n.resolve("excel.col.shift.endTime",   locale),
            excelI18n.resolve("excel.col.shift.breakStart",locale),
            excelI18n.resolve("excel.col.shift.breakEnd",  locale),
            excelI18n.resolve("excel.col.shift.groupName", locale),
            excelI18n.resolve("excel.col.shift.color",     locale),
            excelI18n.resolve("excel.col.shift.deptCodes", locale),
            "Phut lam" // internal column — not user-facing, kept as fixed key
        };
    }

    /**
     * Tìm tên sheet "Danh sach ca" trong file theo bất kỳ locale nào.
     * Trả về tên sheet thực tế trong file, null nếu không tìm thấy.
     */
    private String findShiftListSheetName(MultipartFile file) {
        List<String> candidates = excelI18n.allValues("excel.sheet.shift.list");
        try (java.io.InputStream is = file.getInputStream();
             org.apache.poi.xssf.usermodel.XSSFWorkbook wb = new org.apache.poi.xssf.usermodel.XSSFWorkbook(is)) {
            for (String name : candidates) {
                if (wb.getSheet(name) != null) return name;
            }
            return null;
        } catch (java.io.IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }
    }


    private Map<AssignDayKey, List<String>> groupAssignCells(List<AssignCell> cells) {
        Map<AssignDayKey, List<String>> grouped = new LinkedHashMap<>();
        for (AssignCell cell : cells) {
            AssignDayKey key = new AssignDayKey(cell.getEmpCode(), cell.getEmpName(), cell.getDate());
            grouped.computeIfAbsent(key, k -> new ArrayList<>()).add(cell.getShiftCode());
        }
        return grouped;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void assignOneInNewTx(Long companyId, ShiftDTO.AssignRequest req) {
        shiftService.assign(companyId, req, null);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void deleteOneInNewTx(Long employeeId, java.time.LocalDate date, Long companyId) {
        shiftService.deleteAssignment(employeeId, date, companyId);
    }

    // Format: "HH:MM~HH:MM" hoặc "HH:MM~HH:MM(HH:MM-HH:MM)" với break
    private static final java.util.regex.Pattern CUSTOM_TIME_PATTERN =
        java.util.regex.Pattern.compile(
            "^(\\d{1,2}(?::\\d{2})?)\\s*[~-]\\s*(\\d{1,2}(?::\\d{2})?)(?:\\((\\d{1,2}(?::\\d{2})?)\\s*[~-]\\s*(\\d{1,2}(?::\\d{2})?)\\))?$");
    // Legacy format: "HH:MM-HH:MM" (không có break, dùng - thay ~)
    private static final java.util.regex.Pattern CUSTOM_TIME_LEGACY =
        java.util.regex.Pattern.compile("^(\\d{1,2}(?::\\d{2})?)\\s*[-]\\s*(\\d{1,2}(?::\\d{2})?)$");

    /** Trả về [start, end, breakStart|null, breakEnd|null] hoặc null nếu không parse được */
    /** Unzip xlsx, patch sheet1.xml: thay string cell chứa placeholder bằng formula cell */
    private static byte[] patchWorkbook(byte[] xlsx) throws java.io.IOException {
        java.io.ByteArrayOutputStream result = new java.io.ByteArrayOutputStream();
        try (java.util.zip.ZipInputStream zin = new java.util.zip.ZipInputStream(new java.io.ByteArrayInputStream(xlsx));
             java.util.zip.ZipOutputStream zout = new java.util.zip.ZipOutputStream(result)) {
            java.util.zip.ZipEntry entry;
            boolean hasCalcChain = false;
            StringBuilder calcChainEntries = new StringBuilder();
            while ((entry = zin.getNextEntry()) != null) {
                if (entry.getName().equals("xl/calcChain.xml")) hasCalcChain = true;
                byte[] data = zin.readAllBytes();
                if (entry.getName().equals("xl/worksheets/sheet1.xml")) {
                    String xml = new String(data, java.nio.charset.StandardCharsets.UTF_8);
                    // Thêm namespaces từ template để Excel nhận biết dynamic array, tránh @
                    xml = xml.replace("<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
                        "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" " +
                        "xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" " +
                        "mc:Ignorable=\"x14ac xr xr2 xr3\" " +
                        "xmlns:x14ac=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac\" " +
                        "xmlns:xr=\"http://schemas.microsoft.com/office/spreadsheetml/2014/revision\" " +
                        "xmlns:xr2=\"http://schemas.microsoft.com/office/spreadsheetml/2015/revision2\" " +
                        "xmlns:xr3=\"http://schemas.microsoft.com/office/spreadsheetml/2016/revision3\"");
                    data = xml.getBytes(java.nio.charset.StandardCharsets.UTF_8);
                }
                if (entry.getName().equals("xl/_rels/workbook.xml.rels")) {
                    String xml = new String(data, java.nio.charset.StandardCharsets.UTF_8);
                    if (!xml.contains("metadata")) {
                        xml = xml.replace("</Relationships>",
                            "<Relationship Id=\"rIdMeta\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/sheetMetadata\" Target=\"metadata.xml\"/></Relationships>");
                    }
                    data = xml.getBytes(java.nio.charset.StandardCharsets.UTF_8);
                }
                if (entry.getName().equals("[Content_Types].xml")) {
                    String xml = new String(data, java.nio.charset.StandardCharsets.UTF_8);
                    if (!xml.contains("calcChain")) {
                        xml = xml.replace("</Types>",
                            "<Override PartName=\"/xl/calcChain.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.calcChain+xml\"/></Types>");
                    }
                    if (!xml.contains("metadata")) {
                        xml = xml.replace("</Types>",
                            "<Override PartName=\"/xl/metadata.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheetMetadata+xml\"/></Types>");
                    }
                    data = xml.getBytes(java.nio.charset.StandardCharsets.UTF_8);
                }
                if (entry.getName().equals("xl/workbook.xml")) {
                    String xml = new String(data, java.nio.charset.StandardCharsets.UTF_8);
                    if (!xml.contains("fileVersion")) {
                        xml = xml.replace("<workbookPr",
                            "<fileVersion appName=\"xl\" lastEdited=\"7\" lowestEdited=\"7\" rupBuild=\"29929\"/><workbookPr");
                    }
                    if (!xml.contains("calcPr")) {
                        xml = xml.replace("</workbook>", "<calcPr calcId=\"191029\"/></workbook>");
                    }
                    // Thêm calcFeatures để Excel nhận biết dynamic array (tránh @ implicit intersection)
                    if (!xml.contains("calcFeatures")) {
                        xml = xml.replace("</workbook>",
                            "<extLst>" +
                            "<ext uri=\"{B58B0392-4F1F-4190-BB64-5DF3571DCE5F}\" xmlns:xcalcf=\"http://schemas.microsoft.com/office/spreadsheetml/2018/calcfeatures\">" +
                            "<xcalcf:calcFeatures>" +
                            "<xcalcf:feature name=\"microsoft.com:RD\"/>" +
                            "<xcalcf:feature name=\"microsoft.com:Single\"/>" +
                            "<xcalcf:feature name=\"microsoft.com:FV\"/>" +
                            "<xcalcf:feature name=\"microsoft.com:CNMTM\"/>" +
                            "<xcalcf:feature name=\"microsoft.com:LET_WF\"/>" +
                            "<xcalcf:feature name=\"microsoft.com:LAMBDA_WF\"/>" +
                            "<xcalcf:feature name=\"microsoft.com:ARRAYTEXT_WF\"/>" +
                            "</xcalcf:calcFeatures></ext></extLst>" +
                            "</workbook>");
                    }
                    data = xml.getBytes(java.nio.charset.StandardCharsets.UTF_8);
                }
                java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(entry.getName());
                zout.putNextEntry(newEntry);
                zout.write(data);
                zout.closeEntry();
            }
            // Thêm metadata.xml để bật dynamic array (tắt @ implicit intersection)
            zout.putNextEntry(new java.util.zip.ZipEntry("xl/metadata.xml"));
            String metadata = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
                "<metadata xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" " +
                "xmlns:xda=\"http://schemas.microsoft.com/office/spreadsheetml/2017/dynamicarray\">" +
                "<metadataTypes count=\"1\"><metadataType name=\"XLDAPR\" minSupportedVersion=\"120000\" " +
                "copy=\"1\" pasteAll=\"1\" pasteValues=\"1\" merge=\"1\" splitFirst=\"1\" rowColShift=\"1\" " +
                "clearFormats=\"1\" clearComments=\"1\" assign=\"1\" coerce=\"1\" cellMeta=\"1\"/></metadataTypes>" +
                "<futureMetadata name=\"XLDAPR\" count=\"1\"><bk><extLst>" +
                "<ext uri=\"{bdbb8cdc-fa1e-496e-a857-3c3f30c029c3}\">" +
                "<xda:dynamicArrayProperties fDynamic=\"1\" fCollapsed=\"0\"/></ext></extLst></bk></futureMetadata>" +
                "<cellMetadata count=\"1\"><bk><rc t=\"1\" v=\"0\"/></bk></cellMetadata></metadata>";
            zout.write(metadata.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            zout.closeEntry();

            if (!hasCalcChain) {
                zout.putNextEntry(new java.util.zip.ZipEntry("xl/calcChain.xml"));
                String calcChain = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
                    "<calcChain xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
                    calcChainEntries.toString() + "</calcChain>";
                zout.write(calcChain.getBytes(java.nio.charset.StandardCharsets.UTF_8));
                zout.closeEntry();
            }
        }
        return result.toByteArray();
    }

    private static String colLetter(int colNum) { // 1-based
        StringBuilder sb = new StringBuilder();
        while (colNum > 0) {
            colNum--;
            sb.insert(0, (char)('A' + colNum % 26));
            colNum /= 26;
        }
        return sb.toString();
    }

    /** Public wrapper để các descriptor khác gọi được */
    public LocalTime[] parseCustomTimePublic(String val) { return parseCustomTime(val); }

    private LocalTime[] parseCustomTime(String val) {
        if (val == null) return null;
        String v = val.trim();
        java.util.regex.Matcher m = CUSTOM_TIME_PATTERN.matcher(v);
        if (m.matches()) {
            try {
                LocalTime start      = parseFlexTime(m.group(1));
                LocalTime end        = parseFlexTime(m.group(2));
                LocalTime breakStart = m.group(3) != null ? parseFlexTime(m.group(3)) : null;
                LocalTime breakEnd   = m.group(4) != null ? parseFlexTime(m.group(4)) : null;
                return new LocalTime[]{start, end, breakStart, breakEnd};
            } catch (Exception e) { return null; }
        }
        // Legacy: "HH:MM-HH:MM"
        java.util.regex.Matcher leg = CUSTOM_TIME_LEGACY.matcher(v);
        if (leg.matches()) {
            try {
                return new LocalTime[]{parseFlexTime(leg.group(1)), parseFlexTime(leg.group(2)), null, null};
            } catch (Exception e) { return null; }
        }
        return null;
    }

    private String formatCustomTime(LocalTime start, LocalTime end, LocalTime breakStart, LocalTime breakEnd) {
        String base = start.format(TIME_FMT) + "~" + end.format(TIME_FMT);
        if (breakStart != null && breakEnd != null)
            base += "(" + breakStart.format(TIME_FMT) + "~" + breakEnd.format(TIME_FMT) + ")";
        return base;
    }

    private Integer calcWorkMinutes(LocalTime start, LocalTime end, LocalTime breakStart, LocalTime breakEnd) {
        if (start == null || end == null) return null;
        int total = (int) java.time.Duration.between(start, end).toMinutes();
        if (breakStart != null && breakEnd != null) {
            total -= (int) java.time.Duration.between(breakStart, breakEnd).toMinutes();
        }
        return Math.max(0, total);
    }

    private String buildHoursFormula(String sheetName, int colIndex, int firstDataRow, int lastDataRow) {
        String colLetter = colLetter(colIndex + 1);
        StringBuilder formula = new StringBuilder("SUM(");
        for (int row = firstDataRow; row <= lastDataRow; row++) {
            if (row > firstDataRow) formula.append(",");
            String ref = colLetter + row;
            formula.append(buildHoursTerm(sheetName, ref));
        }
        formula.append(")");
        return formula.toString();
    }

    private String buildHoursTerm(String sheetName, String ref) {
        StringBuilder formula = new StringBuilder("IF(" + ref + "=\"\",0,(");
        for (int i = 1; i <= 5; i++) {
            if (i > 1) formula.append("+");
            formula.append(buildHoursTokenTerm(sheetName, ref, i));
        }
        formula.append(")/60)");
        return formula.toString();
    }

    private String buildHoursTokenTerm(String sheetName, String ref, int tokenIndex) {
        String tokenExpr = String.format(
            "TRIM(MID(SUBSTITUTE(%1$s,CHAR(10),REPT(\" \",99)),%2$d,99))",
            ref, ((tokenIndex - 1) * 99) + 1);
        String normalizedTokenExpr = String.format("SUBSTITUTE(%s,\"~\",\"-\")", tokenExpr);
        String startRaw = String.format("LEFT(%1$s,FIND(\"-\",%1$s)-1)", normalizedTokenExpr);
        String endRaw = String.format(
            "MID(%1$s,FIND(\"-\",%1$s)+1,IFERROR(FIND(\"(\",%1$s),LEN(%1$s)+1)-FIND(\"-\",%1$s)-1)",
            normalizedTokenExpr);
        String breakStartRaw = String.format(
            "MID(%1$s,FIND(\"(\",%1$s)+1,FIND(\"-\",%1$s,FIND(\"(\",%1$s))-FIND(\"(\",%1$s)-1)",
            normalizedTokenExpr);
        String breakEndRaw = String.format(
            "MID(%1$s,FIND(\"-\",%1$s,FIND(\"(\",%1$s))+1,FIND(\")\",%1$s)-FIND(\"-\",%1$s,FIND(\"(\",%1$s))-1)",
            normalizedTokenExpr);
        String startTime = String.format("TIMEVALUE(IF(ISNUMBER(SEARCH(\":\",%1$s)),%1$s,%1$s&\":00\"))", startRaw);
        String endTime = String.format("TIMEVALUE(IF(ISNUMBER(SEARCH(\":\",%1$s)),%1$s,%1$s&\":00\"))", endRaw);
        String breakStartTime = String.format("TIMEVALUE(IF(ISNUMBER(SEARCH(\":\",%1$s)),%1$s,%1$s&\":00\"))", breakStartRaw);
        String breakEndTime = String.format("TIMEVALUE(IF(ISNUMBER(SEARCH(\":\",%1$s)),%1$s,%1$s&\":00\"))", breakEndRaw);
        return String.format(
            "IF(%1$s=\"\",0,IFERROR(VLOOKUP(%1$s,'%2$s'!A:J,10,FALSE),IF(ISNUMBER(SEARCH(\"-\",%3$s)),(MOD(%4$s-%5$s,1)-IFERROR(MOD(%6$s-%7$s,1),0))*1440,0)))",
            tokenExpr, sheetName, normalizedTokenExpr, endTime, startTime, breakEndTime, breakStartTime);
    }

    private LocalTime parseFlexTime(String s) {
        return s.contains(":") ? LocalTime.parse(s, TIME_FMT)
                               : LocalTime.of(Integer.parseInt(s), 0);
    }

    private void addChange(List<FieldChange> changes, String field, String oldVal, String newVal) {
        String o = nvl(oldVal); String n = nvl(newVal);
        if (!o.equals(n)) changes.add(new FieldChange(field, o, n));
    }
    private String fmt(java.time.LocalTime t) { return t != null ? t.format(TIME_FMT) : ""; }
    private String nvl(String s) { return s != null ? s.trim() : ""; }

    private LocalTime parseTime(String val) {
        if (val == null || val.isBlank()) return null;
        try {
            return LocalTime.parse(val.trim(), TIME_FMT);
        } catch (Exception e) {
            return null;
        }
    }

    private List<Long> parseDeptIds(String deptCodes, Map<String, Department> deptMap) {
        if (deptCodes == null || deptCodes.isBlank()) return List.of();
        return Arrays.stream(deptCodes.split(","))
            .map(String::trim)
            .filter(c -> !c.isBlank())
            .map(deptMap::get)
            .filter(Objects::nonNull)
            .map(Department::getId)
            .collect(Collectors.toList());
    }

    private String normalizeDeptCodes(String deptCodes) {
        if (deptCodes == null || deptCodes.isBlank()) return "";
        return Arrays.stream(deptCodes.split(","))
            .map(String::trim)
            .filter(c -> !c.isBlank())
            .sorted(String.CASE_INSENSITIVE_ORDER)
            .collect(Collectors.joining(","));
    }
}
