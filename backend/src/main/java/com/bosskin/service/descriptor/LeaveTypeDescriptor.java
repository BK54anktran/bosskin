package com.bosskin.service.descriptor;

import com.bosskin.entity.Company;
import com.bosskin.entity.LeaveType;
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
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class LeaveTypeDescriptor implements ExcelEntityDescriptor<LeaveTypeDescriptor.Row> {

    private final LeaveTypeRepository leaveTypeRepo;

    @Data
    public static class Row {
        private String code;
        private String name;
        private String unit;
        private String paid;
        private String deductPerDay;
        private String active;
        private String description;
    }

    @Override public String sheetKey() { return "excel.sheet.leave_type.list"; }
    @Override public String type()     { return "leave_type"; }

    @Override
    public List<ExcelColumn<Row>> columns() {
        return List.of(
            ExcelColumn.ofI18n("excel.col.leaveType.code",         r -> r.getCode(),         (r, v) -> r.setCode(v)),
            ExcelColumn.ofI18n("excel.col.leaveType.name",         r -> r.getName(),         (r, v) -> r.setName(v)),
            ExcelColumn.ofI18n("excel.col.leaveType.unit",         r -> r.getUnit(),         (r, v) -> r.setUnit(v)),
            ExcelColumn.ofI18n("excel.col.leaveType.paid",         r -> r.getPaid(),         (r, v) -> r.setPaid(v)),
            ExcelColumn.ofI18n("excel.col.leaveType.deductPerDay", ColType.DECIMAL,
                                                                    r -> r.getDeductPerDay(), (r, v) -> r.setDeductPerDay(v)),
            ExcelColumn.ofI18n("excel.col.leaveType.active",       r -> r.getActive(),       (r, v) -> r.setActive(v)),
            ExcelColumn.ofI18n("excel.col.leaveType.description",  r -> r.getDescription(),  (r, v) -> r.setDescription(v))
        );
    }

    @Override
    public Row newRow() { return new Row(); }

    @Override
    public List<FilterDefinition> filterDefinitions(Long companyId) {
        return List.of(
            FilterDefinition.text("search", "filter.search"),
            FilterDefinition.select("status", "filter.status", List.of(
                FilterDefinition.opt("active",   "filter.status.active"),
                FilterDefinition.opt("inactive", "filter.status.inactive")
            ))
        );
    }

    @Override
    public List<Row> loadForExport(Long companyId, Long userId, Map<String, String> filters) {
        String search    = filters.getOrDefault("search", "").trim().toLowerCase();
        String statusStr = filters.getOrDefault("status", "").trim().toLowerCase();

        return leaveTypeRepo.findByCompanyIdAndDeletedFalseOrderByNameAsc(companyId).stream()
            .filter(t -> {
                if (!search.isEmpty() && !t.getName().toLowerCase().contains(search)
                        && !t.getCode().toLowerCase().contains(search)) return false;
                if ("active".equals(statusStr)   && !t.isActive()) return false;
                if ("inactive".equals(statusStr) && t.isActive())  return false;
                return true;
            })
            .map(t -> {
                Row r = new Row();
                r.setCode(t.getCode());
                r.setName(t.getName());
                r.setUnit(t.getUnit().name());
                r.setPaid(String.valueOf(t.isPaid()));
                r.setDeductPerDay(t.getDeductPerDay() != null ? t.getDeductPerDay().toPlainString() : "1");
                r.setActive(String.valueOf(t.isActive()));
                r.setDescription(t.getDescription() != null ? t.getDescription() : "");
                return r;
            })
            .collect(Collectors.toList());
    }

    @Override
    public String getIdentifier(Row row) {
        return row.getCode() != null ? row.getCode().toUpperCase() : "";
    }

    @Override
    @Transactional
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<Row>> rows,
            boolean dryRun) {

        Map<String, LeaveType> existing = leaveTypeRepo
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
                if (data.getCode() == null || data.getCode().isBlank()) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.leaveType.code_required"));
                    continue;
                }
                String codeKey = data.getCode().trim().toUpperCase();
                LeaveType entity = existing.get(codeKey);

                if (rw.command() == ImportCommand.DELETE) {
                    if (!dryRun && entity != null) {
                        entity.setDeleted(true);
                        entity.setActive(false);
                        leaveTypeRepo.save(entity);
                    }
                    results.add(SheetImportResult.RowResult.ok(rowNum));
                    continue;
                }

                if (data.getName() == null || data.getName().isBlank()) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.leaveType.name_required"));
                    continue;
                }

                LeaveType.Unit unit;
                try {
                    unit = LeaveType.Unit.valueOf(
                        data.getUnit() != null ? data.getUnit().trim().toUpperCase() : "DAY");
                } catch (Exception e) {
                    unit = LeaveType.Unit.DAY;
                }

                boolean paid   = parseBool(data.getPaid(), true);
                boolean active = parseBool(data.getActive(), true);

                BigDecimal deduct;
                try {
                    deduct = new BigDecimal(data.getDeductPerDay() != null
                        ? data.getDeductPerDay().replaceAll("[^\\d.]", "") : "1");
                } catch (Exception e) {
                    deduct = BigDecimal.ONE;
                }

                String diffSummary = null;
                if (entity != null) {
                    boolean same = entity.getName().equals(data.getName().trim())
                        && entity.getUnit() == unit
                        && entity.isPaid() == paid
                        && entity.isActive() == active
                        && entity.getDeductPerDay().compareTo(deduct) == 0;
                    if (same) {
                        results.add(SheetImportResult.RowResult.of(rowNum, "OK", "preview.noChange"));
                        continue;
                    }
                    List<String> parts = new ArrayList<>();
                    if (!entity.getName().equals(data.getName().trim()))
                        parts.add("name: " + entity.getName() + " → " + data.getName().trim());
                    if (entity.getUnit() != unit)
                        parts.add("unit: " + entity.getUnit() + " → " + unit);
                    if (entity.isPaid() != paid)
                        parts.add("paid: " + entity.isPaid() + " → " + paid);
                    if (entity.isActive() != active)
                        parts.add("active: " + entity.isActive() + " → " + active);
                    diffSummary = String.join(" | ", parts);
                    if (dryRun) {
                        results.add(SheetImportResult.RowResult.of(rowNum, "OK", diffSummary));
                        continue;
                    }
                }

                if (!dryRun) {
                    if (entity == null) {
                        Company company = new Company();
                        company.setId(companyId);
                        entity = LeaveType.builder()
                            .company(company)
                            .code(data.getCode().trim().toUpperCase())
                            .name(data.getName().trim())
                            .unit(unit)
                            .paid(paid)
                            .deductPerDay(deduct)
                            .active(active)
                            .description(data.getDescription())
                            .build();
                    } else {
                        entity.setName(data.getName().trim());
                        entity.setUnit(unit);
                        entity.setPaid(paid);
                        entity.setDeductPerDay(deduct);
                        entity.setActive(active);
                        if (data.getDescription() != null)
                            entity.setDescription(data.getDescription());
                    }
                    leaveTypeRepo.save(entity);
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

    private boolean parseBool(String val, boolean defaultVal) {
        if (val == null || val.isBlank()) return defaultVal;
        String v = val.trim().toLowerCase();
        return "true".equals(v) || "1".equals(v) || "yes".equals(v) || "co".equals(v);
    }
}
