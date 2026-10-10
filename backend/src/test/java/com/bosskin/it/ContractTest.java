package com.bosskin.it;

import com.bosskin.entity.Payroll;
import com.bosskin.entity.SalaryFormula;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.service.PayrollService;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Bước L: hợp đồng lao động, phụ lục tăng lương giữa kỳ, cảnh báo hết hạn, xuất / nhập Excel. */
class ContractTest extends IntegrationTest {

    @Autowired PayrollService payrollService;
    @Autowired EmployeeRepository employeeRepository;

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 10, 9, 0);

    private Map<String, Object> contract(Fixture.Emp e, String no, String type, String status, String start, String end,
                                         long salary) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("employeeId", e.id());
        m.put("contractNo", no);
        m.put("contractType", type);
        m.put("status", status);
        m.put("signDate", start);
        m.put("startDate", start);
        m.put("endDate", end);
        m.put("baseSalary", salary);
        return m;
    }

    private static Map<String, Object> allowance(String code, String name, long amount, boolean insurable, boolean taxable) {
        return Map.of("code", code, "name", name, "amount", amount, "insurable", insurable, "taxable", taxable);
    }

    @Test
    @DisplayName("Phụ lục tăng lương từ 16/11: CONTRACT_SALARY kỳ 11 bình quân theo công chuẩn, BH theo mức cuối kỳ + phụ cấp đóng BH")
    void midPeriodRaise_viaAppendix() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(6);
        Map<String, Object> body = contract(e, "HD-001", "INDEFINITE", "ACTIVE", "2026-01-01", null, 10_000_000);
        body.put("allowances", List.of(
            allowance("LUNCH", "Ăn trưa", 730_000, false, false),
            allowance("RESP", "Trách nhiệm", 1_000_000, true, true)));
        long id = api.post(c.adminToken, "/api/v1/contracts", body).expectOk().id();

        Map<String, Object> appendix = new LinkedHashMap<>();
        appendix.put("appendixNo", "PL-01");
        appendix.put("effectiveFrom", "2026-11-16");
        appendix.put("baseSalary", 12_000_000);
        JsonNode after = api.post(c.adminToken, "/api/v1/contracts/" + id + "/appendices", appendix).expectOk().body();
        assertThat(after.path("appendices").size()).isEqualTo(1);
        assertThat(after.path("currentBaseSalary").decimalValue()).isEqualByComparingTo("10000000");
        // Hồ sơ nhân viên đồng bộ theo lương hiệu lực hôm nay
        assertThat(employeeRepository.findById(e.id()).orElseThrow().getContractSalary()).isEqualByComparingTo("10000000");

        // Kỳ 1–30/11: 10 ngày công chuẩn lương 10tr, 11 ngày lương 12tr → (100 + 132) / 21 triệu
        Payroll p = payrollService.generatePayrollWithFormula(e.id(), 2026, 11, SalaryFormula.builder().name("T")
            .expressionGross("CONTRACT_SALARY + ALLOWANCE_LUNCH + ALLOWANCE_KHONG_CO + NON_TAXABLE_ALLOWANCE * 0")
            .expressionNet("GROSS").build());
        assertThat(p.getGrossSalary()).isEqualByComparingTo("11777619.05");
        assertThat(p.getInsuranceBase()).isEqualByComparingTo("13000000");

        // Kỳ 10: toàn kỳ lương cũ
        Payroll oct = payrollService.generatePayrollWithFormula(e.id(), 2026, 10, SalaryFormula.builder().name("T")
            .expressionGross("CONTRACT_SALARY").expressionNet("GROSS").build());
        assertThat(oct.getGrossSalary()).isEqualByComparingTo("10000000");
    }

    @Test
    @DisplayName("Không cho hai hợp đồng hiệu lực chồng ngày; kiểm thời hạn theo loại hợp đồng")
    void overlapAndTypeRules() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(6);
        api.post(c.adminToken, "/api/v1/contracts",
            contract(e, "HD-1", "FIXED_TERM", "ACTIVE", "2026-01-01", "2026-12-31", 9_000_000)).expectOk();
        var overlap = api.post(c.adminToken, "/api/v1/contracts",
            contract(e, "HD-2", "FIXED_TERM", "ACTIVE", "2026-12-01", "2027-12-31", 9_500_000));
        assertThat(overlap.status()).isEqualTo(409);
        assertThat(overlap.raw()).contains("error.contract.overlap|HD-1");
        // Nháp được phép chồng; kích hoạt thì bị chặn
        long draft = api.post(c.adminToken, "/api/v1/contracts",
            contract(e, "HD-2", "FIXED_TERM", "DRAFT", "2026-12-01", "2027-12-31", 9_500_000)).expectOk().id();
        assertThat(api.post(c.adminToken, "/api/v1/contracts/" + draft + "/activate", null).status()).isEqualTo(409);

        assertThat(api.post(c.adminToken, "/api/v1/contracts",
            contract(e, "HD-3", "FIXED_TERM", "DRAFT", "2027-01-01", "2030-01-01", 9_000_000)).raw())
            .contains("error.contract.fixed_term_too_long");
        assertThat(api.post(c.adminToken, "/api/v1/contracts",
            contract(e, "HD-4", "INDEFINITE", "DRAFT", "2027-01-01", "2028-01-01", 9_000_000)).raw())
            .contains("error.contract.indefinite_has_end");
        assertThat(api.post(c.adminToken, "/api/v1/contracts",
            contract(e, "HD-1", "INDEFINITE", "DRAFT", "2027-01-01", null, 9_000_000)).status()).isEqualTo(409);
    }

    @Test
    @DisplayName("Hợp đồng hết hạn trong 30 ngày vào danh sách cần gia hạn; có hợp đồng nối tiếp thì rời danh sách")
    void expiringWithin30Days() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var a = c.emp(6);
        var b = c.emp(7);
        var d = c.emp(8);
        api.post(c.adminToken, "/api/v1/contracts",
            contract(a, "HD-A", "FIXED_TERM", "ACTIVE", "2025-10-31", "2026-10-30", 8_000_000)).expectOk();
        api.post(c.adminToken, "/api/v1/contracts",
            contract(b, "HD-B", "FIXED_TERM", "ACTIVE", "2026-01-01", "2027-01-31", 8_000_000)).expectOk();
        api.post(c.adminToken, "/api/v1/contracts",
            contract(d, "HD-D", "PROBATION", "ACTIVE", "2026-08-01", "2026-10-01", 8_000_000)).expectOk();

        JsonNode list = api.get(c.adminToken, "/api/v1/contracts/expiring").expectOk().body();
        Map<String, JsonNode> byNo = new LinkedHashMap<>();
        for (JsonNode n : list) byNo.put(n.path("contractNo").asText(), n);
        assertThat(byNo).containsOnlyKeys("HD-A", "HD-D");
        assertThat(byNo.get("HD-A").path("daysToEnd").asInt()).isEqualTo(20);
        assertThat(byNo.get("HD-A").path("displayStatus").asText()).isEqualTo("ACTIVE");
        assertThat(byNo.get("HD-D").path("displayStatus").asText()).isEqualTo("EXPIRED");
        assertThat(api.get(c.adminToken, "/api/v1/contracts/expiring?days=120").expectOk().body().size()).isEqualTo(3);
        // Ô cảnh báo ở Tổng quan
        JsonNode risks = api.get(c.adminToken, "/api/v1/dashboard/risks").expectOk().body();
        assertThat(risks.path("contractExpiring").size()).isEqualTo(2);

        api.post(c.adminToken, "/api/v1/contracts",
            contract(a, "HD-A2", "INDEFINITE", "ACTIVE", "2026-10-31", null, 8_500_000)).expectOk();
        list = api.get(c.adminToken, "/api/v1/contracts/expiring").expectOk().body();
        assertThat(list.size()).isEqualTo(1);
        assertThat(list.get(0).path("contractNo").asText()).isEqualTo("HD-D");

        // Nhân viên không có quyền
        assertThat(api.get(c.tokenOf(c.emp(9)), "/api/v1/contracts").status()).isEqualTo(403);
    }

    @Test
    @DisplayName("Xuất Excel rồi nhập lại không đổi gì; sửa lương trong file → xem trước báo UPDATE")
    void excelRoundTrip_noDrift() throws Exception {
        clock.set(NOW);
        var c = fixture.standardCompany();
        Map<String, Object> body = contract(c.emp(6), "HD-X1", "FIXED_TERM", "ACTIVE", "2026-01-01", "2027-12-31", 9_250_000);
        body.put("insuranceSalary", 7_000_000);
        body.put("note", "Ghi chú");
        body.put("allowances", List.of(allowance("LUNCH", "Ăn trưa", 730_000, false, false)));
        api.post(c.adminToken, "/api/v1/contracts", body).expectOk();
        api.post(c.adminToken, "/api/v1/contracts",
            contract(c.emp(7), "HD-X2", "INDEFINITE", "DRAFT", "2026-11-01", null, 8_000_000)).expectOk();

        byte[] file = api.download(c.adminToken, "/api/v1/contracts/export");
        JsonNode diffs = api.upload(c.adminToken, "/api/v1/contracts/preview-import", "hd.xlsx", file).expectOk().body();
        assertThat(diffs.size()).isEqualTo(2);
        for (JsonNode d : diffs) assertThat(d.path("action").asText()).as(d.toString()).isEqualTo("NO_CHANGE");
        JsonNode result = api.upload(c.adminToken, "/api/v1/contracts/import", "hd.xlsx", file).expectOk().body();
        assertThat(result.path("created").asInt()).isZero();
        assertThat(result.path("updated").asInt()).isZero();

        // Sửa lương HD-X1 trong file
        byte[] edited;
        try (XSSFWorkbook wb = new XSSFWorkbook(new ByteArrayInputStream(file)); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            var sheet = wb.getSheetAt(0);
            int salaryCol = -1;
            for (var cell : sheet.getRow(0)) if (cell.getStringCellValue().startsWith("Lương cơ bản") || cell.getStringCellValue().startsWith("Base Salary")) salaryCol = cell.getColumnIndex();
            for (int r = 1; r <= sheet.getLastRowNum(); r++) {
                var row = sheet.getRow(r);
                if ("HD-X1".equals(row.getCell(0).getStringCellValue())) row.getCell(salaryCol).setCellValue("9500000");
            }
            wb.write(out);
            edited = out.toByteArray();
        }
        diffs = api.upload(c.adminToken, "/api/v1/contracts/preview-import", "hd.xlsx", edited).expectOk().body();
        for (JsonNode d : diffs) {
            if (d.path("code").asText().equals("HD-X1")) {
                assertThat(d.path("action").asText()).isEqualTo("UPDATE");
                assertThat(d.path("changes").get(0).path("field").asText()).isEqualTo("baseSalary");
            } else {
                assertThat(d.path("action").asText()).isEqualTo("NO_CHANGE");
            }
        }
        result = api.upload(c.adminToken, "/api/v1/contracts/import", "hd.xlsx", edited).expectOk().body();
        assertThat(result.path("updated").asInt()).isEqualTo(1);
        assertThat(employeeRepository.findById(c.emp(6).id()).orElseThrow().getContractSalary()).isEqualByComparingTo("9500000");
    }

    @Test
    @DisplayName("Nhân viên đã có hợp đồng: không sửa lương HĐ trên hồ sơ được, gửi lại đúng giá trị thì vẫn lưu")
    void employeeForm_salaryManagedByContract() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(6);
        api.post(c.adminToken, "/api/v1/contracts",
            contract(e, "HD-E", "INDEFINITE", "ACTIVE", "2026-01-01", null, 11_000_000)).expectOk();
        JsonNode emp = api.get(c.adminToken, "/api/v1/employees/" + e.id()).expectOk().body();
        Map<String, Object> put = new LinkedHashMap<>();
        put.put("contractSalary", 15_000_000);
        if (!emp.path("positionId").isNull()) put.put("positionId", emp.path("positionId").asLong());
        if (!emp.path("salaryGradeId").isNull()) put.put("salaryGradeId", emp.path("salaryGradeId").asLong());
        var res = api.put(c.adminToken, "/api/v1/employees/" + e.id(), put);
        assertThat(res.status()).isEqualTo(409);
        assertThat(res.raw()).contains("error.contract.salary_managed_by_contract");
        put.put("contractSalary", 11_000_000);
        api.put(c.adminToken, "/api/v1/employees/" + e.id(), put).expectOk();
    }
}
