package com.bosskin.it;

import com.bosskin.entity.Company;
import com.bosskin.entity.Payroll;
import com.bosskin.entity.SalaryFormula;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.service.JobHistoryService;
import com.bosskin.service.PayrollService;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Bước K: lịch sử công tác (mốc theo ngày hiệu lực), quản lý trực tiếp, sơ đồ tổ chức
 * và chế độ duyệt "quản lý trực tiếp trước, rồi HR".
 */
class JobHistoryTest extends IntegrationTest {

    @Autowired JobHistoryService jobHistoryService;
    @Autowired PayrollService payrollService;
    @Autowired EmployeeRepository employeeRepository;
    @Autowired CompanyRepository companyRepository;

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 10, 9, 0);

    private Map<String, Object> history(String from, String type, long deptId) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("effectiveFrom", from);
        m.put("changeType", type);
        m.put("departmentId", deptId);
        return m;
    }

    private void setManager(Fixture.TestCompany c, Fixture.Emp e, Long managerId) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("managerId", managerId);
        api.put(c.adminToken, "/api/v1/employees/" + e.id(), body).expectOk();
    }

    private void managerMode(Fixture.TestCompany c) {
        Company company = companyRepository.findById(c.id).orElseThrow();
        company.setApprovalMode(Company.ApprovalMode.MANAGER_THEN_HR);
        companyRepository.save(company);
    }

    private Map<String, Object> dayLeave(long typeId, String date) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("leaveTypeId", typeId);
        m.put("mode", "DAY_RANGE");
        m.put("fromDate", date);
        m.put("toDate", date);
        m.put("reason", "Việc riêng");
        return m;
    }

    @Test
    @DisplayName("Chuyển phòng ngày tương lai không đổi dữ liệu hôm nay; tới ngày thì tự áp dụng")
    void futureTransfer_appliesOnItsDate() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(6);
        long kt = c.departments.get("KT");

        api.post(c.adminToken, "/api/v1/employees/" + e.id() + "/job-histories",
            history("2026-11-01", "TRANSFER", kt)).expectOk();

        JsonNode now = api.get(c.adminToken, "/api/v1/employees/" + e.id()).expectOk().body();
        assertThat(now.path("departmentId").asLong()).isEqualTo(e.departmentId());
        JsonNode rows = api.get(c.adminToken, "/api/v1/employees/" + e.id() + "/job-histories").expectOk().body();
        assertThat(rows.get(0).path("effectiveFrom").asText()).isEqualTo("2026-11-01");
        assertThat(rows.get(0).path("applied").asBoolean()).isFalse();
        assertThat(rows.get(0).path("current").asBoolean()).isFalse();

        clock.set(LocalDateTime.of(2026, 11, 1, 0, 10));
        assertThat(jobHistoryService.applyDue()).isGreaterThanOrEqualTo(1);
        JsonNode after = api.get(c.adminToken, "/api/v1/employees/" + e.id()).expectOk().body();
        assertThat(after.path("departmentId").asLong()).isEqualTo(kt);
        rows = api.get(c.adminToken, "/api/v1/employees/" + e.id() + "/job-histories").expectOk().body();
        assertThat(rows.get(0).path("current").asBoolean()).isTrue();
    }

    @Test
    @DisplayName("Sửa phòng ban trên hồ sơ ghi một mốc chuyển phòng; mốc đã qua không xoá được, mốc tương lai xoá được")
    void formEdit_recordsHistory_andDeleteRules() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(6);
        api.put(c.adminToken, "/api/v1/employees/" + e.id(), Map.of("departmentId", c.departments.get("KT"))).expectOk();
        JsonNode rows = api.get(c.adminToken, "/api/v1/employees/" + e.id() + "/job-histories").expectOk().body();
        assertThat(rows.get(0).path("changeType").asText()).isEqualTo("TRANSFER");
        assertThat(rows.get(0).path("effectiveFrom").asText()).isEqualTo("2026-10-10");
        assertThat(api.delete(c.adminToken, "/api/v1/employees/job-histories/" + rows.get(0).path("id").asLong()).status())
            .isEqualTo(409);

        long future = api.post(c.adminToken, "/api/v1/employees/" + e.id() + "/job-histories",
            history("2026-12-01", "TRANSFER", c.departments.get("SX"))).expectOk().id();
        assertThat(api.delete(c.adminToken, "/api/v1/employees/job-histories/" + future).ok()).isTrue();

        assertThat(api.post(c.adminToken, "/api/v1/employees/" + e.id() + "/job-histories",
            history("2024-01-01", "TRANSFER", c.departments.get("SX"))).status()).isEqualTo(400);
    }

    @Test
    @DisplayName("Không tạo được vòng quản lý, không tự quản lý chính mình")
    void managerCycle_isRejected() {
        var c = fixture.standardCompany();
        var a = c.emp(5);
        var b = c.emp(6);
        var d = c.emp(7);
        setManager(c, b, a.id());
        setManager(c, d, b.id());

        var cycle = api.put(c.adminToken, "/api/v1/employees/" + a.id(), Map.of("managerId", d.id()));
        assertThat(cycle.status()).isEqualTo(400);
        assertThat(cycle.raw()).contains("error.employee.manager_cycle");
        var self = api.put(c.adminToken, "/api/v1/employees/" + a.id(), Map.of("managerId", a.id()));
        assertThat(self.raw()).contains("error.employee.manager_self");

        // Sửa field khác không xoá quản lý
        api.put(c.adminToken, "/api/v1/employees/" + d.id(), Map.of("phone", "0900000000")).expectOk();
        assertThat(api.get(c.adminToken, "/api/v1/employees/" + d.id()).expectOk().body().path("managerId").asLong())
            .isEqualTo(b.id());

        JsonNode chart = api.get(c.adminToken, "/api/v1/org-chart").expectOk().body();
        assertThat(chart.size()).isEqualTo(10);
        boolean found = false;
        for (JsonNode n : chart) {
            if (n.path("id").asLong() == d.id()) {
                assertThat(n.path("managerId").asLong()).isEqualTo(b.id());
                found = true;
            }
        }
        assertThat(found).isTrue();
    }

    @Test
    @DisplayName("Bảng lương dùng phòng ban và bậc lương hiệu lực ở cuối kỳ, lưu phòng ban lên phiếu")
    void payroll_usesEffectiveDepartmentAndGrade() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        c.createSalaryGrade("NGAY500", "DAILY", 500_000);
        var e = c.emp(6);
        Map<String, Object> body = history("2026-12-01", "PROMOTION", c.departments.get("KT"));
        body.put("salaryGradeId", c.salaryGrades.get("NGAY500"));
        api.post(c.adminToken, "/api/v1/employees/" + e.id() + "/job-histories", body).expectOk();

        SalaryFormula f = SalaryFormula.builder().name("Test").expressionGross("STANDARD_WORK_DAYS").expressionNet("GROSS").build();
        Payroll nov = payrollService.generatePayrollWithFormula(e.id(), 2026, 11, f);
        assertThat(nov.getSalaryGradeCode()).isEqualTo("NGAY300");
        assertThat(nov.getDepartmentId()).isEqualTo(e.departmentId());

        Payroll dec = payrollService.generatePayrollWithFormula(e.id(), 2026, 12, f);
        assertThat(dec.getSalaryGradeCode()).isEqualTo("NGAY500");
        assertThat(dec.getDepartmentId()).isEqualTo(c.departments.get("KT"));
        assertThat(dec.getDepartmentName()).isEqualTo("Kế toán");
    }

    @Test
    @DisplayName("Mặc định duyệt theo quyền như cũ; bật chế độ quản lý thì HR phải chờ quản lý trực tiếp duyệt")
    void managerThenHr_flow() {
        var c = fixture.standardCompany();
        var staff = c.emp(7);
        var lead = c.emp(5);
        String hr = c.tokenOf(c.emp(1));
        c.grantLeaveDays(staff, "PN", 5);
        setManager(c, staff, lead.id());

        assertThat(api.get(c.adminToken, "/api/v1/company-settings").expectOk().body()
            .path("approval").path("mode").asText()).isEqualTo("PERMISSION");
        long first = api.post(c.tokenOf(staff), "/api/v1/leaves/requests",
            dayLeave(c.leaveTypes.get("PN"), "2026-11-10")).expectOk().id();
        api.put(hr, "/api/v1/leaves/requests/" + first + "/approve", Map.of()).expectOk();

        managerMode(c);
        long id = api.post(c.tokenOf(staff), "/api/v1/leaves/requests",
            dayLeave(c.leaveTypes.get("PN"), "2026-11-11")).expectOk().id();
        var blocked = api.put(hr, "/api/v1/leaves/requests/" + id + "/approve", Map.of());
        assertThat(blocked.status()).isEqualTo(409);
        assertThat(blocked.raw()).contains("error.approval.manager_pending");

        // Người khác (không phải quản lý trực tiếp) không duyệt bước quản lý được
        assertThat(api.post(c.tokenOf(c.emp(8)), "/api/v1/team-approvals/LEAVE/" + id + "/approve", Map.of()).status())
            .isEqualTo(403);

        JsonNode team = api.get(c.tokenOf(lead), "/api/v1/team-approvals").expectOk().body();
        assertThat(team.path("enabled").asBoolean()).isTrue();
        assertThat(team.path("leaves").size()).isEqualTo(1);
        assertThat(team.path("leaves").get(0).path("awaitingManagerName").isNull()).isFalse();

        api.post(c.tokenOf(lead), "/api/v1/team-approvals/LEAVE/" + id + "/approve", Map.of("note", "OK")).expectOk();
        assertThat(api.get(c.tokenOf(lead), "/api/v1/team-approvals/count").expectOk().body().path("count").asLong())
            .isZero();
        JsonNode approved = api.put(hr, "/api/v1/leaves/requests/" + id + "/approve", Map.of()).expectOk().body();
        assertThat(approved.path("status").asText()).isEqualTo("APPROVED");
        assertThat(approved.path("managerApprovedAt").isNull()).isFalse();
    }

    @Test
    @DisplayName("Quản lý trực tiếp từ chối đơn nghỉ → đơn bị từ chối và hoàn phép")
    void managerReject_refundsLeave() {
        var c = fixture.standardCompany();
        var staff = c.emp(7);
        var lead = c.emp(5);
        c.grantLeaveDays(staff, "PN", 1);
        setManager(c, staff, lead.id());
        managerMode(c);

        long id = api.post(c.tokenOf(staff), "/api/v1/leaves/requests",
            dayLeave(c.leaveTypes.get("PN"), "2026-11-10")).expectOk().id();
        JsonNode rejected = api.post(c.tokenOf(lead), "/api/v1/team-approvals/LEAVE/" + id + "/reject",
            Map.of("note", "Thiếu người")).expectOk().body();
        assertThat(rejected.path("status").asText()).isEqualTo("REJECTED");
        // Phép đã hoàn: xin lại 1 ngày được
        api.post(c.tokenOf(staff), "/api/v1/leaves/requests", dayLeave(c.leaveTypes.get("PN"), "2026-11-12")).expectOk();
    }

    @Test
    @DisplayName("HR cũng là quản lý trực tiếp thì duyệt một lần là xong cả hai bước")
    void hrIsDirectManager_approvesBothSteps() {
        var c = fixture.standardCompany();
        var staff = c.emp(7);
        var hrEmp = c.emp(1);
        c.grantLeaveDays(staff, "PN", 2);
        setManager(c, staff, hrEmp.id());
        managerMode(c);

        long id = api.post(c.tokenOf(staff), "/api/v1/leaves/requests",
            dayLeave(c.leaveTypes.get("PN"), "2026-11-10")).expectOk().id();
        JsonNode r = api.put(c.tokenOf(hrEmp), "/api/v1/leaves/requests/" + id + "/approve", Map.of()).expectOk().body();
        assertThat(r.path("status").asText()).isEqualTo("APPROVED");
        assertThat(r.path("managerApprovedAt").isNull()).isFalse();
    }
}
