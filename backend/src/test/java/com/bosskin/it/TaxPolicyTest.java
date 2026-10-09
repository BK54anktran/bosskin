package com.bosskin.it;

import com.bosskin.entity.Payroll;
import com.bosskin.entity.SalaryFormula;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.service.FormulaEngine;
import com.bosskin.service.PayrollService;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Bước I: thuế TNCN / BH theo chính sách hiệu lực của kỳ (V13). Số kỳ vọng tính tay:
 * BH người lao động 8% + 1,5% + 1%; 2026: giảm trừ 15,5 triệu, biểu 5 bậc; trước 2026: 11 triệu, biểu 7 bậc;
 * trần BHXH/BHYT 20 × mức tham chiếu (2.340.000 → 2.530.000 từ 01/07/2026), BHTN 20 × lương tối thiểu vùng.
 */
class TaxPolicyTest extends IntegrationTest {

    @Autowired PayrollService payrollService;
    @Autowired EmployeeRepository employeeRepository;
    @Autowired CompanyRepository companyRepository;

    private void setContractSalary(Fixture.Emp e, long amount) {
        var emp = employeeRepository.findById(e.id()).orElseThrow();
        emp.setContractSalary(BigDecimal.valueOf(amount));
        employeeRepository.save(emp);
    }

    private Payroll pay(Fixture.Emp e, int year, int month, String gross) {
        return payrollService.generatePayrollWithFormula(e.id(), year, month, SalaryFormula.builder()
            .name("Test").expressionGross(gross).expressionNet("GROSS - TOTAL_INSURANCE - PIT").build());
    }

    private static BigDecimal insurance(Payroll p) {
        return p.getSocialInsurance().add(p.getHealthInsurance()).add(p.getUnemploymentInsurance());
    }

    private String sys() {
        return api.post(null, "/admin/auth/login", Map.of("email", "sysadmin@test.local", "password", "Test-SysAdmin-123"))
            .expectOk().text("accessToken");
    }

