package com.bosskin.it;

import com.bosskin.entity.Attendance;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Nhân viên tự check-in/out theo mọi loại ca (Mốc 2: A3, A4, A13, A14).
 * Giờ được giả lập bằng {@code clock.set(...)} — giờ Việt Nam.
 */
class SelfCheckInTest extends IntegrationTest {

    private static final LocalDate MON = LocalDate.of(2026, 11, 2);

    @Autowired AttendanceRepository attendanceRepository;

    private int checkIn(String token, LocalDateTime at) {
        clock.set(at);
        return api.post(token, "/api/v1/attendances/self/check-in", Map.of()).status();
    }

    private int checkOut(String token, LocalDateTime at) {
        clock.set(at);
        return api.post(token, "/api/v1/attendances/self/check-out", Map.of()).status();
    }

    @Test
    @DisplayName("A3/A4 · 5 đêm liên tiếp ca 22:00–06:00: check-in và check-out đủ, đúng ngày công")
    void nightShift_fiveConsecutiveNights() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        for (int i = 0; i < 5; i++) c.assign(e, "DEM", MON.plusDays(i));
        String token = c.tokenOf(e);

        for (int i = 0; i < 5; i++) {
            LocalDate night = MON.plusDays(i);
            assertThat(checkIn(token, night.atTime(21, 55))).as("check-in đêm %s", night).isEqualTo(201);

            clock.set(night.plusDays(1).atTime(5, 58));
            var today = api.get(token, "/api/v1/attendances/self/today").expectOk();
            assertThat(today.body().path("canCheckOut").asBoolean()).as("nút check-out sáng %s", night.plusDays(1)).isTrue();
            assertThat(today.text("date")).isEqualTo(night.toString());

            assertThat(checkOut(token, night.plusDays(1).atTime(6, 3))).as("check-out sáng %s", night.plusDays(1)).isEqualTo(200);
        }

        List<Attendance> rows = new java.util.ArrayList<>();
        for (int i = 0; i < 5; i++) rows.addAll(attendanceRepository.findByEmployeeIdAndDate(e.id(), MON.plusDays(i)));
        assertThat(rows).hasSize(5);
        rows.sort(Comparator.comparing(Attendance::getDate));
        for (int i = 0; i < 5; i++) {
            Attendance a = rows.get(i);
            assertThat(a.getDate()).isEqualTo(MON.plusDays(i));
            assertThat(a.getCheckIn()).isEqualTo(MON.plusDays(i).atTime(21, 55));
            assertThat(a.getCheckOut()).isEqualTo(MON.plusDays(i + 1).atTime(6, 3));
        }
    }

    @Test
    @DisplayName("Ngày có 2 ca (sáng, chiều): mỗi ca một dòng công đúng ca")
    void twoShiftsInOneDay() {
        var c = fixture.standardCompany();
        var e = c.emp(7);
        long sang = c.assign(e, "SANG", MON);
        long chieu = c.assign(e, "CHIEU", MON);
        String token = c.tokenOf(e);

        assertThat(checkIn(token, MON.atTime(5, 55))).isEqualTo(201);
        assertThat(checkOut(token, MON.atTime(10, 2))).isEqualTo(200);
        assertThat(checkIn(token, MON.atTime(12, 58))).isEqualTo(201);
        assertThat(checkOut(token, MON.atTime(17, 1))).isEqualTo(200);

        Map<Long, LocalTime> checkInBySlot = new java.util.HashMap<>();
        for (Attendance a : attendanceRepository.findByEmployeeIdAndDate(e.id(), MON)) {
            checkInBySlot.put(a.getShiftAssignment().getId(), a.getCheckIn().toLocalTime());
        }
        assertThat(checkInBySlot).containsEntry(sang, LocalTime.of(5, 55))
            .containsEntry(chieu, LocalTime.of(12, 58));
    }

    @Test
    @DisplayName("A13 · Check-in trong dung sai là đúng giờ, quá dung sai là đi muộn")
    void lateStatus_followsTolerance() {
        var c = fixture.standardCompany();
        var onTime = c.emp(6);
        var late = c.emp(7);
        c.assign(onTime, "HC", MON);
        c.assign(late, "HC", MON);

        checkIn(c.tokenOf(onTime), MON.atTime(8, 10));
        checkIn(c.tokenOf(late), MON.atTime(8, 20));

        assertThat(attendanceRepository.findByEmployeeIdAndDate(onTime.id(), MON).get(0).getStatus())
            .isEqualTo(Attendance.Status.PRESENT);
        assertThat(attendanceRepository.findByEmployeeIdAndDate(late.id(), MON).get(0).getStatus())
            .isEqualTo(Attendance.Status.LATE);
    }

    @Test
    @DisplayName("A14 · Về sớm vẫn check-out được (bị tính về sớm, không bị chặn)")
    void earlyCheckOut_isAllowed() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "HC", MON);
        String token = c.tokenOf(e);

        checkIn(token, MON.atTime(7, 55));

        assertThat(checkOut(token, MON.atTime(11, 0))).isEqualTo(200);
        assertThat(attendanceRepository.findByEmployeeIdAndDate(e.id(), MON).get(0).getCheckOut())
            .isEqualTo(MON.atTime(11, 0));
    }

    @Test
    @DisplayName("Check-in ngoài khung giờ bị từ chối; bấm check-in lần 2 cùng ca bị từ chối")
    void checkInOutsideWindowOrTwice_isRejected() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "HC", MON);
        String token = c.tokenOf(e);

        assertThat(checkIn(token, MON.atTime(6, 0))).isEqualTo(403);
        assertThat(checkIn(token, MON.atTime(8, 0))).isEqualTo(201);
        assertThat(checkIn(token, MON.atTime(8, 1))).isEqualTo(403);
        assertThat(attendanceRepository.findByEmployeeIdAndDate(e.id(), MON)).hasSize(1);
    }
}
