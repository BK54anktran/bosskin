package com.bosskin.service.descriptor;

import com.bosskin.dto.PayrollDTO;
import com.bosskin.entity.Employee;
import com.bosskin.entity.Payroll;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.PayrollRepository;
import com.bosskin.service.DeptScopeService;
import com.bosskin.service.PayrollExcelService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelColumn.ColType;
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
public class PayrollDescriptor implements ExcelEntityDescriptor<PayrollDTO.ImportRow> {

    private final PayrollExcelService   payrollExcelService;
    private final PayrollRepository     payrollRepository;
    private final DepartmentRepository  deptRepo;
    private final EmployeeRepository    employeeRepo;
    private final DeptScopeService      deptScopeService;

    private static final String G_ID      = "identification";
    private static final String G_EARNING = "earnings";
    private static final String G_DED     = "deductions";
    private static final String G_PERIOD  = "period";

    @Override public String sheetKey() { return "excel.sheet.payroll.list"; }
    @Override public String type()     { return "payroll"; }
    @Override public boolean importable() { return false; }

    @Override
    public List<ExcelColumn<PayrollDTO.ImportRow>> columns() {
        return List.of(
            // ── Identification ──
            ExcelColumn.readOnlyI18n("excel.col.payroll.employeeCode",   G_ID, r -> r.getEmployeeCode()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.employeeName",   G_ID, r -> r.getEmployeeName()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.departmentName", G_ID, r -> r.getDepartmentName()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.salaryGradeCode",G_ID, r -> r.getSalaryGradeCode()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.payType",        G_ID, r -> r.getPayType()),
            // ── Hours & days ──
            ExcelColumn.readOnlyI18n("excel.col.payroll.presentDays",      G_PERIOD, ColType.INTEGER, r -> r.getPresentDays()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.dayHours",         G_PERIOD, ColType.DECIMAL, r -> r.getDayHours()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.nightHours",       G_PERIOD, ColType.DECIMAL, r -> r.getNightHours()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.dayOt",            G_PERIOD, ColType.DECIMAL, r -> r.getDayOt()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.nightOt",          G_PERIOD, ColType.DECIMAL, r -> r.getNightOt()),
            // ── Earnings ──
            ExcelColumn.readOnlyI18n("excel.col.payroll.baseSalary",      G_EARNING, ColType.MONEY, r -> r.getBaseSalary()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.totalAllowance",   G_EARNING, ColType.MONEY, r -> r.getTotalAllowance()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.totalIncome",      G_EARNING, ColType.MONEY, r -> r.getTotalIncome()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.grossSalary",      G_EARNING, ColType.MONEY, r -> r.getGrossSalary()),
            // ── Deductions & net ──
            ExcelColumn.readOnlyI18n("excel.col.payroll.totalDeduction",   G_DED, ColType.MONEY, r -> r.getTotalDeduction()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.netSalary",        G_DED, ColType.MONEY, r -> r.getNetSalary()),
            ExcelColumn.readOnlyI18n("excel.col.payroll.status",           G_DED, r -> r.getStatus())
        );
    }

    @Override
    public PayrollDTO.ImportRow newRow() { return new PayrollDTO.ImportRow(); }

    @Override
    public List<PickItem> searchForPick(Long companyId, Long userId, String q) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "PAYROLL_VIEW");
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
    public List<PayrollDTO.ImportRow> loadForExport(Long companyId, Long userId,
                                                     Map<String, String> filters) {
        return payrollExcelService.loadAllForExport(companyId, userId, filters);
    }

    @Override
    public List<FilterDefinition> filterDefinitions(Long companyId) {
        List<FilterDefinition.Option> deptOptions = deptRepo
            .findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .filter(d -> d.getCode() != null && !d.getCode().isBlank())
            .map(d -> FilterDefinition.opt(d.getCode(), d.getName() + " (" + d.getCode() + ")"))
            .collect(Collectors.toList());

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
                FilterDefinition.opt("DRAFT",    "filter.payroll.draft"),
                FilterDefinition.opt("APPROVED", "filter.payroll.approved"),
                FilterDefinition.opt("PAID",     "filter.payroll.paid")
            ))
        );
    }

    @Override
    public String getIdentifier(PayrollDTO.ImportRow row) {
        return (row.getEmployeeCode() != null ? row.getEmployeeCode() : "")
            + "|" + (row.getYear() != null ? row.getYear() : "")
            + "/" + (row.getMonth() != null ? row.getMonth() : "");
    }

    @Override
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<PayrollDTO.ImportRow>> rows,
            boolean dryRun) {
        // Payroll is export-only — importable() returns false so this should never be called
        return rows.stream()
            .map(rw -> SheetImportResult.RowResult.error(rw.rowNum(), "error.payroll.import_not_supported"))
            .collect(Collectors.toList());
    }
}
