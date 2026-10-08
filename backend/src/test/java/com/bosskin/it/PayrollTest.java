package com.bosskin.it;

import com.bosskin.entity.Company;
import com.bosskin.entity.FormulaVariable;
import com.bosskin.entity.Payroll;
import com.bosskin.entity.SalaryFormula;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.FormulaVariableRepository;
import com.bosskin.service.PayrollService;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Bảng lương (Mốc 3b). Số kỳ vọng tính tay:
 * lương HĐ 22.000.000, công chuẩn 22 → 1.000.000/ngày; BH trên lương HĐ: 8% + 1,5% + 1%.
 */
class PayrollTest extends IntegrationTest {

    @Autowired PayrollService payrollService;
    @Autowired EmployeeRepository employeeRepository;
    @Autowired CompanyRepository companyRepository;
    @Autowired FormulaVariableRepository formulaVariableRepository;

    private static final LocalDate NOV_2 = LocalDate.of(2026, 11, 2); // thứ Hai

    private void setContractSalary(Fixture.Emp e, long amount) {
        var emp = employeeRepository.findById(e.id()).orElseThrow();
        emp.setContractSalary(BigDecimal.valueOf(amount));
        employeeRepository.save(emp);
    }

    /** Một ngày làm đủ ca hành chính 08:00–17:00 rồi duyệt công. */
    private void workFullDay(Fixture.TestCompany c, Fixture.Emp e, LocalDate day) {
        long sa = c.assign(e, "HC", day);
        String token = c.tokenOf(e);
        clock.set(day.atTime(7, 55));
        api.post(token, "/api/v1/attendances/self/check-in", Map.of()).expectOk();
        clock.set(day.atTime(17, 2));
        api.post(token, "/api/v1/attendances/self/check-out", Map.of()).expectOk();
        api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", day.toString(), "shiftAssignmentId", sa)).expectOk();
    }

    private SalaryFormula formula(String gross, String net) {
        return SalaryFormula.builder().name("Test").expressionGross(gross).expressionNet(net).build();
    }

    @Test
    @DisplayName("3 ngày làm + 1 ngày phép có lương: GROSS 4.000.000, BH 2.310.000, NET 1.690.000")
    void workedDaysPlusPaidLeave_matchesHandCalculation() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        setContractSalary(e, 22_000_000);
        for (int i = 0; i < 3; i++) workFullDay(c, e, NOV_2.plusDays(i));

        LocalDate leaveDay = NOV_2.plusDays(3);
        long sa = c.assign(e, "HC", leaveDay);
        c.grantLeaveDays(e, "PN", 5);
        long leaveId = api.post(c.tokenOf(e), "/api/v1/leaves/requests", Map.of(
            "leaveTypeId", c.leaveTypes.get("PN"), "mode", "DAY_RANGE",
            "fromDate", leaveDay.toString(), "toDate", leaveDay.toString(), "reason", "Phép năm")).expectOk().id();
        api.put(c.tokenOf(c.emp(1)), "/api/v1/leaves/requests/" + leaveId + "/approve", Map.of()).expectOk();
        api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", leaveDay.toString(), "shiftAssignmentId", sa)).expectOk();

        Payroll p = payrollService.generatePayrollWithFormula(e.id(), 2026, 11, formula(
            "ROUND(CONTRACT_SALARY / STANDARD_WORK_DAYS * (PRESENT_DAYS + PAID_LEAVE_DAYS))",
            "GROSS - TOTAL_INSURANCE - PIT"));

        assertThat(p.getPresentDays()).isEqualTo(3);
        assertThat(p.getGrossSalary()).isEqualByComparingTo("4000000");
        assertThat(p.getSocialInsurance().add(p.getHealthInsurance()).add(p.getUnemploymentInsurance()))
            .isEqualByComparingTo("2310000");
        assertThat(p.getPersonalIncomeTax()).isEqualByComparingTo("0");
        assertThat(p.getNetSalary()).isEqualByComparingTo("1690000");
    }

    @Test
    @DisplayName("L15 · IF chỉ tính nhánh được chọn: không có ngày công thì không lỗi chia 0")
    void ifEvaluatesOnlyChosenBranch() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        setContractSalary(e, 10_000_000);

        Payroll p = payrollService.generatePayrollWithFormula(e.id(), 2026, 11, formula(
            "IF(PRESENT_DAYS > 0, CONTRACT_SALARY / PRESENT_DAYS, 0)", "GROSS"));

        assertThat(p.getGrossSalary()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("L2 · Biến global lỗi mà không công thức nào dùng không làm hỏng bảng lương")
    void unusedBrokenGlobalVariable_isIgnored() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        formulaVariableRepository.save(FormulaVariable.builder()
            .company(companyRef(c.id)).name("HONG").label("Biến hỏng").expression("1 / 0").build());

        Payroll p = payrollService.generatePayrollWithFormula(e.id(), 2026, 11, formula("1000", "GROSS"));

        assertThat(p.getNetSalary()).isEqualByComparingTo("1000");
    }

    @Test
    @DisplayName("L2 · Biến tuỳ chỉnh tham chiếu GROSS dùng được trong NET")
    void customVariableReferencingGross_works() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        SalaryFormula f = formula("5000000", "GROSS + THUONG");
        f.setCustomVars(new java.util.LinkedHashMap<>(Map.of("THUONG", "ROUND(GROSS * 0.1)")));

        Payroll p = payrollService.generatePayrollWithFormula(e.id(), 2026, 11, f);

        assertThat(p.getNetSalary()).isEqualByComparingTo("5500000");
    }

    @Test
    @DisplayName("L6/L7 · Thêm thưởng vào bản nháp: GROSS, thuế, NET tính lại; tính lại giữ nguyên id và khoản chỉnh tay")
    void patchAndRecalculate_inPlace() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        String accountant = c.tokenOf(c.emp(2));
        long gradeFormula = api.post(c.adminToken, "/api/v1/salary-formulas", Map.of(
            "salaryGradeId", c.salaryGrades.get("NGAY300"), "name", "Cố định 20tr",
            "effectiveDate", "2026-01-01",
            "expressionGross", "20000000", "expressionNet", "GROSS - PIT")).expectOk().id();
        long id = api.post(accountant, "/api/v1/payrolls/generate", Map.of(
            "employeeId", e.id(), "year", 2026, "month", 11, "formulaId", gradeFormula)).expectOk().id();
        var before = api.get(accountant, "/api/v1/payrolls/by-employee/" + e.id()).expectOk().body().get(0);
        double pitBefore = before.path("personalIncomeTax").asDouble();

        var patched = api.patch(accountant, "/api/v1/payrolls/" + id, Map.of("bonus", 5_000_000, "note", "Thưởng quý")).expectOk();
        assertThat(patched.body().path("grossSalary").asDouble()).isEqualTo(25_000_000d);
        assertThat(patched.body().path("personalIncomeTax").asDouble()).as("thuế tính lại khi có thưởng").isGreaterThan(pitBefore);

        var recalculated = api.post(accountant, "/api/v1/payrolls/" + id + "/recalculate", Map.of("formulaId", gradeFormula)).expectOk();
        assertThat(recalculated.id()).isEqualTo(id);
        assertThat(recalculated.body().path("bonus").asDouble()).isEqualTo(5_000_000d);
        assertThat(recalculated.body().path("note").asText()).isEqualTo("Thưởng quý");
        assertThat(recalculated.body().path("grossSalary").asDouble()).isEqualTo(25_000_000d);
    }

    private static Company companyRef(long id) {
        Company co = new Company();
        co.setId(id);
        return co;
    }
}
