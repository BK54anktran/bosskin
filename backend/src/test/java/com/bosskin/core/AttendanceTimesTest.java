package com.bosskin.core;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

import static org.assertj.core.api.Assertions.assertThat;

/** Chọn ngày cho giờ chỉ có HH:mm (sửa tay, đơn chấm công) và ghép hiệu số thật. */
class AttendanceTimesTest {

    private static final LocalDate D = LocalDate.of(2026, 11, 2);
    private static final LocalTime T2200 = LocalTime.of(22, 0), T0600 = LocalTime.of(6, 0);

    @Test
    @DisplayName("Không ca: giờ ra nhỏ hơn giờ vào → +1 ngày; lớn hơn → cùng ngày")
    void noShift_outSmallerThanIn_nextDay() {
        LocalDateTime in = AttendanceTimes.resolveIn(D, LocalTime.of(19, 0), null);
        assertThat(in).isEqualTo(D.atTime(19, 0));
        assertThat(AttendanceTimes.resolveOut(D, LocalTime.of(3, 0), in, null, null)).isEqualTo(D.plusDays(1).atTime(3, 0));
        assertThat(AttendanceTimes.resolveOut(D, LocalTime.of(23, 0), in, null, null)).isEqualTo(D.atTime(23, 0));
    }

    @Test
    @DisplayName("Không ca: vào = ra cùng phút → khoảng không hợp lệ (không phải 24 giờ làm việc)")
    void noShift_sameMinute_invalid() {
        LocalDateTime in = D.atTime(10, 0);
        LocalDateTime out = AttendanceTimes.resolveOut(D, LocalTime.of(10, 0), in, null, null);
        assertThat(AttendanceTimes.validSpan(in, out)).isFalse();
    }

    @Test
    @DisplayName("Ca đêm 22:00–06:00: vào 21:50 → ngày công; vào 00:30 (đến muộn qua nửa đêm) → hôm sau")
    void nightShift_checkInDay() {
        assertThat(AttendanceTimes.resolveIn(D, LocalTime.of(21, 50), T2200)).isEqualTo(D.atTime(21, 50));
        assertThat(AttendanceTimes.resolveIn(D, LocalTime.of(0, 30), T2200)).isEqualTo(D.plusDays(1).atTime(0, 30));
    }

    @Test
    @DisplayName("Ca đêm: giờ ra 06:00 luôn rơi hôm sau, dù giờ vào là 22:00 hay 00:30")
    void nightShift_checkOutDay() {
        LocalDateTime in1 = D.atTime(22, 0);
        assertThat(AttendanceTimes.resolveOut(D, T0600, in1, T2200, T0600)).isEqualTo(D.plusDays(1).atTime(6, 0));
        LocalDateTime in2 = D.plusDays(1).atTime(0, 30);
        assertThat(AttendanceTimes.resolveOut(D, T0600, in2, T2200, T0600)).isEqualTo(D.plusDays(1).atTime(6, 0));
    }

    @Test
    @DisplayName("Ca ngày: vào 08:05, ra 17:10 cùng ngày; vào sớm 07:50 vẫn cùng ngày")
    void dayShift_sameDay() {
        LocalTime s = LocalTime.of(8, 0), e = LocalTime.of(17, 0);
        LocalDateTime in = AttendanceTimes.resolveIn(D, LocalTime.of(7, 50), s);
        assertThat(in).isEqualTo(D.atTime(7, 50));
        assertThat(AttendanceTimes.resolveOut(D, LocalTime.of(17, 10), in, s, e)).isEqualTo(D.atTime(17, 10));
    }

    @Test
    @DisplayName("Số ngày lệch cho cặp sửa tay, kể cả chỉ sửa một đầu")
    void overrideDays() {
        // ca đêm, sửa cả hai đầu: 22:00 → 06:00 hôm sau
        assertThat(AttendanceTimes.overrideDays(D, T2200, T0600, null, null, T2200, T0600)).containsExactly(0, 1);
        // đến muộn qua nửa đêm: 00:30 → 06:00 cùng ngày với giờ vào (hôm sau ngày công)
        assertThat(AttendanceTimes.overrideDays(D, LocalTime.of(0, 30), T0600, null, null, T2200, T0600)).containsExactly(1, 1);
        // chỉ sửa giờ ra, giờ vào thật 22:05 (ngày công)
        assertThat(AttendanceTimes.overrideDays(D, null, T0600, D.atTime(22, 5), D.plusDays(1).atTime(6, 10), T2200, T0600))
            .containsExactly(0, 1);
        // chỉ sửa giờ vào, ca ngày
        assertThat(AttendanceTimes.overrideDays(D, LocalTime.of(8, 0), null, D.atTime(8, 10), D.atTime(17, 0),
            LocalTime.of(8, 0), LocalTime.of(17, 0))).containsExactly(0, 0);
    }

    @Test
    @DisplayName("Mốc tuyệt đối: số phút từ 00:00 ngày công, âm khi ở hôm trước, ≥ 1440 khi sang hôm sau; ngày lệch khớp")
    void minutesAndOffsets() {
        assertThat(AttendanceTimes.minutesFrom(D, D.atTime(8, 30))).isEqualTo(510);
        assertThat(AttendanceTimes.minutesFrom(D, D.plusDays(1).atTime(6, 0))).isEqualTo(1440 + 360);
        assertThat(AttendanceTimes.minutesFrom(D, D.minusDays(1).atTime(23, 50))).isEqualTo(-10);
        assertThat(AttendanceTimes.dayOffset(D, D.plusDays(1).atTime(6, 0))).isEqualTo(1);
        assertThat(AttendanceTimes.dayOffset(D, D.minusDays(1).atTime(23, 50))).isEqualTo(-1);
        assertThat(AttendanceTimes.dayOffset(D, null)).isZero();
    }
}
