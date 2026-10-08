package com.bosskin.it;

import com.bosskin.repository.CompanyRepository;
import com.bosskin.support.Api;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Khoá kỳ công (Mốc 2, A12). */
class PeriodLockTest extends IntegrationTest {

    @Autowired CompanyRepository companyRepository;

    private static final LocalDate NOV_3 = LocalDate.of(2026, 11, 3);

    private Api.Res approve(String token, long employeeId, LocalDate date) {
        return api.post(token, "/api/v1/attendances/approve",
            Map.of("employeeId", employeeId, "date", date.toString()));
    }

    @Test
    @DisplayName("Kỳ đã khoá: duyệt công, phân ca, xin nghỉ, tự check-in trong kỳ đều bị chặn; ngoài kỳ vẫn làm được")
    void lockedPeriod_blocksWritesInsidePeriodOnly() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "HC", NOV_3);
        c.grantLeaveDays(e, "PN", 5);
        assertThat(api.post(c.adminToken, "/api/v1/attendance-periods/2026/11/lock", null).status()).isEqualTo(200);

        assertThat(approve(c.adminToken, e.id(), NOV_3).status()).as("duyệt công").isEqualTo(409);
        assertThat(api.post(c.adminToken, "/api/v1/shifts/assignments", Map.of(
            "employeeId", e.id(), "shiftId", c.shifts.get("HC"), "workDate", "2026-11-05")).status())
            .as("phân ca").isEqualTo(409);
        assertThat(api.post(c.tokenOf(e), "/api/v1/leaves/requests", Map.of(
            "leaveTypeId", c.leaveTypes.get("PN"), "mode", "DAY_RANGE",
            "fromDate", "2026-11-10", "toDate", "2026-11-10", "reason", "Việc riêng")).status())
            .as("xin nghỉ").isEqualTo(409);
        clock.set(NOV_3.atTime(7, 58));
        assertThat(api.post(c.tokenOf(e), "/api/v1/attendances/self/check-in", Map.of()).status())
            .as("tự check-in").isEqualTo(409);

        // Ngoài kỳ khoá
        c.assign(e, "HC", LocalDate.of(2026, 12, 1));
        assertThat(approve(c.adminToken, e.id(), LocalDate.of(2026, 12, 1)).status()).isEqualTo(200);
    }

    @Test
    @DisplayName("Mở lại kỳ cần lý do; mở xong thao tác lại được")
    void unlock_requiresReason() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "HC", NOV_3);
        api.post(c.adminToken, "/api/v1/attendance-periods/2026/11/lock", null).expectOk();

        assertThat(api.post(c.adminToken, "/api/v1/attendance-periods/2026/11/unlock", Map.of()).status()).isEqualTo(400);
        var unlocked = api.post(c.adminToken, "/api/v1/attendance-periods/2026/11/unlock",
            Map.of("reason", "Bổ sung công cho NV ốm")).expectOk();

        assertThat(unlocked.body().path("locked").asBoolean()).isFalse();
        assertThat(unlocked.text("unlockReason")).isEqualTo("Bổ sung công cho NV ốm");
        assertThat(approve(c.adminToken, e.id(), NOV_3).status()).isEqualTo(200);
    }

    @Test
    @DisplayName("Chỉ người có quyền khoá kỳ mới khoá/mở được; danh sách trả đủ 12 kỳ")
    void lockPermission_andYearList() {
        var c = fixture.standardCompany();

        assertThat(api.post(c.tokenOf(c.emp(1)), "/api/v1/attendance-periods/2026/11/lock", null).status())
            .as("Quản lý chấm công không có quyền khoá kỳ").isEqualTo(403);
        api.post(c.adminToken, "/api/v1/attendance-periods/2026/11/lock", null).expectOk();
        assertThat(api.post(c.adminToken, "/api/v1/attendance-periods/2026/11/lock", null).status())
            .as("khoá lại kỳ đã khoá").isEqualTo(409);

        var list = api.get(c.adminToken, "/api/v1/attendance-periods?year=2026").expectOk();
        assertThat(list.body()).hasSize(12);
        assertThat(list.body().get(10).path("locked").asBoolean()).isTrue();
        assertThat(list.body().get(9).path("locked").asBoolean()).isFalse();
    }

    @Test
    @DisplayName("Kỳ theo ngày chốt công 26: kỳ tháng 12 là 26/11–25/12")
    void lockFollowsCutoffDay() {
        var c = fixture.standardCompany();
        var company = companyRepository.findById(c.id).orElseThrow();
        company.setPayrollCutoffDay(26);
        companyRepository.save(company);
        var e = c.emp(6);
        c.assign(e, "HC", LocalDate.of(2026, 11, 25));
        c.assign(e, "HC", LocalDate.of(2026, 11, 26));

        var lock = api.post(c.adminToken, "/api/v1/attendance-periods/2026/12/lock", null).expectOk();

        assertThat(lock.text("from")).isEqualTo("2026-11-26");
        assertThat(lock.text("to")).isEqualTo("2026-12-25");
        assertThat(approve(c.adminToken, e.id(), LocalDate.of(2026, 11, 26)).status()).isEqualTo(409);
        assertThat(approve(c.adminToken, e.id(), LocalDate.of(2026, 11, 25)).status()).isEqualTo(200);
    }
}
