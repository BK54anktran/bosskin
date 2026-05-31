package com.bosskin.controller;

import com.bosskin.entity.SalaryFormula;
import com.bosskin.entity.SalaryGrade;
import com.bosskin.entity.User;
import com.bosskin.entity.FormulaVariable;
import com.bosskin.repository.FormulaVariableRepository;
import com.bosskin.repository.SalaryFormulaRepository;
import com.bosskin.repository.SalaryGradeRepository;
import com.bosskin.service.FormulaEngine;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.*;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@RestController
@RequestMapping("/api/v1/salary-formulas")
@RequiredArgsConstructor
public class SalaryFormulaController {

    private final SalaryFormulaRepository formulaRepo;
    private final SalaryGradeRepository gradeRepo;
    private final FormulaVariableRepository varRepo;
    private final FormulaEngine formulaEngine;

    @GetMapping
    public ResponseEntity<List<SalaryFormulaDTO>> list(
            @AuthenticationPrincipal User user,
            @RequestParam(required = false) Long gradeId
    ) {
        requirePermission(user, "PAYROLL_VIEW");
        List<SalaryFormula> formulas = gradeId != null
                ? formulaRepo.findBySalaryGradeIdOrderByEffectiveDateDesc(gradeId)
                : formulaRepo.findByCompanyId(user.getCompany().getId());
        return ResponseEntity.ok(formulas.stream().map(SalaryFormulaDTO::from).toList());
    }

    @PostMapping("/validate")
    public ResponseEntity<ValidationResult> validate(
            @AuthenticationPrincipal User user,
            @RequestBody ValidateRequest body
    ) {
        requirePermission(user, "PAYROLL_VIEW");
        Map<String, String> globalVars = loadGlobalVars(user.getCompany().getId());
        Map<String, String> privateVars = body.getCustomVars() != null ? body.getCustomVars() : Map.of();
        Map<String, SalaryFormula.DeductionVar> deductionVars = body.getDeductionVars() != null ? body.getDeductionVars() : Map.of();
        Map<String, SalaryFormula.DeductionVar> incomeVars    = body.getIncomeVars()    != null ? body.getIncomeVars()    : Map.of();
        Map<String, SalaryFormula.DeductionVar> allowanceVars = body.getAllowanceVars() != null ? body.getAllowanceVars() : Map.of();

        Set<String> baseForPrivate = new HashSet<>(FormulaEngine.ALLOWED_VARIABLES);
        baseForPrivate.addAll(globalVars.keySet());

        Set<String> allowed = new HashSet<>(baseForPrivate);
        allowed.addAll(privateVars.keySet());
        allowed.addAll(deductionVars.keySet());
        allowed.addAll(incomeVars.keySet());
        allowed.addAll(allowanceVars.keySet());

        List<String> errPrivate = formulaEngine.validateCustomVars(privateVars, baseForPrivate);
        List<String> errDeduction = new java.util.ArrayList<>();
        for (Map<String, SalaryFormula.DeductionVar> group : List.of(deductionVars, incomeVars, allowanceVars)) {
            for (Map.Entry<String, SalaryFormula.DeductionVar> e : group.entrySet()) {
                if (e.getValue() == null || e.getValue().getExpression() == null) continue;
                List<String> errs = formulaEngine.validate(e.getValue().getExpression(), allowed);
                for (String err : errs) errDeduction.add("[" + e.getKey() + "] " + err);
            }
        }
        List<String> errorsGross = formulaEngine.validate(body.getExpressionGross(), allowed);
        List<String> errorsNet   = formulaEngine.validate(body.getExpressionNet(), allowed);
        boolean valid = errPrivate.isEmpty() && errDeduction.isEmpty() && errorsGross.isEmpty() && errorsNet.isEmpty();
        return ResponseEntity.ok(new ValidationResult(valid, errPrivate, errDeduction, errorsGross, errorsNet));
    }

