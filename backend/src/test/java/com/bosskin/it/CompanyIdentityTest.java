package com.bosskin.it;

import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * V22 — định danh theo công ty: mã công ty là tiền tố mã NV (không trùng / không là tiền tố của nhau, không đổi khi sửa),
 * đuôi email công ty bắt buộc cho mọi tài khoản và không trùng giữa các công ty.
 */
class CompanyIdentityTest extends IntegrationTest {

    private String sys() {
        return api.post(null, "/admin/auth/login", Map.of("email", "sysadmin@test.local", "password", "Test-SysAdmin-123"))
            .expectOk().text("accessToken");
    }

    private Map<String, Object> company(String code, String domain, String adminEmail) {
        Map<String, Object> b = new LinkedHashMap<>();
        b.put("name", "Công ty " + code);
        b.put("code", code);
        if (domain != null) b.put("domain", domain);
        b.put("adminEmail", adminEmail);
        b.put("adminPassword", Fixture.PASSWORD);
        return b;
    }

    private Map<String, Object> employee(Fixture.TestCompany c, String email) {
        Map<String, Object> b = new LinkedHashMap<>();
        b.put("fullName", "Nhân viên mới");
        b.put("email", email);
        b.put("password", Fixture.PASSWORD);
        b.put("gender", "MALE");
        b.put("joinDate", "2026-01-01");
        b.put("departmentId", c.departments.get("KT"));
        return b;
    }

    @Test
    @DisplayName("Tạo công ty: bắt buộc đuôi email hợp lệ, không trùng; email admin đúng đuôi; mã không trùng / không là tiền tố mã khác")
    void createCompany_rules() {
        String sys = sys();
        var c = fixture.newCompany();
        String code = "Q" + Long.toString(System.nanoTime() % 1_000_000_000L, 36).toUpperCase();
        String domain = code.toLowerCase() + ".vn";

        assertThat(api.post(sys, "/admin/companies", company(code, null, "a@" + domain)).raw())
            .contains("error.company.domain_required");
        assertThat(api.post(sys, "/admin/companies", company(code, "khong hop le", "a@" + domain)).raw())
            .contains("error.company.domain_invalid");
        assertThat(api.post(sys, "/admin/companies", company(code, domain, "a@khac.vn")).raw())
            .contains("error.email.domain_mismatch|" + domain);
        assertThat(api.post(sys, "/admin/companies", company(code, c.code.toLowerCase() + ".test", "a@" + c.code.toLowerCase() + ".test")).raw())
            .contains("error.company.domain_duplicate");
        assertThat(api.post(sys, "/admin/companies", company("1" + code, domain, "a@" + domain)).raw())
            .contains("error.company.code_invalid");
        assertThat(api.post(sys, "/admin/companies", company(c.code + "X", domain, "a@" + domain)).raw())
            .contains("error.company.code_prefix_conflict|" + c.code);
        assertThat(api.post(sys, "/admin/companies", company(c.code.toLowerCase(), domain, "a@" + domain)).raw())
            .contains("error.company.code_duplicate");

        // "@Q…VN " → chuẩn hoá chữ thường, bỏ @; mã viết thường → chữ hoa
        var created = api.post(sys, "/admin/companies", company(code.toLowerCase(), " @" + domain.toUpperCase() + " ", "Admin@" + domain))
            .expectOk().body();
        assertThat(created.path("code").asText()).isEqualTo(code);
        assertThat(created.path("domain").asText()).isEqualTo(domain);
    }

    @Test
    @DisplayName("Sửa công ty: không đổi được mã; đổi đuôi email bị chặn khi trùng công ty khác hoặc còn tài khoản đuôi cũ")
    void updateCompany_codeLocked_domainGuarded() {
        String sys = sys();
        var c = fixture.newCompany();
        var other = fixture.newCompany();

        assertThat(api.put(sys, "/admin/companies/" + c.id, Map.of("code", other.code)).raw())
            .contains("error.company.code_immutable");
        assertThat(api.put(sys, "/admin/companies/" + c.id, Map.of("domain", other.code.toLowerCase() + ".test")).raw())
            .contains("error.company.domain_duplicate");
        assertThat(api.put(sys, "/admin/companies/" + c.id, Map.of("domain", "moi-" + c.code.toLowerCase() + ".vn")).raw())
            .contains("error.company.domain_accounts_mismatch");

        // Gửi lại đúng mã cũ + đổi tên → được
        var updated = api.put(sys, "/admin/companies/" + c.id, Map.of("code", c.code, "name", "Tên mới")).expectOk().body();
        assertThat(updated.path("name").asText()).isEqualTo("Tên mới");
        assertThat(updated.path("code").asText()).isEqualTo(c.code);
    }

    @Test
    @DisplayName("Nhân viên / tài khoản mới phải theo đuôi email công ty; mã NV cấp theo mã công ty")
    void employeeAndUser_followCompanyIdentity() {
        var c = fixture.standardCompany();
        assertThat(c.emp(0).code()).startsWith(c.code).matches(c.code + "\\d{5}");

        var bad = api.post(c.adminToken, "/api/v1/employees", employee(c, "nv@khac.test"));
        assertThat(bad.status()).isEqualTo(400);
        assertThat(bad.raw()).contains("error.email.domain_mismatch|" + c.code.toLowerCase() + ".test");

        var ok = api.post(c.adminToken, "/api/v1/employees", employee(c, c.email("moi"))).expectOk();
        assertThat(ok.text("employeeCode")).startsWith(c.code);

        var user = api.post(c.adminToken, "/api/v1/users",
            Map.of("email", "tk@khac.test", "password", Fixture.PASSWORD, "roleIds", List.of()));
        assertThat(user.raw()).contains("error.email.domain_mismatch");
        api.post(c.adminToken, "/api/v1/users",
            Map.of("email", c.email("tk"), "password", Fixture.PASSWORD, "roleIds", List.of())).expectOk();
    }
}
