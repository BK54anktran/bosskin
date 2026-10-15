package com.bosskin.it;

import com.bosskin.core.CompanyFeatures;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Tính năng theo công ty (V26): tắt đúng tính năng → API của nó 403, tính năng khác vẫn dùng được; đăng nhập trả features + modules. */
class CompanyFeaturesTest extends IntegrationTest {

    private String sys() {
        return api.post(null, "/admin/auth/login", Map.of("email", "sysadmin@test.local", "password", "Test-SysAdmin-123"))
            .expectOk().text("accessToken");
    }

    private static List<String> allExcept(String... off) {
        List<String> skip = List.of(off);
        return CompanyFeatures.ALL.stream().filter(c -> !skip.contains(c)).toList();
    }

    @Test
    @DisplayName("Tắt từng tính năng nhỏ: chỉ API của tính năng đó 403, phần còn lại của gói vẫn chạy; bật lại → chạy")
    void disableSingleFeatures() {
        var c = fixture.standardCompany();
        String sys = sys();
        JsonNode company = api.get(sys, "/admin/companies/" + c.id).expectOk().body();
        assertThat(company.path("features").size()).isEqualTo(CompanyFeatures.ALL.size());

        api.put(sys, "/admin/companies/" + c.id,
            Map.of("features", allExcept("SHIFT_ROTATION", "LEAVE_ACCRUAL", "PAY_FORMULA", "HR_ORGCHART", "HR_MANAGER_APPROVAL", "RPT_PAYROLL", "DATA_EXCEL")))
            .expectOk();

        var rotation = api.get(c.adminToken, "/api/v1/shift-rotations");
        assertThat(rotation.status()).isEqualTo(403);
        assertThat(rotation.raw()).contains("error.company.feature_disabled");
        assertThat(api.get(c.adminToken, "/api/v1/leaves/accrual-rules").status()).isEqualTo(403);
        assertThat(api.get(c.adminToken, "/api/v1/salary-formulas").status()).isEqualTo(403);
        assertThat(api.get(c.adminToken, "/api/v1/org-chart").status()).isEqualTo(403);
        assertThat(api.get(c.adminToken, "/api/v1/reports/payroll-summary?year=2026&month=10").status()).isEqualTo(403);
        assertThat(api.get(c.adminToken, "/api/v1/excel/meta").status()).isEqualTo(403);

        // cùng gói nhưng tính năng khác vẫn chạy
        assertThat(api.get(c.adminToken, "/api/v1/shifts").status()).isEqualTo(200);
        assertThat(api.get(c.adminToken, "/api/v1/leaves/types").status()).isEqualTo(200);
        assertThat(api.get(c.adminToken, "/api/v1/payrolls?month=10&year=2026").status()).isEqualTo(200);
        assertThat(api.get(c.adminToken, "/api/v1/employees").status()).isEqualTo(200);
        assertThat(api.get(c.adminToken, "/api/v1/work-calendars/view?from=2026-11-01&to=2026-11-30").status()).isEqualTo(200);

        // đăng nhập trả features + modules (gói cũ vẫn bật vì tính năng gốc còn bật)
        JsonNode login = api.login(c.adminEmail, com.bosskin.support.Fixture.PASSWORD).expectOk().body();
        assertThat(login.path("user").path("features").toString()).doesNotContain("SHIFT_ROTATION").contains("SHIFT_BASIC");
        assertThat(login.path("user").path("modules").size()).isEqualTo(7);

        api.put(sys, "/admin/companies/" + c.id, Map.of("features", CompanyFeatures.ALL)).expectOk();
        assertThat(api.get(c.adminToken, "/api/v1/shift-rotations").status()).isEqualTo(200);
    }

