package com.bosskin.it;

import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Kiểm tra bộ dữ liệu mẫu dựng được và các luồng nền tảng đang chạy đúng.
 * Đây là test "xanh" — nếu đỏ nghĩa là khung test hoặc luồng cơ bản bị hỏng.
 */
class FixtureSmokeTest extends IntegrationTest {

    @Test
    void standardCompany_buildsAndEmployeesCanLogin() {
        var c = fixture.standardCompany();

        assertThat(c.departments).containsOnlyKeys("BGD", "KT", "SX");
        assertThat(c.employees).hasSize(10);
        assertThat(c.shifts).containsOnlyKeys("HC", "DEM", "SANG", "CHIEU");
        assertThat(c.leaveTypes).containsOnlyKeys("PN", "KL");

        var login = api.login(c.emp(5).email(), Fixture.PASSWORD);
        assertThat(login.status()).isEqualTo(200);
        assertThat(login.text("accessToken")).isNotBlank();
    }

    @Test
    void employeeRole_cannotListEmployees() {
        var c = fixture.standardCompany();
        String token = c.tokenOf(c.emp(5)); // vai trò "Nhân viên"

        assertThat(api.get(token, "/api/v1/employees").status()).isEqualTo(403);
    }

    @Test
    void tenantIsolation_adminCannotReadOtherCompanyEmployee() {
        var a = fixture.standardCompany();
        var b = fixture.standardCompany();

        var res = api.get(a.adminToken, "/api/v1/employees/" + b.emp(0).id());

        assertThat(res.status()).isIn(403, 404);
    }

    @Test
    void shiftAssignment_canAssignMultipleShiftsSameDay() {
        var c = fixture.standardCompany();
        LocalDate day = LocalDate.of(2026, 11, 2);

        c.assign(c.emp(6), "SANG", day);
        c.assign(c.emp(6), "CHIEU", day);

        var res = api.get(c.adminToken, "/api/v1/shifts/assignments/employee/" + c.emp(6).id()
            + "?from=" + day + "&to=" + day);
        assertThat(res.status()).isEqualTo(200);
    }

    @Test
    void wrongPassword_isRejected() {
        var c = fixture.newCompany();
        assertThat(api.login(c.adminEmail, "sai-mat-khau").status()).isIn(400, 401);
    }
}
