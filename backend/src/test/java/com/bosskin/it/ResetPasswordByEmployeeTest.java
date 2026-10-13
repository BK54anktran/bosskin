package com.bosskin.it;

import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Nút 🔑 ở màn Nhân viên: POST /users/by-employee/{employeeId}/reset-password (13/10/2026). */
class ResetPasswordByEmployeeTest extends IntegrationTest {

    @Test
    @DisplayName("Đặt lại mật khẩu theo nhân viên: mật khẩu tạm đăng nhập được, mật khẩu cũ hết hiệu lực; nhân viên thường bị chặn")
    void resetByEmployee() {
        var c = fixture.standardCompany();
        var e = c.emp(4);

        var res = api.post(c.adminToken, "/api/v1/users/by-employee/" + e.id() + "/reset-password", Map.of())
            .expectOk().body();
        String pw = res.path("password").asText();
        assertThat(pw).isNotBlank();
        assertThat(api.login(e.email(), Fixture.PASSWORD).ok()).isFalse();
        assertThat(api.login(e.email(), pw).ok()).isTrue();

        // Nhân viên không có USER_MANAGE
        var denied = api.post(c.tokenOf(c.emp(5)), "/api/v1/users/by-employee/" + e.id() + "/reset-password", Map.of());
        assertThat(denied.status()).isEqualTo(403);
        // Không tồn tại / không có tài khoản
        var missing = api.post(c.adminToken, "/api/v1/users/by-employee/999999/reset-password", Map.of());
        assertThat(missing.status()).isEqualTo(404);
        assertThat(missing.raw()).contains("error.employee.no_account");
    }
}
