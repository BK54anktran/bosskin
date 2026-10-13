package com.bosskin.it;

import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ScriptUtils;

import javax.sql.DataSource;
import java.sql.Connection;
import java.time.LocalDate;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Nghỉ việc không xoá hồ sơ (13/10/2026): POST /employees/{id}/resign, /reinstate; V21 hiện lại người bị nút cũ ẩn. */
class ResignTest extends IntegrationTest {

    @Autowired JdbcTemplate jdbc;
    @Autowired DataSource dataSource;

    private boolean inList(String token, long empId, String status) {
        var page = api.get(token, "/api/v1/employees?page=0&size=50" + (status != null ? "&status=" + status : ""))
            .expectOk().body();
        for (var e : page.path("content")) if (e.path("id").asLong() == empId) return true;
        return false;
    }

    @Test
    @DisplayName("Nghỉ việc: Đã nghỉ + ngày làm cuối, vẫn trong danh sách, khoá tài khoản, gỡ quản lý và ca sau ngày nghỉ")
    void resign_keepsEmployeeVisible() {
        var c = fixture.standardCompany();
        var boss = c.emp(1);
        var e = c.emp(2);
        api.put(c.adminToken, "/api/v1/employees/" + c.emp(3).id(), Map.of("managerId", e.id())).expectOk();
        LocalDate today = LocalDate.now();
        LocalDate last = today.minusDays(1);
        long future = c.assign(e, "HC", today.plusDays(3));
        long before = c.assign(e, "HC", last.minusDays(1));

        var res = api.post(c.adminToken, "/api/v1/employees/" + e.id() + "/resign",
            Map.of("leaveDate", last.toString())).expectOk().body();
        assertThat(res.path("status").asText()).isEqualTo("INACTIVE");
        assertThat(res.path("leaveDate").asText()).isEqualTo(last.toString());

        assertThat(inList(c.adminToken, e.id(), "INACTIVE")).isTrue();
        assertThat(api.get(c.adminToken, "/api/v1/employees/" + e.id()).status()).isEqualTo(200);
        assertThat(api.login(e.email(), Fixture.PASSWORD).ok()).isFalse();
        assertThat(api.get(c.adminToken, "/api/v1/employees/" + c.emp(3).id()).expectOk().body()
            .path("managerId").isNull()).isTrue();
        assertThat(jdbc.queryForObject("SELECT deleted FROM shift_assignments WHERE id = ?", Boolean.class, future)).isTrue();
        assertThat(jdbc.queryForObject("SELECT deleted FROM shift_assignments WHERE id = ?", Boolean.class, before)).isFalse();
        assertThat(boss.id()).isNotEqualTo(e.id());
    }

    @Test
    @DisplayName("Nghỉ việc: ngày làm cuối sau hôm nay hoặc trước ngày vào làm bị từ chối")
    void resign_rejectsBadDates() {
        var c = fixture.standardCompany();
        var e = c.emp(2);
        var future = api.post(c.adminToken, "/api/v1/employees/" + e.id() + "/resign",
            Map.of("leaveDate", LocalDate.now().plusDays(1).toString()));
        assertThat(future.status()).isEqualTo(400);
        assertThat(future.raw()).contains("error.employee.leave_date_future");
        var early = api.post(c.adminToken, "/api/v1/employees/" + e.id() + "/resign",
            Map.of("leaveDate", "2000-01-01"));
        assertThat(early.status()).isEqualTo(400);
        assertThat(early.raw()).contains("error.employee.leave_before_join");
    }

    @Test
    @DisplayName("Đi làm lại: Đang làm, bỏ ngày nghỉ, đăng nhập lại được; người đang làm thì 409")
    void reinstate_reopensAccount() {
        var c = fixture.standardCompany();
        var e = c.emp(2);
        assertThat(api.post(c.adminToken, "/api/v1/employees/" + e.id() + "/reinstate", Map.of()).status()).isEqualTo(409);
        api.post(c.adminToken, "/api/v1/employees/" + e.id() + "/resign", Map.of()).expectOk();

        var res = api.post(c.adminToken, "/api/v1/employees/" + e.id() + "/reinstate", Map.of()).expectOk().body();
        assertThat(res.path("status").asText()).isEqualTo("ACTIVE");
        assertThat(res.path("leaveDate").isNull()).isTrue();
        assertThat(api.login(e.email(), Fixture.PASSWORD).ok()).isTrue();
    }

    @Test
    @DisplayName("V21: người bị nút Nghỉ việc cũ (xoá mềm) ẩn đi hiện lại ở lọc Đã nghỉ")
    void v21_unhidesOldStyleResigned() throws Exception {
        var c = fixture.standardCompany();
        var e = c.emp(2);
        api.delete(c.adminToken, "/api/v1/employees/" + e.id());     // đường cũ: xoá mềm + khoá tài khoản
        assertThat(inList(c.adminToken, e.id(), null)).isFalse();

        try (Connection conn = dataSource.getConnection()) {
            ScriptUtils.executeSqlScript(conn, new ClassPathResource("db/migration/V21__unhide_resigned_employees.sql"));
        }
        assertThat(inList(c.adminToken, e.id(), "INACTIVE")).isTrue();
        var emp = api.get(c.adminToken, "/api/v1/employees/" + e.id()).expectOk().body();
        assertThat(emp.path("leaveDate").asText()).isEqualTo(LocalDate.now().toString());
        assertThat(api.login(e.email(), Fixture.PASSWORD).ok()).isFalse();     // tài khoản vẫn khoá
    }
}