    @Test
    @DisplayName("Tắt tính năng gốc kéo theo con: tắt PAY_BASIC mà còn PAY_FORMULA → từ chối; tắt đủ nhánh → lương 403, quyền PAYROLL_* mất")
    void dependenciesAndPermissions() {
        var c = fixture.standardCompany();
        String sys = sys();
        var bad = api.put(sys, "/admin/companies/" + c.id, Map.of("features", allExcept("PAY_BASIC")));
        assertThat(bad.status()).isEqualTo(400);
        assertThat(bad.raw()).contains("error.company.feature_requires|PAY_FORMULA|PAY_BASIC");
        assertThat(api.put(sys, "/admin/companies/" + c.id, Map.of("features", List.of("XYZ"))).raw())
            .contains("error.company.feature_invalid|XYZ");

        api.put(sys, "/admin/companies/" + c.id, Map.of("features", allExcept("PAY_BASIC", "PAY_FORMULA", "PAY_TAX_INS",
            "PAY_DEPENDENT", "PAY_EMPLOYER_COST", "RPT_PAYROLL", "RPT_INSURANCE"))).expectOk();
        assertThat(api.get(c.adminToken, "/api/v1/payrolls?month=10&year=2026").status()).isEqualTo(403);
        assertThat(api.get(c.tokenOf(c.emp(6)), "/api/v1/payrolls/self").status()).isEqualTo(403);
        JsonNode login = api.login(c.adminEmail, com.bosskin.support.Fixture.PASSWORD).expectOk().body();
        List<String> perms = new java.util.ArrayList<>();
        login.path("user").path("permissions").forEach(p -> perms.add(p.asText()));
        assertThat(perms).noneMatch(p -> p.startsWith("PAYROLL_")).contains("ATTENDANCE_VIEW", "EMPLOYEE_VIEW");
        assertThat(login.path("user").path("modules").toString()).doesNotContain("PAYROLL");
    }

    @Test
    @DisplayName("Tự chấm công cần Ca làm cơ bản hoặc chấm khi không có ca; tắt ATT_SELF thì /self/* 403 nhưng bảng công vẫn dùng được")
    void selfCheckInRules() {
        var c = fixture.standardCompany();
        String sys = sys();
        var noShiftNoFree = api.put(sys, "/admin/companies/" + c.id, Map.of("features", allExcept(
            "SHIFT_BASIC", "SHIFT_ADVANCED", "SHIFT_ROTATION", "SHIFT_SWAP", "SHIFT_REGISTRATION", "SHIFT_REMINDER",
            "ATT_NOSHIFT", "HR_MANAGER_APPROVAL")));
        assertThat(noShiftNoFree.raw()).contains("error.company.feature_requires_any|ATT_SELF|SHIFT_BASIC|ATT_NOSHIFT");

        api.put(sys, "/admin/companies/" + c.id, Map.of("features", allExcept("ATT_SELF", "ATT_GEOFENCE", "ATT_DEVICE", "ATT_NOSHIFT")))
            .expectOk();
        var self = api.get(c.tokenOf(c.emp(6)), "/api/v1/attendances/self/today");
        assertThat(self.status()).isEqualTo(403);
        assertThat(self.raw()).contains("error.company.feature_disabled");
        assertThat(api.get(c.adminToken, "/api/v1/attendances/timesheet?employeeId=" + c.emp(6).id() + "&year=2026&month=11").status())
            .isEqualTo(200);
    }

    @Test
    @DisplayName("Tương thích V24: gửi modules (không gửi features) vẫn đổi được; công ty khác không bị ảnh hưởng")
    void legacyModulesInput() {
        var c = fixture.standardCompany();
        var other = fixture.standardCompany();
        String sys = sys();
        JsonNode updated = api.put(sys, "/admin/companies/" + c.id,
            Map.of("modules", List.of("ATTENDANCE", "SHIFT", "LEAVE", "DOCUMENT", "REPORT"))).expectOk().body();
        assertThat(updated.path("features").toString()).doesNotContain("PAY_BASIC").doesNotContain("HR_CONTRACT\"")
            .contains("ATT_SELF", "HR_ORGCHART");
        assertThat(api.get(c.adminToken, "/api/v1/contracts").status()).isEqualTo(403);
        assertThat(api.get(other.adminToken, "/api/v1/contracts").status()).isEqualTo(200);
    }
}
