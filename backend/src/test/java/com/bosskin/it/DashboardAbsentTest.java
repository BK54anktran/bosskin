package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

/** Tổng quan: ca chưa kết thúc mà chưa check-in thì chưa tính vắng (13/10/2026). */
class DashboardAbsentTest extends IntegrationTest {

    @Test
    @DisplayName("Vắng hôm nay chỉ tính ca đã kết thúc mà chưa có mặt")
    void absentOnlyAfterShiftEnds() {
        var c = fixture.standardCompany();
        LocalDate day = LocalDate.of(2026, 11, 3);
        c.assign(c.emp(6), "HC", day);      // 08:00–17:00

        clock.set(day.atTime(7, 0));        // chưa tới giờ
        assertThat(absent(c.adminToken, day)).isZero();
        clock.set(day.atTime(12, 0));       // đang trong ca, chưa check-in
        assertThat(absent(c.adminToken, day)).isZero();
        clock.set(day.atTime(17, 30));      // hết ca, không check-in
        assertThat(absent(c.adminToken, day)).isEqualTo(1);
    }

    private long absent(String token, LocalDate day) {
        return api.get(token, "/api/v1/dashboard?date=" + day).expectOk().body()
            .path("todayStats").path("absent").asLong();
    }
}
