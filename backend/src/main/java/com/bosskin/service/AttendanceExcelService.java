package com.bosskin.service;

import com.bosskin.dto.AttendanceDTO;
import com.bosskin.entity.Attendance;
import com.bosskin.entity.Department;
import com.bosskin.entity.Employee;
import com.bosskin.entity.ExcelHistory.HistoryType;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import com.bosskin.util.ExcelI18n;
import com.bosskin.util.ExcelUtils;
import com.bosskin.util.ImportCommand;
import com.bosskin.util.SheetImportResult;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.*;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;
import java.util.Arrays;

@Service
@RequiredArgsConstructor
public class AttendanceExcelService {

    private final AttendanceRepository attendanceRepo;
    private final EmployeeRepository employeeRepo;
    private final DepartmentRepository deptRepo;
    private final DeptScopeService deptScopeService;
    private final ShiftAssignmentRepository shiftAssignmentRepo;
    private final ExcelI18n excelI18n;
    private final ExcelHistoryHelper historyHelper;

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");
    private static final DateTimeFormatter SHEET_DATE_FMT = DateTimeFormatter.ofPattern("MM-yyyy");
    private static final String[] WEEKDAY_VI = {"CN", "T2", "T3", "T4", "T5", "T6", "T7"};

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    // ── Universal Export (for UniversalExcelService) ─────────────────────────

