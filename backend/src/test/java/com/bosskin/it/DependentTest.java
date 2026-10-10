package com.bosskin.it;

import com.bosskin.entity.Payroll;
import com.bosskin.entity.SalaryFormula;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.service.PayrollService;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.io.ByteArrayInputStream;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Bước M: người phụ thuộc, sàn lương đóng BH, BH công ty đóng, che dữ liệu nhạy cảm. */
class DependentTest extends IntegrationTest {

    @Autowired PayrollService payrollService;
    @Autowired EmployeeRepository employeeRepository;

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 10, 9, 0);

    private static SalaryFormula netFormula() {
        return SalaryFormula.builder().name("T")
            .expressionGross("CONTRACT_SALARY").expressionNet("GROSS - TOTAL_INSURANCE - PIT").build();
    }

    private void contract(Fixture.TestCompany c, Fixture.Emp e, long salary, Long insuranceSalary) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("employeeId", e.id());
        m.put("contractNo", "HD-" + e.code());
        m.put("contractType", "INDEFINITE");
        m.put("status", "ACTIVE");
        m.put("startDate", "2026-01-01");
        m.put("baseSalary", salary);
        if (insuranceSalary != null) m.put("insuranceSalary", insuranceSalary);
        api.post(c.adminToken, "/api/v1/contracts", m).expectOk();
    }

    private static Map<String, Object> dependent(Fixture.Emp e, String name, String from, String to, String status) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("employeeId", e.id());
        m.put("fullName", name);
        m.put("relationship", "CHILD");
        m.put("dateOfBirth", "2020-05-01");
        m.put("deductionFrom", from);
        m.put("deductionTo", to);
        m.put("registrationStatus", status);
        return m;
    }

    @Test
    @DisplayName("NV có 2 người phụ thuộc: giảm trừ 15,5tr + 2 × 6,2tr, thuế đúng; BH công ty đóng 17,5% / 3% / 1%")
    void twoDependents_correctTax() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(6);
        contract(c, e, 40_000_000, null);
        api.post(c.adminToken, "/api/v1/dependents", dependent(e, "Con 1", "2026-01-15", null, "REGISTERED")).expectOk();
        api.post(c.adminToken, "/api/v1/dependents", dependent(e, "Con 2", "2026-03-01", null, "PENDING")).expectOk();
        // Chưa đăng ký → không tính
        api.post(c.adminToken, "/api/v1/dependents", dependent(e, "Mẹ", "2026-01-01", null, "NOT_REGISTERED")).expectOk();

        Payroll p = payrollService.generatePayrollWithFormula(e.id(), 2026, 11, netFormula());
        assertThat(p.getDependents()).isEqualTo(2);
        assertThat(p.getFamilyDeduction()).isEqualByComparingTo("27900000");
        // BH người lao động 10,5% × 40tr = 4,2tr; thu nhập tính thuế 40 − 4,2 − 27,9 = 7,9tr → 5% = 395.000
        assertThat(p.getPersonalIncomeTax()).isEqualByComparingTo("395000");
        assertThat(p.getNetSalary()).isEqualByComparingTo("35405000");
        assertThat(p.getEmployerSocialIns()).isEqualByComparingTo("7000000");
        assertThat(p.getEmployerHealthIns()).isEqualByComparingTo("1200000");
        assertThat(p.getEmployerUnemploymentIns()).isEqualByComparingTo("400000");

        // Tỷ lệ công ty đổi được ở cài đặt (vd. TNLĐ-BNN 0,3% → BHXH 17,3%)
        JsonNode settings = api.get(c.adminToken, "/api/v1/company-settings").expectOk().body();
        assertThat(settings.path("payroll").path("employerSocialPercent").decimalValue()).isEqualByComparingTo("17.5");

        JsonNode list = api.get(c.adminToken, "/api/v1/dependents?employeeId=" + e.id()).expectOk().body();
        assertThat(list.size()).isEqualTo(3);
        assertThat(list.get(0).path("deductionFrom").asText()).isEqualTo("2026-01-01");
    }

    @Test
    @DisplayName("Người phụ thuộc hết hạn tháng 8: kỳ 8 còn giảm trừ, kỳ 9 thôi; ngày kết thúc trước ngày bắt đầu bị chặn")
    void dependentEndingMidYear() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(6);
        contract(c, e, 30_000_000, null);
        long id = api.post(c.adminToken, "/api/v1/dependents",
            dependent(e, "Con", "2026-01-01", "2026-08-31", "REGISTERED")).expectOk().id();

        Payroll aug = payrollService.generatePayrollWithFormula(e.id(), 2026, 8, netFormula());
        assertThat(aug.getDependents()).isEqualTo(1);
        assertThat(aug.getFamilyDeduction()).isEqualByComparingTo("21700000");
        Payroll sep = payrollService.generatePayrollWithFormula(e.id(), 2026, 9, netFormula());
        assertThat(sep.getDependents()).isZero();
        assertThat(sep.getFamilyDeduction()).isEqualByComparingTo("15500000");
        assertThat(sep.getPersonalIncomeTax()).isGreaterThan(aug.getPersonalIncomeTax());

        var bad = api.put(c.adminToken, "/api/v1/dependents/" + id, dependent(e, "Con", "2026-05-01", "2026-04-01", "REGISTERED"));
        assertThat(bad.status()).isEqualTo(400);
        assertThat(bad.raw()).contains("error.dependent.invalid_period");

        api.delete(c.adminToken, "/api/v1/dependents/" + id).expectOk();
        // Đã xoá → kỳ 7 (trong khoảng giảm trừ cũ) không còn tính
        Payroll jul = payrollService.generatePayrollWithFormula(e.id(), 2026, 7, netFormula());
        assertThat(jul.getDependents()).isZero();
    }

    @Test
    @DisplayName("Lương đóng BH dưới lương tối thiểu vùng → nâng lên sàn")
    void insuranceFloor() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(6);
        contract(c, e, 4_000_000, 3_000_000L);
        Payroll p = payrollService.generatePayrollWithFormula(e.id(), 2026, 11, netFormula());
        // Vùng 1 năm 2026: 5.310.000
        assertThat(p.getInsuranceBase()).isEqualByComparingTo("5310000");
        assertThat(p.getSocialInsurance()).isEqualByComparingTo("424800");
    }

    @Test
    @DisplayName("Không có EMPLOYEE_SENSITIVE_VIEW: MST / CCCD / tài khoản che, gửi lại bản che không ghi đè, có quyền thì thấy đủ")
    void sensitiveFieldsMasked() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var target = c.emp(6);
        var hr = c.emp(5);
        String url = "/api/v1/employees/" + target.id();

        Map<String, Object> full = new LinkedHashMap<>();
        full.put("identityCard", "001099012345");
        full.put("bankAccount", "190312345678");
        full.put("taxCode", "8123456789");
        full.put("socialInsuranceNo", "0123456789");
        full.put("healthInsurancePlace", "BV Bạch Mai");
        full.put("insuranceJoinDate", "2026-01-01");
        api.put(c.adminToken, url, full).expectOk();
        api.post(c.adminToken, "/api/v1/dependents", Map.of("employeeId", target.id(), "fullName", "Con",
            "relationship", "CHILD", "taxCode", "8999888777", "deductionFrom", "2026-01-01")).expectOk();

        JsonNode admin = api.get(c.adminToken, url).expectOk().body();
        assertThat(admin.path("taxCode").asText()).isEqualTo("8123456789");
        assertThat(admin.path("identityCard").asText()).isEqualTo("001099012345");

        c.createRole("Nhân sự hạn chế", List.of("EMPLOYEE_VIEW", "EMPLOYEE_UPDATE"));
        c.setRole(hr, "Nhân sự hạn chế");
        String hrToken = c.tokenOf(hr);
        JsonNode masked = api.get(hrToken, url).expectOk().body();
        assertThat(masked.path("identityCard").asText()).isEqualTo("********2345");
        assertThat(masked.path("taxCode").asText()).isEqualTo("******6789");
        assertThat(masked.path("bankAccount").asText()).isEqualTo("********5678");
        assertThat(masked.path("socialInsuranceNo").asText()).isEqualTo("******6789");
        assertThat(masked.path("healthInsurancePlace").asText()).isEqualTo("BV Bạch Mai");
        JsonNode deps = api.get(hrToken, "/api/v1/dependents?employeeId=" + target.id()).expectOk().body();
        assertThat(deps.get(0).path("taxCode").asText()).isEqualTo("******8777");

        // Form gửi lại nguyên bản che + đổi SĐT → dữ liệu thật giữ nguyên
        Map<String, Object> back = new LinkedHashMap<>();
        back.put("phone", "0909000111");
        back.put("identityCard", masked.path("identityCard").asText());
        back.put("taxCode", masked.path("taxCode").asText());
        back.put("bankAccount", masked.path("bankAccount").asText());
        api.put(hrToken, url, back).expectOk();
        var saved = employeeRepository.findById(target.id()).orElseThrow();
        assertThat(saved.getIdentityCard()).isEqualTo("001099012345");
        assertThat(saved.getTaxCode()).isEqualTo("8123456789");
        assertThat(saved.getBankAccount()).isEqualTo("190312345678");
        assertThat(saved.getPhone()).isEqualTo("0909000111");

        // Có quyền xem dữ liệu nhạy cảm → thấy đủ
        c.createRole("Nhân sự đủ quyền", List.of("EMPLOYEE_VIEW", "EMPLOYEE_UPDATE", "EMPLOYEE_SENSITIVE_VIEW"));
        c.setRole(hr, "Nhân sự đủ quyền");
        JsonNode fullView = api.get(c.tokenOf(hr), url).expectOk().body();
        assertThat(fullView.path("identityCard").asText()).isEqualTo("001099012345");
        assertThat(fullView.path("socialInsuranceNo").asText()).isEqualTo("0123456789");
    }

    @Test
    @DisplayName("Báo cáo NV tham gia BH, người phụ thuộc; báo cáo lương có cột BH công ty đóng + tổng chi phí")
    void reports() throws Exception {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(6);
        api.put(c.adminToken, "/api/v1/employees/" + e.id(),
            Map.of("taxCode", "8123456789", "socialInsuranceNo", "0123456789", "insuranceJoinDate", "2026-01-01")).expectOk();
        contract(c, e, 20_000_000, null);
        api.post(c.adminToken, "/api/v1/dependents", dependent(e, "Con", "2026-01-01", null, "REGISTERED")).expectOk();

        byte[] insured = api.download(c.adminToken, "/api/v1/reports/insured-employees");
        try (XSSFWorkbook wb = new XSSFWorkbook(new ByteArrayInputStream(insured))) {
            var sheet = wb.getSheetAt(0);
            assertThat(sheet.getLastRowNum()).isEqualTo(1);
            Row r = sheet.getRow(1);
            assertThat(r.getCell(5).getStringCellValue()).isEqualTo("8123456789");
            assertThat(r.getCell(9).getNumericCellValue()).isEqualTo(20_000_000d);
        }
        byte[] deps = api.download(c.adminToken, "/api/v1/reports/dependents");
        try (XSSFWorkbook wb = new XSSFWorkbook(new ByteArrayInputStream(deps))) {
            Row r = wb.getSheetAt(0).getRow(1);
            assertThat(r.getCell(4).getStringCellValue()).isEqualTo("Con");
            assertThat(r.getCell(8).getStringCellValue()).isEqualTo("01/2026");
        }
    }
}
