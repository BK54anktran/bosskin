package com.bosskin.it;

import com.bosskin.entity.Attendance;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * V27: giờ vào / ra lưu ngày giờ đầy đủ, giờ công = hiệu số thật; giờ sửa tay chỉ nhập HH:mm thì backend chọn ngày
 * (giờ ra nhỏ hơn giờ vào → +1 ngày) và lưu datetime; bảng công trả "số ngày lệch" để app hiện "+N".
 */
class AttendanceDateTimeTest extends IntegrationTest {

    private static final LocalDate MON = LocalDate.of(2026, 11, 2);

    @Autowired AttendanceRepository attendanceRepository;

    private JsonNode row(Fixture.TestCompany c, Fixture.Emp e, LocalDate date) {
        JsonNode rows = api.get(c.adminToken, "/api/v1/attendances/timesheet?employeeId=" + e.id() + "&year=2026&month=11")
            .expectOk().body();
        for (JsonNode r : rows) {
            if (date.toString().equals(r.path("date").asText())) return r;
        }
        throw new AssertionError("không có dòng công ngày " + date);
    }

    private long overrideRecord(Fixture.TestCompany c, Fixture.Emp e, LocalDate date) {
        return api.post(c.adminToken, "/api/v1/attendances/override",
            Map.of("employeeId", e.id(), "date", date.toString())).expectOk().body().path("attendanceId").asLong();
    }

