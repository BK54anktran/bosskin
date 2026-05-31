package com.bosskin.service;

import com.bosskin.core.PayrollPeriod;
import com.bosskin.entity.Attendance;
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

    private Payroll doGeneratePayroll(Long employeeId, int year, int month, Long formulaId, SalaryFormula inlineFormula) {
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
        try {
            vars = formulaEngine.resolveCustomVars(allCustomExprs, vars);
            grossSalary = formulaEngine.evaluate(formula.getExpressionGross(), vars);
            vars.put("GROSS", grossSalary);
            vars = formulaEngine.resolveCustomVars(allCustomExprs, vars);

            BigDecimal socialRate   = vars.getOrDefault("SOCIAL_INS_RATE",  DEFAULT_SOCIAL_INS_RATE);
            BigDecimal healthRate   = vars.getOrDefault("HEALTH_INS_RATE",  DEFAULT_HEALTH_INS_RATE);
            BigDecimal unemployRate = vars.getOrDefault("UNEMPLOYMENT_RATE", DEFAULT_UNEMPLOYMENT_RATE);
            socialInsurance       = vars.getOrDefault("SOCIAL_INS",
                    baseSalary.multiply(socialRate)).setScale(2, RoundingMode.HALF_UP);
            healthInsurance       = vars.getOrDefault("HEALTH_INS",
                    baseSalary.multiply(healthRate)).setScale(2, RoundingMode.HALF_UP);
            unemploymentInsurance = vars.getOrDefault("UNEMPLOYMENT_INS",
                    baseSalary.multiply(unemployRate)).setScale(2, RoundingMode.HALF_UP);
            BigDecimal taxableIncome = grossSalary
                .subtract(socialInsurance).subtract(healthInsurance)
                .subtract(unemploymentInsurance).subtract(PERSONAL_DEDUCTION);
            personalIncomeTax = vars.getOrDefault("PIT",
                    taxableIncome.compareTo(BigDecimal.ZERO) > 0
                        ? FormulaEngine.pitVN(taxableIncome) : BigDecimal.ZERO);

            evaluateVarGroup(sortedByOrder(formula.getDeductionVars()), vars, customDeductions);
            evaluateVarGroup(sortedByOrder(formula.getIncomeVars()),    vars, incomeEntries);
            evaluateVarGroup(sortedByOrder(formula.getAllowanceVars()), vars, allowanceEntries);

            netSalary = formulaEngine.evaluate(formula.getExpressionNet(), vars);
        } catch (FormulaEngine.FormulaEvaluationException e) {
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
            .standardWorkDays(employee.getCompany().getStandardWorkDays())
            .periodFrom(period.from())
            .periodTo(period.to())
            .presentDays((int) presentDays)
            .totalOvertimeHours(totalOvertime)
            .dayHours(snapDayHours)
            .nightHours(snapNightHours)
            .dayOt(snapDayOt)
            .nightOt(snapNightOt)
            .build();

        return payrollRepository.save(payroll);
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

        // Nếu có customFormula mới → tính lại hoàn toàn với formula inline
        if (customFormula != null) {
            payroll.setCustomFormula(customFormula);
            // Tạo SalaryFormula tạm từ customFormula để tính lại
            SalaryFormula inlineFormula = SalaryFormula.builder()
                .salaryGrade(payroll.getEmployee().getSalaryGrade())
                .name(customFormula.getName())
                .effectiveDate(java.time.LocalDate.now())
                .expressionGross(customFormula.getExpressionGross())
                .expressionNet(customFormula.getExpressionNet())
                .customVars(customFormula.getCustomVars() != null ? customFormula.getCustomVars() : new java.util.LinkedHashMap<>())
                .deductionVars(withSortOrder(customFormula.getDeductionVars()))
                .incomeVars(withSortOrder(customFormula.getIncomeVars()))
                .allowanceVars(withSortOrder(customFormula.getAllowanceVars()))
                .build();
            Long employeeId = payroll.getEmployee().getId();
            int year = payroll.getYear(), month = payroll.getMonth();
            payrollRepository.delete(payroll);
            payrollRepository.flush();
            Payroll recalculated = generatePayrollWithFormula(employeeId, year, month, inlineFormula);
            recalculated.setCustomFormula(customFormula);
            if (allowance != null) recalculated.setAllowance(allowance);
            if (bonus != null)     recalculated.setBonus(bonus);
            if (otherDeductions != null) recalculated.setOtherDeductions(otherDeductions);
            if (note != null)      recalculated.setNote(note);
            // Recalculate net after manual adjustments
            BigDecimal g = recalculated.getGrossSalary()
                .subtract(recalculated.getAllowance() != null ? recalculated.getAllowance() : BigDecimal.ZERO)
                .subtract(recalculated.getBonus() != null ? recalculated.getBonus() : BigDecimal.ZERO)
                .add(recalculated.getAllowance() != null ? recalculated.getAllowance() : BigDecimal.ZERO)
                .add(recalculated.getBonus() != null ? recalculated.getBonus() : BigDecimal.ZERO);
            recalculated.setGrossSalary(g);
            BigDecimal totalDed = recalculated.getSocialInsurance()
                .add(recalculated.getHealthInsurance())
                .add(recalculated.getUnemploymentInsurance())
                .add(recalculated.getPersonalIncomeTax())
                .add(recalculated.getOtherDeductions());
            recalculated.setNetSalary(g.subtract(totalDed));
            return payrollRepository.save(recalculated);
        }

        // Không có customFormula → chỉ patch allowance/bonus/note
        BigDecimal baseGross = payroll.getGrossSalary()
            .subtract(payroll.getAllowance())
            .subtract(payroll.getBonus());

        if (allowance != null)       payroll.setAllowance(allowance);
        if (bonus != null)           payroll.setBonus(bonus);
        if (otherDeductions != null) payroll.setOtherDeductions(otherDeductions);
        if (note != null)            payroll.setNote(note);

        BigDecimal gross = baseGross
            .add(payroll.getAllowance())
            .add(payroll.getBonus());
        payroll.setGrossSalary(gross);

        BigDecimal totalDeductions = payroll.getSocialInsurance()
            .add(payroll.getHealthInsurance())
            .add(payroll.getUnemploymentInsurance())
            .add(payroll.getPersonalIncomeTax())
            .add(payroll.getOtherDeductions());
        payroll.setNetSalary(gross.subtract(totalDeductions));

        return payrollRepository.save(payroll);
    }

    @Transactional
    public Payroll approve(Long payrollId) {
        Payroll payroll = getOrThrow(payrollId);
        if (payroll.getStatus() != Payroll.Status.DRAFT) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.payroll.approve_non_draft");
        }
        payroll.setStatus(Payroll.Status.APPROVED);
        payroll.setApprovedAt(LocalDateTime.now());
        return payrollRepository.save(payroll);
    }

    @Transactional
    public Payroll markAsPaid(Long payrollId) {
        Payroll payroll = getOrThrow(payrollId);
        if (payroll.getStatus() != Payroll.Status.APPROVED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.payroll.pay_non_approved");
        }
        payroll.setStatus(Payroll.Status.PAID);
        payroll.setPaidAt(LocalDateTime.now());
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

    private Map<String, BigDecimal> buildFormulaVariables(
            List<Attendance> attendances, BigDecimal baseRate,
            Employee employee, PayrollPeriod period) {

        // ── Ngày công ─────────────────────────────────────────────────────────
        long presentDays = attendances.stream()
            .filter(a -> a.getStatus() == Attendance.Status.PRESENT || a.getStatus() == Attendance.Status.LATE)
            .count();
        long absentDays = attendances.stream()
            .filter(a -> a.getStatus() == Attendance.Status.ABSENT)
            .count();
        long leaveDays = attendances.stream()
            .filter(a -> a.getStatus() == Attendance.Status.LEAVE)
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
        return vars;
    }

    private Payroll getOrThrow(Long id) {
        return payrollRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.payroll.not_found"));
    }
}
