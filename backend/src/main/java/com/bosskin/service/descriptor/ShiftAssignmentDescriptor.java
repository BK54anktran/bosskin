package com.bosskin.service.descriptor;

import com.bosskin.dto.ShiftDTO;
import com.bosskin.entity.Department;
import com.bosskin.entity.Employee;
import com.bosskin.entity.ShiftAssignment;
import com.bosskin.entity.WorkShift;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import com.bosskin.repository.WorkShiftRepository;
import com.bosskin.service.DeptScopeService;
import com.bosskin.service.ShiftExcelService;
import com.bosskin.service.WorkShiftService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelEntityDescriptor;
import com.bosskin.util.FilterDefinition;
import com.bosskin.util.ImportCommand;
import com.bosskin.util.SheetImportResult;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class ShiftAssignmentDescriptor implements ExcelEntityDescriptor<ShiftAssignmentDescriptor.Row> {

    private final ShiftAssignmentRepository assignRepo;
    private final DepartmentRepository      deptRepo;
    private final EmployeeRepository        employeeRepo;
    private final WorkShiftRepository       shiftRepo;
    private final WorkShiftService          shiftService;
    private final ShiftExcelService         shiftExcelService;
    private final DeptScopeService          deptScopeService;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    @Data
    public static class Row {
        private String assignmentId; // ID của ShiftAssignment — dùng để update/delete chính xác
        private String empCode;
        private String empName;
        private String deptName;
        private String date;
        private String shiftCode;
        private String shiftName;
        private String startTime;
        private String endTime;
        private String breakStart;
        private String breakEnd;
        private String note;
    }

    @Override public String sheetKey() { return "excel.sheet.shift.assign"; }
    @Override public String type()     { return "shift_assignment"; }

    @Override
    public List<ExcelColumn<Row>> columns() {
        return List.of(
            ExcelColumn.hiddenI18n("excel.col.assignment.id", r -> r.assignmentId, (r, v) -> r.assignmentId = v),
            ExcelColumn.ofI18n("excel.col.assignment.empCode",   r -> r.empCode,    (r, v) -> r.empCode    = v),
            ExcelColumn.readOnlyI18n("excel.col.assignment.empName",   r -> r.empName),
            ExcelColumn.readOnlyI18n("excel.col.assignment.deptName",  r -> r.deptName),
            ExcelColumn.ofI18n("excel.col.assignment.date",      r -> r.date,       (r, v) -> r.date       = v),
            ExcelColumn.ofI18n("excel.col.assignment.shiftCode", r -> r.shiftCode,  (r, v) -> r.shiftCode  = v),
            ExcelColumn.readOnlyI18n("excel.col.assignment.shiftName", r -> r.shiftName),
            ExcelColumn.readOnlyI18n("excel.col.assignment.startTime", r -> r.startTime),
            ExcelColumn.readOnlyI18n("excel.col.assignment.endTime",   r -> r.endTime),
            ExcelColumn.readOnlyI18n("excel.col.assignment.breakStart",r -> r.breakStart),
            ExcelColumn.readOnlyI18n("excel.col.assignment.breakEnd",  r -> r.breakEnd),
            ExcelColumn.ofI18n("excel.col.assignment.note",      r -> r.note,       (r, v) -> r.note       = v)
        );
    }

    @Override
    public Row newRow() { return new Row(); }

    @Override
    public List<Row> loadForExport(Long companyId, Long userId, Map<String, String> filters) {
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

        List<ShiftAssignment> assignments = assignRepo.findByCompanyAndDateRange(companyId, from, to);

        String deptCodesRaw = filters.getOrDefault("departmentCodes", "").trim();
        Set<String> deptFilter = deptCodesRaw.isEmpty() ? Set.of()
            : java.util.Arrays.stream(deptCodesRaw.split(","))
                .map(String::trim).filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());

        List<Row> result = new ArrayList<>();
        for (ShiftAssignment a : assignments) {
            if (a.getEmployee() == null) continue;
            Department dept = a.getEmployee().getDepartment();
            if (!deptFilter.isEmpty()) {
                String code = dept != null ? dept.getCode() : "";
                if (!deptFilter.contains(code)) continue;
            }

            Row r = new Row();
            r.assignmentId = String.valueOf(a.getId());
            r.empCode  = a.getEmployee().getEmployeeCode();
            r.empName  = a.getEmployee().getFullName();
            r.deptName = dept != null ? dept.getName() : "";
            r.date     = a.getWorkDate() != null ? a.getWorkDate().format(DATE_FMT) : "";

            WorkShift shift = a.getShift();
            if (shift != null) {
                r.shiftCode  = shift.getCode();
                r.shiftName  = shift.getName();
                r.startTime  = fmt(shift.getStartTime());
                r.endTime    = fmt(shift.getEndTime());
                r.breakStart = fmt(shift.getBreakStart());
                r.breakEnd   = fmt(shift.getBreakEnd());
            } else if (a.getSnapshotCode() != null) {
                r.shiftCode  = a.getSnapshotCode();
                r.shiftName  = nvl(a.getSnapshotName());
                r.startTime  = fmt(a.getSnapshotStartTime());
                r.endTime    = fmt(a.getSnapshotEndTime());
                r.breakStart = fmt(a.getSnapshotBreakStart());
                r.breakEnd   = fmt(a.getSnapshotBreakEnd());
            } else if (a.getCustomStartTime() != null) {
                // Custom time: encode thành shiftCode dạng "07:00~15:00(12:00~13:00)"
                StringBuilder sb = new StringBuilder();
                sb.append(fmt(a.getCustomStartTime())).append("~").append(fmt(a.getCustomEndTime()));
                if (a.getCustomBreakStart() != null && a.getCustomBreakEnd() != null)
                    sb.append("(").append(fmt(a.getCustomBreakStart())).append("~").append(fmt(a.getCustomBreakEnd())).append(")");
                r.shiftCode  = sb.toString();
                r.shiftName  = "Ca tùy chỉnh";
                r.startTime  = fmt(a.getCustomStartTime());
                r.endTime    = fmt(a.getCustomEndTime());
                r.breakStart = fmt(a.getCustomBreakStart());
                r.breakEnd   = fmt(a.getCustomBreakEnd());
            }
            r.note = nvl(a.getNote());
            result.add(r);
        }
        return result;
    }

    @Override
    public List<FilterDefinition> filterDefinitions(Long companyId) {
        List<FilterDefinition.Option> deptOptions = deptRepo
            .findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .filter(d -> d.getCode() != null && !d.getCode().isBlank())
            .map(d -> FilterDefinition.opt(d.getCode(), d.getName() + " (" + d.getCode() + ")"))
            .collect(Collectors.toList());

        int curYear = LocalDate.now().getYear();
        List<FilterDefinition.Option> yearOptions = List.of(
            FilterDefinition.opt(String.valueOf(curYear - 1), String.valueOf(curYear - 1)),
            FilterDefinition.opt(String.valueOf(curYear),     String.valueOf(curYear)),
            FilterDefinition.opt(String.valueOf(curYear + 1), String.valueOf(curYear + 1))
        );

        List<FilterDefinition.Option> monthOptions = new ArrayList<>();
        for (int m = 1; m <= 12; m++)
            monthOptions.add(FilterDefinition.opt(String.valueOf(m), String.format("%02d", m)));

        return List.of(
            FilterDefinition.select("departmentCodes", "filter.department", deptOptions),
            FilterDefinition.select("year",  "filter.year",  yearOptions),
            FilterDefinition.select("month", "filter.month", monthOptions)
        );
    }

    @Override
    public String getIdentifier(Row row) {
        // Ưu tiên ID thực của record — chính xác khi 1 NV có nhiều ca/ngày
        if (row.assignmentId != null && !row.assignmentId.isBlank())
            return "id:" + row.assignmentId.trim();
        return nvl(row.empCode) + "|" + nvl(row.date) + "|" + nvl(row.shiftCode);
    }

    @Override
    public boolean importable() { return true; }

    @Override
    @Transactional
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<Row>> rows,
            boolean dryRun) {

        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "SHIFT_VIEW");
        Map<String, Employee> empMap = employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            .stream()
            .filter(e -> scopeIds.isEmpty() || (e.getDepartment() != null && scopeIds.contains(e.getDepartment().getId())))
            .collect(Collectors.toMap(Employee::getEmployeeCode, e -> e, (a, b) -> a));
        Map<String, WorkShift> shiftMap = shiftRepo.findByCompanyIdAndActiveTrue(companyId)
            .stream().collect(Collectors.toMap(WorkShift::getCode, s -> s, (a, b) -> a));

        List<SheetImportResult.RowResult> results = new ArrayList<>();
        for (RowWithCommand<Row> rw : rows) {
            int rowNum = rw.rowNum();
            Row row = rw.data();
            ImportCommand cmd = rw.command();

            if (cmd == null) { results.add(SheetImportResult.RowResult.skip(rowNum)); continue; }
            if (row.empCode == null || row.empCode.isBlank()) {
                results.add(SheetImportResult.RowResult.error(rowNum, "error.employee.code_required"));
                continue;
            }
            if (row.date == null || row.date.isBlank()) {
                results.add(SheetImportResult.RowResult.error(rowNum, "error.assignment.date_required"));
                continue;
            }

            try {
                Employee emp = empMap.get(row.empCode.trim());
                if (emp == null) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.employee.not_found|" + row.empCode));
                    continue;
                }

                LocalDate date = LocalDate.parse(row.date.trim(), DATE_FMT);

                // Nếu có assignmentId → thao tác chính xác trên record đó
                Long assignId = null;
                if (row.assignmentId != null && !row.assignmentId.isBlank()) {
                    try { assignId = Long.parseLong(row.assignmentId.trim()); } catch (Exception ignored) {}
                }

                if (cmd == ImportCommand.DELETE) {
                    if (!dryRun) {
                        if (assignId != null) assignRepo.softDeleteById(assignId);
                        else shiftService.deleteAssignment(emp.getId(), date, companyId);
                    }
                    results.add(SheetImportResult.RowResult.ok(rowNum));
                    continue;
                }

                if (row.shiftCode == null || row.shiftCode.isBlank()) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.assignment.shift_required"));
                    continue;
                }

                String code = row.shiftCode.trim();
                WorkShift shift = shiftMap.get(code);
                ShiftDTO.AssignRequest req;

                if (shift != null) {
                    req = new ShiftDTO.AssignRequest(emp.getId(), shift.getId(), date, nvl(row.note).isBlank() ? null : row.note.trim(), null, null, null, null);
                } else {
                    LocalTime[] custom = shiftExcelService.parseCustomTimePublic(code);
                    if (custom == null) {
                        results.add(SheetImportResult.RowResult.error(rowNum, "error.assignment.invalid_shift|" + code));
                        continue;
                    }
                    req = new ShiftDTO.AssignRequest(emp.getId(), null, date, nvl(row.note).isBlank() ? null : row.note.trim(),
                        custom[0], custom[1], custom[2], custom[3]);
                }

                if (!dryRun) {
                    // Có ID → xóa đúng record đó rồi tạo lại (thay thế ca cụ thể, không ảnh hưởng ca khác cùng ngày)
                    if (assignId != null) assignRepo.softDeleteById(assignId);
                    else shiftService.deleteAssignment(emp.getId(), date, companyId);
                    shiftExcelService.assignOneInNewTx(companyId, req);
                }
                results.add(SheetImportResult.RowResult.ok(rowNum));
            } catch (Exception e) {
                results.add(SheetImportResult.RowResult.error(rowNum, e.getMessage()));
            }
        }
        return results;
    }

    private String fmt(LocalTime t) { return t != null ? t.format(TIME_FMT) : ""; }
    private String nvl(String s)    { return s != null ? s : ""; }
}
