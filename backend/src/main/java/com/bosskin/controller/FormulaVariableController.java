package com.bosskin.controller;

import com.bosskin.entity.FormulaVariable;
import com.bosskin.entity.User;
import com.bosskin.repository.FormulaVariableRepository;
import com.bosskin.repository.SalaryFormulaRepository;
import com.bosskin.service.FormulaEngine;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.*;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/formula-variables")
@RequiredArgsConstructor
public class FormulaVariableController {

    private final FormulaVariableRepository repo;
    private final SalaryFormulaRepository formulaRepo;
    private final FormulaEngine formulaEngine;
    private final com.bosskin.i18n.AppText appText;

    @GetMapping("/categories")
    public ResponseEntity<List<String>> listCategories(@AuthenticationPrincipal User user) {
        requirePermission(user, "PAYROLL_VIEW");
        List<String> cats = repo.findByCompanyIdOrderByName(user.getCompany().getId())
                .stream()
                .map(FormulaVariable::getCategory)
                .filter(c -> c != null && !c.isBlank())
                .distinct()
                .sorted()
                .toList();
        return ResponseEntity.ok(cats);
    }

    @GetMapping
    public ResponseEntity<List<FormulaVariableDTO>> list(@AuthenticationPrincipal User user) {
        requirePermission(user, "PAYROLL_VIEW");
        return ResponseEntity.ok(
                repo.findByCompanyIdOrderByName(user.getCompany().getId())
                        .stream().map(FormulaVariableDTO::from).toList());
    }

    /**
     * Trả về tất cả biến: system (read-only) + global + private (từ mọi formula).
     * Dùng cho tab Variables.
     */
    @GetMapping("/all")
    public ResponseEntity<List<AllVariableDTO>> listAll(@AuthenticationPrincipal User user) {
        requirePermission(user, "PAYROLL_VIEW");
        List<AllVariableDTO> result = new ArrayList<>();

        // 1. System variables (read-only)
        FormulaEngine.SYSTEM_VARS.forEach((name, sv) ->
                result.add(AllVariableDTO.system(name, appText.t("var.desc." + name), appText.t(FormulaEngine.categoryKey(sv.category()))
                        , appText.t("var.scope.system"))));

        // 2. Global variables
        repo.findByCompanyIdOrderByName(user.getCompany().getId())
                .forEach(v -> result.add(AllVariableDTO.global(v, appText.t("var.scope.global"))));

        // 3. Private variables — gom từ tất cả formulas
        formulaRepo.findByCompanyId(user.getCompany().getId()).forEach(f -> {
            if (f.getCustomVars() == null || f.getCustomVars().isEmpty()) return;
            String formulaLabel = f.getSalaryGrade().getCode() + " — " + f.getSalaryGrade().getName();
            Long formulaId = f.getId();
            f.getCustomVars().forEach((name, expr) ->
                    result.add(AllVariableDTO.privateVar(name, expr, formulaLabel, formulaId)));
        });

        return ResponseEntity.ok(result);
    }

    /**
     * Kiểm tra global var có đang được dùng trong formula nào không.
     * Trả về danh sách formula IDs đang dùng.
     */
    @GetMapping("/{id}/usages")
    public ResponseEntity<List<UsageDTO>> usages(
            @PathVariable Long id,
            @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "PAYROLL_VIEW");
        FormulaVariable v = repo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.variable.not_found"));
        requireSameCompany(v, user);