    private Map<String, Object> ov(String in, String out) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("overrideCheckIn", in);
        m.put("overrideCheckOut", out);
        return m;
    }

    @Test
    @DisplayName("Ca đêm: chấm vào 21:55 ngày công, ra 06:03 hôm sau → đủ 8 giờ trong ca, giờ ra lệch +1 ngày")
    void rawOvernight_hoursAndOffsets() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "DEM", MON);
        String token = c.tokenOf(e);
        clock.set(MON.atTime(21, 55));
        api.post(token, "/api/v1/attendances/self/check-in", Map.of()).expectOk();
        clock.set(MON.plusDays(1).atTime(6, 3));
        api.post(token, "/api/v1/attendances/self/check-out", Map.of()).expectOk();

        JsonNode r = row(c, e, MON);
        assertThat(r.path("actualHours").asDouble()).isEqualTo(8.0);
        assertThat(r.path("totalHours").asDouble()).isEqualTo(8.0);
        assertThat(r.path("checkIn").asText()).isEqualTo(MON + "T21:55");
        assertThat(r.path("checkOut").asText()).isEqualTo(MON.plusDays(1) + "T06:03");
    }

    @Test
    @DisplayName("Sửa tay ca đêm 22:00 → 06:00: lưu datetime, giờ ra là hôm sau (+1), đủ 8 giờ")
    void overrideOvernight_storesNextDay() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "DEM", MON);
        long id = overrideRecord(c, e, MON);
        api.patch(c.adminToken, "/api/v1/attendances/" + id + "/override", ov("22:00", "06:00")).expectOk();

        Attendance a = attendanceRepository.findById(id).orElseThrow();
        assertThat(a.getOverrideCheckInAt()).isEqualTo(LocalDateTime.of(MON, java.time.LocalTime.of(22, 0)));
        assertThat(a.getOverrideCheckOutAt()).isEqualTo(LocalDateTime.of(MON.plusDays(1), java.time.LocalTime.of(6, 0)));
        JsonNode r = row(c, e, MON);
        assertThat(r.path("overrideCheckIn").asText()).isEqualTo(MON + "T22:00");
        assertThat(r.path("overrideCheckOut").asText()).isEqualTo(MON.plusDays(1) + "T06:00");
        assertThat(r.path("actualHours").asDouble()).isEqualTo(8.0);
        // Không bật chế độ ngày / đêm: cả 8 giờ là giờ ngày, phút 23:59–00:00 không bị tính nhầm là giờ đêm (từng ra 7h59 + 1 phút đêm)
        assertThat(r.path("regularDayHours").asDouble()).isEqualTo(8.0);
        assertThat(r.path("regularNightHours").asDouble()).isZero();
    }

    @Test
    @DisplayName("Sửa tay ca đêm, đến muộn 00:30 (qua nửa đêm): giờ vào là hôm sau (+1) → 5,5 giờ, không tính 22 giờ sớm hơn")
    void overrideLateAfterMidnight_checkInNextDay() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "DEM", MON);
        long id = overrideRecord(c, e, MON);
        api.patch(c.adminToken, "/api/v1/attendances/" + id + "/override", ov("00:30", "06:00")).expectOk();

        Attendance a = attendanceRepository.findById(id).orElseThrow();
        assertThat(a.getOverrideCheckInAt()).isEqualTo(LocalDateTime.of(MON.plusDays(1), java.time.LocalTime.of(0, 30)));
        assertThat(a.getOverrideCheckOutAt()).isEqualTo(LocalDateTime.of(MON.plusDays(1), java.time.LocalTime.of(6, 0)));
        JsonNode r = row(c, e, MON);
        assertThat(r.path("overrideCheckIn").asText()).isEqualTo(MON.plusDays(1) + "T00:30");
        assertThat(r.path("overrideCheckOut").asText()).isEqualTo(MON.plusDays(1) + "T06:00");
        assertThat(r.path("actualHours").asDouble()).isEqualTo(5.5);
    }

    @Test
    @DisplayName("Không có ca: sửa tay 19:00 → 03:00 thì giờ ra nhỏ hơn nên +1 ngày, đủ 8 giờ")
    void overrideNoShift_smallerOutPlusOneDay() {
        var c = fixture.standardCompany();
        var e = c.emp(7);
        long id = overrideRecord(c, e, MON);
        api.patch(c.adminToken, "/api/v1/attendances/" + id + "/override", ov("19:00", "03:00")).expectOk();

        Attendance a = attendanceRepository.findById(id).orElseThrow();
        assertThat(a.getOverrideCheckOutAt()).isEqualTo(LocalDateTime.of(MON.plusDays(1), java.time.LocalTime.of(3, 0)));
        JsonNode r = row(c, e, MON);
        assertThat(r.path("overrideCheckOut").asText()).isEqualTo(MON.plusDays(1) + "T03:00");
        assertThat(r.path("actualHours").asDouble()).isEqualTo(8.0);
    }

    @Test
    @DisplayName("Sửa tay giờ ra bằng giờ vào (cùng phút) bị từ chối, không lưu")
    void overrideSameMinute_rejected() {
        var c = fixture.standardCompany();
        var e = c.emp(7);
        long id = overrideRecord(c, e, MON);
        var res = api.patch(c.adminToken, "/api/v1/attendances/" + id + "/override", ov("10:00", "10:00"));
        assertThat(res.status()).isEqualTo(400);
        assertThat(res.raw()).contains("error.attendance.override_range_invalid");
    }

    @Test
    @DisplayName("Chỉ sửa giờ ra khi giờ vào thật là 22:05: giờ ra ghép sang hôm sau theo giờ vào thật")
    void overrideOnlyCheckOut_usesRawCheckIn() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "DEM", MON);
        String token = c.tokenOf(e);
        clock.set(MON.atTime(22, 5));
        api.post(token, "/api/v1/attendances/self/check-in", Map.of()).expectOk();
        long id = attendanceRepository.findByEmployeeIdAndDate(e.id(), MON).get(0).getId();
        api.patch(c.adminToken, "/api/v1/attendances/" + id + "/override", ov(null, "06:00")).expectOk();

        Attendance a = attendanceRepository.findById(id).orElseThrow();
        assertThat(a.getOverrideCheckInAt()).isNull();
        assertThat(a.getOverrideCheckOutAt()).isEqualTo(LocalDateTime.of(MON.plusDays(1), java.time.LocalTime.of(6, 0)));
        // 22:05 → 06:00 hôm sau = 7 giờ 55
        assertThat(row(c, e, MON).path("actualHours").asDouble()).isEqualTo(475 / 60.0);
    }
}
