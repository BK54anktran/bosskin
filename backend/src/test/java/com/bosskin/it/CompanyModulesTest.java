package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Gói chức năng theo công ty (V24): system admin tắt gói → quyền thuộc gói bị gỡ, API 403, đăng nhập không còn quyền đó. */
class CompanyModulesTest extends IntegrationTest {

    private String sys() {
        return api.post(null, "/admin/auth/login", Map.of("email", "sysadmin@test.local", "password", "Test-SysAdmin-123"))
            .expectOk().text("accessToken");
    }

    private static List<String> perms(JsonNode login) {
        List<String> out = new ArrayList<>();
        login.path("user").path("permissions").forEach(p -> out.add(p.asText()));
        return out;
    }

    @Test
    @DisplayName("Mặc định bật hết; tắt Tính lương + Hợp đồng → API 403, đăng nhập mất quyền PAYROLL_* / CONTRACT_*, gói khác vẫn dùng được")
    void disableModules() {
        var c = fixture.standardCompany();
        String sys = sys();
        JsonNode company = api.get(sys, "/admin/companies/" + c.id).expectOk().body();
        assertThat(company.path("modules").size()).isEqualTo(7);
        assertThat(api.get(c.adminToken, "/api/v1/payrolls?month=10&year=2026").status()).isEqualTo(200);

        JsonNode updated = api.put(sys, "/admin/companies/" + c.id,
            Map.of("modules", List.of("ATTENDANCE", "SHIFT", "LEAVE", "DOCUMENT", "REPORT"))).expectOk().body();
        assertThat(updated.path("modules").toString()).doesNotContain("PAYROLL").doesNotContain("CONTRACT");

        assertThat(api.get(c.adminToken, "/api/v1/payrolls?month=10&year=2026").status()).isEqualTo(403);
        assertThat(api.get(c.adminToken, "/api/v1/contracts").status()).isEqualTo(403);
        assertThat(api.get(c.adminToken, "/api/v1/shifts").status()).isEqualTo(200);
        assertThat(api.get(c.adminToken, "/api/v1/employees").status()).isEqualTo(200);
        // Phiếu lương của tôi chỉ kiểm ATTENDANCE_SELF → chặn riêng theo gói
        var self = api.get(c.tokenOf(c.emp(6)), "/api/v1/payrolls/self");
        assertThat(self.status()).isEqualTo(403);
        assertThat(self.raw()).contains("error.company.module_disabled");

        JsonNode login = api.login(c.adminEmail, com.bosskin.support.Fixture.PASSWORD).expectOk().body();
        assertThat(perms(login)).noneMatch(p -> p.startsWith("PAYROLL_") || p.startsWith("CONTRACT_"));
        assertThat(perms(login)).contains("ATTENDANCE_VIEW", "SHIFT_VIEW", "EMPLOYEE_VIEW");
        assertThat(login.path("user").path("modules").toString()).isEqualTo("[\"ATTENDANCE\",\"SHIFT\",\"LEAVE\",\"DOCUMENT\",\"REPORT\"]");

        // Bật lại → dùng được như cũ (quyền vai trò không bị xoá, chỉ bị che)
        api.put(sys, "/admin/companies/" + c.id, Map.of("modules", List.of("ATTENDANCE", "SHIFT", "LEAVE", "PAYROLL", "CONTRACT", "DOCUMENT", "REPORT")))
            .expectOk();
        assertThat(api.get(c.adminToken, "/api/v1/payrolls?month=10&year=2026").status()).isEqualTo(200);
    }

    @Test
    @DisplayName("Chấm công cần Ca làm; mã gói lạ bị từ chối; system admin đăng nhập thay công ty cũng bị chặn gói đã tắt")
    void dependencyAndImpersonate() {
        var c = fixture.standardCompany();
        String sys = sys();
        assertThat(api.put(sys, "/admin/companies/" + c.id, Map.of("modules", List.of("ATTENDANCE", "LEAVE"))).raw())
            .contains("error.company.module_requires|ATTENDANCE|SHIFT");
        assertThat(api.put(sys, "/admin/companies/" + c.id, Map.of("modules", List.of("ABC"))).raw())
            .contains("error.company.module_invalid|ABC");

        api.put(sys, "/admin/companies/" + c.id, Map.of("modules", List.of("SHIFT", "ATTENDANCE"))).expectOk();
        String imp = api.post(sys, "/admin/companies/" + c.id + "/impersonate", null).expectOk().text("accessToken");
        assertThat(api.get(imp, "/api/v1/leaves/types").status()).isEqualTo(403);
        assertThat(api.get(imp, "/api/v1/shifts").status()).isEqualTo(200);
        // Công ty khác không bị ảnh hưởng
        var other = fixture.standardCompany();
        assertThat(api.get(other.adminToken, "/api/v1/payrolls?month=10&year=2026").status()).isEqualTo(200);
    }
}
