package com.bosskin.service.descriptor;

import com.bosskin.dto.EmployeeDTO;
import com.bosskin.entity.Employee;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.SalaryGradeRepository;
import com.bosskin.service.DeptScopeService;
import com.bosskin.service.EmployeeImportService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelEntityDescriptor;
import com.bosskin.util.FilterDefinition;
import com.bosskin.util.ImportCommand;
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
public class EmployeeDescriptor implements ExcelEntityDescriptor<EmployeeDTO.ImportRow> {

    private final EmployeeImportService employeeImportService;
    private final DepartmentRepository  deptRepo;
    private final SalaryGradeRepository salaryGradeRepo;
    private final EmployeeRepository    employeeRepo;
    private final DeptScopeService      deptScopeService;

    private static final String G_BASIC    = "basic";
    private static final String G_CONTRACT = "contract";
    private static final String G_PERSONAL = "personal";

    @Override public String sheetKey() { return "excel.sheet.employee.basic"; }
    @Override public String type()     { return "employee"; }

    @Override
    public List<ExcelColumn<EmployeeDTO.ImportRow>> columns() {
        return List.of(
            // ── Basic ── (required = bắt buộc khi import)
            ExcelColumn.ofI18n("excel.col.employee.code",           G_BASIC, true,  true,  r -> r.getEmployeeCode(),   (r, v) -> r.setEmployeeCode(v)),
            ExcelColumn.ofI18n("excel.col.employee.fullName",       G_BASIC, true,  true,  r -> r.getFullName(),       (r, v) -> r.setFullName(v)),
            ExcelColumn.ofI18n("excel.col.employee.email",          G_BASIC, true,  true,  r -> r.getEmail(),          (r, v) -> r.setEmail(v)),
            ExcelColumn.ofI18n("excel.col.employee.phone",          G_BASIC, true,  false, r -> r.getPhone(),          (r, v) -> r.setPhone(v)),
            ExcelColumn.ofI18n("excel.col.employee.gender",         G_BASIC, true,  false, r -> r.getGender(),         (r, v) -> r.setGender(v)),
            ExcelColumn.ofI18n("excel.col.employee.dateOfBirth",    G_BASIC, true,  false, r -> r.getDateOfBirth(),    (r, v) -> r.setDateOfBirth(v)),
            ExcelColumn.ofI18n("excel.col.employee.joinDate",       G_BASIC, true,  false, r -> r.getJoinDate(),       (r, v) -> r.setJoinDate(v)),
            ExcelColumn.ofI18n("excel.col.employee.leaveDate",      G_BASIC, false, false, r -> r.getLeaveDate(),      (r, v) -> r.setLeaveDate(v)),
            ExcelColumn.ofI18n("excel.col.employee.status",         G_BASIC, true,  false, r -> r.getStatus(),         (r, v) -> r.setStatus(v)),
            // ── Contract ────────────────────────────────────────────────────────
            ExcelColumn.ofI18n("excel.col.employee.departmentCode", G_CONTRACT, true,  true,  r -> r.getDepartmentCode(), (r, v) -> r.setDepartmentCode(v)),
            ExcelColumn.readOnlyI18n("excel.col.employee.departmentName", G_CONTRACT, r -> r.getDepartmentName()),
            ExcelColumn.ofI18n("excel.col.employee.positionCode",   G_CONTRACT, true,  false, r -> r.getPositionCode(),   (r, v) -> r.setPositionCode(v)),
            ExcelColumn.readOnlyI18n("excel.col.employee.positionName", G_CONTRACT, r -> r.getPositionName()),
            ExcelColumn.ofI18n("excel.col.employee.salaryGradeCode",G_CONTRACT, true,  true,  r -> r.getSalaryGradeCode(),(r, v) -> r.setSalaryGradeCode(v)),
            ExcelColumn.ofI18n("excel.col.employee.contractSalary", G_CONTRACT, false, false, r -> r.getContractSalary(), (r, v) -> r.setContractSalary(v)),
            // ── Personal ────────────────────────────────────────────────────────
            ExcelColumn.ofI18n("excel.col.employee.identityCard",   G_PERSONAL, false, false, r -> r.getIdentityCard(),   (r, v) -> r.setIdentityCard(v)),
            ExcelColumn.ofI18n("excel.col.employee.address",        G_PERSONAL, false, false, r -> r.getAddress(),        (r, v) -> r.setAddress(v)),
            ExcelColumn.ofI18n("excel.col.employee.personalEmail",  G_PERSONAL, false, false, r -> r.getPersonalEmail(),  (r, v) -> r.setPersonalEmail(v)),
            ExcelColumn.ofI18n("excel.col.employee.bankAccount",    G_PERSONAL, false, false, r -> r.getBankAccount(),    (r, v) -> r.setBankAccount(v)),
            ExcelColumn.ofI18n("excel.col.employee.bankName",       G_PERSONAL, false, false, r -> r.getBankName(),       (r, v) -> r.setBankName(v)),
            // ── Thuế / bảo hiểm (bước M) ────────────────────────────────────────
            ExcelColumn.ofI18n("excel.col.employee.taxCode",           G_PERSONAL, false, false, r -> r.getTaxCode(),           (r, v) -> r.setTaxCode(v)),
            ExcelColumn.ofI18n("excel.col.employee.socialInsuranceNo", G_PERSONAL, false, false, r -> r.getSocialInsuranceNo(), (r, v) -> r.setSocialInsuranceNo(v)),
            ExcelColumn.ofI18n("excel.col.employee.healthInsurancePlace", G_PERSONAL, false, false, r -> r.getHealthInsurancePlace(), (r, v) -> r.setHealthInsurancePlace(v)),
            ExcelColumn.ofI18n("excel.col.employee.insuranceJoinDate", G_PERSONAL, false, false, r -> r.getInsuranceJoinDate(), (r, v) -> r.setInsuranceJoinDate(v))
        );
    }

