package com.bosskin.it.knownbugs;

import com.bosskin.repository.RoleRepository;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tái hiện lỗi bảo mật/phân quyền đã biết. Mỗi test khẳng định hành vi ĐÚNG,
 * nên hiện đang đỏ. Sửa xong lỗi nào thì bỏ @Tag("known-bug") của test đó.
 * Mã lỗi (S1, D1…) theo docs/review-2026-10/danh-gia.html — sửa ở Mốc 1.
 */
@Tag("known-bug")
class SecurityKnownBugsTest extends IntegrationTest {

    /** Giá trị mặc định đang nằm trong application.yml. */
    private static final String DEFAULT_JWT_SECRET = "bosskin-super-secret-key-change-in-production-2024";

    @Autowired RoleRepository roleRepository;
    @Autowired JdbcTemplate jdbc;

    @Test
    @DisplayName("S1 · Token system admin tự ký bằng secret mặc định không được chấp nhận")
    void s1_forgedSystemTokenWithDefaultSecret_isRejected() {
        long now = System.currentTimeMillis();
        String forged = Jwts.builder()
            .claims(Map.of("type", "SYSTEM"))
            .subject("sysadmin@bosskin.io")
            .issuedAt(new Date(now))
            .expiration(new Date(now + 3_600_000))
            .signWith(Keys.hmacShaKeyFor(DEFAULT_JWT_SECRET.getBytes(StandardCharsets.UTF_8)))
            .compact();

        var res = api.get(forged, "/admin/companies");

        assertThat(res.status()).as("forged token phải bị từ chối").isIn(401, 403);
    }

    @Test
    @DisplayName("S2 · DB mới không có sẵn tài khoản seed (mật khẩu hash nằm công khai trong migration)")
    void s2_freshDatabaseHasNoSeedAccounts() {
        Integer sysAdmins = jdbc.queryForObject(
            "SELECT COUNT(*) FROM system_admins WHERE email = 'sysadmin@bosskin.io' AND enabled = 1", Integer.class);
        Integer companyUsers = jdbc.queryForObject(
            "SELECT COUNT(*) FROM users WHERE email LIKE '%@bosskin.vn' AND enabled = 1", Integer.class);

        assertThat(sysAdmins).as("system admin seed").isZero();
        assertThat(companyUsers).as("tài khoản công ty seed @bosskin.vn").isZero();
    }

    @Test
    @DisplayName("S3 · Tài khoản bị khoá không dùng tiếp access token cũ được")
    void s3_disabledUser_oldAccessTokenRejected() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        String token = c.tokenOf(e);
        assertThat(api.get(token, "/api/v1/attendances/self/today").status()).isEqualTo(200);

        api.patch(c.adminToken, "/api/v1/users/" + e.userId() + "/enabled", Map.of("enabled", false)).expectOk();

        assertThat(api.get(token, "/api/v1/attendances/self/today").status()).isIn(401, 403);
    }

    @Test
    @DisplayName("S3 · Tài khoản bị khoá không refresh token được")
    void s3_disabledUser_cannotRefresh() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        String refresh = api.login(e.email(), Fixture.PASSWORD).expectOk().text("refreshToken");

        api.patch(c.adminToken, "/api/v1/users/" + e.userId() + "/enabled", Map.of("enabled", false)).expectOk();

        var res = api.post(null, "/api/v1/auth/refresh", Map.of("refreshToken", refresh));
        assertThat(res.status()).isIn(400, 401, 403);
    }

    @Test
    @DisplayName("S4 · Refresh token không dùng thay access token được")
    void s4_refreshTokenCannotBeUsedAsAccessToken() {
        var c = fixture.standardCompany();
        String refresh = api.login(c.emp(6).email(), Fixture.PASSWORD).expectOk().text("refreshToken");

        assertThat(api.get(refresh, "/api/v1/attendances/self/today").status()).isIn(401, 403);
    }

    @Test
    @DisplayName("D1 · Nhân viên mới của công ty mới không nhận vai trò Admin")
    void d1_newEmployeeInNewCompany_isNotAdmin() {
        var c = fixture.newCompany();
        c.createDepartment("SX", "Sản xuất", null);
        var e = c.createEmployee("Nhân viên mới", "SX");

        String token = c.tokenOf(e);

        assertThat(api.get(token, "/api/v1/employees").status())
            .as("nhân viên mới không được xem danh sách nhân viên").isEqualTo(403);
        assertThat(api.get(token, "/api/v1/roles").status())
            .as("nhân viên mới không được xem vai trò").isEqualTo(403);
    }

    @Test
    @DisplayName("S6 · Người quản lý tài khoản không tự gán cho mình vai trò Admin")
    void s6_userManagerCannotEscalateOwnRole() {
        var c = fixture.standardCompany();
        c.createRole("Quản lý tài khoản", List.of("USER_MANAGE"));
        var e = c.emp(4);
        c.setRole(e, "Quản lý tài khoản");
        long adminRoleId = roleRepository.findByCompanyIdAndName(c.id, "Admin").orElseThrow().getId();

        var res = api.put(c.tokenOf(e), "/api/v1/users/" + e.userId() + "/roles",
            Map.of("roleIds", List.of(adminRoleId)));

        assertThat(res.status()).isEqualTo(403);
    }
}