        List<UsageDTO> usages = formulaRepo.findByCompanyId(user.getCompany().getId()).stream()
                .filter(f -> expressionContains(f.getExpressionGross(), v.getName())
                        || expressionContains(f.getExpressionNet(), v.getName())
                        || (f.getCustomVars() != null && f.getCustomVars().values().stream()
                                .anyMatch(e -> expressionContains(e, v.getName()))))
                .map(f -> new UsageDTO(
                        f.getId(),
                        f.getSalaryGrade().getCode() + " — " + f.getSalaryGrade().getName(),
                        f.getEffectiveDate().toString()))
                .toList();
        return ResponseEntity.ok(usages);
    }

    private boolean expressionContains(String expr, String varName) {
        if (expr == null) return false;
        // Check word boundary: varName không nằm trong tên biến khác
        return expr.matches("(?s).*\\b" + varName + "\\b.*");
    }

    @PostMapping("/validate")
    public ResponseEntity<ValidationResult> validate(
            @AuthenticationPrincipal User user,
            @RequestBody ValidateRequest body
    ) {
        requirePermission(user, "PAYROLL_VIEW");
        // Load all existing custom vars của company, merge với biến đang validate
        Map<String, String> existing = repo.findByCompanyIdOrderByName(user.getCompany().getId())
                .stream()
                .filter(v -> !v.getName().equals(body.getName())) // exclude self khi edit
                .collect(Collectors.toMap(FormulaVariable::getName, FormulaVariable::getExpression));
        existing.put(body.getName(), body.getExpression());

        Set<String> allowed = new HashSet<>(FormulaEngine.ALLOWED_VARIABLES);
        allowed.addAll(existing.keySet());
        List<String> errors = formulaEngine.validateCustomVars(existing, allowed);
        return ResponseEntity.ok(new ValidationResult(errors.isEmpty(), errors));
    }

    @PostMapping
    public ResponseEntity<FormulaVariableDTO> create(
            @AuthenticationPrincipal User user,
            @RequestBody FormulaVariableRequest body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        validateName(body.getName());
        if (repo.findByCompanyIdAndName(user.getCompany().getId(), body.getName()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "error.variable.name_duplicate|" + body.getName());
        }
        // Validate expression
        validateExpression(body.getName(), body.getExpression(), null, user.getCompany().getId());

        String cat = body.getCategory() != null && !body.getCategory().isBlank()
                ? body.getCategory().trim() : null;
        FormulaVariable v = FormulaVariable.builder()
                .company(user.getCompany())
                .name(body.getName().toUpperCase())
                .label(body.getLabel())
                .expression(body.getExpression().trim())
                .category(cat)
                .build();
        return ResponseEntity.status(HttpStatus.CREATED).body(FormulaVariableDTO.from(repo.save(v)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<FormulaVariableDTO> update(
            @PathVariable Long id,
            @AuthenticationPrincipal User user,
            @RequestBody FormulaVariableRequest body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        FormulaVariable v = repo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.variable.not_found"));
        requireSameCompany(v, user);
        // Đổi tên: check không trùng với biến khác
        if (body.getName() != null && !body.getName().equals(v.getName())) {
            String newName = body.getName().toUpperCase();
            validateName(newName);
            if (repo.existsByCompanyIdAndNameAndIdNot(user.getCompany().getId(), newName, id)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "error.variable.name_duplicate|" + newName);
            }
            v.setName(newName);
        }
        if (body.getLabel() != null) v.setLabel(body.getLabel());
        if (body.getCategory() != null) {
            v.setCategory(body.getCategory().isBlank() ? null : body.getCategory().trim());
        }
        if (body.getExpression() != null) {
            validateExpression(v.getName(), body.getExpression(), id, user.getCompany().getId());
            v.setExpression(body.getExpression().trim());
        }
        return ResponseEntity.ok(FormulaVariableDTO.from(repo.save(v)));
    }

    @PatchMapping("/{id}/show-in-formula")
    public ResponseEntity<FormulaVariableDTO> toggleShowInFormula(
            @PathVariable Long id,
            @AuthenticationPrincipal User user,
            @RequestBody java.util.Map<String, Boolean> body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        FormulaVariable v = repo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.variable.not_found"));
        requireSameCompany(v, user);
        Boolean show = body.get("showInFormula");
        if (show != null) v.setShowInFormula(show);
        return ResponseEntity.ok(FormulaVariableDTO.from(repo.save(v)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            @PathVariable Long id,
            @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        FormulaVariable v = repo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.variable.not_found"));
        requireSameCompany(v, user);
        repo.delete(v);
        return ResponseEntity.noContent().build();
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private void validateName(String name) {
        if (!name.matches("[A-Z][A-Z0-9_]{0,49}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "error.variable.name_format");
        }
        if (FormulaEngine.RESERVED_KEYWORDS.contains(name)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "error.variable.name_reserved|" + name);
        }
        if (FormulaEngine.SYSTEM_VAR_DESCRIPTIONS.containsKey(name)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "error.variable.name_system|" + name);
        }
    }

    private void validateExpression(String name, String expression, Long excludeId, Long companyId) {
        Map<String, String> allVars = repo.findByCompanyIdOrderByName(companyId)
                .stream()
                .filter(v -> excludeId == null || !v.getId().equals(excludeId))
                .collect(Collectors.toMap(FormulaVariable::getName, FormulaVariable::getExpression));
        allVars.put(name, expression);

        // allowed = system vars + tất cả tên global vars (để biến có thể tham chiếu lẫn nhau)
        Set<String> allowed = new HashSet<>(FormulaEngine.ALLOWED_VARIABLES);
        allowed.addAll(allVars.keySet());

        List<String> errors = formulaEngine.validateCustomVars(allVars, allowed);
        if (!errors.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "error.formula.invalid|" + String.join("; ", errors).replace('|', '/'));
        }
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }

    private void requireSameCompany(FormulaVariable v, User user) {
        if (!v.getCompany().getId().equals(user.getCompany().getId()))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }

    // ─── DTOs ─────────────────────────────────────────────────────────────────

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class FormulaVariableRequest {
        private String name;
        private String label;
        private String expression;
        private String category;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ValidateRequest {
        private String name;
        private String expression;
    }

    @Getter @Builder
    public static class ValidationResult {
        private boolean valid;
        private List<String> errors;
    }

    @Getter @Builder
    public static class FormulaVariableDTO {
        private Long id;
        private String name;
        private String label;
        private String expression;
        private String category;
        private boolean showInFormula;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime createdAt;

        public static FormulaVariableDTO from(FormulaVariable v) {
            return FormulaVariableDTO.builder()
                    .id(v.getId())
                    .name(v.getName())
                    .label(v.getLabel())
                    .expression(v.getExpression())
                    .category(v.getCategory())
                    .showInFormula(v.isShowInFormula())
                    .createdAt(v.getCreatedAt())
                    .build();
        }
    }

    @Getter @Builder
    public static class AllVariableDTO {
        private Long id;          // null nếu system hoặc private
        private String name;
        private String label;
        private String expression;
        private String category;
        private String scope;      // "SYSTEM" | "GLOBAL" | "PRIVATE"
        private String scopeLabel;
        private Long formulaId;    // chỉ có nếu scope=PRIVATE
        private boolean showInFormula;

        static AllVariableDTO system(String name, String desc, String category, String scopeLabel) {
            return AllVariableDTO.builder()
                    .name(name).label(desc).category(category).expression(null)
                    .scope("SYSTEM").scopeLabel(scopeLabel).showInFormula(false).build();
        }

        static AllVariableDTO global(FormulaVariable v, String scopeLabel) {
            return AllVariableDTO.builder()
                    .id(v.getId()).name(v.getName()).label(v.getLabel())
                    .expression(v.getExpression())
                    .category(v.getCategory())
                    .scope("GLOBAL").scopeLabel(scopeLabel)
                    .showInFormula(v.isShowInFormula()).build();
        }

        static AllVariableDTO privateVar(String name, String expr, String formulaLabel, Long formulaId) {
            return AllVariableDTO.builder()
                    .name(name).label("").expression(expr)
                    .scope("PRIVATE").scopeLabel(formulaLabel).formulaId(formulaId).build();
        }
    }

    @Getter @Builder
    public static class UsageDTO {
        private Long formulaId;
        private String formulaLabel;
        private String effectiveDate;
    }
}
