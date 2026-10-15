package com.bosskin.it;

import com.bosskin.entity.Attendance;
import com.bosskin.entity.Company;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** V25: công ty bật "chấm công không cần xếp ca" → ngày không có ca vẫn tự chấm vào / ra được, công không gắn ca. */
class CheckInWithoutShiftTest extends IntegrationTest {

    private static final LocalDate MON = LocalDate.of(2026, 11, 2);

    @Autowired AttendanceRepository attendanceRepository;
    @Autowired CompanyRepository companyRepository;

    private void enable(Fixture.TestCompany c) {
        Company company = companyRepository.findById(c.id).orElseThrow();
        company.setCheckInWithoutShift(true);
        companyRepository.save(company);
    }

    private com.bosskin.support.Api.Res post(String token, String url, LocalDateTime at) {
        clock.set(at);
        return api.post(token, url, Map.of());
    }

    @Test
    @DisplayName("Tắt (mặc định): ngày không có ca thì không chấm được")
    void disabled_noShift_rejected() {
        var c = fixture.standardCompany();
        String token = c.tokenOf(c.emp(6));
        var r = post(token, "/api/v1/attendances/self/check-in", MON.atTime(8, 0));
        assertThat(r.status()).isEqualTo(400);
        assertThat(r.raw()).contains("error.attendance.no_shift_today");
    }

    @Test
    @DisplayName("Bật: ngày không có ca chấm vào / ra một lần, công không gắn ca, không xét đi muộn")
    void enabled_noShift_checkInOutOnce() {
        var c = fixture.standardCompany();
        enable(c);
        var e = c.emp(6);
        String token = c.tokenOf(e);

        clock.set(MON.atTime(10, 30));
        var today = api.get(token, "/api/v1/attendances/self/today").expectOk();
        assertThat(today.body().path("canCheckIn").asBoolean()).isTrue();
        assertThat(today.text("message")).isEqualTo("attendanceNoShiftFreeCheckIn");

        assertThat(post(token, "/api/v1/attendances/self/check-in", MON.atTime(10, 30)).status()).isEqualTo(201);
        var again = post(token, "/api/v1/attendances/self/check-in", MON.atTime(10, 35));
        assertThat(again.status()).isEqualTo(400);
        assertThat(again.raw()).contains("error.attendance.already_checked_in");

        assertThat(post(token, "/api/v1/attendances/self/check-out", MON.atTime(16, 0)).status()).isEqualTo(200);
        var outAgain = post(token, "/api/v1/attendances/self/check-out", MON.atTime(16, 5));
        assertThat(outAgain.status()).isEqualTo(400);
        assertThat(outAgain.raw()).contains("error.attendance.already_checked_out");

        List<Attendance> rows = attendanceRepository.findByEmployeeIdAndDate(e.id(), MON);
        assertThat(rows).hasSize(1);
        Attendance a = rows.get(0);
        assertThat(a.getShiftAssignment()).isNull();
        assertThat(a.getStatus()).isEqualTo(Attendance.Status.PRESENT);
        assertThat(a.getCheckIn()).isEqualTo(MON.atTime(10, 30));
        assertThat(a.getCheckOut()).isEqualTo(MON.atTime(16, 0));
    }

    @Test
    @DisplayName("Bật: chấm ra trước khi chấm vào báo chưa chấm vào")
    void enabled_checkOutWithoutCheckIn() {
        var c = fixture.standardCompany();
        enable(c);
        var r = post(c.tokenOf(c.emp(6)), "/api/v1/attendances/self/check-out", MON.atTime(17, 0));
        assertThat(r.status()).isEqualTo(400);
        assertThat(r.raw()).contains("error.attendance.not_checked_in");
    }

    @Test
    @DisplayName("Bật: chấm vào tối, chấm ra sáng hôm sau (không có ca) → công của ngày chấm vào")
    void enabled_noShift_overnight() {
        var c = fixture.standardCompany();
        enable(c);
        var e = c.emp(6);
        String token = c.tokenOf(e);
        assertThat(post(token, "/api/v1/attendances/self/check-in", MON.atTime(22, 0)).status()).isEqualTo(201);
        assertThat(post(token, "/api/v1/attendances/self/check-out", MON.plusDays(1).atTime(6, 0)).status()).isEqualTo(200);
        Attendance a = attendanceRepository.findByEmployeeIdAndDate(e.id(), MON).get(0);
        assertThat(a.getCheckOut()).isEqualTo(MON.plusDays(1).atTime(6, 0));
    }

    @Test
    @DisplayName("Bật: ngày có ca vẫn chấm theo khung giờ ca như cũ")
    void enabled_dayWithShift_keepsWindow() {
        var c = fixture.standardCompany();
        enable(c);
        var e = c.emp(6);
        c.assign(e, "HC", MON);
        var r = post(c.tokenOf(e), "/api/v1/attendances/self/check-in", MON.atTime(14, 0));
        assertThat(r.status()).isEqualTo(403);
        assertThat(r.raw()).contains("error.attendance.outside_check_in_window");
        assertThat(post(c.tokenOf(e), "/api/v1/attendances/self/check-in", MON.atTime(8, 20)).status()).isEqualTo(201);
        assertThat(attendanceRepository.findByEmployeeIdAndDate(e.id(), MON).get(0).getStatus())
            .isEqualTo(Attendance.Status.LATE);
    }
}