    @Transactional(readOnly = true)
    public List<AttendanceDTO.ImportRow> loadAllForExport(Long companyId, Long userId,
                                                           Map<String, String> filters) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "ATTENDANCE_VIEW");

        String deptCodesRaw = filters.getOrDefault("departmentCodes", "");
        if (!deptCodesRaw.isBlank()) {
            Set<Long> pickedIds = Arrays.stream(deptCodesRaw.split(","))
                .map(String::trim).filter(c -> !c.isEmpty())
                .map(code -> deptRepo.findByCodeAndCompanyId(code, companyId))
                .filter(Optional::isPresent).map(opt -> opt.get().getId())
                .collect(Collectors.toSet());
            if (pickedIds.isEmpty()) return List.of();
            final Set<Long> scope = scopeIds;
            scopeIds = scope.isEmpty() ? pickedIds
                : pickedIds.stream().filter(scope::contains).collect(Collectors.toSet());
            if (scopeIds.isEmpty()) return List.of();
        }

        // Date range: default current month
        LocalDate from;
        LocalDate to;
        String yearStr  = filters.getOrDefault("year",  "");
        String monthStr = filters.getOrDefault("month", "");
        if (!yearStr.isBlank() && !monthStr.isBlank()) {
            try {
                int y = Integer.parseInt(yearStr.trim());
                int m = Integer.parseInt(monthStr.trim());
                from = LocalDate.of(y, m, 1);
                to   = from.withDayOfMonth(from.lengthOfMonth());
            } catch (Exception e) {
                from = LocalDate.now().withDayOfMonth(1);
                to   = from.withDayOfMonth(from.lengthOfMonth());
            }
        } else {
            from = LocalDate.now().withDayOfMonth(1);
            to   = from.withDayOfMonth(from.lengthOfMonth());
        }

        final Set<Long> finalScopeIds = scopeIds;
        Long deptId = null;
        if (finalScopeIds.size() == 1) deptId = finalScopeIds.iterator().next();

        List<Attendance> list;
        if (!finalScopeIds.isEmpty() && deptId == null) {
            list = attendanceRepo.findByCompanyAndDateRange(companyId, from, to)
                .stream()
                .filter(a -> a.getEmployee() != null
                    && a.getEmployee().getDepartment() != null
                    && finalScopeIds.contains(a.getEmployee().getDepartment().getId()))
                .collect(Collectors.toList());
        } else {
            list = attendanceRepo.findByCompanyAndDateRangeAndDept(companyId, from, to, deptId);
        }

        String statusFilter = filters.getOrDefault("status", "");
        if (!statusFilter.isBlank() && !statusFilter.equals("ALL")) {
            Attendance.Status s;
            try { s = Attendance.Status.valueOf(statusFilter.trim()); } catch (Exception e) { s = null; }
            final Attendance.Status fs = s;
            if (fs != null) list = list.stream().filter(a -> fs.equals(a.getStatus())).collect(Collectors.toList());
        }

        String empCode = filters.getOrDefault("employeeCode", "").trim();
        if (!empCode.isBlank()) {
            list = list.stream()
                .filter(a -> a.getEmployee() != null && empCode.equalsIgnoreCase(a.getEmployee().getEmployeeCode()))
                .collect(Collectors.toList());
        }

        // Filter: search (comma-separated employee codes từ pick)
        String searchRaw = filters.getOrDefault("search", "").trim();
        if (!searchRaw.isBlank()) {
            Set<String> codes = Arrays.stream(searchRaw.split(","))
                .map(String::trim).filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());
            list = list.stream()
                .filter(a -> a.getEmployee() != null && codes.contains(a.getEmployee().getEmployeeCode()))
                .collect(Collectors.toList());
        }

        return list.stream().map(this::toUniversalRow).collect(Collectors.toList());
    }

    private AttendanceDTO.ImportRow toUniversalRow(Attendance a) {
        Employee emp = a.getEmployee();
        var row = new AttendanceDTO.ImportRow();
        row.setDate(a.getDate() != null ? a.getDate().format(DATE_FMT) : "");
        row.setEmployeeCode(emp != null ? nvlStr(emp.getEmployeeCode()) : "");
        row.setEmployeeName(emp != null ? nvlStr(emp.getFullName()) : "");
        row.setDepartmentName(emp != null && emp.getDepartment() != null
            ? nvlStr(emp.getDepartment().getName()) : "");
        row.setStatus(a.getStatus() != null ? a.getStatus().name() : "");
        row.setCheckIn(a.getCheckIn() != null ? a.getCheckIn().toLocalTime().format(TIME_FMT) : "");
        row.setCheckOut(a.getCheckOut() != null ? a.getCheckOut().toLocalTime().format(TIME_FMT) : "");
        row.setNote(nvlStr(a.getNote()));
        row.setOverrideCheckIn(a.getOverrideCheckIn() != null ? a.getOverrideCheckIn().format(TIME_FMT) : "");
        row.setOverrideCheckOut(a.getOverrideCheckOut() != null ? a.getOverrideCheckOut().format(TIME_FMT) : "");
        row.setOverrideBreakMinutes(a.getOverrideBreakMinutes() != null ? String.valueOf(a.getOverrideBreakMinutes()) : "");
        row.setOverrideOtDayMinutes(a.getOverrideOtDayMinutes() != null ? String.valueOf(a.getOverrideOtDayMinutes()) : "");
        row.setOverrideOtNightMinutes(a.getOverrideOtNightMinutes() != null ? String.valueOf(a.getOverrideOtNightMinutes()) : "");
        row.setSnapActualHours(a.getSnapActualHours() != null ? String.format("%.2f", a.getSnapActualHours()) : "");
        row.setSnapDayOt(a.getSnapDayOt() != null ? String.format("%.2f", a.getSnapDayOt()) : "");
        row.setSnapNightOt(a.getSnapNightOt() != null ? String.format("%.2f", a.getSnapNightOt()) : "");
        row.setApproved(a.isApproved() ? "true" : "false");
        return row;
    }

    // ── Universal Import (for UniversalExcelService) ─────────────────────────

    @Transactional
    public SheetImportResult.RowResult previewUniversalRow(Long companyId, Long userId,
                                                            AttendanceDTO.ImportRow row,
                                                            ImportCommand cmd) {
        try {
            validateUniversalRow(row);
            Employee emp = resolveEmployee(companyId, row.getEmployeeCode());
            LocalDate date = parseDateStr(row.getDate());
            Optional<Attendance> existing = attendanceRepo.findByEmployeeIdAndDate(emp.getId(), date)
                .stream().findFirst();
            return switch (cmd) {
                case CREATE -> existing.isPresent()
                    ? SheetImportResult.RowResult.warn(0, "warning.attendance.already_exists")
                    : SheetImportResult.RowResult.ok(0);
                case UPDATE -> existing.isEmpty()
                    ? SheetImportResult.RowResult.warn(0, "warning.attendance.not_found")
                    : SheetImportResult.RowResult.ok(0);
                case MERGE  -> existing.isEmpty()
                    ? SheetImportResult.RowResult.ok(0)
                    : attendanceNoChange(existing.get(), row)
                        ? SheetImportResult.RowResult.of(0, "OK", "preview.noChange")
                        : SheetImportResult.RowResult.ok(0);
                case DELETE -> existing.isEmpty()
                    ? SheetImportResult.RowResult.warn(0, "warning.attendance.not_found")
                    : SheetImportResult.RowResult.ok(0);
            };
        } catch (Exception e) {
            return SheetImportResult.RowResult.error(0, e.getMessage());
        }
    }

    @Transactional
    public boolean importUniversalRow(Long companyId, Long userId, AttendanceDTO.ImportRow row,
                                       ImportCommand cmd, Set<String> presentColumns) {
        validateUniversalRow(row);
        Employee emp  = resolveEmployee(companyId, row.getEmployeeCode());
        LocalDate date = parseDateStr(row.getDate());
        Optional<Attendance> existing = attendanceRepo.findByEmployeeIdAndDate(emp.getId(), date)
            .stream().findFirst();

        if (cmd == ImportCommand.DELETE) {
            existing.ifPresent(a -> { a.setDeleted(true); attendanceRepo.save(a); });
            return existing.isPresent();
        }
        if (cmd == ImportCommand.CREATE && existing.isPresent()) return false;

        Attendance a = existing.orElseGet(() -> Attendance.builder().employee(emp).date(date).build());

        if (hasCol(presentColumns, "excel.col.attendance.status") && notBlank(row.getStatus()))
            try { a.setStatus(Attendance.Status.valueOf(row.getStatus().trim().toUpperCase())); } catch (Exception ignored) {}
        if (hasCol(presentColumns, "excel.col.attendance.checkIn") && notBlank(row.getCheckIn()))
            a.setCheckIn(date.atTime(parseTimeStr(row.getCheckIn())));
        if (hasCol(presentColumns, "excel.col.attendance.checkOut") && notBlank(row.getCheckOut()))
            a.setCheckOut(date.atTime(parseTimeStr(row.getCheckOut())));
        if (hasCol(presentColumns, "excel.col.attendance.note") && row.getNote() != null)
            a.setNote(row.getNote());
        if (hasCol(presentColumns, "excel.col.attendance.overrideCheckIn") && notBlank(row.getOverrideCheckIn()))
            a.setOverrideCheckIn(parseTimeStr(row.getOverrideCheckIn()));
        if (hasCol(presentColumns, "excel.col.attendance.overrideCheckOut") && notBlank(row.getOverrideCheckOut()))
            a.setOverrideCheckOut(parseTimeStr(row.getOverrideCheckOut()));
        if (hasCol(presentColumns, "excel.col.attendance.overrideBreakMinutes") && notBlank(row.getOverrideBreakMinutes()))
            try { a.setOverrideBreakMinutes(Integer.parseInt(row.getOverrideBreakMinutes().trim())); } catch (Exception ignored) {}
        if (hasCol(presentColumns, "excel.col.attendance.overrideOtDayMinutes") && notBlank(row.getOverrideOtDayMinutes()))
            try { a.setOverrideOtDayMinutes(Integer.parseInt(row.getOverrideOtDayMinutes().trim())); } catch (Exception ignored) {}
        if (hasCol(presentColumns, "excel.col.attendance.overrideOtNightMinutes") && notBlank(row.getOverrideOtNightMinutes()))
            try { a.setOverrideOtNightMinutes(Integer.parseInt(row.getOverrideOtNightMinutes().trim())); } catch (Exception ignored) {}

        attendanceRepo.save(a);
        return true;
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private void validateUniversalRow(AttendanceDTO.ImportRow row) {
        if (row.getDate() == null || row.getDate().isBlank())
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.BAD_REQUEST, "error.attendance.date_required");
        if (row.getEmployeeCode() == null || row.getEmployeeCode().isBlank())
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.BAD_REQUEST, "error.employee.code_required");
        parseDateStr(row.getDate());
    }

    private Employee resolveEmployee(Long companyId, String code) {
        return employeeRepo.findByEmployeeCodeAndCompanyId(code.trim(), companyId)
            .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.NOT_FOUND, "error.employee.not_found:" + code));
    }

    private LocalDate parseDateStr(String s) {
        try { return LocalDate.parse(s.trim(), DATE_FMT); }
        catch (java.time.format.DateTimeParseException e) {
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.BAD_REQUEST, "error.attendance.invalid_date:" + s);
        }
    }

    private LocalTime parseTimeStr(String s) {
        try { return LocalTime.parse(s.trim(), TIME_FMT); }
        catch (java.time.format.DateTimeParseException e) {
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.BAD_REQUEST, "error.attendance.invalid_time:" + s);
        }
    }

    private static boolean hasCol(Set<String> cols, String key) {
        return cols == null || cols.isEmpty() || cols.contains(key);
    }

    private static boolean notBlank(String s) { return s != null && !s.isBlank(); }

    private static String nvlStr(String s) { return s != null ? s : ""; }

    private boolean attendanceNoChange(Attendance a, AttendanceDTO.ImportRow row) {
        String rowStatus = row.getStatus() != null ? row.getStatus().trim() : "";
        String curStatus = a.getStatus() != null ? a.getStatus().name() : "";
        if (!rowStatus.isEmpty() && !rowStatus.equalsIgnoreCase(curStatus)) return false;
        if (!nvlStr(row.getNote()).equals(nvlStr(a.getNote()))) return false;
        if (!eqOverrideTime(row.getOverrideCheckIn(),  a.getOverrideCheckIn()))  return false;
        if (!eqOverrideTime(row.getOverrideCheckOut(), a.getOverrideCheckOut())) return false;
        if (!eqOverrideInt(row.getOverrideBreakMinutes(),    a.getOverrideBreakMinutes()))    return false;
        if (!eqOverrideInt(row.getOverrideOtDayMinutes(),    a.getOverrideOtDayMinutes()))    return false;
        if (!eqOverrideInt(row.getOverrideOtNightMinutes(),  a.getOverrideOtNightMinutes()))  return false;
        return true;
    }

    private boolean eqOverrideTime(String rowVal, java.time.LocalTime curVal) {
        if (rowVal == null || rowVal.isBlank()) return curVal == null;
        try { return parseTimeStr(rowVal).equals(curVal); } catch (Exception e) { return false; }
    }

    private boolean eqOverrideInt(String rowVal, Integer curVal) {
        if (rowVal == null || rowVal.isBlank()) return curVal == null;
        try { return Integer.parseInt(rowVal.trim()) == (curVal != null ? curVal : 0); } catch (Exception e) { return false; }
    }

    // ── Export ──────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public ResponseEntity<byte[]> exportAttendance(Long companyId, Long userId,
                                                    LocalDate from, LocalDate to,
                                                    List<Long> departmentIds) {
        java.util.Locale locale = LocaleContextHolder.getLocale();
        List<LocalDate> dates = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) dates.add(d);

        // Resolve scope
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "ATTENDANCE_VIEW");

        // All active employees in scope
        List<Employee> allEmps = employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            .stream()
            .filter(e -> e.getStatus() == Employee.Status.ACTIVE)
            .filter(e -> scopeIds.isEmpty() || (e.getDepartment() != null && scopeIds.contains(e.getDepartment().getId())))
            .filter(e -> departmentIds == null || departmentIds.isEmpty()
                || (e.getDepartment() != null && departmentIds.contains(e.getDepartment().getId())))
            .sorted(Comparator.comparing(Employee::getFullName))
            .collect(Collectors.toList());

        // Fetch attendances for the month
        List<Attendance> attendances = attendanceRepo.findByCompanyAndDateRange(companyId, from, to);
        // empId -> date -> Attendance (one per date as per unique constraint)
        Map<Long, Map<LocalDate, Attendance>> grid = new HashMap<>();
        for (Attendance a : attendances) {
            grid.computeIfAbsent(a.getEmployee().getId(), k -> new HashMap<>())
                .put(a.getDate(), a);
        }

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            wb.setCellFormulaValidation(false);

            XSSFColor blue = new XSSFColor(new byte[]{(byte)0x21,(byte)0x5C,(byte)0x98}, null);
            XSSFColor red  = new XSSFColor(new byte[]{(byte)0xDC,(byte)0x26,(byte)0x26}, null);
            XSSFColor redBg= new XSSFColor(new byte[]{(byte)0xFE,(byte)0xE2,(byte)0xE2}, null);

            XSSFFont whiteFont = wb.createFont();
            whiteFont.setBold(true);
            whiteFont.setColor(new XSSFColor(new byte[]{(byte)0xFF,(byte)0xFF,(byte)0xFF}, null));

            XSSFFont redFont = wb.createFont();
            redFont.setBold(true);
            redFont.setColor(red);

            XSSFCellStyle hStyle = wb.createCellStyle();
            hStyle.setFont(whiteFont);
            hStyle.setFillForegroundColor(blue);
            hStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            hStyle.setAlignment(HorizontalAlignment.CENTER);
            hStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            hStyle.setBorderBottom(BorderStyle.MEDIUM);
            hStyle.setBorderRight(BorderStyle.THIN);
            hStyle.setWrapText(true);

            XSSFCellStyle wStyle = wb.createCellStyle();
            wStyle.setFont(redFont);
            wStyle.setFillForegroundColor(redBg);
            wStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            wStyle.setAlignment(HorizontalAlignment.CENTER);
            wStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            wStyle.setBorderBottom(BorderStyle.MEDIUM);
            wStyle.setBorderRight(BorderStyle.HAIR);
            wStyle.setWrapText(true);

            XSSFCellStyle dayStyle = wb.createCellStyle();
            dayStyle.setFont(whiteFont);
            dayStyle.setFillForegroundColor(blue);
            dayStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            dayStyle.setAlignment(HorizontalAlignment.CENTER);
            dayStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            dayStyle.setBorderBottom(BorderStyle.MEDIUM);
            dayStyle.setBorderRight(BorderStyle.HAIR);
            dayStyle.setWrapText(true);

            CellStyle cellStyle = wb.createCellStyle();
            cellStyle.setAlignment(HorizontalAlignment.CENTER);
            cellStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            cellStyle.setBorderRight(BorderStyle.HAIR);
            cellStyle.setBorderBottom(BorderStyle.HAIR);

            CellStyle wCellStyle = wb.createCellStyle();
            wCellStyle.setAlignment(HorizontalAlignment.CENTER);
            wCellStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            wCellStyle.setFillForegroundColor(IndexedColors.ROSE.getIndex());
            wCellStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            wCellStyle.setBorderRight(BorderStyle.HAIR);
            wCellStyle.setBorderBottom(BorderStyle.HAIR);

            CellStyle fixedStyle = wb.createCellStyle();
            fixedStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            fixedStyle.setBorderRight(BorderStyle.THIN);
            fixedStyle.setBorderBottom(BorderStyle.HAIR);

            String sheetName = sanitizeSheetName(
                excelI18n.resolve("excel.sheet.attendance.month", locale, to.format(SHEET_DATE_FMT)));
            Sheet sheet = wb.createSheet(sheetName);

            // Header row
            Row hRow = sheet.createRow(0);
            hRow.setHeight((short)600);
            String[] fixedCols = {
                excelI18n.resolve("excel.col.attendance.empCode",   locale),
                excelI18n.resolve("excel.col.attendance.empName",   locale),
                excelI18n.resolve("excel.col.attendance.department",locale)
            };
            int[] fixedWidths  = {14, 28, 20};
            for (int c = 0; c < fixedCols.length; c++) {
                Cell cell = hRow.createCell(c);
                cell.setCellValue(fixedCols[c]);
                cell.setCellStyle(hStyle);
                sheet.setColumnWidth(c, fixedWidths[c] * 256);
            }
            for (int c = 0; c < dates.size(); c++) {
                LocalDate d = dates.get(c);
                boolean weekend = d.getDayOfWeek() == java.time.DayOfWeek.SATURDAY
                    || d.getDayOfWeek() == java.time.DayOfWeek.SUNDAY;
                int dow = d.getDayOfWeek().getValue() % 7;
                Cell cell = hRow.createCell(fixedCols.length + c);
                cell.setCellValue(d.getDayOfMonth() + "/" + d.getMonthValue() + "\n" + WEEKDAY_VI[dow] + "\n*");
                cell.setCellStyle(weekend ? wStyle : dayStyle);
                sheet.setColumnWidth(fixedCols.length + c, 12 * 256);
            }

            // Data rows
            int rowIdx = 1;
            for (Employee emp : allEmps) {
                Row row = sheet.createRow(rowIdx++);
                row.setHeight((short)400);

                Cell c0 = row.createCell(0); c0.setCellValue(emp.getEmployeeCode()); c0.setCellStyle(fixedStyle);
                Cell c1 = row.createCell(1); c1.setCellValue(emp.getFullName()); c1.setCellStyle(fixedStyle);
                Cell c2 = row.createCell(2);
                c2.setCellValue(emp.getDepartment() != null ? emp.getDepartment().getName() : "");
                c2.setCellStyle(fixedStyle);

                Map<LocalDate, Attendance> dayMap = grid.getOrDefault(emp.getId(), Map.of());
                for (int c = 0; c < dates.size(); c++) {
                    LocalDate d = dates.get(c);
                    boolean weekend = d.getDayOfWeek() == java.time.DayOfWeek.SATURDAY
                        || d.getDayOfWeek() == java.time.DayOfWeek.SUNDAY;
                    Attendance att = dayMap.get(d);
                    String cellVal = formatCellValue(att);
                    Cell cell = row.createCell(fixedCols.length + c);
                    if (!cellVal.isEmpty()) cell.setCellValue(cellVal);
                    cell.setCellStyle(weekend ? wCellStyle : cellStyle);
                }
            }

            // Freeze 3 columns + header row
            sheet.createFreezePane(3, 1);
            autoSizeAll(sheet, fixedCols.length + dates.size());

            wb.setForceFormulaRecalculation(true);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            wb.write(out);
            byte[] bytes = out.toByteArray();

            String filenameBase = excelI18n.resolve("excel.file.attendance.month", locale)
                + "-" + from.format(DateTimeFormatter.ofPattern("ddMMyyyy"))
                + "-" + to.format(DateTimeFormatter.ofPattern("ddMMyyyy"));
            historyHelper.save(companyId, userId, HistoryType.EXPORT, "attendance",
                    filenameBase + ".xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse(filenameBase, bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    private String formatCellValue(Attendance att) {
        if (att == null) return "";
        if (att.getStatus() == Attendance.Status.LEAVE) return "LEAVE";
        if (att.getStatus() == Attendance.Status.ABSENT) return "ABSENT";

        // Prefer override check-in/out, fall back to actual
        LocalTime ci = att.getOverrideCheckIn();
        LocalTime co = att.getOverrideCheckOut();
        if (ci == null && att.getCheckIn() != null)  ci = att.getCheckIn().toLocalTime();
        if (co == null && att.getCheckOut() != null) co = att.getCheckOut().toLocalTime();

        if (ci != null && co != null) return ci.format(TIME_FMT) + "~" + co.format(TIME_FMT);
        if (ci != null) return ci.format(TIME_FMT) + "~";
        return att.getStatus() != null ? att.getStatus().name() : "";
    }

    // ── Export Timesheet (ngày × cột — giống màn hình Theo tháng) ────────────

    public ResponseEntity<byte[]> exportTimesheetRange(
            Long companyId, Long userId,
            String employeeName, String employeeCode,
            LocalDate from, LocalDate to,
            List<com.bosskin.dto.AttendanceDTO.TimesheetRow> rows,
            boolean dayNightMode, boolean otEnabled,
            java.util.Locale locale) {

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFColor blue  = new XSSFColor(new byte[]{(byte)0x21,(byte)0x5C,(byte)0x98}, null);
            XSSFColor red   = new XSSFColor(new byte[]{(byte)0xDC,(byte)0x26,(byte)0x26}, null);
            XSSFColor redBg = new XSSFColor(new byte[]{(byte)0xFE,(byte)0xE2,(byte)0xE2}, null);

            XSSFFont whiteFont = wb.createFont(); whiteFont.setBold(true);
            whiteFont.setColor(new XSSFColor(new byte[]{(byte)0xFF,(byte)0xFF,(byte)0xFF}, null));
            XSSFFont redFont = wb.createFont(); redFont.setBold(true); redFont.setColor(red);

            XSSFCellStyle hStyle = wb.createCellStyle();
            hStyle.setFont(whiteFont); hStyle.setFillForegroundColor(blue);
            hStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            hStyle.setAlignment(HorizontalAlignment.CENTER);
            hStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            hStyle.setBorderBottom(BorderStyle.MEDIUM); hStyle.setBorderRight(BorderStyle.THIN);
            hStyle.setWrapText(true);

            XSSFCellStyle wStyle = wb.createCellStyle();
            wStyle.setFont(redFont); wStyle.setFillForegroundColor(redBg);
            wStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            wStyle.setAlignment(HorizontalAlignment.CENTER);
            wStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            wStyle.setBorderBottom(BorderStyle.MEDIUM); wStyle.setBorderRight(BorderStyle.HAIR);
            wStyle.setWrapText(true);

            CellStyle cellStyle = wb.createCellStyle();
            cellStyle.setAlignment(HorizontalAlignment.CENTER);
            cellStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            cellStyle.setBorderRight(BorderStyle.HAIR); cellStyle.setBorderBottom(BorderStyle.HAIR);

            CellStyle wCellStyle = wb.createCellStyle();
            wCellStyle.setAlignment(HorizontalAlignment.CENTER);
            wCellStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            wCellStyle.setFillForegroundColor(IndexedColors.ROSE.getIndex());
            wCellStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            wCellStyle.setBorderRight(BorderStyle.HAIR); wCellStyle.setBorderBottom(BorderStyle.HAIR);

            CellStyle fixedStyle = wb.createCellStyle();
            fixedStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            fixedStyle.setBorderRight(BorderStyle.THIN); fixedStyle.setBorderBottom(BorderStyle.HAIR);

            String sheetName = sanitizeSheetName(
                excelI18n.resolve("excel.sheet.attendance.timesheet", locale, to.format(SHEET_DATE_FMT)));
            Sheet sheet = wb.createSheet(sheetName);

            // Build column list
            List<String> cols = new java.util.ArrayList<>(java.util.Arrays.asList(
                excelI18n.resolve("excel.col.attendance.date",           locale),
                excelI18n.resolve("excel.col.attendance.dayOfWeek",      locale),
                excelI18n.resolve("excel.col.attendance.leave",          locale),
                excelI18n.resolve("excel.col.attendance.shift",          locale),
                excelI18n.resolve("excel.col.attendance.breakTime",      locale),
                excelI18n.resolve("excel.col.attendance.checkIn",        locale),
                excelI18n.resolve("excel.col.attendance.checkOut",       locale),
                excelI18n.resolve("excel.col.attendance.requestCheckIn", locale),
                excelI18n.resolve("excel.col.attendance.requestCheckOut",locale),
                excelI18n.resolve("excel.col.attendance.totalHours",     locale),
                excelI18n.resolve("excel.col.attendance.dayHours",       locale)
            ));
            if (otEnabled) cols.add(excelI18n.resolve("excel.col.attendance.otDay",     locale));
            if (dayNightMode) {
                cols.add(excelI18n.resolve("excel.col.attendance.nightHours", locale));
                if (otEnabled) cols.add(excelI18n.resolve("excel.col.attendance.otNight", locale));
            }
            cols.add(excelI18n.resolve("excel.col.attendance.status",        locale));
            cols.add(excelI18n.resolve("excel.col.attendance.approveStatus", locale));
            cols.add(excelI18n.resolve("excel.col.attendance.delete",        locale));

            int[] colWidths = new int[cols.size()];
            colWidths[0] = 8; colWidths[1] = 6;
            for (int i = 2; i < cols.size(); i++) colWidths[i] = 16;

            // Header row
            Row hRow = sheet.createRow(0); hRow.setHeight((short)600);
            for (int c = 0; c < cols.size(); c++) {
                Cell cell = hRow.createCell(c); cell.setCellValue(cols.get(c));
                cell.setCellStyle(hStyle);
                sheet.setColumnWidth(c, colWidths[c] * 256);
            }

            // Info row (employee)
            Row infoRow = sheet.createRow(1);
            Cell infoCell = infoRow.createCell(0);
            infoCell.setCellValue(employeeCode + " - " + employeeName + "   |   "
                + from.format(DateTimeFormatter.ofPattern("dd/MM/yyyy"))
                + " → " + to.format(DateTimeFormatter.ofPattern("dd/MM/yyyy")));
            infoCell.setCellStyle(fixedStyle);
            if (cols.size() > 1) sheet.addMergedRegion(new org.apache.poi.ss.util.CellRangeAddress(1, 1, 0, cols.size() - 1));

            int rowIdx = 2;
            for (com.bosskin.dto.AttendanceDTO.TimesheetRow r : rows) {
                boolean weekend = r.isWeekend();
                CellStyle cs = weekend ? wCellStyle : cellStyle;
                Row row = sheet.createRow(rowIdx++);
                row.setHeight((short)400);
                // Ca làm: dùng shiftStart-shiftEnd nếu có, fallback shiftName
                String caLam = "";
                if (r.getShiftStart() != null && r.getShiftEnd() != null)
                    caLam = r.getShiftStart().format(TIME_FMT) + " - " + r.getShiftEnd().format(TIME_FMT);
                else if (r.getShiftName() != null)
                    caLam = r.getShiftName();

                // Trạng thái: từ workFlags (giống màn hình); fallback status chỉ khi có record thực
                String trangThai = "";
                if (r.getWorkFlags() != null && !r.getWorkFlags().isEmpty()) {
                    trangThai = java.util.Arrays.stream(r.getWorkFlags().split(","))
                        .map(f -> switch (f.trim()) {
                            case "ON_TIME"   -> "Đúng giờ";
                            case "LATE_IN"   -> "Đi trễ";
                            case "EARLY_OUT" -> "Về sớm";
                            case "EARLY_IN"  -> "Vào sớm";
                            case "LATE_OUT"  -> "Về muộn";
                            case "OVERTIME"  -> "Tăng ca";
                            case "LEAVE"     -> "Nghỉ phép";
                            default          -> f.trim();
                        })
                        .collect(java.util.stream.Collectors.joining(", "));
                } else if (r.getStatus() != null && r.getAttendanceId() != null) {
                    // Chỉ hiện status khi có record chấm công thực (tránh hiện "Vắng" ngày không có ca)
                    trangThai = switch (r.getStatus().name()) {
                        case "PRESENT"  -> "Có mặt";
                        case "ABSENT"   -> "Vắng";
                        case "LATE"     -> "Đi trễ";
                        case "HALF_DAY" -> "Nửa ngày";
                        case "LEAVE"    -> "Nghỉ phép";
                        default -> r.getStatus().name();
                    };
                }

                int ci = 0;
                setCell(row, ci++, r.getDate() != null ? String.valueOf(r.getDate().getDayOfMonth()) : "", cs);
                setCell(row, ci++, r.getDayLabel() != null ? r.getDayLabel() : "", cs);
                setCell(row, ci++, r.getLeaveCode() != null ? r.getLeaveCode() : "", cs);
                setCell(row, ci++, caLam, cs);
                setCell(row, ci++, r.getBreakMinutes() > 0 ? formatMins(r.getBreakMinutes()) : "", cs);
                // Check-in: ưu tiên override → actual (giống màn hình)
                String checkInVal = r.getOverrideCheckIn() != null ? r.getOverrideCheckIn().format(TIME_FMT)
                    : (r.getCheckIn() != null ? r.getCheckIn().format(TIME_FMT) : "");
                String checkOutVal = r.getOverrideCheckOut() != null ? r.getOverrideCheckOut().format(TIME_FMT)
                    : (r.getCheckOut() != null ? r.getCheckOut().format(TIME_FMT) : "");
                setCell(row, ci++, checkInVal, cs);
                setCell(row, ci++, checkOutVal, cs);
                setCell(row, ci++, r.getRequestedCheckIn() != null ? r.getRequestedCheckIn().format(TIME_FMT) : "", cs);
                setCell(row, ci++, r.getRequestedCheckOut() != null ? r.getRequestedCheckOut().format(TIME_FMT) : "", cs);
                setCell(row, ci++, r.getTotalHours() > 0 ? formatHours(r.getTotalHours()) : "", cs);
                setCell(row, ci++, r.getRegularDayHours() > 0 ? formatHours(r.getRegularDayHours()) : "", cs);
                if (otEnabled) {
                    double otDay = r.getOverrideOtDayMinutes() != null
                        ? r.getOverrideOtDayMinutes() / 60.0 : r.getOtDayHours();
                    setCell(row, ci++, otDay > 0 ? formatHours(otDay) : "", cs);
                }
                if (dayNightMode) {
                    setCell(row, ci++, r.getRegularNightHours() > 0 ? formatHours(r.getRegularNightHours()) : "", cs);
                    if (otEnabled) {
                        double otNight = r.getOverrideOtNightMinutes() != null
                            ? r.getOverrideOtNightMinutes() / 60.0 : r.getOtNightHours();
                        setCell(row, ci++, otNight > 0 ? formatHours(otNight) : "", cs);
                    }
                }
                setCell(row, ci++, trangThai, cs);
                setCell(row, ci++, r.isApproved() ? "true" : "false", cs);
                setCell(row, ci++, "", cs); // Xóa — user điền "x" để xóa khi import
            }

            sheet.createFreezePane(0, 2);
            autoSizeAll(sheet, cols.size());

            wb.setForceFormulaRecalculation(true);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            wb.write(out);
            String filenameBase = excelI18n.resolve("excel.file.attendance.timesheet", locale)
                + "-" + employeeCode
                + "-" + from.format(DateTimeFormatter.ofPattern("ddMMyyyy"))
                + "-" + to.format(DateTimeFormatter.ofPattern("ddMMyyyy"));
            historyHelper.save(companyId, userId, HistoryType.EXPORT, "attendance",
                    filenameBase + ".xlsx", out.toByteArray(), null, null, null);
            return ExcelUtils.buildFileResponse(filenameBase, out.toByteArray());
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ── Export Day View (1 sheet — nhiều NV × 1 ngày, giống màn hình Theo ngày) ─

    public ResponseEntity<byte[]> exportDayView(
            Long companyId, Long userId,
            LocalDate date,
            List<com.bosskin.dto.AttendanceDTO.DayViewRow> dayRows,
            boolean dayNightMode, boolean otEnabled,
            java.util.Locale locale) {

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            wb.setCellFormulaValidation(false);

            XSSFColor blue = new XSSFColor(new byte[]{(byte)0x21,(byte)0x5C,(byte)0x98}, null);

            XSSFFont whiteFont = wb.createFont(); whiteFont.setBold(true);
            whiteFont.setColor(new XSSFColor(new byte[]{(byte)0xFF,(byte)0xFF,(byte)0xFF}, null));

            XSSFCellStyle hStyle = wb.createCellStyle();
            hStyle.setFont(whiteFont); hStyle.setFillForegroundColor(blue);
            hStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            hStyle.setAlignment(HorizontalAlignment.CENTER);
            hStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            hStyle.setBorderBottom(BorderStyle.MEDIUM); hStyle.setBorderRight(BorderStyle.THIN);
            hStyle.setWrapText(true);

            CellStyle cellStyle = wb.createCellStyle();
            cellStyle.setAlignment(HorizontalAlignment.CENTER);
            cellStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            cellStyle.setBorderRight(BorderStyle.HAIR); cellStyle.setBorderBottom(BorderStyle.HAIR);

            CellStyle empStyle = wb.createCellStyle();
            empStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            empStyle.setBorderRight(BorderStyle.THIN); empStyle.setBorderBottom(BorderStyle.HAIR);
            empStyle.setWrapText(true);

            CellStyle fixedStyle = wb.createCellStyle();
            fixedStyle.setVerticalAlignment(VerticalAlignment.CENTER);
            fixedStyle.setBorderRight(BorderStyle.THIN); fixedStyle.setBorderBottom(BorderStyle.HAIR);

            // Cột: Nhân viên (fixed) + các cột giống tab Theo tháng
            List<String> cols = new ArrayList<>(java.util.Arrays.asList(
                excelI18n.resolve("excel.col.attendance.employee",       locale),
                excelI18n.resolve("excel.col.attendance.leave",          locale),
                excelI18n.resolve("excel.col.attendance.shift",          locale),
                excelI18n.resolve("excel.col.attendance.breakTime",      locale),
                excelI18n.resolve("excel.col.attendance.checkIn",        locale),
                excelI18n.resolve("excel.col.attendance.checkOut",       locale),
                excelI18n.resolve("excel.col.attendance.requestCheckIn", locale),
                excelI18n.resolve("excel.col.attendance.requestCheckOut",locale),
                excelI18n.resolve("excel.col.attendance.totalHours",     locale),
                excelI18n.resolve("excel.col.attendance.dayHours",       locale)
            ));
            if (otEnabled) cols.add(excelI18n.resolve("excel.col.attendance.otDay",     locale));
            if (dayNightMode) {
                cols.add(excelI18n.resolve("excel.col.attendance.nightHours", locale));
                if (otEnabled) cols.add(excelI18n.resolve("excel.col.attendance.otNight", locale));
            }
            cols.add(excelI18n.resolve("excel.col.attendance.status",        locale));
            cols.add(excelI18n.resolve("excel.col.attendance.approveStatus", locale));
            cols.add(excelI18n.resolve("excel.col.attendance.delete",        locale));

            String sheetName = sanitizeSheetName(
                excelI18n.resolve("excel.sheet.attendance.day", locale, date.format(DateTimeFormatter.ofPattern("dd-MM-yyyy"))));
            Sheet sheet = wb.createSheet(sheetName);

            // Info row — ngày
            Row infoRow = sheet.createRow(0);
            Cell infoCell = infoRow.createCell(0);
            String dayLabel = excelI18n.resolve("excel.sheet.attendance.day", locale, date.format(DateTimeFormatter.ofPattern("dd/MM/yyyy")));
            infoCell.setCellValue(dayLabel);
            infoCell.setCellStyle(fixedStyle);
            if (cols.size() > 1) sheet.addMergedRegion(new org.apache.poi.ss.util.CellRangeAddress(0, 0, 0, cols.size() - 1));

            // Header
            Row hRow = sheet.createRow(1); hRow.setHeight((short)600);
            sheet.setColumnWidth(0, 32 * 256); // Nhân viên
            for (int c = 0; c < cols.size(); c++) {
                Cell cell = hRow.createCell(c); cell.setCellValue(cols.get(c));
                cell.setCellStyle(hStyle);
                if (c > 0) sheet.setColumnWidth(c, 16 * 256);
            }

            // Data rows — group by employee, mỗi slot 1 dòng, merge cột NV nếu nhiều slot
            int rowIdx = 2;
            // group theo employeeId giữ thứ tự
            java.util.LinkedHashMap<Long, List<com.bosskin.dto.AttendanceDTO.DayViewRow>> byEmp = new java.util.LinkedHashMap<>();
            for (var r : dayRows) byEmp.computeIfAbsent(r.getEmployeeId(), k -> new ArrayList<>()).add(r);

            for (var entry : byEmp.entrySet()) {
                var slots = entry.getValue();
                if (slots.isEmpty()) continue;
                var firstSlot = slots.get(0);
                String empLabel = (firstSlot.getEmployeeCode() != null ? firstSlot.getEmployeeCode() : "")
                    + " - " + (firstSlot.getEmployeeFullName() != null ? firstSlot.getEmployeeFullName() : "")
                    + (firstSlot.getDepartmentName() != null ? "\n" + firstSlot.getDepartmentName() : "");

                int empStartRow = rowIdx;
                for (var r : slots) {
                    Row row = sheet.createRow(rowIdx++); row.setHeight((short)-1);

                    // Cột NV: chỉ ghi ở slot đầu, merge sau
                    if (r == firstSlot) {
                        Cell empCell = row.createCell(0);
                        empCell.setCellValue(empLabel);
                        empCell.setCellStyle(empStyle);
                    } else {
                        row.createCell(0).setCellStyle(empStyle);
                    }

                    String caLam = "";
                    if (r.getShiftStart() != null && r.getShiftEnd() != null)
                        caLam = r.getShiftStart().format(TIME_FMT) + " - " + r.getShiftEnd().format(TIME_FMT);
                    else if (r.getShiftName() != null) caLam = r.getShiftName();

                    String trangThai = "";
                    if (r.getWorkFlags() != null && !r.getWorkFlags().isEmpty()) {
                        trangThai = java.util.Arrays.stream(r.getWorkFlags().split(","))
                            .map(f -> switch (f.trim()) {
                                case "ON_TIME"   -> "Đúng giờ";
                                case "LATE_IN"   -> "Đi trễ";
                                case "EARLY_OUT" -> "Về sớm";
                                case "EARLY_IN"  -> "Vào sớm";
                                case "LATE_OUT"  -> "Về muộn";
                                case "OVERTIME"  -> "Tăng ca";
                                case "LEAVE"     -> "Nghỉ phép";
                                default          -> f.trim();
                            })
                            .collect(java.util.stream.Collectors.joining(", "));
                    } else if (r.getStatus() != null && r.getAttendanceId() != null) {
                        trangThai = switch (r.getStatus().name()) {
                            case "PRESENT"  -> "Có mặt";
                            case "ABSENT"   -> "Vắng";
                            case "LATE"     -> "Đi trễ";
                            case "HALF_DAY" -> "Nửa ngày";
                            case "LEAVE"    -> "Nghỉ phép";
                            default -> r.getStatus().name();
                        };
                    }

                    String checkInVal = r.getOverrideCheckIn() != null ? r.getOverrideCheckIn().format(TIME_FMT)
                        : (r.getCheckIn() != null ? r.getCheckIn().format(TIME_FMT) : "");
                    String checkOutVal = r.getOverrideCheckOut() != null ? r.getOverrideCheckOut().format(TIME_FMT)
                        : (r.getCheckOut() != null ? r.getCheckOut().format(TIME_FMT) : "");

                    int ci = 1;
                    setCell(row, ci++, r.getLeaveCode() != null ? r.getLeaveCode() : "", cellStyle);
                    setCell(row, ci++, caLam, cellStyle);
                    setCell(row, ci++, r.getBreakMinutes() > 0 ? formatMins(r.getBreakMinutes()) : "", cellStyle);
                    setCell(row, ci++, checkInVal, cellStyle);
                    setCell(row, ci++, checkOutVal, cellStyle);
                    setCell(row, ci++, r.getRequestedCheckIn() != null ? r.getRequestedCheckIn().format(TIME_FMT) : "", cellStyle);
                    setCell(row, ci++, r.getRequestedCheckOut() != null ? r.getRequestedCheckOut().format(TIME_FMT) : "", cellStyle);
                    setCell(row, ci++, r.getTotalHours() > 0 ? formatHours(r.getTotalHours()) : "", cellStyle);
                    setCell(row, ci++, r.getRegularDayHours() > 0 ? formatHours(r.getRegularDayHours()) : "", cellStyle);
                    if (otEnabled) {
                        double otDay = r.getOverrideOtDayMinutes() != null
                            ? r.getOverrideOtDayMinutes() / 60.0 : r.getOtDayHours();
                        setCell(row, ci++, otDay > 0 ? formatHours(otDay) : "", cellStyle);
                    }
                    if (dayNightMode) {
                        setCell(row, ci++, r.getRegularNightHours() > 0 ? formatHours(r.getRegularNightHours()) : "", cellStyle);
                        if (otEnabled) {
                            double otNight = r.getOverrideOtNightMinutes() != null
                                ? r.getOverrideOtNightMinutes() / 60.0 : r.getOtNightHours();
                            setCell(row, ci++, otNight > 0 ? formatHours(otNight) : "", cellStyle);
                        }
                    }
                    setCell(row, ci++, trangThai, cellStyle);
                    setCell(row, ci++, r.isApproved() ? "true" : "false", cellStyle);
                    setCell(row, ci++, "", cellStyle); // Xóa — user điền "x" để xóa khi import
                }
                // Merge cột NV nếu nhiều slot
                if (slots.size() > 1) {
                    sheet.addMergedRegion(new org.apache.poi.ss.util.CellRangeAddress(empStartRow, rowIdx - 1, 0, 0));
                }
            }

            sheet.createFreezePane(1, 2);
            autoSizeAll(sheet, cols.size());

            wb.setForceFormulaRecalculation(true);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            wb.write(out);
            String filenameBase = excelI18n.resolve("excel.file.attendance.day", locale)
                + "-" + date.format(DateTimeFormatter.ofPattern("ddMMyyyy"));
            historyHelper.save(companyId, userId, HistoryType.EXPORT, "attendance",
                    filenameBase + ".xlsx", out.toByteArray(), null, null, null);
            return ExcelUtils.buildFileResponse(filenameBase, out.toByteArray());
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    private void setCell(Row row, int col, String val, CellStyle cs) {
        Cell cell = row.createCell(col);
        if (val != null && !val.isEmpty()) cell.setCellValue(val);
        cell.setCellStyle(cs);
    }

    private String formatHours(double h) {
        int total = (int) Math.round(h * 60);
        return String.format("%02d:%02d", total / 60, total % 60);
    }

    private String formatMins(int mins) {
        return String.format("%02d:%02d", mins / 60, mins % 60);
    }

    // ── Preview Import ──────────────────────────────────────────────────────

    public record ApproveTask(Long attendanceId, boolean approve) {}

    private final ThreadLocal<List<ApproveTask>> approveTaskHolder = ThreadLocal.withInitial(ArrayList::new);

    public List<ApproveTask> getLastImportApproveTasks() {
        List<ApproveTask> tasks = new ArrayList<>(approveTaskHolder.get());
        approveTaskHolder.remove();
        return tasks;
    }

    @Data @Builder
    public static class AttendanceDiff {
        private String action; // CREATE | UPDATE | NO_CHANGE
        private String code;   // employee code
        private String name;   // display label
        private List<FieldChange> changes;
        private List<String> warnings;
    }

    @Data @AllArgsConstructor
    public static class FieldChange {
        private String field;
        private String oldValue;
        private String newValue;
    }

    @Transactional(readOnly = true)
    public List<AttendanceDiff> previewImport(Long companyId, Long userId, MultipartFile file) {
        List<AttendanceImportRow> rows = readAttendanceSheet(file);
        if (rows.isEmpty()) return List.of();

        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "ATTENDANCE_VIEW");

        Map<String, Employee> empMap = employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            .stream()
            .filter(e -> scopeIds.isEmpty() || (e.getDepartment() != null && scopeIds.contains(e.getDepartment().getId())))
            .collect(Collectors.toMap(Employee::getEmployeeCode, e -> e, (a, b) -> a));

        // Collect unique dates to fetch existing attendances
        Set<LocalDate> dates = rows.stream().map(r -> r.date).collect(Collectors.toSet());
        if (dates.isEmpty()) return List.of();
        LocalDate minDate = dates.stream().min(Comparator.naturalOrder()).orElseThrow();
        LocalDate maxDate = dates.stream().max(Comparator.naturalOrder()).orElseThrow();

        List<Attendance> existing = attendanceRepo.findByCompanyAndDateRange(companyId, minDate, maxDate);
        // empId -> date -> Attendance
        Map<Long, Map<LocalDate, Attendance>> existingMap = new HashMap<>();
        for (Attendance a : existing) {
            existingMap.computeIfAbsent(a.getEmployee().getId(), k -> new HashMap<>()).put(a.getDate(), a);
        }

        DateTimeFormatter ddMM = DateTimeFormatter.ofPattern("dd/MM");
        List<AttendanceDiff> result = new ArrayList<>();

        for (AttendanceImportRow row : rows) {
            List<String> warnings = new ArrayList<>();
            Employee emp = empMap.get(row.empCode);
            if (emp == null) {
                warnings.add("Không tìm thấy nhân viên: " + row.empCode);
                result.add(AttendanceDiff.builder()
                    .action("CREATE").code(row.empCode)
                    .name(row.empName + " — " + row.date.format(ddMM))
                    .changes(List.of()).warnings(warnings).build());
                continue;
            }

            Attendance att = existingMap.getOrDefault(emp.getId(), Map.of()).get(row.date);
            String currentVal = att != null ? formatCellValue(att) : "";
            String newVal = row.cellValue != null ? row.cellValue.trim() : "";

            if (row.deleteFlag) {
                if (att == null || att.isDeleted()) continue;
                result.add(AttendanceDiff.builder()
                    .action("DELETE").code(row.empCode)
                    .name(emp.getFullName() + " — " + row.date.format(ddMM))
                    .changes(List.of(new FieldChange("Chấm công", currentVal, "XÓA")))
                    .warnings(warnings).build());
                continue;
            }

            if (att == null && newVal.isEmpty()) continue;
            if (att == null) {
                result.add(AttendanceDiff.builder()
                    .action("CREATE").code(row.empCode)
                    .name(emp.getFullName() + " — " + row.date.format(ddMM) + " → " + newVal)
                    .changes(List.of(new FieldChange("Chấm công", "", newVal)))
                    .warnings(warnings).build());
            } else {
                List<FieldChange> changes = new ArrayList<>();
                if (!currentVal.equals(newVal)) {
                    changes.add(new FieldChange("Chấm công", currentVal, newVal));
                }
                String action = changes.isEmpty() ? "NO_CHANGE" : "UPDATE";
                if (action.equals("NO_CHANGE") && warnings.isEmpty()) continue;
                result.add(AttendanceDiff.builder()
                    .action(action).code(row.empCode)
                    .name(emp.getFullName() + " — " + row.date.format(ddMM))
                    .changes(changes).warnings(warnings).build());
            }
        }
        return result;
    }

    // ── Import ──────────────────────────────────────────────────────────────

    @Transactional
    public Map<String, Integer> importAttendance(Long companyId, Long userId, MultipartFile file) {
        List<AttendanceImportRow> rows = readAttendanceSheet(file);
        if (rows.isEmpty()) return Map.of("created", 0, "updated", 0, "skipped", 0);

        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "ATTENDANCE_VIEW");

        Map<String, Employee> empMap = employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            .stream()
            .filter(e -> scopeIds.isEmpty() || (e.getDepartment() != null && scopeIds.contains(e.getDepartment().getId())))
            .collect(Collectors.toMap(Employee::getEmployeeCode, e -> e, (a, b) -> a));

        Set<LocalDate> dates = rows.stream().map(r -> r.date).collect(Collectors.toSet());
        if (dates.isEmpty()) return Map.of("created", 0, "updated", 0, "skipped", 0);
        LocalDate minDate = dates.stream().min(Comparator.naturalOrder()).orElseThrow();
        LocalDate maxDate = dates.stream().max(Comparator.naturalOrder()).orElseThrow();

        List<Attendance> existing = attendanceRepo.findByCompanyAndDateRange(companyId, minDate, maxDate);
        Map<Long, Map<LocalDate, Attendance>> existingMap = new HashMap<>();
        for (Attendance a : existing) {
            existingMap.computeIfAbsent(a.getEmployee().getId(), k -> new HashMap<>()).put(a.getDate(), a);
        }

        int created = 0, updated = 0, deleted = 0, skipped = 0;
        List<Attendance> toSave = new ArrayList<>();
        for (AttendanceImportRow row : rows) {
            Employee emp = empMap.get(row.empCode);
            if (emp == null) { skipped++; continue; }

            try {
                Attendance att = existingMap.getOrDefault(emp.getId(), Map.of()).get(row.date);

                if (row.deleteFlag) {
                    if (att == null || att.isDeleted()) { skipped++; continue; }
                    att.setDeleted(true);
                    att.setDeletedAt(LocalDateTime.now());
                    toSave.add(att);
                    deleted++;
                    continue;
                }

                String newVal = row.cellValue != null ? row.cellValue.trim() : "";
                if (newVal.isEmpty()) { skipped++; continue; }

                ParsedCell parsed = parseCellValue(newVal);
                if (att == null) {
                    Attendance.AttendanceBuilder b = Attendance.builder()
                        .employee(emp)
                        .date(row.date)
                        .deleted(false)
                        .approved(false);
                    applyParsed(b, parsed);
                    toSave.add(b.build());
                    created++;
                } else {
                    applyParsedToExisting(att, parsed);
                    toSave.add(att);
                    updated++;
                }
            } catch (Exception e) {
                skipped++;
            }
        }
        attendanceRepo.saveAll(toSave);
        Map<String, Integer> result = Map.of("created", created, "updated", updated, "deleted", deleted, "skipped", skipped);
        historyHelper.save(companyId, userId, HistoryType.IMPORT, "attendance",
                "cham-cong-import.xlsx", file.isEmpty() ? new byte[0] : readBytes(file),
                created + updated, 0, skipped);
        return result;
    }

    // ── Internal helpers ────────────────────────────────────────────────────

    private static class AttendanceImportRow {
        String empCode;
        String empName;
        LocalDate date;
        String cellValue;
        boolean deleteFlag; // true nếu cột "Xóa" có giá trị
    }

    private List<AttendanceImportRow> readAttendanceSheet(MultipartFile file) {
        try (InputStream is = file.getInputStream();
             XSSFWorkbook wb = new XSSFWorkbook(is)) {

            Sheet sheet = wb.getSheetAt(0);
            DataFormatter formatter = new DataFormatter();
            Row headerRow = sheet.getRow(0);
            if (headerRow == null) return List.of();

            // Parse year + month from sheet name "Cham cong MM-yyyy"
            String sheetName = sheet.getSheetName();
            int sheetYear;
            try {
                String datePart = sheetName.replace("Cham cong ", "").trim();
                String[] parts = datePart.split("-");
                sheetYear = Integer.parseInt(parts[1]);
            } catch (Exception e) {
                sheetYear = LocalDate.now().getYear();
            }

            // Parse date columns from header (format: "d/M\nWeekday") + tìm cột "Xóa"
            List<LocalDate> dates = new ArrayList<>();
            List<Integer> dateCols = new ArrayList<>();
            int deleteCol = -1;
            for (int c = 3; c < headerRow.getLastCellNum(); c++) {
                Cell cell = headerRow.getCell(c);
                if (cell == null) continue;
                String raw = formatter.formatCellValue(cell).trim();
                if (raw.equalsIgnoreCase("Xóa") || raw.equalsIgnoreCase("Xoa")
                        || raw.equalsIgnoreCase("Xóa *") || raw.equalsIgnoreCase("Xoa *")) {
                    deleteCol = c;
                    continue;
                }
                String dayMonthPart = raw.contains("\n") ? raw.substring(0, raw.indexOf('\n')).trim() : raw.trim();
                if (dayMonthPart.isBlank()) continue;
                try {
                    String[] dm = dayMonthPart.split("/");
                    int day   = Integer.parseInt(dm[0].trim());
                    int month = Integer.parseInt(dm[1].trim());
                    dates.add(LocalDate.of(sheetYear, month, day));
                    dateCols.add(c);
                } catch (Exception ignored) {}
            }

            List<AttendanceImportRow> result = new ArrayList<>();
            int lastDataRow = Math.max(1, sheet.getLastRowNum());
            for (int r = 1; r <= lastDataRow; r++) {
                Row row = sheet.getRow(r);
                if (row == null) continue;
                Cell empCell  = row.getCell(0);
                Cell nameCell = row.getCell(1);
                if (empCell == null) continue;
                String empCode = formatter.formatCellValue(empCell).trim();
                String empName = nameCell != null ? formatter.formatCellValue(nameCell).trim() : empCode;
                if (empCode.isBlank()) continue;

                for (int ci = 0; ci < dateCols.size(); ci++) {
                    Cell cell = row.getCell(dateCols.get(ci));
                    String val = cell == null ? "" : formatter.formatCellValue(cell).trim();
                    // Đọc cột Xóa cho ngày này (nếu có cột Xóa riêng theo ngày thì không có ở đây)
                    // Format ngang: cột Xóa áp dụng cho toàn hàng (nhân viên), không theo ngày cụ thể
                    String deleteVal = deleteCol >= 0 && row.getCell(deleteCol) != null
                        ? formatter.formatCellValue(row.getCell(deleteCol)).trim() : "";
                    boolean toDelete = !deleteVal.isEmpty();
                    if (val.isEmpty() && !toDelete) continue;
                    AttendanceImportRow ir = new AttendanceImportRow();
                    ir.empCode    = empCode;
                    ir.empName    = empName;
                    ir.date       = dates.get(ci);
                    ir.cellValue  = val;
                    ir.deleteFlag = toDelete;
                    result.add(ir);
                }
            }
            return result;
        } catch (IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }
    }

    private static class ParsedCell {
        Attendance.Status status;
        LocalTime checkIn;
        LocalTime checkOut;
    }

    private ParsedCell parseCellValue(String val) {
        ParsedCell p = new ParsedCell();
        if ("LEAVE".equalsIgnoreCase(val))   { p.status = Attendance.Status.LEAVE;  return p; }
        if ("ABSENT".equalsIgnoreCase(val))  { p.status = Attendance.Status.ABSENT; return p; }
        // "HH:MM~HH:MM" or "HH:MM~"
        if (val.contains("~")) {
            String[] parts = val.split("~");
            try { p.checkIn  = LocalTime.parse(parts[0].trim(), TIME_FMT); } catch (Exception ignored) {}
            if (parts.length > 1 && !parts[1].trim().isEmpty()) {
                try { p.checkOut = LocalTime.parse(parts[1].trim(), TIME_FMT); } catch (Exception ignored) {}
            }
            p.status = Attendance.Status.PRESENT;
        } else {
            try { p.status = Attendance.Status.valueOf(val.toUpperCase()); }
            catch (Exception e) { p.status = Attendance.Status.PRESENT; }
        }
        return p;
    }

    private void applyParsed(Attendance.AttendanceBuilder b, ParsedCell p) {
        b.status(p.status != null ? p.status : Attendance.Status.PRESENT);
        if (p.checkIn  != null) b.overrideCheckIn(p.checkIn);
        if (p.checkOut != null) b.overrideCheckOut(p.checkOut);
    }

    private void applyParsedToExisting(Attendance att, ParsedCell p) {
        if (p.status != null) att.setStatus(p.status);
        if (p.checkIn  != null) att.setOverrideCheckIn(p.checkIn);
        if (p.checkOut != null) att.setOverrideCheckOut(p.checkOut);
    }

    // ── Import Timesheet (format dọc: hàng = ngày, cột = trường) ──────────────

    private static class TimesheetImportRow {
        String empCode;
        LocalDate date;
        String checkIn;
        String checkOut;
        String breakMinutes;
        String otDayMinutes;
        String otNightMinutes;
        boolean deleteFlag;
        Boolean approved; // null = không đổi, true = duyệt, false = bỏ duyệt
    }

    private List<TimesheetImportRow> readTimesheetSheet(MultipartFile file) {
        try (InputStream is = file.getInputStream();
             XSSFWorkbook wb = new XSSFWorkbook(is)) {
            Sheet sheet = wb.getSheetAt(0);
            DataFormatter fmt = new DataFormatter();

            // Tự detect: row 0 là info row hay header row?
            // - Timesheet: row 0 = header, row 1 = info "EMP - Tên | date"
            // - Day view:  row 0 = info "Chấm công ngày: dd/MM/yyyy", row 1 = header
            Row row0 = sheet.getRow(0);
            if (row0 == null) return List.of();
            String row0First = fmt.formatCellValue(row0.getCell(0)).trim();
            boolean isDayViewFormat = row0First.startsWith("Chấm công ngày");

            Row headerRow = isDayViewFormat ? sheet.getRow(1) : sheet.getRow(0);
            if (headerRow == null) return List.of();

            // Info row chứa mã NV + from/to date (chỉ có ở timesheet format)
            String empCode = null;
            LocalDate periodFrom = null; // ngày bắt đầu kỳ lương — dùng để xác định tháng đúng
            if (!isDayViewFormat) {
                Row infoRow = sheet.getRow(1);
                if (infoRow != null) {
                    String info = fmt.formatCellValue(infoRow.getCell(0)).trim();
                    int dashIdx = info.indexOf(" - ");
                    if (dashIdx > 0) empCode = info.substring(0, dashIdx).trim();
                    // Parse from date: "... | 25/05/2026 → 24/06/2026"
                    int pipeIdx = info.indexOf("|");
                    if (pipeIdx >= 0) {
                        String datePart = info.substring(pipeIdx + 1).trim();
                        String fromStr = datePart.contains("→") ? datePart.substring(0, datePart.indexOf("→")).trim() : datePart.trim();
                        try { periodFrom = LocalDate.parse(fromStr, DateTimeFormatter.ofPattern("dd/MM/yyyy")); }
                        catch (Exception ignored) {}
                    }
                }
            }
            int dataStartRow = 2;

            // Map tên cột (bỏ " *", bỏ newline) → index
            Map<String, Integer> colIdx = new HashMap<>();
            for (int c = 0; c < headerRow.getLastCellNum(); c++) {
                Cell cell = headerRow.getCell(c);
                if (cell == null) continue;
                String name = fmt.formatCellValue(cell).trim()
                    .replace("\n", " ").replace("  ", " ")  // normalize newline
                    .replace(" *", "").trim();
                colIdx.put(name, c);
            }

            Integer colNgay    = colIdx.get("Ngày");
            Integer colCI      = colIdx.get("Check-in");
            Integer colCO      = colIdx.get("Check-out");
            Integer colBreak   = colIdx.get("Giờ giải lao");
            Integer colOtDay   = colIdx.get("Tăng ca ngày");
            Integer colOtNight = colIdx.get("Tăng ca đêm");
            Integer colDelete   = colIdx.get("Xóa");
            Integer colApproved = colIdx.get("Trạng thái duyệt");
            // Cột Nhân viên (day view format)
            Integer colEmp     = colIdx.get("Nhân viên");

            if (colNgay == null && colEmp == null) return List.of();

            List<TimesheetImportRow> result = new ArrayList<>();
            for (int r = dataStartRow; r <= sheet.getLastRowNum(); r++) {
                Row row = sheet.getRow(r);
                if (row == null) continue;

                // Day view format: cột Nhân viên chứa "EMP - Tên\nPhòng ban"
                String rowEmpCode = empCode;
                if (colEmp != null) {
                    String empCell = fmt.formatCellValue(row.getCell(colEmp)).trim();
                    int dash = empCell.indexOf(" - ");
                    if (dash > 0) rowEmpCode = empCell.substring(0, dash).trim();
                    else if (!empCell.isBlank()) rowEmpCode = empCell.split("\n")[0].trim();
                }
                if (rowEmpCode == null || rowEmpCode.isBlank()) continue;

                // Parse ngày
                LocalDate date;
                if (isDayViewFormat) {
                    // Day view: ngày lấy từ sheet name "Cham cong dd-MM-yyyy"
                    String sn = sheet.getSheetName();
                    try {
                        String part = sn.replace("Cham cong ", "").trim();
                        String[] p = part.split("-");
                        date = LocalDate.of(Integer.parseInt(p[2]), Integer.parseInt(p[1]), Integer.parseInt(p[0]));
                    } catch (Exception e) { continue; }
                } else {
                    // Timesheet: cột "Ngày" chứa số ngày trong tháng
                    if (colNgay == null) continue;
                    String dayStr = fmt.formatCellValue(row.getCell(colNgay)).trim();
                    if (dayStr.isBlank()) continue;
                    int dayOfMonth;
                    try { dayOfMonth = (int) Double.parseDouble(dayStr); }
                    catch (Exception e) { continue; }

                    if (periodFrom != null) {
                        // Xác định tháng đúng: nếu ngày >= cutoff (ngày bắt đầu kỳ) → tháng của periodFrom
                        // nếu ngày < cutoff → tháng tiếp theo
                        LocalDate candidate = periodFrom.withDayOfMonth(1);
                        // Thử xây ngày trong tháng periodFrom
                        try {
                            LocalDate d1 = periodFrom.withDayOfMonth(dayOfMonth);
                            // d1 phải >= periodFrom
                            date = !d1.isBefore(periodFrom) ? d1 : d1.plusMonths(1);
                        } catch (Exception e) {
                            // Ngày không hợp lệ trong tháng đó (vd 31/02) → tháng sau
                            try { date = candidate.plusMonths(1).withDayOfMonth(dayOfMonth); }
                            catch (Exception e2) { continue; }
                        }
                    } else {
                        // Fallback: dùng sheet name
                        LocalDate baseDate = parseBaseDateFromSheetName(sheet.getSheetName());
                        if (baseDate == null) continue;
                        try { date = LocalDate.of(baseDate.getYear(), baseDate.getMonthValue(), dayOfMonth); }
                        catch (Exception e) { continue; }
                    }
                }

                TimesheetImportRow ir = new TimesheetImportRow();
                ir.empCode      = rowEmpCode;
                ir.date         = date;
                ir.checkIn      = colCI      != null ? fmt.formatCellValue(row.getCell(colCI)).trim()      : null;
                ir.checkOut     = colCO      != null ? fmt.formatCellValue(row.getCell(colCO)).trim()      : null;
                ir.breakMinutes = colBreak   != null ? fmt.formatCellValue(row.getCell(colBreak)).trim()   : null;
                ir.otDayMinutes = colOtDay   != null ? fmt.formatCellValue(row.getCell(colOtDay)).trim()   : null;
                ir.otNightMinutes = colOtNight != null ? fmt.formatCellValue(row.getCell(colOtNight)).trim() : null;
                ir.deleteFlag   = colDelete  != null && !fmt.formatCellValue(row.getCell(colDelete)).trim().isEmpty();
                if (colApproved != null) {
                    String approvedVal = fmt.formatCellValue(row.getCell(colApproved)).trim().toLowerCase();
                    if (approvedVal.equals("true"))  ir.approved = true;
                    else if (approvedVal.equals("false")) ir.approved = false;
                    // blank = không đổi → null
                }

                boolean hasAnyCol = ir.deleteFlag || ir.approved != null
                    || ir.checkIn != null || ir.checkOut != null
                    || ir.breakMinutes != null || ir.otDayMinutes != null || ir.otNightMinutes != null;
                if (!hasAnyCol) continue;
                result.add(ir);
            }
            return result;
        } catch (IOException e) {
            throw new RuntimeException("error.excel.import_failed", e);
        }
    }

    private static String sanitizeSheetName(String name) {
        String sanitized = name.replaceAll("[/\\\\?*\\[\\]]", "-");
        return sanitized.length() > 31 ? sanitized.substring(0, 31) : sanitized;
    }

    private LocalDate parseBaseDateFromSheetName(String sheetName) {
        // "Cham cong dd-MM-yyyy" (day view) hoặc "Cham cong MM-yyyy" (timesheet)
        try {
            String part = sheetName.replace("Cham cong ", "").trim();
            String[] parts = part.split("-");
            if (parts.length == 3) {
                // dd-MM-yyyy
                return LocalDate.of(Integer.parseInt(parts[2]), Integer.parseInt(parts[1]), 1);
            } else if (parts.length == 2) {
                // MM-yyyy
                return LocalDate.of(Integer.parseInt(parts[1]), Integer.parseInt(parts[0]), 1);
            }
        } catch (Exception ignored) {}
        return null;
    }

    @Transactional(readOnly = true)
    public List<AttendanceDiff> previewImportTimesheet(Long companyId, Long userId, MultipartFile file) {
        List<TimesheetImportRow> rows = readTimesheetSheet(file);
        if (rows.isEmpty()) return List.of();

        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "ATTENDANCE_VIEW");
        Map<String, com.bosskin.entity.Employee> empMap = employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            .stream()
            .filter(e -> scopeIds.isEmpty() || (e.getDepartment() != null && scopeIds.contains(e.getDepartment().getId())))
            .collect(Collectors.toMap(com.bosskin.entity.Employee::getEmployeeCode, e -> e, (a, b) -> a));

        Set<LocalDate> dates = rows.stream().map(r -> r.date).collect(Collectors.toSet());
        LocalDate minDate = dates.stream().min(Comparator.naturalOrder()).orElseThrow();
        LocalDate maxDate = dates.stream().max(Comparator.naturalOrder()).orElseThrow();
        List<Attendance> existing = attendanceRepo.findByCompanyAndDateRange(companyId, minDate, maxDate);
        Map<Long, Map<LocalDate, Attendance>> existingMap = new HashMap<>();
        for (Attendance a : existing) {
            existingMap.computeIfAbsent(a.getEmployee().getId(), k -> new HashMap<>()).put(a.getDate(), a);
        }

        DateTimeFormatter ddMM = DateTimeFormatter.ofPattern("dd/MM");
        List<AttendanceDiff> result = new ArrayList<>();
        for (TimesheetImportRow row : rows) {
            com.bosskin.entity.Employee emp = empMap.get(row.empCode);
            if (emp == null) {
                result.add(AttendanceDiff.builder().action("CREATE").code(row.empCode)
                    .name(row.empCode + " — " + row.date.format(ddMM))
                    .changes(List.of()).warnings(List.of("Không tìm thấy nhân viên: " + row.empCode)).build());
                continue;
            }
            Attendance att = existingMap.getOrDefault(emp.getId(), Map.of()).get(row.date);
            String label = emp.getFullName() + " — " + row.date.format(ddMM);

            if (row.deleteFlag) {
                if (att == null || att.isDeleted()) continue;
                result.add(AttendanceDiff.builder().action("DELETE").code(row.empCode).name(label)
                    .changes(List.of(new FieldChange("Chấm công", formatCellValue(att), "XÓA")))
                    .warnings(List.of()).build());
                continue;
            }

            List<FieldChange> changes = new ArrayList<>();
            String curCI = "", curCO = "", curBr = "", curOtDay = "", curOtNight = "";
            if (att != null) {
                curCI = att.getOverrideCheckIn() != null ? att.getOverrideCheckIn().format(TIME_FMT)
                    : (att.getCheckIn() != null ? att.getCheckIn().toLocalTime().format(TIME_FMT) : "");
                curCO = att.getOverrideCheckOut() != null ? att.getOverrideCheckOut().format(TIME_FMT)
                    : (att.getCheckOut() != null ? att.getCheckOut().toLocalTime().format(TIME_FMT) : "");
                curBr     = att.getOverrideBreakMinutes()    != null ? formatMins(att.getOverrideBreakMinutes())    : "";
                curOtDay  = att.getOverrideOtDayMinutes()    != null ? formatMins(att.getOverrideOtDayMinutes())    : "";
                curOtNight = att.getOverrideOtNightMinutes() != null ? formatMins(att.getOverrideOtNightMinutes())  : "";
            }
            // Detect thay đổi: cả khi thêm mới lẫn khi xóa (để trống) giá trị cũ
            if (row.checkIn     != null && !row.checkIn.equals(curCI))
                changes.add(new FieldChange("Check-in",      curCI,     row.checkIn));
            if (row.checkOut    != null && !row.checkOut.equals(curCO))
                changes.add(new FieldChange("Check-out",     curCO,     row.checkOut));
            if (row.breakMinutes  != null && !row.breakMinutes.equals(curBr))
                changes.add(new FieldChange("Giờ giải lao", curBr,     row.breakMinutes));
            if (row.otDayMinutes  != null && !row.otDayMinutes.equals(curOtDay))
                changes.add(new FieldChange("Tăng ca ngày", curOtDay,  row.otDayMinutes));
            if (row.otNightMinutes != null && !row.otNightMinutes.equals(curOtNight))
                changes.add(new FieldChange("Tăng ca đêm",  curOtNight, row.otNightMinutes));
            if (row.approved != null && att != null && row.approved != att.isApproved())
                changes.add(new FieldChange("Trạng thái duyệt",
                    att.isApproved() ? "true" : "false", row.approved ? "true" : "false"));

            if (changes.isEmpty() && att != null) continue;
            if (changes.isEmpty() && att == null) continue; // row trống, không có gì để tạo
            String action = att == null ? "CREATE" : "UPDATE";
            // Với CREATE, hiện tất cả field sẽ được tạo
            if (att == null) {
                if (row.checkIn     != null && !row.checkIn.isBlank())
                    changes.add(new FieldChange("Check-in",      "", row.checkIn));
                if (row.checkOut    != null && !row.checkOut.isBlank())
                    changes.add(new FieldChange("Check-out",     "", row.checkOut));
                if (row.breakMinutes != null && !row.breakMinutes.isBlank())
                    changes.add(new FieldChange("Giờ giải lao",  "", row.breakMinutes));
                if (row.otDayMinutes != null && !row.otDayMinutes.isBlank())
                    changes.add(new FieldChange("Tăng ca ngày",  "", row.otDayMinutes));
                if (row.otNightMinutes != null && !row.otNightMinutes.isBlank())
                    changes.add(new FieldChange("Tăng ca đêm",   "", row.otNightMinutes));
            }
            result.add(AttendanceDiff.builder().action(action).code(row.empCode).name(label)
                .changes(changes).warnings(List.of()).build());
        }
        return result;
    }

    @Transactional
    public Map<String, Integer> importTimesheet(Long companyId, Long userId, MultipartFile file) {
        List<TimesheetImportRow> rows = readTimesheetSheet(file);
        if (rows.isEmpty()) return Map.of("created", 0, "updated", 0, "deleted", 0, "skipped", 0);

        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "ATTENDANCE_VIEW");
        Map<String, com.bosskin.entity.Employee> empMap = employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            .stream()
            .filter(e -> scopeIds.isEmpty() || (e.getDepartment() != null && scopeIds.contains(e.getDepartment().getId())))
            .collect(Collectors.toMap(com.bosskin.entity.Employee::getEmployeeCode, e -> e, (a, b) -> a));

        Set<LocalDate> dates = rows.stream().map(r -> r.date).collect(Collectors.toSet());
        LocalDate minDate = dates.stream().min(Comparator.naturalOrder()).orElseThrow();
        LocalDate maxDate = dates.stream().max(Comparator.naturalOrder()).orElseThrow();
        List<Attendance> existing = attendanceRepo.findByCompanyAndDateRange(companyId, minDate, maxDate);
        Map<Long, Map<LocalDate, Attendance>> existingMap = new HashMap<>();
        for (Attendance a : existing) {
            existingMap.computeIfAbsent(a.getEmployee().getId(), k -> new HashMap<>()).put(a.getDate(), a);
        }

        // Load shift assignments cho toàn bộ date range — key: employeeId -> Set<date>
        List<com.bosskin.entity.ShiftAssignment> allShiftAssignments =
            shiftAssignmentRepo.findByCompanyAndDateRange(companyId, minDate, maxDate);
        Map<Long, Set<LocalDate>> shiftDatesByEmployee = new HashMap<>();
        for (com.bosskin.entity.ShiftAssignment sa : allShiftAssignments) {
            shiftDatesByEmployee
                .computeIfAbsent(sa.getEmployee().getId(), k -> new HashSet<>())
                .add(sa.getWorkDate());
        }

        List<ApproveTask> approveTasks = new ArrayList<>();
        approveTaskHolder.set(approveTasks);

        int created = 0, updated = 0, deleted = 0, skipped = 0;
        // toSave: entities to batch-persist; approveFlags[i] = shouldApprove for toSave[i]
        List<Attendance> toSave = new ArrayList<>();
        List<Boolean> approveFlags = new ArrayList<>();

        for (TimesheetImportRow row : rows) {
            com.bosskin.entity.Employee emp = empMap.get(row.empCode);
            if (emp == null) { skipped++; continue; }
            try {
                Attendance att = existingMap.getOrDefault(emp.getId(), Map.of()).get(row.date);
                if (row.deleteFlag) {
                    if (att == null || att.isDeleted()) { skipped++; continue; }
                    att.setDeleted(true);
                    att.setDeletedAt(LocalDateTime.now());
                    toSave.add(att); approveFlags.add(false);
                    deleted++; continue;
                }
                if (att == null) {
                    boolean hasCheckIn = row.checkIn != null && !row.checkIn.isBlank();
                    boolean hasCheckOut = row.checkOut != null && !row.checkOut.isBlank();
                    boolean hasShift = shiftDatesByEmployee
                        .getOrDefault(emp.getId(), Set.of())
                        .contains(row.date);
                    if (!hasCheckIn && !hasCheckOut && !hasShift) { skipped++; continue; }
                    Attendance.AttendanceBuilder b = Attendance.builder()
                        .employee(emp).date(row.date).deleted(false).approved(false)
                        .status(null);
                    applyTimesheetRow(b, row);
                    toSave.add(b.build());
                    approveFlags.add(row.approved != null && row.approved);
                    created++;
                } else {
                    boolean wasApproved = att.isApproved();
                    if (wasApproved) {
                        att.setApproved(false);
                        att.setApprovedAt(null); att.setApprovedBy(null);
                        att.setSnapActualHours(null); att.setSnapDayHours(null);
                        att.setSnapDayOt(null); att.setSnapNightHours(null);
                        att.setSnapNightOt(null); att.setWorkFlags(null);
                        // A5: giữ trạng thái; duyệt lại sẽ tính lại
                    }
                    applyTimesheetRowToExisting(att, row);
                    boolean shouldApprove = row.approved != null ? row.approved : wasApproved;
                    toSave.add(att); approveFlags.add(shouldApprove);
                    updated++;
                }
            } catch (Exception e) { skipped++; }
        }

        // Batch save tất cả → lấy IDs cho approval tasks
        List<Attendance> saved = attendanceRepo.saveAll(toSave);
        for (int i = 0; i < saved.size(); i++) {
            if (Boolean.TRUE.equals(approveFlags.get(i))) {
                approveTasks.add(new ApproveTask(saved.get(i).getId(), true));
            }
        }
        Map<String, Integer> result = Map.of("created", created, "updated", updated, "deleted", deleted, "skipped", skipped);
        historyHelper.save(companyId, userId, HistoryType.IMPORT, "attendance",
                "timesheet-import.xlsx", file.isEmpty() ? new byte[0] : readBytes(file),
                created + updated, 0, skipped);
        return result;
    }

    private void applyTimesheetRow(Attendance.AttendanceBuilder b, TimesheetImportRow row) {
        if (row.checkIn  != null && !row.checkIn.isBlank())
            try { b.overrideCheckIn(LocalTime.parse(row.checkIn, TIME_FMT)); } catch (Exception ignored) {}
        if (row.checkOut != null && !row.checkOut.isBlank())
            try { b.overrideCheckOut(LocalTime.parse(row.checkOut, TIME_FMT)); } catch (Exception ignored) {}
        if (row.breakMinutes != null && !row.breakMinutes.isBlank())
            try { b.overrideBreakMinutes(parseDurationToMinutes(row.breakMinutes)); } catch (Exception ignored) {}
        if (row.otDayMinutes != null && !row.otDayMinutes.isBlank())
            try { b.overrideOtDayMinutes(parseDurationToMinutes(row.otDayMinutes)); } catch (Exception ignored) {}
        if (row.otNightMinutes != null && !row.otNightMinutes.isBlank())
            try { b.overrideOtNightMinutes(parseDurationToMinutes(row.otNightMinutes)); } catch (Exception ignored) {}
    }

    private void applyTimesheetRowToExisting(Attendance att, TimesheetImportRow row) {
        // approved được xử lý riêng qua doApprove() trong controller — không set ở đây
        if (row.checkIn != null) {
            if (row.checkIn.isBlank()) att.setOverrideCheckIn(null);
            else try { att.setOverrideCheckIn(LocalTime.parse(row.checkIn, TIME_FMT)); } catch (Exception ignored) {}
        }
        if (row.checkOut != null) {
            if (row.checkOut.isBlank()) att.setOverrideCheckOut(null);
            else try { att.setOverrideCheckOut(LocalTime.parse(row.checkOut, TIME_FMT)); } catch (Exception ignored) {}
        }
        if (row.breakMinutes != null) {
            if (row.breakMinutes.isBlank()) att.setOverrideBreakMinutes(null);
            else try { att.setOverrideBreakMinutes(parseDurationToMinutes(row.breakMinutes)); } catch (Exception ignored) {}
        }
        if (row.otDayMinutes != null) {
            if (row.otDayMinutes.isBlank()) att.setOverrideOtDayMinutes(null);
            else try { att.setOverrideOtDayMinutes(parseDurationToMinutes(row.otDayMinutes)); } catch (Exception ignored) {}
        }
        if (row.otNightMinutes != null) {
            if (row.otNightMinutes.isBlank()) att.setOverrideOtNightMinutes(null);
            else try { att.setOverrideOtNightMinutes(parseDurationToMinutes(row.otNightMinutes)); } catch (Exception ignored) {}
        }
    }

    // Parse "HH:mm" hoặc số phút nguyên → phút
    private int parseDurationToMinutes(String val) {
        val = val.trim();
        if (val.contains(":")) {
            String[] p = val.split(":");
            return Integer.parseInt(p[0]) * 60 + Integer.parseInt(p[1]);
        }
        return (int) Math.round(Double.parseDouble(val) * 60);
    }

    private void autoSizeAll(Sheet sheet, int numCols) {
        for (int c = 0; c < numCols; c++) {
            sheet.autoSizeColumn(c);
            int current = sheet.getColumnWidth(c);
            sheet.setColumnWidth(c, Math.min(current + 512, 65280));
        }
    }

    private static byte[] readBytes(MultipartFile file) {
        try { return file.getBytes(); } catch (IOException e) { return new byte[0]; }
    }
}
