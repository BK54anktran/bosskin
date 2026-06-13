package com.bosskin.service.descriptor;

import com.bosskin.entity.SalaryFormula;
import com.bosskin.entity.SalaryGrade;
import com.bosskin.repository.SalaryFormulaRepository;
import com.bosskin.repository.SalaryGradeRepository;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelEntityDescriptor;
import com.bosskin.util.FilterDefinition;
import com.bosskin.util.ImportCommand;
import com.bosskin.util.SheetImportResult;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class SalaryFormulaDescriptor implements ExcelEntityDescriptor<SalaryFormulaDescriptor.Row> {

    private final SalaryFormulaRepository formulaRepo;
    private final SalaryGradeRepository   gradeRepo;

    @Data
    public static class Row {
        private String gradeCode;
        private String gradeName;       // readonly
        private String formulaName;
        private String effectiveDate;
        private String expressionGross;
        private String expressionNet;
        private String customVars;
        private String incomeVars;
        private String allowanceVars;
        private String deductionVars;
    }

    @Override public String sheetKey()    { return "excel.sheet.salary_formula.list"; }
    @Override public String type()        { return "salary_formula"; }
    @Override public boolean importable() { return true; }

    @Override
    public List<ExcelColumn<Row>> columns() {
        return List.of(
            ExcelColumn.ofI18n("excel.col.formula.gradeCode",       r -> r.getGradeCode(),       (r, v) -> r.setGradeCode(v)),
            ExcelColumn.readOnlyI18n("excel.col.formula.gradeName",  r -> r.getGradeName()),
            ExcelColumn.ofI18n("excel.col.formula.formulaName",     r -> r.getFormulaName(),     (r, v) -> r.setFormulaName(v)),
            ExcelColumn.ofI18n("excel.col.formula.effectiveDate",   r -> r.getEffectiveDate(),   (r, v) -> r.setEffectiveDate(v)),
            ExcelColumn.ofI18n("excel.col.formula.expressionGross", r -> r.getExpressionGross(), (r, v) -> r.setExpressionGross(v)),
            ExcelColumn.ofI18n("excel.col.formula.expressionNet",   r -> r.getExpressionNet(),   (r, v) -> r.setExpressionNet(v)),
            ExcelColumn.ofI18n("excel.col.formula.customVars",      r -> r.getCustomVars(),      (r, v) -> r.setCustomVars(v)),
            ExcelColumn.ofI18n("excel.col.formula.incomeVars",      r -> r.getIncomeVars(),      (r, v) -> r.setIncomeVars(v)),
            ExcelColumn.ofI18n("excel.col.formula.allowanceVars",   r -> r.getAllowanceVars(),   (r, v) -> r.setAllowanceVars(v)),
            ExcelColumn.ofI18n("excel.col.formula.deductionVars",   r -> r.getDeductionVars(),   (r, v) -> r.setDeductionVars(v))
        );
    }

    @Override public Row newRow() { return new Row(); }

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
        List<FilterDefinition.Option> gradeOptions = gradeRepo.findByCompanyId(companyId).stream()
            .map(g -> FilterDefinition.opt(g.getCode(), g.getName() + " (" + g.getCode() + ")"))
            .collect(Collectors.toList());
        return List.of(
            FilterDefinition.text("search", "filter.search"),
            FilterDefinition.select("gradeCode", "filter.grade", gradeOptions)
        );
    }

    @Override
    public List<Row> loadForExport(Long companyId, Long userId, Map<String, String> filters) {
        String gradeCodeFilter = filters.getOrDefault("gradeCode", "").trim().toUpperCase();
        String searchRaw       = filters.getOrDefault("search", "").trim();
        Set<String> pickedCodes = searchRaw.isEmpty() ? Set.of()
            : Arrays.stream(searchRaw.split(","))
                .map(s -> s.trim().toUpperCase()).filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());

        Map<Long, String> gradeCodeMap = gradeRepo.findByCompanyId(companyId).stream()
            .collect(Collectors.toMap(SalaryGrade::getId, SalaryGrade::getCode, (a, b) -> a));
        Map<Long, String> gradeNameMap = gradeRepo.findByCompanyId(companyId).stream()
            .collect(Collectors.toMap(SalaryGrade::getId, SalaryGrade::getName, (a, b) -> a));

        return formulaRepo.findByCompanyId(companyId).stream()
            .filter(f -> {
                String gCode = gradeCodeMap.getOrDefault(f.getSalaryGrade().getId(), "").toUpperCase();
                if (!pickedCodes.isEmpty()) return pickedCodes.contains(gCode);
                if (!gradeCodeFilter.isEmpty()) return gradeCodeFilter.equals(gCode);
                return true;
            })
            .map(f -> {
                Row r = new Row();
                r.setGradeCode(gradeCodeMap.getOrDefault(f.getSalaryGrade().getId(), ""));
                r.setGradeName(gradeNameMap.getOrDefault(f.getSalaryGrade().getId(), ""));
                r.setFormulaName(f.getName() != null ? f.getName() : "");
                r.setEffectiveDate(f.getEffectiveDate() != null ? f.getEffectiveDate().toString() : "");
                r.setExpressionGross(f.getExpressionGross() != null ? f.getExpressionGross() : "");
                r.setExpressionNet(f.getExpressionNet() != null ? f.getExpressionNet() : "");
                r.setCustomVars(customVarsToText(f.getCustomVars()));
                r.setIncomeVars(deductionVarsToText(f.getIncomeVars()));
                r.setAllowanceVars(deductionVarsToText(f.getAllowanceVars()));
                r.setDeductionVars(deductionVarsToText(f.getDeductionVars()));
                return r;
            })
            .collect(Collectors.toList());
    }

    @Override
    public String getIdentifier(Row row) {
        return (row.getGradeCode() != null ? row.getGradeCode() : "")
            + "|" + (row.getEffectiveDate() != null ? row.getEffectiveDate() : "");
    }

    @Override
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<Row>> rows,
            boolean dryRun) {

        // grade code (upper) → entity
        Map<String, SalaryGrade> gradeByCode = gradeRepo.findByCompanyId(companyId).stream()
            .collect(Collectors.toMap(g -> g.getCode().toUpperCase(), g -> g, (a, b) -> a));

        // (gradeId, effectiveDate) → formula entity
        Map<String, SalaryFormula> existing = formulaRepo.findByCompanyId(companyId).stream()
            .collect(Collectors.toMap(
                f -> f.getSalaryGrade().getId() + "|" + f.getEffectiveDate(),
                f -> f, (a, b) -> a));

        List<SheetImportResult.RowResult> results = new ArrayList<>();

        for (RowWithCommand<Row> rw : rows) {
            int rowNum = rw.rowNum();
            try {
                if (rw.command() == null) {
                    results.add(SheetImportResult.RowResult.skip(rowNum));
                    continue;
                }
                Row data = rw.data();

                if (data.getGradeCode() == null || data.getGradeCode().isBlank()) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.grade.code_required"));
                    continue;
                }
                SalaryGrade grade = gradeByCode.get(data.getGradeCode().trim().toUpperCase());
                if (grade == null) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.grade.not_found"));
                    continue;
                }

                LocalDate effectiveDate;
                try {
                    effectiveDate = LocalDate.parse(data.getEffectiveDate().trim());
                } catch (Exception e) {
                    results.add(SheetImportResult.RowResult.error(rowNum, "error.formula.invalid_date"));
                    continue;
                }

                String existingKey = grade.getId() + "|" + effectiveDate;
                SalaryFormula formula = existing.get(existingKey);

                if (rw.command() == ImportCommand.DELETE) {
                    if (!dryRun && formula != null) formulaRepo.delete(formula);
                    results.add(SheetImportResult.RowResult.ok(rowNum));
                    continue;
                }

                // Parse text → maps
                Map<String, String> customVars   = parseCustomVars(data.getCustomVars());
                Map<String, SalaryFormula.DeductionVar> incomeVars    = parseDeductionVars(data.getIncomeVars());
                Map<String, SalaryFormula.DeductionVar> allowanceVars = parseDeductionVars(data.getAllowanceVars());
                Map<String, SalaryFormula.DeductionVar> deductionVars = parseDeductionVars(data.getDeductionVars());

                // NO_CHANGE / diff summary for existing formula
                String diffSummary = null;
                if (formula != null) {
                    String newName  = data.getFormulaName()    != null ? data.getFormulaName().trim()    : "";
                    String newGross = data.getExpressionGross() != null ? data.getExpressionGross().trim() : "";
                    String newNet   = data.getExpressionNet()  != null ? data.getExpressionNet().trim()  : "";
                    boolean sameName  = newName.equals(formula.getName()           != null ? formula.getName()           : "");
                    boolean sameGross = newGross.equals(formula.getExpressionGross() != null ? formula.getExpressionGross() : "");
                    boolean sameNet   = newNet.equals(formula.getExpressionNet()   != null ? formula.getExpressionNet()   : "");
                    boolean sameCustom = Objects.equals(customVars,     formula.getCustomVars());
                    boolean sameIncome = Objects.equals(incomeVars,     formula.getIncomeVars());
                    boolean sameAllow  = Objects.equals(allowanceVars,  formula.getAllowanceVars());
                    boolean sameDeduct = Objects.equals(deductionVars,  formula.getDeductionVars());
                    if (sameName && sameGross && sameNet && sameCustom && sameIncome && sameAllow && sameDeduct) {
                        results.add(SheetImportResult.RowResult.of(rowNum, "OK", "preview.noChange"));
                        continue;
                    }
                    List<String> parts = new ArrayList<>();
                    if (!sameName)   parts.add("name: " + formula.getName() + " → " + newName);
                    if (!sameGross)  parts.add("gross: " + shorten(formula.getExpressionGross()) + " → " + shorten(newGross));
                    if (!sameNet)    parts.add("net: "   + shorten(formula.getExpressionNet())   + " → " + shorten(newNet));
                    if (!sameCustom) parts.add("customVars changed");
                    if (!sameIncome) parts.add("incomeVars changed");
                    if (!sameAllow)  parts.add("allowanceVars changed");
                    if (!sameDeduct) parts.add("deductionVars changed");
                    diffSummary = String.join(" | ", parts);
                    if (dryRun) {
                        results.add(SheetImportResult.RowResult.of(rowNum, "OK", diffSummary));
                        continue;
                    }
                }

                if (!dryRun) {
                    if (formula == null) {
                        formula = SalaryFormula.builder()
                            .salaryGrade(grade)
                            .name(data.getFormulaName() != null ? data.getFormulaName().trim() : "")
                            .effectiveDate(effectiveDate)
                            .expressionGross(data.getExpressionGross() != null ? data.getExpressionGross().trim() : "")
                            .expressionNet(data.getExpressionNet() != null ? data.getExpressionNet().trim() : "")
                            .customVars(customVars)
                            .incomeVars(incomeVars)
                            .allowanceVars(allowanceVars)
                            .deductionVars(deductionVars)
                            .build();
                    } else {
                        if (data.getFormulaName() != null && !data.getFormulaName().isBlank())
                            formula.setName(data.getFormulaName().trim());
                        if (data.getExpressionGross() != null && !data.getExpressionGross().isBlank())
                            formula.setExpressionGross(data.getExpressionGross().trim());
                        if (data.getExpressionNet() != null && !data.getExpressionNet().isBlank())
                            formula.setExpressionNet(data.getExpressionNet().trim());
                        formula.setCustomVars(customVars);
                        formula.setIncomeVars(incomeVars);
                        formula.setAllowanceVars(allowanceVars);
                        formula.setDeductionVars(deductionVars);
                    }
                    formulaRepo.save(formula);
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

    // ─── Text → export ────────────────────────────────────────────────────────

    private static String shorten(String s) {
        if (s == null) return "";
        return s.length() > 30 ? s.substring(0, 30) + "…" : s;
    }

    private String customVarsToText(Map<String, String> vars) {
        if (vars == null || vars.isEmpty()) return "";
        return vars.entrySet().stream()
            .map(e -> e.getKey() + " = " + e.getValue())
            .collect(Collectors.joining("\n"));
    }

    private String deductionVarsToText(Map<String, SalaryFormula.DeductionVar> vars) {
        if (vars == null || vars.isEmpty()) return "";
        return vars.entrySet().stream()
            .sorted(Comparator.comparingInt(e -> e.getValue().getSortOrder()))
            .map(e -> e.getKey() + " | " + e.getValue().getLabel() + " | " + e.getValue().getExpression())
            .collect(Collectors.joining("\n"));
    }

    // ─── Text → import ────────────────────────────────────────────────────────

    /** "VAR = expr\nVAR2 = expr2" → {"VAR":"expr",...} */
    private Map<String, String> parseCustomVars(String text) {
        Map<String, String> result = new LinkedHashMap<>();
        if (text == null || text.isBlank()) return result;
        for (String line : text.split("\n")) {
            int eq = line.indexOf('=');
            if (eq < 0) continue;
            String key = line.substring(0, eq).trim();
            String val = line.substring(eq + 1).trim();
            if (!key.isEmpty()) result.put(key, val);
        }
        return result;
    }

    /** "VAR | label | expr\nVAR2 | label2 | expr2" → {"VAR":{label,expr,sortOrder},...} */
    private Map<String, SalaryFormula.DeductionVar> parseDeductionVars(String text) {
        Map<String, SalaryFormula.DeductionVar> result = new LinkedHashMap<>();
        if (text == null || text.isBlank()) return result;
        AtomicInteger order = new AtomicInteger(0);
        for (String line : text.split("\n")) {
            String[] parts = line.split("\\|", 3);
            if (parts.length < 3) continue;
            String key   = parts[0].trim();
            String label = parts[1].trim();
            String expr  = parts[2].trim();
            if (!key.isEmpty()) {
                result.put(key, new SalaryFormula.DeductionVar(label, expr, order.getAndIncrement()));
            }
        }
        return result;
    }
}
