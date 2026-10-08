package com.bosskin.it;

import com.bosskin.security.JwtUtil;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

/** Hồi quy cho phần xác thực sửa ở Mốc 1 (S3, S4, S5, D4, đăng xuất). */
class AuthTest extends IntegrationTest {

    @Autowired JwtUtil jwtUtil;
    @Autowired org.springframework.test.web.servlet.MockMvc mvc;

    @Test
    @DisplayName("D4 · Nhân viên bị xoá: token cũ hết tác dụng và không đăng nhập lại được")
    void d4_deletedEmployee_losesAccess() {
        var c = fixture.standardCompany();
        var e = c.emp(8);
        String token = c.tokenOf(e);

        api.delete(c.adminToken, "/api/v1/employees/" + e.id()).expectOk();

        assertThat(api.get(token, "/api/v1/attendances/self/today").status()).isIn(401, 403);
        assertThat(api.login(e.email(), Fixture.PASSWORD).ok()).isFalse();
    }

    @Test
    @DisplayName("Đăng xuất thu hồi refresh token")
    void logout_revokesRefreshToken() {
        var c = fixture.standardCompany();
        String refresh = api.login(c.emp(6).email(), Fixture.PASSWORD).expectOk().text("refreshToken");

        assertThat(api.post(null, "/api/v1/auth/logout", Map.of("refreshToken", refresh)).status()).isEqualTo(204);

        assertThat(api.post(null, "/api/v1/auth/refresh", Map.of("refreshToken", refresh)).ok()).isFalse();
    }

    @Test
    @DisplayName("Refresh token hợp lệ vẫn đổi được token mới")
    void refresh_stillWorks() {
        var c = fixture.standardCompany();
        String refresh = api.login(c.emp(6).email(), Fixture.PASSWORD).expectOk().text("refreshToken");

        var res = api.post(null, "/api/v1/auth/refresh", Map.of("refreshToken", refresh));

        assertThat(res.status()).isEqualTo(200);
        assertThat(api.get(res.text("accessToken"), "/api/v1/attendances/self/today").status()).isEqualTo(200);
    }

    @Test
    @DisplayName("S5 · Token impersonate mang email không phải system admin bị từ chối")
    void s5_impersonateTokenForNonSysAdmin_isRejected() {
        var c = fixture.standardCompany();
        String token = jwtUtil.generateImpersonateToken(c.emp(6).email(), c.id, Set.of("EMPLOYEE_VIEW"));

        assertThat(api.get(token, "/api/v1/employees").status()).isIn(401, 403);
    }

    @Test
    @DisplayName("S5 · System admin impersonate được, phiên sống tối đa 1 giờ")
    void s5_sysAdminImpersonation_isShortLived() {
        var c = fixture.standardCompany();
        String sys = api.post(null, "/admin/auth/login",
            Map.of("email", "sysadmin@test.local", "password", "Test-SysAdmin-123")).expectOk().text("accessToken");

        var res = api.post(sys, "/admin/companies/" + c.id + "/impersonate", null).expectOk();

        assertThat(res.body().path("expiresIn").asLong()).isLessThanOrEqualTo(3_600_000L);
        assertThat(api.get(res.text("accessToken"), "/api/v1/employees").status()).isEqualTo(200);
    }

    @Test
    @DisplayName("Admin không tự khoá tài khoản của chính mình")
    void admin_cannotDisableSelf() {
        var c = fixture.newCompany();
        long adminUserId = api.login(c.adminEmail, Fixture.PASSWORD).body().path("user").path("id").asLong();

        var res = api.patch(c.adminToken, "/api/v1/users/" + adminUserId + "/enabled", Map.of("enabled", false));

        assertThat(res.status()).isEqualTo(400);
    }

    @Test
    @DisplayName("S10 · Sai mật khẩu 5 lần thì tạm khoá đăng nhập, kể cả khi nhập đúng")
    void s10_tooManyFailedLogins_temporarilyLocked() {
        var c = fixture.newCompany();
        for (int i = 0; i < 5; i++) {
            assertThat(api.login(c.adminEmail, "sai-mat-khau-" + i).status()).isEqualTo(401);
        }

        assertThat(api.login(c.adminEmail, Fixture.PASSWORD).status()).isEqualTo(429);
    }

    @Test
    @DisplayName("S12 · Thư mục upload không cho chứa ../")
    void s12_uploadFolderTraversal_isRejected() throws Exception {
        var c = fixture.newCompany();
        var file = new org.springframework.mock.web.MockMultipartFile(
            "file", "a.png", "image/png", new byte[]{(byte) 0x89, 'P', 'N', 'G'});

        var res = mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .multipart("/api/v1/upload/image").file(file).param("folder", "../company-1")
                .header("Authorization", "Bearer " + c.adminToken))
            .andReturn().getResponse();

        assertThat(res.getStatus()).isEqualTo(400);
    }
}
