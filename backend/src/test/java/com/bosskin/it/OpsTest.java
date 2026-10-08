package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

/** Bước 2 — sẵn sàng chạy thật: nhật ký thao tác, health check, mã request. */
class OpsTest extends IntegrationTest {

    @Autowired MockMvc mvc;

    private com.fasterxml.jackson.databind.JsonNode logs(String token, String query) {
        return api.get(token, "/api/v1/audit-logs" + query).expectOk().body().path("content");
    }

    @Test
    @DisplayName("Nhật ký: duyệt lương, đổi quyền vai trò, impersonate được ghi; chỉ người có AUDIT_VIEW xem được")
    void auditLog_recordsSensitiveActions() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        String accountant = c.tokenOf(c.emp(2));

        long formula = api.post(c.adminToken, "/api/v1/salary-formulas", Map.of(
            "salaryGradeId", c.salaryGrades.get("NGAY300"), "name", "Cố định",
            "effectiveDate", "2026-01-01", "expressionGross", "10000000", "expressionNet", "GROSS")).expectOk().id();
        long payrollId = api.post(accountant, "/api/v1/payrolls/generate", Map.of(
            "employeeId", e.id(), "year", 2026, "month", 11, "formulaId", formula)).expectOk().id();
        api.post(c.adminToken, "/api/v1/payrolls/" + payrollId + "/approve", null).expectOk();

        var approve = logs(c.adminToken, "?action=PAYROLL_APPROVE");
        assertThat(approve).hasSize(1);
        assertThat(approve.get(0).path("actorEmail").asText()).isEqualTo(c.adminEmail);
        assertThat(approve.get(0).path("entityId").asText()).isEqualTo(String.valueOf(payrollId));
        assertThat(approve.get(0).path("requestId").asText()).isNotBlank();
        assertThat(logs(c.adminToken, "?action=PAYROLL_GENERATE").get(0).path("actorEmail").asText())
            .isEqualTo(c.emp(2).email());

        long roleId = c.roles.get("Kế toán");
        api.put(c.adminToken, "/api/v1/roles/" + roleId + "/permissions",
            Map.of("permissions", List.of("PAYROLL_VIEW"))).expectOk();
        var roleLog = logs(c.adminToken, "?action=ROLE_PERMISSIONS&entityType=ROLE&entityId=" + roleId);
        assertThat(roleLog).hasSize(1);
        assertThat(roleLog.get(0).path("detail").asText()).contains("before").contains("PAYROLL_APPROVE");

        String sys = api.post(null, "/admin/auth/login",
            Map.of("email", "sysadmin@test.local", "password", "Test-SysAdmin-123")).expectOk().text("accessToken");
        api.post(sys, "/admin/companies/" + c.id + "/impersonate", null).expectOk();
        assertThat(logs(c.adminToken, "?action=IMPERSONATE_START")).hasSize(1);
        assertThat(api.get(sys, "/admin/audit-logs?companyId=" + c.id + "&action=IMPERSONATE_START")
            .expectOk().body().path("content")).hasSize(1);

        assertThat(api.get(c.tokenOf(e), "/api/v1/audit-logs").status()).as("nhân viên thường").isEqualTo(403);

        // Công ty khác không thấy nhật ký của công ty này
        var other = fixture.standardCompany();
        assertThat(logs(other.adminToken, "?action=PAYROLL_APPROVE")).isEmpty();
    }

    @Test
    @DisplayName("Health check mở không cần đăng nhập; endpoint actuator khác bị chặn")
    void actuatorHealth_isPublic_othersClosed() throws Exception {
        var health = mvc.perform(get("/actuator/health")).andReturn().getResponse();
        assertThat(health.getStatus()).isEqualTo(200);
        assertThat(health.getContentAsString()).contains("\"UP\"").doesNotContain("db");
        assertThat(mvc.perform(get("/actuator/env")).andReturn().getResponse().getStatus()).isIn(401, 403, 404);
    }

    @Test
    @DisplayName("Mỗi request có mã X-Request-ID, lỗi trả kèm requestId")
    void requestId_inHeaderAndErrorBody() throws Exception {
        var ok = mvc.perform(get("/actuator/health").header("X-Request-ID", "test-rid-1")).andReturn().getResponse();
        assertThat(ok.getHeader("X-Request-ID")).isEqualTo("test-rid-1");

        var c = fixture.standardCompany();
        var err = api.get(c.adminToken, "/api/v1/payrolls/by-employee/999999999");
        if (!err.ok()) {
            assertThat(err.body().path("requestId").asText()).isNotBlank();
        }
        var bad = api.post(c.adminToken, "/api/v1/payrolls/999999999/approve", null);
        assertThat(bad.status()).isEqualTo(404);
        assertThat(bad.body().path("requestId").asText()).isNotBlank();
    }
}
