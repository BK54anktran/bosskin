package com.bosskin.service;

import com.bosskin.core.PayrollPeriod;
import com.bosskin.entity.Attendance;
import com.bosskin.entity.Company;
import com.bosskin.entity.Employee;
import com.bosskin.entity.FormulaVariable;
import com.bosskin.entity.Payroll;
import com.bosskin.entity.SalaryFormula;
import com.bosskin.entity.SalaryHistory;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.FormulaVariableRepository;
import com.bosskin.repository.PayrollRepository;
import com.bosskin.repository.SalaryFormulaRepository;
import com.bosskin.repository.SalaryHistoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@lombok.extern.slf4j.Slf4j
@Service
@RequiredArgsConstructor
public class PayrollService {

    private static final BigDecimal DEFAULT_SOCIAL_INS_RATE   = new BigDecimal("0.08");
    private static final BigDecimal DEFAULT_HEALTH_INS_RATE   = new BigDecimal("0.015");
    private static final BigDecimal DEFAULT_UNEMPLOYMENT_RATE = new BigDecimal("0.01");
    private static final BigDecimal PERSONAL_DEDUCTION        = new BigDecimal("11000000");

    private final PayrollRepository          payrollRepository;
    private final EmployeeRepository         employeeRepository;
    private final AttendanceRepository       attendanceRepository;
    private final SalaryHistoryRepository    salaryHistoryRepository;
    private final SalaryFormulaRepository    salaryFormulaRepository;
    private final FormulaVariableRepository  formulaVariableRepository;
    private final FormulaEngine              formulaEngine;
    private final com.bosskin.repository.AttendanceApproveLeaveRepository approveLeaveRepository;
    private final ObjectMapper               objectMapper;

    @Transactional
    public Payroll generatePayroll(Long employeeId, int year, int month) {
        return generatePayroll(employeeId, year, month, null);
    }

    @Transactional
    public Payroll generatePayrollWithFormula(Long employeeId, int year, int month, SalaryFormula inlineFormula) {
        return doGeneratePayroll(employeeId, year, month, null, inlineFormula);
    }

    @Transactional
    public Payroll generatePayroll(Long employeeId, int year, int month, Long formulaId) {
        if (payrollRepository.findByEmployeeIdAndYearAndMonth(employeeId, year, month).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.payroll.already_exists");
        }
        return doGeneratePayroll(employeeId, year, month, formulaId, null);
    }

    /** Khoản chỉnh tay trên bảng lương nháp: phụ cấp, thưởng cộng vào GROSS; khấu trừ khác trừ sau NET. */
    public record ManualAdjustments(BigDecimal allowance, BigDecimal bonus, BigDecimal otherDeductions) {
        static final ManualAdjustments NONE = new ManualAdjustments(BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO);
        BigDecimal allowanceOrZero()       { return allowance != null ? allowance : BigDecimal.ZERO; }
        BigDecimal bonusOrZero()           { return bonus != null ? bonus : BigDecimal.ZERO; }
        BigDecimal otherDeductionsOrZero() { return otherDeductions != null ? otherDeductions : BigDecimal.ZERO; }
    }

    private Payroll doGeneratePayroll(Long employeeId, int year, int month, Long formulaId, SalaryFormula inlineFormula) {
        return payrollRepository.save(computePayroll(employeeId, year, month, formulaId, inlineFormula, ManualAdjustments.NONE));
    }

    /** Tính bảng lương (chưa lưu). */
    private Payroll computePayroll(Long employeeId, int year, int month, Long formulaId, SalaryFormula inlineFormula,
                                   ManualAdjustments manual) {
        Employee employee = employeeRepository.findById(employeeId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));

        PayrollPeriod period = PayrollPeriod.of(year, month, employee.getCompany().getPayrollCutoffDay());

