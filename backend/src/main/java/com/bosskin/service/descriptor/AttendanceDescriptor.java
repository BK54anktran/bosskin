package com.bosskin.service.descriptor;

import com.bosskin.dto.AttendanceDTO;
import com.bosskin.entity.Employee;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.service.AttendanceExcelService;
import com.bosskin.service.DeptScopeService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelEntityDescriptor;
import com.bosskin.util.FilterDefinition;
import com.bosskin.util.SheetImportResult;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class AttendanceDescriptor implements ExcelEntityDescriptor<AttendanceDTO.ImportRow> {

    private final AttendanceExcelService attendanceExcelService;
    private final DepartmentRepository   deptRepo;
    private final EmployeeRepository     employeeRepo;
    private final DeptScopeService       deptScopeService;

    private static final String G_BASIC    = "basic";
    private static final String G_COMPUTED = "computed";
    private static final String G_OVERRIDE = "override";

    @Override public String sheetKey() { return "excel.sheet.attendance.list"; }
    @Override public String type()     { return "attendance"; }

    @Override
    public List<ExcelColumn<AttendanceDTO.ImportRow>> columns() {
        return List.of(
            // ── Basic ──
            ExcelColumn.ofI18n("excel.col.attendance.date",         G_BASIC, true,  true,  r -> r.getDate(),         (r, v) -> r.setDate(v)),
            ExcelColumn.ofI18n("excel.col.attendance.employeeCode", G_BASIC, true,  true,  r -> r.getEmployeeCode(), (r, v) -> r.setEmployeeCode(v)),
            ExcelColumn.readOnlyI18n("excel.col.attendance.employeeName",   G_BASIC, r -> r.getEmployeeName()),
            ExcelColumn.readOnlyI18n("excel.col.attendance.departmentName", G_BASIC, r -> r.getDepartmentName()),
            ExcelColumn.ofI18n("excel.col.attendance.status",       G_BASIC, true,  false, r -> r.getStatus(),       (r, v) -> r.setStatus(v)),
            ExcelColumn.ofI18n("excel.col.attendance.checkIn",      G_BASIC, true,  false, r -> r.getCheckIn(),      (r, v) -> r.setCheckIn(v)),
            ExcelColumn.ofI18n("excel.col.attendance.checkOut",     G_BASIC, true,  false, r -> r.getCheckOut(),     (r, v) -> r.setCheckOut(v)),
            ExcelColumn.ofI18n("excel.col.attendance.note",         G_BASIC, false, false, r -> r.getNote(),         (r, v) -> r.setNote(v)),
            // ── Computed (read-only) ──
            ExcelColumn.readOnlyI18n("excel.col.attendance.snapActualHours", G_COMPUTED, r -> r.getSnapActualHours()),
            ExcelColumn.readOnlyI18n("excel.col.attendance.snapDayOt",       G_COMPUTED, r -> r.getSnapDayOt()),
            ExcelColumn.readOnlyI18n("excel.col.attendance.snapNightOt",     G_COMPUTED, r -> r.getSnapNightOt()),
            ExcelColumn.readOnlyI18n("excel.col.attendance.approved",        G_COMPUTED, r -> r.getApproved()),
            // ── Override ──
            ExcelColumn.ofI18n("excel.col.attendance.overrideCheckIn",       G_OVERRIDE, false, false, r -> r.getOverrideCheckIn(),       (r, v) -> r.setOverrideCheckIn(v)),
            ExcelColumn.ofI18n("excel.col.attendance.overrideCheckOut",      G_OVERRIDE, false, false, r -> r.getOverrideCheckOut(),      (r, v) -> r.setOverrideCheckOut(v)),
            ExcelColumn.ofI18n("excel.col.attendance.overrideBreakMinutes",  G_OVERRIDE, false, false, r -> r.getOverrideBreakMinutes(),  (r, v) -> r.setOverrideBreakMinutes(v)),
            ExcelColumn.ofI18n("excel.col.attendance.overrideOtDayMinutes",  G_OVERRIDE, false, false, r -> r.getOverrideOtDayMinutes(),  (r, v) -> r.setOverrideOtDayMinutes(v)),
            ExcelColumn.ofI18n("excel.col.attendance.overrideOtNightMinutes",G_OVERRIDE, false, false, r -> r.getOverrideOtNightMinutes(),(r, v) -> r.setOverrideOtNightMinutes(v))
        );
    }

    @Override
    public AttendanceDTO.ImportRow newRow() { return new AttendanceDTO.ImportRow(); }

    @Override
    public List<PickItem> searchForPick(Long companyId, Long userId, String q) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "ATTENDANCE_VIEW");
        org.springframework.data.domain.Page<Employee> page = scopeIds.isEmpty()
            ? employeeRepo.findAllWithFilters(companyId, q, null, null, PageRequest.of(0, 20))
            : employeeRepo.findAllWithDeptScope(companyId, scopeIds, q, null, PageRequest.of(0, 20));
        return page.getContent().stream()
            .map(e -> new PickItem(
                e.getEmployeeCode(),
                e.getFullName() + " (" + e.getEmployeeCode() + ")"
                    + (e.getDepartment() != null ? " — " + e.getDepartment().getName() : "")))
            .collect(Collectors.toList());
    }

    @Override
    public List<AttendanceDTO.ImportRow> loadForExport(Long companyId, Long userId,
                                                        Map<String, String> filters) {
        return attendanceExcelService.loadAllForExport(companyId, userId, filters);
    }

    @Override
    public List<FilterDefinition> filterDefinitions(Long companyId) {
        List<FilterDefinition.Option> deptOptions = deptRepo
            .findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .filter(d -> d.getCode() != null && !d.getCode().isBlank())
            .map(d -> FilterDefinition.opt(d.getCode(), d.getName() + " (" + d.getCode() + ")"))
            .collect(Collectors.toList());

        // Year options: current year ± 1
        int curYear = java.time.LocalDate.now().getYear();
        List<FilterDefinition.Option> yearOptions = List.of(
            FilterDefinition.opt(String.valueOf(curYear - 1), String.valueOf(curYear - 1)),
            FilterDefinition.opt(String.valueOf(curYear),     String.valueOf(curYear)),
            FilterDefinition.opt(String.valueOf(curYear + 1), String.valueOf(curYear + 1))
        );

        List<FilterDefinition.Option> monthOptions = new ArrayList<>();
        for (int m = 1; m <= 12; m++)
            monthOptions.add(FilterDefinition.opt(String.valueOf(m), String.format("%02d", m)));

        return List.of(
            FilterDefinition.text("search", "filter.search"),
            FilterDefinition.select("departmentCodes", "filter.department", deptOptions),
            FilterDefinition.select("year",  "filter.year",  yearOptions),
            FilterDefinition.select("month", "filter.month", monthOptions),
            FilterDefinition.select("status", "filter.status", List.of(
                FilterDefinition.opt("ALL",      "filter.status.all"),
                FilterDefinition.opt("PRESENT",  "filter.attendance.present"),
                FilterDefinition.opt("ABSENT",   "filter.attendance.absent"),
                FilterDefinition.opt("LATE",     "filter.attendance.late"),
                FilterDefinition.opt("HALF_DAY", "filter.attendance.halfDay"),
                FilterDefinition.opt("LEAVE",    "filter.attendance.leave")
            ))
        );
    }

    @Override
    public String getIdentifier(AttendanceDTO.ImportRow row) {
        return (row.getEmployeeCode() != null ? row.getEmployeeCode() : "")
            + "|" + (row.getDate() != null ? row.getDate() : "");
    }

    @Override
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<AttendanceDTO.ImportRow>> rows,
            boolean dryRun) {

        List<SheetImportResult.RowResult> results = new ArrayList<>();
        for (RowWithCommand<AttendanceDTO.ImportRow> rw : rows) {
            if (rw.command() == null) {
                results.add(SheetImportResult.RowResult.skip(rw.rowNum()));
                continue;
            }
            if (dryRun) {
                try {
                    SheetImportResult.RowResult r = attendanceExcelService
                        .previewUniversalRow(companyId, userId, rw.data(), rw.command());
                    results.add(SheetImportResult.RowResult.of(rw.rowNum(), r.status(), r.message()));
                } catch (Exception e) {
                    results.add(SheetImportResult.RowResult.error(rw.rowNum(), e.getMessage()));
                }
            } else {
                try {
                    boolean done = attendanceExcelService
                        .importUniversalRow(companyId, userId, rw.data(), rw.command(), rw.presentColumns());
                    results.add(done
                        ? SheetImportResult.RowResult.ok(rw.rowNum())
                        : SheetImportResult.RowResult.warn(rw.rowNum(), "warning.attendance.already_exists"));
                } catch (Exception e) {
                    results.add(SheetImportResult.RowResult.error(rw.rowNum(), e.getMessage()));
                }
            }
        }
        return results;
    }
}