    @Test
    @DisplayName("Kỳ 11/2026, lương 50 triệu: BH 5.250.000, giảm trừ 15,5 triệu, thuế 5 bậc 2.425.000")
    void year2026_fiveBrackets() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        setContractSalary(e, 50_000_000);
        Payroll p = pay(e, 2026, 11, "50000000");
        assertThat(insurance(p)).isEqualByComparingTo("5250000");
        assertThat(p.getFamilyDeduction()).isEqualByComparingTo("15500000");
        assertThat(p.getInsuranceBase()).isEqualByComparingTo("50000000");
        // 50.000.000 − 5.250.000 − 15.500.000 = 29.250.000 → 10tr×5% + 19,25tr×10%
        assertThat(p.getPersonalIncomeTax()).isEqualByComparingTo("2425000");
        assertThat(p.getNetSalary()).isEqualByComparingTo("42325000");
    }

    @Test
    @DisplayName("Lương 120 triệu vượt trần: BHXH/BHYT trên 50,6 triệu, BHTN trên 106,2 triệu (vùng I); thuế 20.089.300")
    void insuranceCaps_region1() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        setContractSalary(e, 120_000_000);
        Payroll p = pay(e, 2026, 11, "120000000");
        assertThat(p.getInsuranceBase()).isEqualByComparingTo("50600000");
        assertThat(p.getSocialInsurance()).isEqualByComparingTo("4048000");
        assertThat(p.getHealthInsurance()).isEqualByComparingTo("759000");
        assertThat(p.getUnemploymentInsurance()).isEqualByComparingTo("1062000");
        // 120.000.000 − 5.869.000 − 15.500.000 = 98.631.000 → 0,5 + 2 + 6 + 38,631×30% = 20.089.300
        assertThat(p.getPersonalIncomeTax()).isEqualByComparingTo("20089300");
    }

    @Test
    @DisplayName("Công ty vùng IV: trần BHTN = 20 × 3.700.000 = 74 triệu")
    void unemploymentCap_followsCompanyRegion() {
        var c = fixture.standardCompany();
        var company = companyRepository.findById(c.id).orElseThrow();
        company.setMinWageRegion(4);
        companyRepository.save(company);
        var e = c.emp(6);
        setContractSalary(e, 120_000_000);
        Payroll p = pay(e, 2026, 11, "120000000");
        assertThat(p.getUnemploymentInsurance()).isEqualByComparingTo("740000");
    }

    @Test
    @DisplayName("Kỳ 11/2025 vẫn tính theo chính sách cũ (11 triệu, 7 bậc); kỳ 01/2026 theo chính sách mới")
    void effectiveDate_picksPolicyOfPeriod() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        setContractSalary(e, 20_000_000);
        Payroll old = pay(e, 2025, 11, "20000000");
        assertThat(old.getFamilyDeduction()).isEqualByComparingTo("11000000");
        // 20.000.000 − 2.100.000 − 11.000.000 = 6.900.000 → 5tr×5% + 1,9tr×10%
        assertThat(old.getPersonalIncomeTax()).isEqualByComparingTo("440000");
        Payroll jan = pay(e, 2026, 1, "20000000");
        // 20.000.000 − 2.100.000 − 15.500.000 = 2.400.000 → 5%
        assertThat(jan.getPersonalIncomeTax()).isEqualByComparingTo("120000");
    }

    @Test
    @DisplayName("PIT_VN trong công thức dùng biểu của kỳ; biến FAMILY_DEDUCTION, INSURANCE_CAP có giá trị")
    void formulaFunctionAndVariables_followPolicy() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        setContractSalary(e, 10_000_000);
        Payroll p = payrollService.generatePayrollWithFormula(e.id(), 2026, 11, SalaryFormula.builder().name("Test")
            .expressionGross("PIT_VN(40000000) + FAMILY_DEDUCTION * 0 + INSURANCE_CAP * 0")
            .expressionNet("GROSS").build());
        // 40 triệu tính thuế theo 5 bậc: 0,5 + 2 + 10tr×20% = 4.500.000
        assertThat(p.getGrossSalary()).isEqualByComparingTo("4500000");
        assertThat(FormulaEngine.pitVN(new BigDecimal("40000000"), FormulaEngine.DEFAULT_PIT_BRACKETS))
            .isEqualByComparingTo("4500000");
    }

    @Test
    @DisplayName("System admin thêm / sửa / xoá chính sách; trùng ngày 409, biểu sai 400; user công ty không gọi được")
    void adminCrud() {
        String sys = sys();
        var list = api.get(sys, "/admin/tax-policies").expectOk().body();
        assertThat(list.size()).isGreaterThanOrEqualTo(3);
        Map<String, Object> body = new java.util.LinkedHashMap<>(Map.of(
            "effectiveFrom", "2099-01-01", "personalDeduction", 20000000, "dependentDeduction", 8000000,
            "brackets", List.of(Map.of("upTo", 10000000, "rate", 0.05), Map.of("rate", 0.30)),
            "referenceWage", 3000000, "insuranceCapMultiplier", 20, "unemploymentCapMultiplier", 20,
            "minWages", List.of(6000000, 5000000, 4500000, 4000000)));
        body.put("note", "Thử");
        long id = api.post(sys, "/admin/tax-policies", body).expectOk().id();
        try {
            assertThat(api.post(sys, "/admin/tax-policies", body).status()).isEqualTo(409);
            Map<String, Object> bad = new java.util.LinkedHashMap<>(body);
            bad.put("effectiveFrom", "2099-02-01");
            bad.put("brackets", List.of(Map.of("upTo", 10000000, "rate", 0.05), Map.of("upTo", 5000000, "rate", 0.1), Map.of("rate", 0.3)));
            assertThat(api.post(sys, "/admin/tax-policies", bad).raw()).contains("error.tax_policy.brackets_invalid");
            body.put("personalDeduction", 21000000);
            assertThat(api.put(sys, "/admin/tax-policies/" + id, body).expectOk().body().path("personalDeduction").asDouble())
                .isEqualTo(21000000d);
            var c = fixture.newCompany();
            assertThat(api.get(c.adminToken, "/admin/tax-policies").status()).isIn(401, 403);
        } finally {
            api.delete(sys, "/admin/tax-policies/" + id).expectOk();
        }
    }
}