        BigDecimal baseSalary;
        if (employee.getSalaryGrade() != null) {
            baseSalary = employee.getSalaryGrade().getBaseRate();
        } else {
            SalaryHistory salaryHistory = salaryHistoryRepository
                .findTopByEmployeeIdAndEffectiveDateLessThanEqualOrderByEffectiveDateDesc(employeeId, period.from())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "error.payroll.salary_not_configured"));
            baseSalary = salaryHistory.getBaseSalary();
        }

        List<Attendance> attendances = attendanceRepository.findApprovedByEmployeeAndDateRange(employeeId, period.from(), period.to());

        long presentDays = attendances.stream()
            .filter(a -> a.getStatus() == Attendance.Status.PRESENT || a.getStatus() == Attendance.Status.LATE)
            .map(Attendance::getDate)
            .distinct()
            .count();

        double totalOvertimeDouble = attendances.stream()
            .mapToDouble(a -> (a.getSnapDayOt() != null ? a.getSnapDayOt() : 0)
                            + (a.getSnapNightOt() != null ? a.getSnapNightOt() : 0))
            .sum();
        BigDecimal totalOvertime = BigDecimal.valueOf(totalOvertimeDouble).setScale(2, RoundingMode.HALF_UP);

        BigDecimal snapDayHours   = BigDecimal.valueOf(attendances.stream().mapToDouble(a -> a.getSnapDayHours()   != null ? a.getSnapDayHours()   : 0).sum()).setScale(2, RoundingMode.HALF_UP);
        BigDecimal snapNightHours = BigDecimal.valueOf(attendances.stream().mapToDouble(a -> a.getSnapNightHours() != null ? a.getSnapNightHours() : 0).sum()).setScale(2, RoundingMode.HALF_UP);
        BigDecimal snapDayOt      = BigDecimal.valueOf(attendances.stream().mapToDouble(a -> a.getSnapDayOt()      != null ? a.getSnapDayOt()      : 0).sum()).setScale(2, RoundingMode.HALF_UP);
        BigDecimal snapNightOt    = BigDecimal.valueOf(attendances.stream().mapToDouble(a -> a.getSnapNightOt()    != null ? a.getSnapNightOt()    : 0).sum()).setScale(2, RoundingMode.HALF_UP);

        // Resolve formula: inline > formulaId > auto-lookup
        SalaryFormula formula;
        if (inlineFormula != null) {
            formula = inlineFormula;
        } else {
            Optional<SalaryFormula> formulaOpt;
            if (formulaId != null) {
                formulaOpt = salaryFormulaRepository.findById(formulaId);
            } else if (employee.getSalaryGrade() != null) {
                formulaOpt = salaryFormulaRepository
                    .findTopBySalaryGradeIdAndEffectiveDateLessThanEqualOrderByEffectiveDateDesc(
                        employee.getSalaryGrade().getId(), period.from());
                if (formulaOpt.isEmpty()) {
                    formulaOpt = salaryFormulaRepository
                        .findTopBySalaryGradeIdOrderByEffectiveDateDesc(
                            employee.getSalaryGrade().getId());
                }
            } else {
                formulaOpt = Optional.empty();
            }
            formula = formulaOpt.orElseThrow(() ->
                new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.payroll.formula_not_configured"));
        }

        BigDecimal grossSalary;
        BigDecimal socialInsurance;
        BigDecimal healthInsurance;
        BigDecimal unemploymentInsurance;
        BigDecimal personalIncomeTax;
        BigDecimal netSalary;
        BigDecimal overtimePay;
        Map<String, Payroll.DeductionEntry> customDeductions = new java.util.LinkedHashMap<>();
        Map<String, Payroll.DeductionEntry> incomeEntries    = new java.util.LinkedHashMap<>();
        Map<String, Payroll.DeductionEntry> allowanceEntries = new java.util.LinkedHashMap<>();

        Map<String, BigDecimal> vars = buildFormulaVariables(attendances, baseSalary, employee, period);

        List<FormulaVariable> globalVarList = formulaVariableRepository
            .findByCompanyIdOrderByName(employee.getCompany().getId());
        Map<String, String> globalVarExprs = globalVarList.stream()
            .collect(java.util.stream.Collectors.toMap(
                FormulaVariable::getName, FormulaVariable::getExpression));
        Map<String, String> allCustomExprs = new java.util.LinkedHashMap<>(globalVarExprs);
        if (formula.getCustomVars() != null) allCustomExprs.putAll(formula.getCustomVars());
        sortedByOrder(formula.getIncomeVars()).forEach((k, v) -> {
            if (v != null && v.getExpression() != null) allCustomExprs.put(k, v.getExpression());
        });
        sortedByOrder(formula.getAllowanceVars()).forEach((k, v) -> {
            if (v != null && v.getExpression() != null) allCustomExprs.put(k, v.getExpression());
        });
        // L2: chỉ tính các biến tuỳ chỉnh/global thực sự được dùng — một biến global lỗi mà không
        // công thức nào dùng không còn làm hỏng lương mọi người.
        java.util.Set<String> roots = new java.util.HashSet<>(IMPLICIT_SYSTEM_VARS);
        roots.addAll(formulaEngine.referencedVariables(formula.getExpressionGross()));
        roots.addAll(formulaEngine.referencedVariables(formula.getExpressionNet()));
        for (var group : java.util.Arrays.asList(formula.getDeductionVars(), formula.getIncomeVars(), formula.getAllowanceVars())) {
            if (group == null) continue;
            group.forEach((k, v) -> { roots.add(k); if (v != null) roots.addAll(formulaEngine.referencedVariables(v.getExpression())); });
        }
        Map<String, String> usedCustomExprs = formulaEngine.keepReachable(allCustomExprs, roots);
        // Biến bảo hiểm/thuế do hệ thống tính (nếu công ty không tự định nghĩa) có sau GROSS
        java.util.Set<String> systemComputed = new java.util.HashSet<>(SYSTEM_COMPUTED_VARS);
        systemComputed.removeAll(usedCustomExprs.keySet());
        try {
            // Giai đoạn 1: biến không phụ thuộc GROSS → tính GROSS
            java.util.Set<String> notYet = new java.util.HashSet<>(systemComputed);
            notYet.add("GROSS");
            vars = formulaEngine.resolveCustomVarsExcept(usedCustomExprs, vars, notYet);
            // L6: phụ cấp/thưởng chỉnh tay vào GROSS trước khi tính bảo hiểm, thuế, NET
            vars.put("ALLOWANCE_MANUAL", manual.allowanceOrZero());
            vars.put("BONUS", manual.bonusOrZero());
            vars.put("OTHER_DEDUCTIONS", manual.otherDeductionsOrZero());
            grossSalary = formulaEngine.evaluate(formula.getExpressionGross(), vars)
                .add(manual.allowanceOrZero()).add(manual.bonusOrZero());
            vars.put("GROSS", grossSalary);
            // Giai đoạn 2: biến phụ thuộc GROSS (trừ bảo hiểm/thuế hệ thống)
            vars = formulaEngine.resolveCustomVarsExcept(usedCustomExprs, vars, systemComputed);

            // Bảo hiểm tính trên lương hợp đồng nếu có, không thì trên đơn giá bậc lương
            BigDecimal contractSalary = employee.getContractSalary();
            BigDecimal insuranceBase = contractSalary != null && contractSalary.compareTo(BigDecimal.ZERO) > 0
                ? contractSalary : baseSalary;
            BigDecimal socialRate   = vars.getOrDefault("SOCIAL_INS_RATE",  DEFAULT_SOCIAL_INS_RATE);
            BigDecimal healthRate   = vars.getOrDefault("HEALTH_INS_RATE",  DEFAULT_HEALTH_INS_RATE);
            BigDecimal unemployRate = vars.getOrDefault("UNEMPLOYMENT_RATE", DEFAULT_UNEMPLOYMENT_RATE);
            socialInsurance       = vars.getOrDefault("SOCIAL_INS",
                    insuranceBase.multiply(socialRate)).setScale(2, RoundingMode.HALF_UP);
            healthInsurance       = vars.getOrDefault("HEALTH_INS",
                    insuranceBase.multiply(healthRate)).setScale(2, RoundingMode.HALF_UP);
            unemploymentInsurance = vars.getOrDefault("UNEMPLOYMENT_INS",
                    insuranceBase.multiply(unemployRate)).setScale(2, RoundingMode.HALF_UP);
            BigDecimal taxableIncome = grossSalary
                .subtract(socialInsurance).subtract(healthInsurance)
                .subtract(unemploymentInsurance).subtract(PERSONAL_DEDUCTION);
            personalIncomeTax = vars.getOrDefault("PIT",
                    taxableIncome.compareTo(BigDecimal.ZERO) > 0
                        ? FormulaEngine.pitVN(taxableIncome) : BigDecimal.ZERO);

            // L5: đưa bảo hiểm/thuế vào biến để công thức NET dùng đúng các số đã lưu
            vars.put("SOCIAL_INS", socialInsurance);
            vars.put("HEALTH_INS", healthInsurance);
            vars.put("UNEMPLOYMENT_INS", unemploymentInsurance);
            vars.put("TOTAL_INSURANCE", socialInsurance.add(healthInsurance).add(unemploymentInsurance));
            vars.put("PIT", personalIncomeTax);
            vars = formulaEngine.resolveCustomVars(usedCustomExprs, vars);

            evaluateVarGroup(sortedByOrder(formula.getDeductionVars()), vars, customDeductions);
            evaluateVarGroup(sortedByOrder(formula.getIncomeVars()),    vars, incomeEntries);
            evaluateVarGroup(sortedByOrder(formula.getAllowanceVars()), vars, allowanceEntries);

            netSalary = formulaEngine.evaluate(formula.getExpressionNet(), vars)
                .subtract(manual.otherDeductionsOrZero());
        } catch (FormulaEngine.FormulaEvaluationException e) {
            log.warn("Tính lương NV {} kỳ {}/{} lỗi công thức: {}", employeeId, month, year, e.getMessage());
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.payroll.formula_evaluation_failed");
        }
        overtimePay = vars.getOrDefault("DAY_OT", BigDecimal.ZERO)
            .add(vars.getOrDefault("NIGHT_OT", BigDecimal.ZERO));

        Payroll payroll = Payroll.builder()
            .employee(employee)
            .year(year)
            .month(month)
            .baseSalary(baseSalary)
            .overtimePay(overtimePay)
            .grossSalary(grossSalary)
            .socialInsurance(socialInsurance)
            .healthInsurance(healthInsurance)
            .unemploymentInsurance(unemploymentInsurance)
            .personalIncomeTax(personalIncomeTax)
            .customDeductions(customDeductions)
            .incomeEntries(incomeEntries)
            .allowanceEntries(allowanceEntries)
            .netSalary(netSalary)
            .payType(employee.getSalaryGrade() != null ? employee.getSalaryGrade().getPayType().name() : null)
            .salaryGradeId(employee.getSalaryGrade() != null ? employee.getSalaryGrade().getId() : null)
            .salaryGradeCode(employee.getSalaryGrade() != null ? employee.getSalaryGrade().getCode() : null)
            .salaryGradeName(employee.getSalaryGrade() != null ? employee.getSalaryGrade().getName() : null)
            .standardWorkDays(employee.getCompany().getStandardWorkDays())
            .periodFrom(period.from())
            .periodTo(period.to())
            .presentDays((int) presentDays)
            .totalOvertimeHours(totalOvertime)
            .dayHours(snapDayHours)
            .nightHours(snapNightHours)
            .dayOt(snapDayOt)
            .nightOt(snapNightOt)
            .allowance(manual.allowanceOrZero())
            .bonus(manual.bonusOrZero())
            .otherDeductions(manual.otherDeductionsOrZero())
            .build();

        return payroll;
    }

    /**
     * L7: tính lại bảng lương nháp NGAY TRÊN bản ghi đang có (một transaction): giữ id, trạng thái,
     * ghi chú, khoản chỉnh tay, công thức riêng. Tính lỗi thì bản nháp cũ còn nguyên.
     */
    @Transactional
    public Payroll recalculate(Long payrollId, Long formulaId) {
        Payroll payroll = getOrThrow(payrollId);
        if (payroll.getStatus() != Payroll.Status.DRAFT) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.payroll.recalculate_non_draft");
        }
        return recalculateInPlace(payroll, formulaId);
    }

    private Payroll recalculateInPlace(Payroll payroll, Long formulaId) {
        SalaryFormula inline = payroll.getCustomFormula() != null ? toInlineFormula(payroll) : null;
        Payroll fresh = computePayroll(payroll.getEmployee().getId(), payroll.getYear(), payroll.getMonth(),
            inline != null ? null : formulaId, inline,
            new ManualAdjustments(payroll.getAllowance(), payroll.getBonus(), payroll.getOtherDeductions()));
        copyComputed(fresh, payroll);
        return payrollRepository.save(payroll);
    }

    private SalaryFormula toInlineFormula(Payroll payroll) {
        Payroll.CustomFormula cf = payroll.getCustomFormula();
        return SalaryFormula.builder()
            .salaryGrade(payroll.getEmployee().getSalaryGrade())
            .name(cf.getName())
            .effectiveDate(java.time.LocalDate.now())
            .expressionGross(cf.getExpressionGross())
            .expressionNet(cf.getExpressionNet())
            .customVars(cf.getCustomVars() != null ? cf.getCustomVars() : new java.util.LinkedHashMap<>())
            .deductionVars(withSortOrder(cf.getDeductionVars()))
            .incomeVars(withSortOrder(cf.getIncomeVars()))
            .allowanceVars(withSortOrder(cf.getAllowanceVars()))
            .build();
    }

    private static void copyComputed(Payroll src, Payroll dst) {
        dst.setBaseSalary(src.getBaseSalary());
        dst.setOvertimePay(src.getOvertimePay());
        dst.setGrossSalary(src.getGrossSalary());
        dst.setSocialInsurance(src.getSocialInsurance());
        dst.setHealthInsurance(src.getHealthInsurance());
        dst.setUnemploymentInsurance(src.getUnemploymentInsurance());
        dst.setPersonalIncomeTax(src.getPersonalIncomeTax());
        dst.setCustomDeductions(src.getCustomDeductions());
        dst.setIncomeEntries(src.getIncomeEntries());
        dst.setAllowanceEntries(src.getAllowanceEntries());
        dst.setNetSalary(src.getNetSalary());
        dst.setPayType(src.getPayType());
        dst.setSalaryGradeId(src.getSalaryGradeId());
        dst.setSalaryGradeCode(src.getSalaryGradeCode());
        dst.setSalaryGradeName(src.getSalaryGradeName());
        dst.setStandardWorkDays(src.getStandardWorkDays());
        dst.setPeriodFrom(src.getPeriodFrom());
        dst.setPeriodTo(src.getPeriodTo());
        dst.setPresentDays(src.getPresentDays());
        dst.setTotalOvertimeHours(src.getTotalOvertimeHours());
        dst.setDayHours(src.getDayHours());
        dst.setNightHours(src.getNightHours());
        dst.setDayOt(src.getDayOt());
        dst.setNightOt(src.getNightOt());
        dst.setAllowance(src.getAllowance());
        dst.setBonus(src.getBonus());
        dst.setOtherDeductions(src.getOtherDeductions());
    }

    @Transactional
    public Payroll patchDraft(Long payrollId, BigDecimal allowance, BigDecimal bonus,
                               BigDecimal otherDeductions, String note,
                               Payroll.CustomFormula customFormula) {
        Payroll payroll = getOrThrow(payrollId);
        if (payroll.getStatus() != Payroll.Status.DRAFT) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.payroll.edit_non_draft");
        }
        if ((allowance != null && allowance.signum() < 0) || (bonus != null && bonus.signum() < 0)
                || (otherDeductions != null && otherDeductions.signum() < 0)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.payroll.negative_adjustment");
        }
        if (customFormula != null) payroll.setCustomFormula(customFormula);
        if (allowance != null)       payroll.setAllowance(allowance);
        if (bonus != null)           payroll.setBonus(bonus);
        if (otherDeductions != null) payroll.setOtherDeductions(otherDeductions);
        if (note != null)            payroll.setNote(note);
        // L6: luôn tính lại theo công thức (phụ cấp/thưởng vào GROSS → BH/thuế/NET tính lại),
        // không còn ghi đè NET bằng công thức cứng gross − BH − thuế
        return recalculateInPlace(payroll, null);
    }

    @Transactional
    public Payroll approve(Long payrollId) {
        return approve(payrollId, null);
    }

    @Transactional
    public Payroll approve(Long payrollId, Long approvedById) {
        Payroll payroll = getOrThrow(payrollId);
        if (payroll.getStatus() != Payroll.Status.DRAFT) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.payroll.approve_non_draft");
        }
        payroll.setStatus(Payroll.Status.APPROVED);
        payroll.setApprovedAt(LocalDateTime.now());
        payroll.setApprovedById(approvedById);
        return payrollRepository.save(payroll);
    }

    @Transactional
    public Payroll markAsPaid(Long payrollId) {
        return markAsPaid(payrollId, null);
    }

    @Transactional
    public Payroll markAsPaid(Long payrollId, Long paidById) {
        Payroll payroll = getOrThrow(payrollId);
        if (payroll.getStatus() != Payroll.Status.APPROVED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.payroll.pay_non_approved");
        }
        payroll.setStatus(Payroll.Status.PAID);
        payroll.setPaidAt(LocalDateTime.now());
        payroll.setPaidById(paidById);
        return payrollRepository.save(payroll);
    }

    private static Map<String, SalaryFormula.DeductionVar> withSortOrder(Map<String, SalaryFormula.DeductionVar> vars) {
        if (vars == null || vars.isEmpty()) return new java.util.LinkedHashMap<>();
        java.util.LinkedHashMap<String, SalaryFormula.DeductionVar> result = new java.util.LinkedHashMap<>();
        int i = 0;
        for (Map.Entry<String, SalaryFormula.DeductionVar> e : vars.entrySet()) {
            SalaryFormula.DeductionVar dv = e.getValue();
            result.put(e.getKey(), new SalaryFormula.DeductionVar(dv.getLabel(), dv.getExpression(), i++));
        }
        return result;
    }

    private static Map<String, SalaryFormula.DeductionVar> sortedByOrder(Map<String, SalaryFormula.DeductionVar> vars) {
        if (vars == null || vars.isEmpty()) return vars;
        return vars.entrySet().stream()
            .sorted(java.util.Comparator.comparingInt(e -> e.getValue().getSortOrder()))
            .collect(java.util.stream.Collectors.toMap(
                Map.Entry::getKey, Map.Entry::getValue,
                (a, b) -> a, java.util.LinkedHashMap::new));
    }

    private void evaluateVarGroup(
        Map<String, SalaryFormula.DeductionVar> group,
        Map<String, BigDecimal> vars,
        Map<String, Payroll.DeductionEntry> target
    ) throws FormulaEngine.FormulaEvaluationException {
        if (group == null) return;
        for (Map.Entry<String, SalaryFormula.DeductionVar> entry : group.entrySet()) {
            SalaryFormula.DeductionVar dv;
            if (entry.getValue() instanceof SalaryFormula.DeductionVar) {
                dv = entry.getValue();
            } else {
                dv = objectMapper.convertValue(entry.getValue(), SalaryFormula.DeductionVar.class);
            }
            if (dv == null || dv.getExpression() == null) continue;
            BigDecimal amount = formulaEngine.evaluate(dv.getExpression(), vars)
                .setScale(2, RoundingMode.HALF_UP);
            target.put(entry.getKey(), new Payroll.DeductionEntry(dv.getLabel(), amount, dv.getSortOrder()));
            vars.put(entry.getKey(), amount);
        }
    }

    /** Biến code Java đọc trực tiếp từ vars (nên luôn được tính nếu công ty có định nghĩa). */
    private static final java.util.Set<String> IMPLICIT_SYSTEM_VARS = java.util.Set.of(
        "SOCIAL_INS_RATE", "HEALTH_INS_RATE", "UNEMPLOYMENT_RATE",
        "SOCIAL_INS", "HEALTH_INS", "UNEMPLOYMENT_INS", "PIT");
    /** Biến hệ thống chỉ có giá trị sau khi tính GROSS. */
    private static final java.util.Set<String> SYSTEM_COMPUTED_VARS = java.util.Set.of(
        "SOCIAL_INS", "HEALTH_INS", "UNEMPLOYMENT_INS", "TOTAL_INSURANCE", "PIT");

    private Map<String, BigDecimal> buildFormulaVariables(
            List<Attendance> attendances, BigDecimal baseRate,
            Employee employee, PayrollPeriod period) {

        // ── Ngày công ─────────────────────────────────────────────────────────
        long presentDays = attendances.stream()
            .filter(a -> a.getStatus() == Attendance.Status.PRESENT || a.getStatus() == Attendance.Status.LATE)
            .map(Attendance::getDate)
            .distinct()
            .count();
        long absentDays = attendances.stream()
            .filter(a -> a.getStatus() == Attendance.Status.ABSENT)
            .map(Attendance::getDate)
            .distinct()
            .count();
        long leaveDays = attendances.stream()
            .filter(a -> a.getStatus() == Attendance.Status.LEAVE)
            .map(Attendance::getDate)
            .distinct()
            .count();

        // ── Work flags (đếm theo ngày duy nhất, lấy từ workFlags snapshot) ──
        java.util.Set<java.time.LocalDate> onTimeDates    = new java.util.HashSet<>();
        java.util.Set<java.time.LocalDate> lateInDates    = new java.util.HashSet<>();
        java.util.Set<java.time.LocalDate> earlyOutDates  = new java.util.HashSet<>();
        java.util.Set<java.time.LocalDate> overtimeDates  = new java.util.HashSet<>();
        for (Attendance a : attendances) {
            if (a.getWorkFlags() == null || a.getWorkFlags().isBlank()) continue;
            java.time.LocalDate d = a.getDate();
            for (String flag : a.getWorkFlags().split(",")) {
                switch (flag.trim()) {
                    case "ON_TIME"   -> onTimeDates.add(d);
                    case "LATE_IN"   -> lateInDates.add(d);
                    case "EARLY_OUT" -> earlyOutDates.add(d);
                    case "OVERTIME"  -> overtimeDates.add(d);
                }
            }
        }

        // ── Giờ công ──────────────────────────────────────────────────────────
        double dayHours = attendances.stream()
            .mapToDouble(a -> a.getSnapDayHours() != null ? a.getSnapDayHours() : 0).sum();
        double nightHours = attendances.stream()
            .mapToDouble(a -> a.getSnapNightHours() != null ? a.getSnapNightHours() : 0).sum();
        double dayOt = attendances.stream()
            .mapToDouble(a -> a.getSnapDayOt() != null ? a.getSnapDayOt() : 0).sum();
        double nightOt = attendances.stream()
            .mapToDouble(a -> a.getSnapNightOt() != null ? a.getSnapNightOt() : 0).sum();
        double totalOt = dayOt + nightOt;

        // ── Thâm niên (tính đến ngày đầu kỳ lương) ───────────────────────────
        java.time.LocalDate refDate = period.from();
        java.time.LocalDate joinDate = employee.getJoinDate() != null ? employee.getJoinDate() : refDate;
        java.time.Period tenure = java.time.Period.between(joinDate, refDate);
        long tenureYears  = tenure.getYears();
        long tenureMonths = tenureYears * 12L + tenure.getMonths();
        long tenureDays   = java.time.temporal.ChronoUnit.DAYS.between(joinDate, refDate);

        // ── Contract salary ───────────────────────────────────────────────────
        BigDecimal contractSalary = employee.getContractSalary() != null
            ? employee.getContractSalary() : BigDecimal.ZERO;

        // ── Build map ─────────────────────────────────────────────────────────
        Map<String, BigDecimal> vars = new HashMap<>();
        vars.put("PRESENT_DAYS",    BigDecimal.valueOf(presentDays));
        vars.put("ABSENT_DAYS",     BigDecimal.valueOf(absentDays));
        vars.put("LEAVE_DAYS",      BigDecimal.valueOf(leaveDays));
        vars.put("ON_TIME_DAYS",    BigDecimal.valueOf(onTimeDates.size()));
        vars.put("LATE_IN_DAYS",    BigDecimal.valueOf(lateInDates.size()));
        vars.put("EARLY_OUT_DAYS",  BigDecimal.valueOf(earlyOutDates.size()));
        vars.put("OVERTIME_DAYS",   BigDecimal.valueOf(overtimeDates.size()));
        vars.put("DAY_HOURS",       BigDecimal.valueOf(dayHours).setScale(2, RoundingMode.HALF_UP));
        vars.put("NIGHT_HOURS",     BigDecimal.valueOf(nightHours).setScale(2, RoundingMode.HALF_UP));
        vars.put("DAY_OT",          BigDecimal.valueOf(dayOt).setScale(2, RoundingMode.HALF_UP));
        vars.put("NIGHT_OT",        BigDecimal.valueOf(nightOt).setScale(2, RoundingMode.HALF_UP));
        vars.put("TOTAL_OT_HOURS",  BigDecimal.valueOf(totalOt).setScale(2, RoundingMode.HALF_UP));
        vars.put("BASE_RATE",       baseRate);
        vars.put("CONTRACT_SALARY", contractSalary);
        vars.put("TENURE_YEARS",    BigDecimal.valueOf(tenureYears));
        vars.put("TENURE_MONTHS",   BigDecimal.valueOf(tenureMonths));
        vars.put("TENURE_DAYS",     BigDecimal.valueOf(tenureDays));

        // L3: biến cài đặt trước đây được công bố nhưng không bao giờ gán giá trị
        Company company = employee.getCompany();
        vars.put("STANDARD_WORK_DAYS", BigDecimal.valueOf(company.getStandardWorkDays()));
        vars.put("HOURS_PER_DAY", company.getLeaveHoursPerDay() != null
            ? company.getLeaveHoursPerDay() : BigDecimal.valueOf(8));

        // L1: ngày nghỉ phép có lương / không lương (theo snapshot khi duyệt công)
        java.util.Map<Long, java.time.LocalDate> leaveAttDates = attendances.stream()
            .filter(a -> a.getStatus() == Attendance.Status.LEAVE)
            .collect(java.util.stream.Collectors.toMap(Attendance::getId, Attendance::getDate, (x, y) -> x));
        java.util.Set<java.time.LocalDate> paidLeaveDates = new java.util.HashSet<>();
        java.util.Set<java.time.LocalDate> unpaidLeaveDates = new java.util.HashSet<>();
        if (!leaveAttDates.isEmpty()) {
            for (var al : approveLeaveRepository.findByAttendanceIdIn(leaveAttDates.keySet())) {
                java.time.LocalDate d = leaveAttDates.get(al.getAttendance().getId());
                if (d == null) continue;
                (al.isPaid() ? paidLeaveDates : unpaidLeaveDates).add(d);
            }
            unpaidLeaveDates.removeAll(paidLeaveDates);
        }
        vars.put("PAID_LEAVE_DAYS",   BigDecimal.valueOf(paidLeaveDates.size()));
        vars.put("UNPAID_LEAVE_DAYS", BigDecimal.valueOf(unpaidLeaveDates.size()));
        return vars;
    }

    private Payroll getOrThrow(Long id) {
        return payrollRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.payroll.not_found"));
    }
}
