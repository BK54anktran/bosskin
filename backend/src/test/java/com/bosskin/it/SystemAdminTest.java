package com.bosskin.it;

import com.bosskin.audit.AuditLogRepository;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/** System admin quản lý tài khoản system admin khác (mật khẩu sinh tự động). */
class SystemAdminTest extends IntegrationTest {

    @Autowired AuditLogRepository auditLogRepository;

    private String sys() {
        return api.post(null, "/admin/auth/login", Map.of("email", "sysadmin@test.local", "password", "Test-SysAdmin-123"))
            .expectOk().text("accessToken");
    }

    @Test
    @DisplayName("Tạo system admin mới: mật khẩu sinh tự động trả một lần, đăng nhập được; trùng email bị từ chối")
    void create_and_login() {
        String sys = sys();
        String email = "ops-" + UUID.randomUUID().toString().substring(0, 8) + "@test.local";
        var created = api.post(sys, "/admin/system-admins", Map.of("email", email.toUpperCase(), "name", "Vận hành")).expectOk().body();
        String pw = created.path("password").asText();
        assertThat(pw).hasSize(16).matches(".*[a-z].*").matches(".*[A-Z].*").matches(".*[0-9].*");
        assertThat(created.path("email").asText()).isEqualTo(email);
        assertThat(api.post(null, "/admin/auth/login", Map.of("email", email, "password", pw)).expectOk().text("accessToken")).isNotBlank();
        assertThat(api.get(sys, "/admin/system-admins").expectOk().body().toString()).doesNotContain("\"password\"");
        assertThat(api.post(sys, "/admin/system-admins", Map.of("email", email)).status()).isEqualTo(409);
        assertThat(api.post(sys, "/admin/system-admins", Map.of("email", "khong-hop-le")).raw()).contains("error.sysadmin.email_invalid");
        assertThat(auditLogRepository.findAll()).anyMatch(a -> "SYSADMIN_CREATE".equals(a.getAction()) && email.equals(a.getSummary()));
    }

    @Test
    @DisplayName("Khoá / đặt lại mật khẩu tài khoản khác; không tự khoá mình; người dùng công ty không vào được")
    void disable_reset() {
        String sys = sys();
        String email = "ops-" + UUID.randomUUID().toString().substring(0, 8) + "@test.local";
        var created = api.post(sys, "/admin/system-admins", Map.of("email", email)).expectOk().body();
        long id = created.path("id").asLong();

        long myId = 0;
        for (var a : api.get(sys, "/admin/system-admins").expectOk().body()) if (a.path("self").asBoolean()) myId = a.path("id").asLong();
        assertThat(api.patch(sys, "/admin/system-admins/" + myId + "/enabled", Map.of("enabled", false)).raw())
            .contains("error.sysadmin.cannot_change_self");

        api.patch(sys, "/admin/system-admins/" + id + "/enabled", Map.of("enabled", false)).expectOk();
        assertThat(api.post(null, "/admin/auth/login", Map.of("email", email, "password", created.path("password").asText())).ok()).isFalse();
        api.patch(sys, "/admin/system-admins/" + id + "/enabled", Map.of("enabled", true)).expectOk();

        String pw2 = api.post(sys, "/admin/system-admins/" + id + "/reset-password", null).expectOk().text("password");
        assertThat(api.post(null, "/admin/auth/login", Map.of("email", email, "password", pw2)).ok()).isTrue();
        api.post(sys, "/admin/system-admins/" + id + "/reset-2fa", null).expectOk();

        var c = fixture.standardCompany();
        assertThat(api.get(c.adminToken, "/admin/system-admins").status()).isIn(401, 403);
    }
}