    @Override
    public EmployeeDTO.ImportRow newRow() { return new EmployeeDTO.ImportRow(); }

    @Override
    public List<EmployeeDTO.ImportRow> loadForExport(Long companyId, Long userId,
                                                      Map<String, String> filters) {
        return employeeImportService.loadAllForExport(companyId, userId, filters);
    }

    @Override
    public List<PickItem> searchForPick(Long companyId, Long userId, String q) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");
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
    public List<FilterDefinition> filterDefinitions(Long companyId) {
        // Department options — value = code, label = "Tên (mã)"
        List<FilterDefinition.Option> deptOptions = deptRepo
            .findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .filter(d -> d.getCode() != null && !d.getCode().isBlank())
            .map(d -> FilterDefinition.opt(d.getCode(), d.getName() + " (" + d.getCode() + ")"))
            .collect(Collectors.toList());

        // SalaryGrade options
        List<FilterDefinition.Option> gradeOptions = salaryGradeRepo
            .findByCompanyId(companyId).stream()
            .map(g -> FilterDefinition.opt(g.getCode(), g.getName()))
            .collect(Collectors.toList());

        return List.of(
            FilterDefinition.text("search", "filter.search"),
            FilterDefinition.select("departmentCodes", "filter.department", deptOptions),
            FilterDefinition.select("status", "filter.status", List.of(
                FilterDefinition.opt("ALL",      "filter.status.all"),
                FilterDefinition.opt("ACTIVE",   "filter.status.active"),
                FilterDefinition.opt("INACTIVE", "filter.status.inactive")
            )),
            FilterDefinition.select("salaryGradeCode", "filter.salaryGrade", gradeOptions),
            FilterDefinition.dateRange("joinDateFrom", "filter.joinDate")
        );
    }

    @Override
    public String getIdentifier(EmployeeDTO.ImportRow row) {
        String code = row.getEmployeeCode()   != null ? row.getEmployeeCode()   : "";
        String name = row.getFullName()       != null ? row.getFullName()       : "";
        String dept = row.getDepartmentName() != null ? row.getDepartmentName() : "";
        return code + "|" + name + "|" + dept;
    }

    @Override
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<EmployeeDTO.ImportRow>> rows,
            boolean dryRun) {

        List<SheetImportResult.RowResult> results = new ArrayList<>();

        for (RowWithCommand<EmployeeDTO.ImportRow> rw : rows) {
            if (rw.command() == null) {
                results.add(SheetImportResult.RowResult.skip(rw.rowNum()));
                continue;
            }

            if (dryRun) {
                try {
                    SheetImportResult.RowResult r = employeeImportService
                        .previewRow(companyId, userId, rw.data(), rw.command());
                    results.add(SheetImportResult.RowResult.of(rw.rowNum(), r.status(), r.message()));
                } catch (Exception e) {
                    results.add(SheetImportResult.RowResult.error(rw.rowNum(), e.getMessage()));
                }
            } else {
                try {
                    boolean done = employeeImportService.importRow(companyId, userId, rw.data(), rw.command(), rw.presentColumns());
                    results.add(done
                        ? SheetImportResult.RowResult.ok(rw.rowNum())
                        : SheetImportResult.RowResult.warn(rw.rowNum(), "warning.employee.already_exists"));
                } catch (Exception e) {
                    results.add(SheetImportResult.RowResult.error(rw.rowNum(), e.getMessage()));
                }
            }
        }

        return results;
    }
}
