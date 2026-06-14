package com.bosskin.service.descriptor;

import com.bosskin.entity.Company;
import com.bosskin.entity.Employee;
import com.bosskin.entity.LeaveGrant;
import com.bosskin.entity.LeaveType;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.LeaveGrantRepository;
import com.bosskin.repository.LeaveTypeRepository;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelColumn.ColType;
import com.bosskin.util.ExcelEntityDescriptor;
import com.bosskin.util.FilterDefinition;
import com.bosskin.util.ImportCommand;
import com.bosskin.util.SheetImportResult;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class LeaveGrantDescriptor implements ExcelEntityDescriptor<LeaveGrantDescriptor.Row> {

    private final LeaveGrantRepository grantRepo;
    private final LeaveTypeRepository  leaveTypeRepo;
    private final EmployeeRepository   employeeRepo;
    private final DepartmentRepository deptRepo;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    @Data
    public static class Row {
        private String empCode;
        private String empName;
        private String deptName;
        private String leaveTypeCode;
        private String leaveTypeName;
        private String grantDays;
        private String grantHours;
        private String usedDays;
        private String usedHours;
        private String grantedAt;
        private String validFrom;
        private String validTo;
        private String note;
    }

    @Override public String sheetKey() { return "excel.sheet.leave_grant.list"; }
    @Override public String type()     { return "leave_grant"; }

    @Override
    public List<ExcelColumn<Row>> columns() {
        return List.of(
            ExcelColumn.ofI18n("excel.col.leaveGrant.empCode",       r -> r.getEmpCode(),       (r, v) -> r.setEmpCode(v)),
            ExcelColumn.readOnlyI18n("excel.col.leaveGrant.empName",       r -> r.getEmpName()),
            ExcelColumn.readOnlyI18n("excel.col.leaveGrant.deptName",       r -> r.getDeptName()),
            ExcelColumn.ofI18n("excel.col.leaveGrant.leaveTypeCode",  r -> r.getLeaveTypeCode(),  (r, v) -> r.setLeaveTypeCode(v)),
            ExcelColumn.readOnlyI18n("excel.col.leaveGrant.leaveTypeName", r -> r.getLeaveTypeName()),
            ExcelColumn.ofI18n("excel.col.leaveGrant.grantDays",      ColType.DECIMAL,
                                                                       r -> r.getGrantDays(),      (r, v) -> r.setGrantDays(v)),
            ExcelColumn.ofI18n("excel.col.leaveGrant.grantHours",     ColType.DECIMAL,
                                                                       r -> r.getGrantHours(),     (r, v) -> r.setGrantHours(v)),
            ExcelColumn.readOnlyI18n("excel.col.leaveGrant.usedDays",  null, ColType.DECIMAL, r -> r.getUsedDays()),
            ExcelColumn.readOnlyI18n("excel.col.leaveGrant.usedHours", null, ColType.DECIMAL, r -> r.getUsedHours()),
            ExcelColumn.ofI18n("excel.col.leaveGrant.grantedAt",      r -> r.getGrantedAt(),      (r, v) -> r.setGrantedAt(v)),
            ExcelColumn.ofI18n("excel.col.leaveGrant.validFrom",      r -> r.getValidFrom(),      (r, v) -> r.setValidFrom(v)),
            ExcelColumn.ofI18n("excel.col.leaveGrant.validTo",        r -> r.getValidTo(),        (r, v) -> r.setValidTo(v)),
            ExcelColumn.ofI18n("excel.col.leaveGrant.note",           r -> r.getNote(),           (r, v) -> r.setNote(v))
        );
    }

    @Override
    public Row newRow() { return new Row(); }

    @Override
    public List<FilterDefinition> filterDefinitions(Long companyId) {
        List<FilterDefinition.Option> deptOptions = deptRepo
            .findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .filter(d -> d.getCode() != null && !d.getCode().isBlank())
            .map(d -> FilterDefinition.opt(d.getCode(), d.getName() + " (" + d.getCode() + ")"))
            .collect(Collectors.toList());

        List<FilterDefinition.Option> leaveTypeOptions = leaveTypeRepo
            .findByCompanyIdAndDeletedFalseOrderByNameAsc(companyId).stream()
            .map(t -> FilterDefinition.opt(t.getCode(), t.getName() + " (" + t.getCode() + ")"))
            .collect(Collectors.toList());

        return List.of(
            FilterDefinition.text("search",        "filter.search"),
            FilterDefinition.select("department",  "filter.department",  deptOptions),
            FilterDefinition.select("leaveType",   "filter.leaveType",   leaveTypeOptions)
        );
    }

    @Override
    public List<Row> loadForExport(Long companyId, Long userId, Map<String, String> filters) {
        String searchRaw   = filters.getOrDefault("search",      "").trim().toLowerCase();
        String deptFilter  = filters.getOrDefault("department",  "").trim().toUpperCase();
        String ltFilter    = filters.getOrDefault("leaveType",   "").trim().toUpperCase();

        Map<String, String> deptCodeByEmpId = buildDeptCodeMap(companyId);
        Map<String, String> deptNameByEmpId = buildDeptNameMap(companyId);

        List<LeaveGrant> grants = grantRepo.findForCompany(companyId, null, null);

        return grants.stream()
            .filter(g -> g.getEmployee() != null)
            .filter(g -> {
                Employee e = g.getEmployee();
                String code = e.getEmployeeCode() != null ? e.getEmployeeCode() : "";
                String name = e.getFullName() != null ? e.getFullName() : "";
                if (!searchRaw.isEmpty()
                        && !code.toLowerCase().contains(searchRaw)
                        && !name.toLowerCase().contains(searchRaw)) return false;

                if (!deptFilter.isEmpty()) {
                    String dc = deptCodeByEmpId.getOrDefault(String.valueOf(e.getId()), "");
                    if (!deptFilter.equals(dc)) return false;
                }
                if (!ltFilter.isEmpty()) {
                    String ltCode = g.getLeaveType() != null ? g.getLeaveType().getCode().toUpperCase() : "";
                    if (!ltFilter.equals(ltCode)) return false;
                }
                return true;
            })
            .map(g -> {
                Employee e = g.getEmployee();
                Row r = new Row();
                r.setEmpCode(e.getEmployeeCode());
                r.setEmpName(e.getFullName());
                r.setDeptName(deptNameByEmpId.getOrDefault(String.valueOf(e.getId()), ""));
                if (g.getLeaveType() != null) {
                    r.setLeaveTypeCode(g.getLeaveType().getCode());
                    r.setLeaveTypeName(g.getLeaveType().getName());
                }
                r.setGrantDays(g.getGrantDays() != null  ? g.getGrantDays().toPlainString()  : "");
                r.setGrantHours(g.getGrantHours() != null ? g.getGrantHours().toPlainString() : "");
                r.setUsedDays(g.getUsedDays().toPlainString());
                r.setUsedHours(g.getUsedHours().toPlainString());
                r.setGrantedAt(g.getGrantedAt() != null ? g.getGrantedAt().format(DATE_FMT) : "");
                r.setValidFrom(g.getValidFrom() != null ? g.getValidFrom().format(DATE_FMT) : "");
                r.setValidTo(g.getValidTo() != null ? g.getValidTo().format(DATE_FMT) : "");
                r.setNote(g.getNote() != null ? g.getNote() : "");
                return r;
            })
            .collect(Collectors.toList());
    }

    @Override
    public String getIdentifier(Row row) {
        return nvl(row.getEmpCode()) + "|" + nvl(row.getLeaveTypeCode()) + "|" + nvl(row.getGrantedAt());
    }

    @Override
    @Transactional
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<Row>> rows,
            boolean dryRun) {

        Map<String, Employee> empMap = employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
            .collect(Collectors.toMap(Employee::getEmployeeCode, e -> e, (a, b) -> a));

        Map<String, LeaveType> ltMap = leaveTypeRepo
            .findByCompanyIdAndDeletedFalseOrderByNameAsc(companyId).stream()
            .collect(Collectors.toMap(t -> t.getCode().toUpperCase(), t -> t, (a, b) -> a));

        List<SheetImportResult.RowResult> results = new ArrayList<>();

        for (RowWithCommand<Row> rw : rows) {
            int rowNum = rw.rowNum();
            try {
                if (rw.command() == null) {
                    results.add(SheetImportResult.RowResult.skip(rowNum));
                    continue;
                }
                Row data = rw.data();

                if (data.getEmpCode() == null || data.getEmpCode().isBlank()) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.leaveGrant.emp_required"));
                    continue;
                }
                if (data.getLeaveTypeCode() == null || data.getLeaveTypeCode().isBlank()) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.leaveGrant.leaveType_required"));
                    continue;
                }
                if (data.getGrantedAt() == null || data.getGrantedAt().isBlank()) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.leaveGrant.grantedAt_required"));
                    continue;
                }

                Employee emp = empMap.get(data.getEmpCode().trim());
                if (emp == null) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.employee.not_found:" + data.getEmpCode()));
                    continue;
                }

                LeaveType lt = ltMap.get(data.getLeaveTypeCode().trim().toUpperCase());
                if (lt == null) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.leaveGrant.leaveType_not_found:" + data.getLeaveTypeCode()));
                    continue;
                }

                LocalDate grantedAt;
                try { grantedAt = LocalDate.parse(data.getGrantedAt().trim(), DATE_FMT); }
                catch (Exception e) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.leaveGrant.invalid_date"));
                    continue;
                }

                LocalDate validFrom = parseDate(data.getValidFrom());
                LocalDate validTo   = parseDate(data.getValidTo());

                BigDecimal grantDays  = parseBD(data.getGrantDays());
                BigDecimal grantHours = parseBD(data.getGrantHours());

                if (rw.command() == ImportCommand.DELETE) {
                    // DELETE: tìm grant khớp và soft-delete
                    if (!dryRun) {
                        grantRepo.findForCompany(companyId, emp.getId(), lt.getId()).stream()
                            .filter(g -> grantedAt.equals(g.getGrantedAt()))
                            .forEach(g -> grantRepo.deleteById(g.getId()));
                    }
                    results.add(SheetImportResult.RowResult.ok(rowNum));
                    continue;
                }

                if (dryRun) {
                    String summary = "CREATE: " + data.getEmpCode() + " | " + data.getLeaveTypeCode()
                        + " | days=" + grantDays + " hours=" + grantHours;
                    results.add(SheetImportResult.RowResult.of(rowNum, "OK", summary));
                    continue;
                }

                Company company = new Company();
                company.setId(companyId);

                LeaveGrant grant = LeaveGrant.builder()
                    .company(company)
                    .employee(emp)
                    .leaveType(lt)
                    .source(LeaveGrant.Source.MANUAL)
                    .grantDays(grantDays)
                    .grantHours(grantHours)
                    .grantedAt(grantedAt)
                    .validFrom(validFrom)
                    .validTo(validTo)
                    .note(data.getNote() != null && !data.getNote().isBlank() ? data.getNote().trim() : null)
                    .build();
                grantRepo.save(grant);
                results.add(SheetImportResult.RowResult.ok(rowNum));
            } catch (Exception e) {
                results.add(SheetImportResult.RowResult.error(rowNum, e.getMessage()));
            }
        }
        return results;
    }

    private Map<String, String> buildDeptCodeMap(Long companyId) {
        return employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
            .collect(Collectors.toMap(
                e -> String.valueOf(e.getId()),
                e -> e.getDepartment() != null && e.getDepartment().getCode() != null
                    ? e.getDepartment().getCode().toUpperCase() : "",
                (a, b) -> a));
    }

    private Map<String, String> buildDeptNameMap(Long companyId) {
        return employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
            .collect(Collectors.toMap(
                e -> String.valueOf(e.getId()),
                e -> e.getDepartment() != null && e.getDepartment().getName() != null
                    ? e.getDepartment().getName() : "",
                (a, b) -> a));
    }

    private LocalDate parseDate(String val) {
        if (val == null || val.isBlank()) return null;
        try { return LocalDate.parse(val.trim(), DATE_FMT); } catch (Exception e) { return null; }
    }

    private BigDecimal parseBD(String val) {
        if (val == null || val.isBlank()) return null;
        try { return new BigDecimal(val.replaceAll("[^\\d.]", "")); } catch (Exception e) { return null; }
    }

    private String nvl(String s) { return s != null ? s : ""; }
}
