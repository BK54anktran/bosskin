package com.bosskin.service.descriptor;

import com.bosskin.entity.SalaryGrade;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.SalaryGradeRepository;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelColumn.ColType;
import com.bosskin.util.ExcelEntityDescriptor;
import com.bosskin.util.FilterDefinition;
import com.bosskin.util.ImportCommand;
import com.bosskin.util.SheetImportResult;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.*;
import java.util.stream.Collectors;

@Component
@Order(30) // bước E: thứ tự nhập theo phụ thuộc (phòng ban → … → nhân viên → số dư phép / phân ca)
@RequiredArgsConstructor
public class SalaryGradeDescriptor implements ExcelEntityDescriptor<SalaryGradeDescriptor.Row> {

    private final SalaryGradeRepository gradeRepo;
    private final DepartmentRepository  deptRepo;
    private final com.bosskin.repository.EmployeeRepository employeeRepo;
    private final com.bosskin.repository.EmployeeJobHistoryRepository jobHistoryRepo;

    @Data
    public static class Row {
        private String code;
        private String name;
        private String payType;
        private String baseRate;
        private String departmentCode;
        private String departmentName;
        private String delete;

        public boolean isMarkedDelete() {
            if (delete == null) return false;
            String v = delete.trim().toLowerCase();
            return v.equals("x") || v.equals("delete") || v.equals("1") || v.equals("true");
        }
    }

    @Override public String sheetKey() { return "excel.sheet.salary_grade.list"; }
    @Override public String type()     { return "salary_grade"; }

    @Override
    public List<ExcelColumn<Row>> columns() {
        return List.of(
            ExcelColumn.ofI18n("excel.col.grade.code",           r -> r.getCode(),           (r, v) -> r.setCode(v)),
            ExcelColumn.ofI18n("excel.col.grade.name",           r -> r.getName(),           (r, v) -> r.setName(v)),
            ExcelColumn.ofI18n("excel.col.grade.payType",        r -> r.getPayType(),        (r, v) -> r.setPayType(v)),
            ExcelColumn.ofI18n("excel.col.grade.baseRate", ColType.MONEY,
                                                                  r -> r.getBaseRate(),       (r, v) -> r.setBaseRate(v)),
            ExcelColumn.ofI18n("excel.col.grade.departmentCode", r -> r.getDepartmentCode(), (r, v) -> r.setDepartmentCode(v)),
            ExcelColumn.readOnlyI18n("excel.col.grade.departmentName",                        r -> r.getDepartmentName())
        );
    }

    @Override
    public Row newRow() { return new Row(); }

    @Override
    public List<PickItem> searchForPick(Long companyId, Long userId, String q) {
        String lq = q == null ? "" : q.trim().toLowerCase();
        return gradeRepo.findByCompanyId(companyId).stream()
            .filter(g -> lq.isEmpty()
                || g.getName().toLowerCase().contains(lq)
                || g.getCode().toLowerCase().contains(lq))
            .limit(20)
            .map(g -> new PickItem(g.getCode(), g.getName() + " (" + g.getCode() + ")"))
            .collect(Collectors.toList());
    }

    @Override
    public List<FilterDefinition> filterDefinitions(Long companyId) {
        List<FilterDefinition.Option> deptOptions = deptRepo
            .findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .filter(d -> d.getCode() != null && !d.getCode().isBlank())
            .map(d -> FilterDefinition.opt(d.getCode(), d.getName() + " (" + d.getCode() + ")"))
            .collect(Collectors.toList());

        return List.of(
            FilterDefinition.text("search", "filter.search"),
            FilterDefinition.select("departmentCode", "filter.department", deptOptions),
            FilterDefinition.select("payType", "filter.grade.payType", List.of(
                FilterDefinition.opt("DAILY",  "filter.grade.payType.daily"),
                FilterDefinition.opt("HOURLY", "filter.grade.payType.hourly")
            ))
        );
    }

    @Override
    public List<Row> loadForExport(Long companyId, Long userId, Map<String, String> filters) {
        String deptCodeFilter = filters.getOrDefault("departmentCode", "").trim().toUpperCase();
        String payTypeFilter  = filters.getOrDefault("payType", "").trim().toUpperCase();
        String searchRaw      = filters.getOrDefault("search", "").trim();
        Set<String> pickedCodes = searchRaw.isEmpty() ? Set.of()
            : Arrays.stream(searchRaw.split(","))
                .map(s -> s.trim().toUpperCase()).filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());

