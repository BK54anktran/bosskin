package com.bosskin.service.descriptor;

import com.bosskin.entity.Company;
import com.bosskin.entity.FormulaVariable;
import com.bosskin.repository.FormulaVariableRepository;
import com.bosskin.service.FormulaEngine;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelEntityDescriptor;
import com.bosskin.util.FilterDefinition;
import com.bosskin.util.ImportCommand;
import com.bosskin.util.SheetImportResult;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class FormulaVariableDescriptor implements ExcelEntityDescriptor<FormulaVariableDescriptor.Row> {

    private final FormulaVariableRepository variableRepo;

    @Data
    public static class Row {
        private String name;
        private String label;
        private String expression;
        private String category;
        private String showInFormula;
    }

    @Override public String sheetKey() { return "excel.sheet.formula_variable.list"; }
    @Override public String type()     { return "formula_variable"; }

    @Override
    public List<ExcelColumn<Row>> columns() {
        return List.of(
            ExcelColumn.ofI18n("excel.col.variable.name",          r -> r.getName(),          (r, v) -> r.setName(v)),
            ExcelColumn.ofI18n("excel.col.variable.label",         r -> r.getLabel(),         (r, v) -> r.setLabel(v)),
            ExcelColumn.ofI18n("excel.col.variable.expression",    r -> r.getExpression(),    (r, v) -> r.setExpression(v)),
            ExcelColumn.ofI18n("excel.col.variable.category",      r -> r.getCategory(),      (r, v) -> r.setCategory(v)),
            ExcelColumn.ofI18n("excel.col.variable.showInFormula", r -> r.getShowInFormula(), (r, v) -> r.setShowInFormula(v))
        );
    }

    @Override public Row newRow() { return new Row(); }

    @Override
    public List<PickItem> searchForPick(Long companyId, Long userId, String q) {
        String lq = q == null ? "" : q.trim().toLowerCase();
        return variableRepo.findByCompanyIdOrderByName(companyId).stream()
            .filter(v -> lq.isEmpty()
                || v.getName().toLowerCase().contains(lq)
                || v.getLabel().toLowerCase().contains(lq))
            .limit(20)
            .map(v -> new PickItem(v.getName(), v.getLabel() + " (" + v.getName() + ")"))
            .collect(Collectors.toList());
    }

    @Override
    public List<FilterDefinition> filterDefinitions(Long companyId) {
        // Collect distinct categories
        List<FilterDefinition.Option> catOptions = variableRepo.findByCompanyIdOrderByName(companyId)
            .stream()
            .map(FormulaVariable::getCategory)
            .filter(c -> c != null && !c.isBlank())
            .distinct().sorted()
            .map(c -> FilterDefinition.opt(c, c))
            .collect(Collectors.toList());

        List<FilterDefinition> filters = new ArrayList<>();
        filters.add(FilterDefinition.text("search", "filter.search"));
        if (!catOptions.isEmpty())
            filters.add(FilterDefinition.select("category", "filter.variable.category", catOptions));
        return filters;
    }

    @Override
    public List<Row> loadForExport(Long companyId, Long userId, Map<String, String> filters) {
        String categoryFilter = filters.getOrDefault("category", "").trim();
        String searchRaw      = filters.getOrDefault("search", "").trim();
        Set<String> pickedNames = searchRaw.isEmpty() ? Set.of()
            : Arrays.stream(searchRaw.split(","))
                .map(s -> s.trim().toUpperCase()).filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());

        List<Row> result = new ArrayList<>();

        // System vars (read-only reference — import will skip these)
        if (pickedNames.isEmpty()) {
            FormulaEngine.SYSTEM_VARS.forEach((name, sv) -> {
                if (!categoryFilter.isEmpty() && !categoryFilter.equals(sv.category())) return;
                Row r = new Row();
                r.setName(name);
                r.setLabel(sv.description());
                r.setExpression("");
                r.setCategory(sv.category());
                r.setShowInFormula("system");
                result.add(r);
            });
        }

        // User-defined vars from DB
        variableRepo.findByCompanyIdOrderByName(companyId).stream()
            .filter(v -> {
                if (!pickedNames.isEmpty())
                    return v.getName() != null && pickedNames.contains(v.getName().toUpperCase());
                if (!categoryFilter.isEmpty())
                    return categoryFilter.equals(v.getCategory());
                return true;
            })
            .forEach(v -> {
                Row r = new Row();
                r.setName(v.getName());
                r.setLabel(v.getLabel() != null ? v.getLabel() : "");
                r.setExpression(v.getExpression() != null ? v.getExpression() : "");
                r.setCategory(v.getCategory() != null ? v.getCategory() : "");
                r.setShowInFormula(v.isShowInFormula() ? "true" : "false");
                result.add(r);
            });

        return result;
    }

    private static String shorten(String s) {
        if (s == null) return "";
        return s.length() > 30 ? s.substring(0, 30) + "…" : s;
    }

    @Override
    public String getIdentifier(Row row) {
        return row.getName() != null ? row.getName() : "";
    }

    @Override
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<Row>> rows,
            boolean dryRun) {

        Set<String> systemVarNames = FormulaEngine.SYSTEM_VARS.keySet();

        Map<String, FormulaVariable> existing = variableRepo.findByCompanyIdOrderByName(companyId)
            .stream().collect(Collectors.toMap(
                v -> v.getName().toUpperCase(), v -> v, (a, b) -> a));

        List<SheetImportResult.RowResult> results = new ArrayList<>();

        for (RowWithCommand<Row> rw : rows) {
            int rowNum = rw.rowNum();
            try {
                if (rw.command() == null) {
                    results.add(SheetImportResult.RowResult.skip(rowNum));
                    continue;
                }
                Row data = rw.data();
                if (data.getName() == null || data.getName().isBlank()) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.variable.name_required"));
                    continue;
                }
                String nameKey = data.getName().trim().toUpperCase();
                // System vars are read-only reference rows — skip silently
                if (systemVarNames.contains(nameKey)) {
                    results.add(SheetImportResult.RowResult.skip(rowNum));
                    continue;
                }
                FormulaVariable variable = existing.get(nameKey);

                if (rw.command() == ImportCommand.DELETE) {
                    if (!dryRun && variable != null) variableRepo.delete(variable);
                    results.add(SheetImportResult.RowResult.ok(rowNum));
                    continue;
                }

                boolean showInFormula = !"false".equalsIgnoreCase(
                    data.getShowInFormula() != null ? data.getShowInFormula().trim() : "true");

                // Check NO_CHANGE / build diff summary
                String diffSummary = null;
                if (variable != null) {
                    String newLabel      = data.getLabel()      != null ? data.getLabel().trim()      : "";
                    String newExpr       = data.getExpression() != null ? data.getExpression().trim() : "";
                    String newCategory   = data.getCategory()   != null && !data.getCategory().isBlank()
                                          ? data.getCategory().trim() : null;
                    String oldLabel      = variable.getLabel()      != null ? variable.getLabel()      : "";
                    String oldExpr       = variable.getExpression() != null ? variable.getExpression() : "";
                    boolean sameLabel    = newLabel.equals(oldLabel);
                    boolean sameExpr     = newExpr.equals(oldExpr);
                    boolean sameCat      = Objects.equals(newCategory, variable.getCategory());
                    boolean sameShow     = showInFormula == variable.isShowInFormula();
                    if (sameLabel && sameExpr && sameCat && sameShow) {
                        results.add(SheetImportResult.RowResult.of(rowNum, "OK", "preview.noChange"));
                        continue;
                    }
                    List<String> parts = new ArrayList<>();
                    if (!sameLabel) parts.add("label: " + oldLabel + " → " + newLabel);
                    if (!sameExpr)  parts.add("expression: " + shorten(oldExpr) + " → " + shorten(newExpr));
                    if (!sameCat)   parts.add("category: " + variable.getCategory() + " → " + newCategory);
                    if (!sameShow)  parts.add("showInFormula: " + variable.isShowInFormula() + " → " + showInFormula);
                    diffSummary = String.join(" | ", parts);
                    if (dryRun) {
                        results.add(SheetImportResult.RowResult.of(rowNum, "OK", diffSummary));
                        continue;
                    }
                }

                if (!dryRun) {
                    if (variable == null) {
                        Company company = new Company();
                        company.setId(companyId);
                        variable = FormulaVariable.builder()
                            .company(company)
                            .name(data.getName().trim())
                            .label(data.getLabel() != null ? data.getLabel().trim() : "")
                            .expression(data.getExpression() != null ? data.getExpression().trim() : "")
                            .category(data.getCategory() != null && !data.getCategory().isBlank()
                                ? data.getCategory().trim() : null)
                            .showInFormula(showInFormula)
                            .build();
                    } else {
                        if (data.getLabel() != null && !data.getLabel().isBlank())
                            variable.setLabel(data.getLabel().trim());
                        if (data.getExpression() != null && !data.getExpression().isBlank())
                            variable.setExpression(data.getExpression().trim());
                        if (data.getCategory() != null)
                            variable.setCategory(data.getCategory().isBlank() ? null : data.getCategory().trim());
                        variable.setShowInFormula(showInFormula);
                    }
                    variableRepo.save(variable);
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