    @PostMapping
    public ResponseEntity<SalaryFormulaDTO> create(
            @AuthenticationPrincipal User user,
            @RequestBody SalaryFormulaRequest body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        SalaryGrade grade = gradeRepo.findById(body.getSalaryGradeId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy bậc lương"));
        requireSameCompany(grade, user);
        requireUniqueName(body.getName(), null, user.getCompany().getId());
        Map<String, String> privateVars = body.getCustomVars() != null ? body.getCustomVars() : Map.of();
        Map<String, SalaryFormula.DeductionVar> deductionVars = body.getDeductionVars() != null ? body.getDeductionVars() : Map.of();
        Map<String, SalaryFormula.DeductionVar> incomeVars    = body.getIncomeVars()    != null ? body.getIncomeVars()    : Map.of();
        Map<String, SalaryFormula.DeductionVar> allowanceVars = body.getAllowanceVars() != null ? body.getAllowanceVars() : Map.of();
        validateOrThrow(body.getExpressionGross(), body.getExpressionNet(), privateVars, deductionVars, incomeVars, allowanceVars, user.getCompany().getId());

        SalaryFormula formula = SalaryFormula.builder()
                .salaryGrade(grade)
                .name(body.getName().trim())
                .effectiveDate(body.getEffectiveDate())
                .expressionGross(body.getExpressionGross().trim())
                .expressionNet(body.getExpressionNet().trim())
                .customVars(new java.util.LinkedHashMap<>(privateVars))
                .deductionVars(withSortOrder(deductionVars))
                .incomeVars(withSortOrder(incomeVars))
                .allowanceVars(withSortOrder(allowanceVars))
                .build();
        return ResponseEntity.status(HttpStatus.CREATED).body(SalaryFormulaDTO.from(formulaRepo.save(formula)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<SalaryFormulaDTO> update(
            @PathVariable Long id,
            @AuthenticationPrincipal User user,
            @RequestBody SalaryFormulaRequest body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        SalaryFormula formula = formulaRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy công thức lương"));
        requireSameCompany(formula.getSalaryGrade(), user);
        requireUniqueName(body.getName(), id, user.getCompany().getId());
        Map<String, String> privateVars = body.getCustomVars() != null ? body.getCustomVars() : Map.of();
        Map<String, SalaryFormula.DeductionVar> deductionVars = body.getDeductionVars() != null ? body.getDeductionVars() : Map.of();
        Map<String, SalaryFormula.DeductionVar> incomeVars    = body.getIncomeVars()    != null ? body.getIncomeVars()    : Map.of();
        Map<String, SalaryFormula.DeductionVar> allowanceVars = body.getAllowanceVars() != null ? body.getAllowanceVars() : Map.of();
        validateOrThrow(body.getExpressionGross(), body.getExpressionNet(), privateVars, deductionVars, incomeVars, allowanceVars, user.getCompany().getId());
        formula.setName(body.getName().trim());
        if (body.getEffectiveDate() != null) formula.setEffectiveDate(body.getEffectiveDate());
        formula.setExpressionGross(body.getExpressionGross().trim());
        formula.setExpressionNet(body.getExpressionNet().trim());
        formula.setCustomVars(new java.util.LinkedHashMap<>(privateVars));
        formula.setDeductionVars(withSortOrder(deductionVars));
        formula.setIncomeVars(withSortOrder(incomeVars));
        formula.setAllowanceVars(withSortOrder(allowanceVars));
        return ResponseEntity.ok(SalaryFormulaDTO.from(formulaRepo.save(formula)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            @PathVariable Long id,
            @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        SalaryFormula formula = formulaRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy công thức lương"));
        requireSameCompany(formula.getSalaryGrade(), user);
        formulaRepo.delete(formula);
        return ResponseEntity.noContent().build();
    }

    private Map<String, String> loadGlobalVars(Long companyId) {
        return varRepo.findByCompanyIdOrderByName(companyId)
                .stream()
                .collect(java.util.stream.Collectors.toMap(
                        FormulaVariable::getName, FormulaVariable::getExpression));
    }

    private void validateOrThrow(String gross, String net, Map<String, String> privateVars,
                                  Map<String, SalaryFormula.DeductionVar> deductionVars,
                                  Map<String, SalaryFormula.DeductionVar> incomeVars,
                                  Map<String, SalaryFormula.DeductionVar> allowanceVars,
                                  Long companyId) {
        Map<String, String> globalVars = loadGlobalVars(companyId);

        Set<String> baseForPrivate = new HashSet<>(FormulaEngine.ALLOWED_VARIABLES);
        baseForPrivate.addAll(globalVars.keySet());

        Set<String> allowed = new HashSet<>(baseForPrivate);
        allowed.addAll(privateVars.keySet());
        allowed.addAll(deductionVars.keySet());
        allowed.addAll(incomeVars.keySet());
        allowed.addAll(allowanceVars.keySet());

        List<String> all = new java.util.ArrayList<>();
        all.addAll(formulaEngine.validateCustomVars(privateVars, baseForPrivate));
        for (Map<String, SalaryFormula.DeductionVar> group : List.of(deductionVars, incomeVars, allowanceVars)) {
            for (Map.Entry<String, SalaryFormula.DeductionVar> e : group.entrySet()) {
                if (e.getValue() == null || e.getValue().getExpression() == null) continue;
                for (String err : formulaEngine.validate(e.getValue().getExpression(), allowed))
                    all.add("[" + e.getKey() + "] " + err);
            }
        }
        all.addAll(formulaEngine.validate(gross, allowed));
        all.addAll(formulaEngine.validate(net, allowed));
        if (!all.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "error.formula.invalid");
        }
    }

    /** Gán sortOrder theo thứ tự trong Map (insertion order từ LinkedHashMap). */
    private static Map<String, SalaryFormula.DeductionVar> withSortOrder(Map<String, SalaryFormula.DeductionVar> vars) {
        java.util.LinkedHashMap<String, SalaryFormula.DeductionVar> result = new java.util.LinkedHashMap<>();
        int i = 0;
        for (Map.Entry<String, SalaryFormula.DeductionVar> e : vars.entrySet()) {
            SalaryFormula.DeductionVar dv = e.getValue();
            result.put(e.getKey(), new SalaryFormula.DeductionVar(dv.getLabel(), dv.getExpression(), i++));
        }
        return result;
    }

    /** Sort Map theo sortOrder trước khi trả về client. */
    private static Map<String, SalaryFormula.DeductionVar> sortedByOrder(Map<String, SalaryFormula.DeductionVar> vars) {
        if (vars == null || vars.isEmpty()) return vars;
        return vars.entrySet().stream()
            .sorted(java.util.Comparator.comparingInt(e -> e.getValue().getSortOrder()))
            .collect(java.util.stream.Collectors.toMap(
                Map.Entry::getKey, Map.Entry::getValue,
                (a, b) -> a, java.util.LinkedHashMap::new));
    }

    private void requireUniqueName(String name, Long excludeId, Long companyId) {
        if (name == null || name.isBlank())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.formula.name_required");
        boolean exists = formulaRepo.countByNameAndCompanyIdAndIdNot(
                name.trim(), companyId, excludeId != null ? excludeId : -1L) > 0;
        if (exists)
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.formula.name_duplicate");
    }

    private void requirePermission(User user, String perm) {
        if (!user.hasPermission(perm))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền: " + perm);
    }

    private void requireSameCompany(SalaryGrade grade, User user) {
        if (grade.getDepartment() != null &&
                !grade.getDepartment().getCompany().getId().equals(user.getCompany().getId()))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền");
    }

    // ─── DTOs ─────────────────────────────────────────────────────────────────

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class SalaryFormulaRequest {
        private Long salaryGradeId;
        private String name;
        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDate effectiveDate;
        private String expressionGross;
        private String expressionNet;
        private Map<String, String> customVars;
        private Map<String, SalaryFormula.DeductionVar> deductionVars;
        private Map<String, SalaryFormula.DeductionVar> incomeVars;
        private Map<String, SalaryFormula.DeductionVar> allowanceVars;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ValidateRequest {
        private String expressionGross;
        private String expressionNet;
        private Map<String, String> customVars;
        private Map<String, SalaryFormula.DeductionVar> deductionVars;
        private Map<String, SalaryFormula.DeductionVar> incomeVars;
        private Map<String, SalaryFormula.DeductionVar> allowanceVars;
    }

    @Getter @Builder
    public static class ValidationResult {
        private boolean valid;
        private List<String> errorsPrivate;
        private List<String> errorsDeduction;
        private List<String> errorsGross;
        private List<String> errorsNet;
    }

    @Getter @Builder
    public static class SalaryFormulaDTO {
        private Long id;
        private Long salaryGradeId;
        private String salaryGradeCode;
        private String salaryGradeName;
        private String name;
        private Long departmentId;
        private String departmentName;
        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDate effectiveDate;
        private String expressionGross;
        private String expressionNet;
        private Map<String, String> customVars;
        private Map<String, SalaryFormula.DeductionVar> deductionVars;
        private Map<String, SalaryFormula.DeductionVar> incomeVars;
        private Map<String, SalaryFormula.DeductionVar> allowanceVars;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime createdAt;

        public static SalaryFormulaDTO from(SalaryFormula f) {
            SalaryGrade g = f.getSalaryGrade();
            return SalaryFormulaDTO.builder()
                    .id(f.getId())
                    .salaryGradeId(g.getId())
                    .salaryGradeCode(g.getCode())
                    .salaryGradeName(g.getName())
                    .name(f.getName())
                    .departmentId(g.getDepartment() != null ? g.getDepartment().getId() : null)
                    .departmentName(g.getDepartment() != null ? g.getDepartment().getName() : null)
                    .effectiveDate(f.getEffectiveDate())
                    .expressionGross(f.getExpressionGross())
                    .expressionNet(f.getExpressionNet())
                    .customVars(f.getCustomVars() != null ? f.getCustomVars() : Map.of())
                    .deductionVars(SalaryFormulaController.sortedByOrder(f.getDeductionVars() != null ? f.getDeductionVars() : Map.of()))
                    .incomeVars(SalaryFormulaController.sortedByOrder(f.getIncomeVars() != null ? f.getIncomeVars() : Map.of()))
                    .allowanceVars(SalaryFormulaController.sortedByOrder(f.getAllowanceVars() != null ? f.getAllowanceVars() : Map.of()))
                    .createdAt(f.getCreatedAt())
                    .build();
        }
    }
}