        // Build dept code → name map for readonly column
        Map<Long, String> deptCodeMap = deptRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(d -> d.getId(), d -> d.getCode() != null ? d.getCode() : "",
                (a, b) -> a));
        Map<Long, String> deptNameMap = deptRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(d -> d.getId(), d -> d.getName() != null ? d.getName() : "",
                (a, b) -> a));

        return gradeRepo.findByCompanyId(companyId).stream()
            .filter(g -> {
                if (!pickedCodes.isEmpty())
                    return pickedCodes.contains(g.getCode().toUpperCase());
                if (!payTypeFilter.isEmpty() && !payTypeFilter.equals(g.getPayType().name()))
                    return false;
                if (!deptCodeFilter.isEmpty()) {
                    String gDeptCode = g.getDepartment() != null
                        ? deptCodeMap.getOrDefault(g.getDepartment().getId(), "").toUpperCase()
                        : "";
                    return deptCodeFilter.equals(gDeptCode);
                }
                return true;
            })
            .map(g -> {
                Row r = new Row();
                r.setCode(g.getCode());
                r.setName(g.getName());
                r.setPayType(g.getPayType().name());
                r.setBaseRate(g.getBaseRate() != null ? g.getBaseRate().toPlainString() : "");
                if (g.getDepartment() != null) {
                    r.setDepartmentCode(deptCodeMap.getOrDefault(g.getDepartment().getId(), ""));
                    r.setDepartmentName(deptNameMap.getOrDefault(g.getDepartment().getId(), ""));
                } else {
                    r.setDepartmentCode("");
                    r.setDepartmentName("");
                }
                return r;
            })
            .collect(Collectors.toList());
    }

    @Override
    public String getIdentifier(Row row) {
        return row.getCode() != null ? row.getCode() : "";
    }

    @Override
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<Row>> rows,
            boolean dryRun) {

        // Build dept code → entity map
        Map<String, com.bosskin.entity.Department> deptByCode = deptRepo
            .findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .filter(d -> d.getCode() != null && !d.getCode().isBlank())
            .collect(Collectors.toMap(d -> d.getCode().toUpperCase(),
                d -> d, (a, b) -> a));

        // Build existing grades map: code → entity
        Map<String, SalaryGrade> existing = gradeRepo.findByCompanyId(companyId).stream()
            .collect(Collectors.toMap(g -> g.getCode().toUpperCase(), g -> g, (a, b) -> a));

        List<SheetImportResult.RowResult> results = new ArrayList<>();

        for (RowWithCommand<Row> rw : rows) {
            int rowNum = rw.rowNum();
            try {
                if (rw.command() == null) {
                    results.add(SheetImportResult.RowResult.skip(rowNum));
                    continue;
                }
                Row data = rw.data();
                if (data.getCode() == null || data.getCode().isBlank()) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.grade.code_required"));
                    continue;
                }
                String codeKey = data.getCode().trim().toUpperCase();
                SalaryGrade grade = existing.get(codeKey);

                if (rw.command() == ImportCommand.DELETE) {
                    if (grade != null && (employeeRepo.countBySalaryGradeId(grade.getId()) > 0
                            || jobHistoryRepo.countUsingSalaryGrade(grade.getId()) > 0)) {
                        results.add(SheetImportResult.RowResult.error(rowNum, "error.salary_grade.in_use"));
                        continue;
                    }
                    if (!dryRun && grade != null) gradeRepo.delete(grade);
                    results.add(SheetImportResult.RowResult.ok(rowNum));
                    continue;
                }

                // Resolve department (nullable — null = company-wide)
                com.bosskin.entity.Department dept = null;
                if (data.getDepartmentCode() != null && !data.getDepartmentCode().isBlank()) {
                    dept = deptByCode.get(data.getDepartmentCode().trim().toUpperCase());
                    if (dept == null) {
                        results.add(SheetImportResult.RowResult.error(rowNum, "error.department.not_found"));
                        continue;
                    }
                }

                BigDecimal baseRate;
                try {
                    baseRate = new BigDecimal(data.getBaseRate().replaceAll("[^\\d.]", ""));
                } catch (Exception e) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.grade.base_rate_invalid"));
                    continue;
                }

                SalaryGrade.PayType payType;
                try {
                    payType = SalaryGrade.PayType.valueOf(
                        data.getPayType() != null ? data.getPayType().trim().toUpperCase() : "DAILY");
                } catch (Exception e) {
                    payType = SalaryGrade.PayType.DAILY;
                }

                // NO_CHANGE / diff summary for existing grade
                String diffSummary = null;
                if (grade != null) {
                    String newName = data.getName() != null ? data.getName().trim() : "";
                    boolean sameName  = newName.equals(grade.getName() != null ? grade.getName() : "");
                    boolean sameType  = payType == grade.getPayType();
                    boolean sameRate  = baseRate.compareTo(grade.getBaseRate()) == 0;
                    Long newDeptId    = dept != null ? dept.getId() : null;
                    Long oldDeptId    = grade.getDepartment() != null ? grade.getDepartment().getId() : null;
                    boolean sameDept  = Objects.equals(newDeptId, oldDeptId);
                    if (sameName && sameType && sameRate && sameDept) {
                        results.add(SheetImportResult.RowResult.of(rowNum, "OK", "preview.noChange"));
                        continue;
                    }
                    List<String> parts = new java.util.ArrayList<>();
                    if (!sameName) parts.add("name: " + grade.getName() + " → " + newName);
                    if (!sameType) parts.add("payType: " + grade.getPayType() + " → " + payType);
                    if (!sameRate) parts.add("baseRate: " + grade.getBaseRate() + " → " + baseRate);
                    if (!sameDept) parts.add("department: " + oldDeptId + " → " + newDeptId);
                    diffSummary = String.join(" | ", parts);
                    if (dryRun) {
                        results.add(SheetImportResult.RowResult.of(rowNum, "OK", diffSummary));
                        continue;
                    }
                }

                if (!dryRun) {
                    if (grade == null) {
                        com.bosskin.entity.Company company = new com.bosskin.entity.Company();
                        company.setId(companyId);
                        grade = SalaryGrade.builder()
                            .company(company)
                            .code(data.getCode().trim())
                            .name(data.getName() != null ? data.getName().trim() : "")
                            .payType(payType)
                            .baseRate(baseRate)
                            .department(dept)
                            .build();
                    } else {
                        grade.setName(data.getName() != null ? data.getName().trim() : grade.getName());
                        grade.setPayType(payType);
                        grade.setBaseRate(baseRate);
                        grade.setDepartment(dept);
                    }
                    gradeRepo.save(grade);
                }
                results.add(diffSummary != null
                    ? SheetImportResult.RowResult.of(rowNum, "OK", diffSummary)
                    : SheetImportResult.RowResult.ok(rowNum));
            } catch (Exception e) {
                results.add(SheetImportResult.RowResult.error(rowNum, e.getMessage()));
            }
        }
        return results;
    }
}
