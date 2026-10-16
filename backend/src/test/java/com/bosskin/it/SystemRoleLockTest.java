package com.bosskin.it;

import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** V30: vai trò Admin sinh sẵn và tài khoản admin đầu tiên bị khoá với người dùng công ty. */
class SystemRoleLockTest extends IntegrationTest {

    private long adminRoleId(Fixture.TestCompany c) {
        for (JsonNode r : api.get(c.adminToken, "/api/v1/roles").expectOk().body()) {
            if (r.path("system").asBoolean()) return r.path("id").asLong();
        }
        throw new AssertionError("không thấy vai trò hệ thống (Admin)");
    }

    @Test
    @DisplayName("Admin mặc định không sửa quyền / đổi tên / xoá được, nhưng vẫn gán cho người khác được")
    void systemAdminRoleIsLocked() {
        var c = fixture.standardCompany();
        long adminRoleId = adminRoleId(c);

        assertThat(api.put(c.adminToken, "/api/v1/roles/" + adminRoleId + "/permissions",
            Map.of("permissions", List.of("EMPLOYEE_VIEW"))).status()).isEqualTo(403);
        assertThat(api.put(c.adminToken, "/api/v1/roles/" + adminRoleId,
            Map.of("name", "Quản trị khác", "permissions", List.of("EMPLOYEE_VIEW"))).status()).isEqualTo(403);
        assertThat(api.delete(c.adminToken, "/api/v1/roles/" + adminRoleId).status()).isEqualTo(403);

        api.put(c.adminToken, "/api/v1/users/" + c.emp(3).userId() + "/roles",
            Map.of("roleIds", List.of(adminRoleId))).expectOk();
    }

    @Test
    @DisplayName("Admin thứ hai không tác động được lên admin đầu tiên (vai trò, quyền, phạm vi, khoá, đặt lại mật khẩu, gỡ 2FA); admin đầu vẫn quản được admin thứ hai")
    void firstAdminAccountIsLocked() {
        var c = fixture.standardCompany();
        long adminRoleId = adminRoleId(c);
        long firstAdminId = api.login(c.adminEmail, Fixture.PASSWORD).body().path("user").path("id").asLong();
        var second = c.emp(3);
        api.put(c.adminToken, "/api/v1/users/" + second.userId() + "/roles", Map.of("roleIds", List.of(adminRoleId))).expectOk();
        String token = c.tokenOf(second);

        var roles = api.put(token, "/api/v1/users/" + firstAdminId + "/roles", Map.of("roleIds", List.of(c.roles.get("Nhân viên"))));
        assertThat(roles.status()).isEqualTo(403);
        assertThat(roles.raw()).contains("error.user.first_admin_locked");
        assertThat(api.put(token, "/api/v1/users/" + firstAdminId + "/permissions", Map.of("permissionCodes", List.of())).status()).isEqualTo(403);
        assertThat(api.patch(token, "/api/v1/users/" + firstAdminId + "/enabled", Map.of("enabled", false)).status()).isEqualTo(403);
        assertThat(api.put(token, "/api/v1/users/" + firstAdminId + "/dept-scopes", Map.of()).status()).isEqualTo(403);
        assertThat(api.post(token, "/api/v1/users/" + firstAdminId + "/reset-password", Map.of()).status()).isEqualTo(403);
        assertThat(api.delete(token, "/api/v1/users/" + firstAdminId + "/2fa").status()).isEqualTo(403);

        api.put(c.adminToken, "/api/v1/users/" + second.userId() + "/roles",
            Map.of("roleIds", List.of(c.roles.get("Nhân viên")))).expectOk();
    }
}
