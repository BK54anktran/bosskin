package com.bosskin.it;

import com.bosskin.core.Totp;
import com.bosskin.repository.SystemAdminRepository;
import com.bosskin.service.AuthService;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Bước C — xác thực 2 lớp (TOTP). */
class TwoFactorTest extends IntegrationTest {

    @Autowired AuthService authService;
    @Autowired SystemAdminRepository systemAdminRepository;

    private static final String SYS_EMAIL = "sysadmin@test.local";
    private static final String SYS_PW = "Test-SysAdmin-123";

    @AfterEach
    void restoreSysadmin() {
        ReflectionTestUtils.setField(authService, "requireSysadmin2fa", false);
        systemAdminRepository.findByEmail(SYS_EMAIL).ifPresent(a -> {
            a.setTotpEnabled(false);
            a.setTotpSecret(null);
            a.setTotpRecoveryCodes(null);
            systemAdminRepository.save(a);
        });
    }

    private String code(String secret) {
        return Totp.codeAt(secret, clock.instant());
    }

    @Test
    @DisplayName("Nhân viên tự bật 2FA: đăng nhập cần mã, sai mã bị từ chối, mã dự phòng dùng được đúng một lần")
    void userEnables2fa_loginNeedsCode() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        String token = c.tokenOf(e);

        String secret = api.post(token, "/api/v1/profile/2fa/setup", null).expectOk().text("secret");
        assertThat(api.post(token, "/api/v1/profile/2fa/enable", Map.of("code", "000000")).status()).isEqualTo(400);
        var enabled = api.post(token, "/api/v1/profile/2fa/enable", Map.of("code", code(secret))).expectOk().body();
        var recovery = enabled.path("recoveryCodes");
        assertThat(recovery).hasSize(8);

        var login = api.login(e.email(), Fixture.PASSWORD).expectOk().body();
        assertThat(login.path("twoFactor").asText()).isEqualTo("REQUIRED");
        assertThat(login.path("accessToken").isNull() || login.path("accessToken").isMissingNode()).isTrue();
        String challenge = login.path("challengeToken").asText();

        assertThat(api.get(challenge, "/api/v1/employees").status()).as("phiếu chờ không phải access token").isIn(401, 403);
        assertThat(api.post(null, "/api/v1/auth/2fa/verify", Map.of("challengeToken", challenge, "code", "123456")).status())
            .isEqualTo(401);
        var ok = api.post(null, "/api/v1/auth/2fa/verify", Map.of("challengeToken", challenge, "code", code(secret))).expectOk();
        assertThat(api.get(ok.text("accessToken"), "/api/v1/attendances/self/today").status()).isEqualTo(200);

        String rc = recovery.get(0).asText();
        String ch2 = api.login(e.email(), Fixture.PASSWORD).expectOk().text("challengeToken");
        assertThat(api.post(null, "/api/v1/auth/2fa/verify", Map.of("challengeToken", ch2, "code", rc)).status()).isEqualTo(200);
        String ch3 = api.login(e.email(), Fixture.PASSWORD).expectOk().text("challengeToken");
        assertThat(api.post(null, "/api/v1/auth/2fa/verify", Map.of("challengeToken", ch3, "code", rc)).status())
            .as("mã dự phòng đã dùng").isEqualTo(401);

        // Admin gỡ 2FA (mất điện thoại) → đăng nhập lại không cần mã
        api.delete(c.adminToken, "/api/v1/users/" + e.userId() + "/2fa").expectOk();
        assertThat(api.login(e.email(), Fixture.PASSWORD).expectOk().text("accessToken")).isNotBlank();
    }

    @Test
    @DisplayName("Công ty bắt buộc 2FA với quản trị: admin phải cài ở lần đăng nhập tới, không tắt được; nhân viên thường không bị ảnh hưởng")
    void companyRequiresAdmin2fa() {
        var c = fixture.standardCompany();
        String sys = api.post(null, "/admin/auth/login", Map.of("email", SYS_EMAIL, "password", SYS_PW))
            .expectOk().text("accessToken");
        api.put(sys, "/admin/companies/" + c.id + "/require-admin-2fa", Map.of("required", true)).expectOk();

        var login = api.login(c.adminEmail, Fixture.PASSWORD).expectOk().body();
        assertThat(login.path("twoFactor").asText()).isEqualTo("SETUP_REQUIRED");
        String ch = login.path("challengeToken").asText();
        String secret = api.post(null, "/api/v1/auth/2fa/setup", Map.of("challengeToken", ch)).expectOk().text("secret");
        var done = api.post(null, "/api/v1/auth/2fa/enable", Map.of("challengeToken", ch, "code", code(secret))).expectOk().body();
        assertThat(done.path("recoveryCodes")).hasSize(8);
        String adminToken = done.path("accessToken").asText();

        var disable = api.post(adminToken, "/api/v1/profile/2fa/disable",
            Map.of("password", Fixture.PASSWORD, "code", code(secret)));
        assertThat(disable.status()).isEqualTo(400);
        assertThat(disable.raw()).contains("error.2fa.required_by_company");

        assertThat(api.login(c.emp(6).email(), Fixture.PASSWORD).expectOk().text("accessToken"))
            .as("nhân viên không có ROLE_MANAGE").isNotBlank();
    }

    @Test
    @DisplayName("System admin bắt buộc 2FA: lần đầu phải cài, các lần sau nhập mã")
    void sysadmin_must_use2fa() {
        ReflectionTestUtils.setField(authService, "requireSysadmin2fa", true);
        var first = api.post(null, "/admin/auth/login", Map.of("email", SYS_EMAIL, "password", SYS_PW)).expectOk().body();
        assertThat(first.path("twoFactor").asText()).isEqualTo("SETUP_REQUIRED");
        String ch = first.path("challengeToken").asText();
        String secret = api.post(null, "/admin/auth/2fa/setup", Map.of("challengeToken", ch)).expectOk().text("secret");
        String token = api.post(null, "/admin/auth/2fa/enable", Map.of("challengeToken", ch, "code", code(secret)))
            .expectOk().text("accessToken");
        assertThat(api.get(token, "/admin/companies").status()).isEqualTo(200);

        var next = api.post(null, "/admin/auth/login", Map.of("email", SYS_EMAIL, "password", SYS_PW)).expectOk().body();
        assertThat(next.path("twoFactor").asText()).isEqualTo("REQUIRED");
        var verified = api.post(null, "/admin/auth/2fa/verify",
            Map.of("challengeToken", next.path("challengeToken").asText(), "code", code(secret))).expectOk();
        assertThat(verified.text("accessToken")).isNotBlank();

        // Phiếu cài (SETUP) không dùng để bỏ qua bước nhập mã (VERIFY)
        assertThat(api.post(null, "/admin/auth/2fa/verify", Map.of("challengeToken", ch, "code", code(secret))).status())
            .isEqualTo(401);
    }
}
