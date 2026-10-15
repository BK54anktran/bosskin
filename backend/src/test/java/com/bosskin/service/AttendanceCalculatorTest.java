package com.bosskin.service;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

/** Giờ công trên trục tuyệt đối (phút từ 00:00 ngày công): hiệu số thật, không đoán qua đêm. */
class AttendanceCalculatorTest {

    private static final int DS = 6 * 60, DE = 22 * 60; // ban ngày 06:00–22:00
    private static int m(int h, int min) { return h * 60 + min; }

    @Test
    @DisplayName("Ca hành chính 08–17 nghỉ 12–13, vào 08:00 ra 17:00 → 8 giờ ban ngày")
    void dayShift() {
        var r = AttendanceCalculator.calculate(m(8, 0), m(17, 0), m(12, 0), m(13, 0), m(8, 0), m(17, 0), DS, DE, null, null);
        assertThat(r.actualHours()).isEqualTo(8.0);
        assertThat(r.regularDayHours()).isEqualTo(8.0);
        assertThat(r.regularNightHours()).isZero();
    }

    @Test
    @DisplayName("Ca đêm 22:00–06:00 (kết thúc = 1800 phút): vào 21:55 ra 06:03 hôm sau → 8 giờ đêm")
    void nightShift() {
        var r = AttendanceCalculator.calculate(m(22, 0), 1440 + m(6, 0), null, null, m(21, 55), 1440 + m(6, 3), DS, DE, null, null);
        assertThat(r.actualHours()).isEqualTo(8.0);
        assertThat(r.regularNightHours()).isEqualTo(8.0);
        assertThat(r.regularDayHours()).isZero();
        assertThat(r.outsideShiftHours()).isCloseTo(8 / 60.0, within(1e-9));
    }

    @Test
    @DisplayName("Ca đêm, đến muộn 00:30 hôm sau (1470 phút) → 5,5 giờ")
    void nightShiftLateAfterMidnight() {
        var r = AttendanceCalculator.calculate(m(22, 0), 1440 + m(6, 0), null, null, 1440 + m(0, 30), 1440 + m(6, 0), DS, DE, null, null);
        assertThat(r.actualHours()).isEqualTo(5.5);
    }

    @Test
    @DisplayName("Ca đêm có giờ nghỉ sau nửa đêm 02:00–02:30 (đặt cùng trục = 1560–1590): trừ đủ 30 phút")
    void nightShiftBreakAfterMidnight() {
        var r = AttendanceCalculator.calculate(m(22, 0), 1440 + m(6, 0), 1440 + m(2, 0), 1440 + m(2, 30),
            m(22, 0), 1440 + m(6, 0), DS, DE, null, null);
        assertThat(r.actualHours()).isEqualTo(7.5);
    }

    @Test
    @DisplayName("Không ca, vào 19:00 ra 03:00 hôm sau: 8 giờ, 3 giờ ban ngày (19–22) + 5 giờ đêm")
    void noShiftOvernight() {
        var r = AttendanceCalculator.calculate(null, null, null, null, m(19, 0), 1440 + m(3, 0), DS, DE, null, null);
        assertThat(r.actualHours()).isEqualTo(8.0);
        assertThat(r.regularDayHours()).isEqualTo(3.0);
        assertThat(r.regularNightHours()).isEqualTo(5.0);
    }

    @Test
    @DisplayName("Ra không sau vào → 0 giờ; vào = ra cùng phút → 0 giờ; khoảng từ 24 giờ trở lên → 0 giờ")
    void invalidSpansAreZero() {
        assertThat(AttendanceCalculator.calculate(null, null, null, null, m(10, 0), m(10, 0), DS, DE, null, null).actualHours()).isZero();
        assertThat(AttendanceCalculator.calculate(null, null, null, null, m(10, 0), m(9, 0), DS, DE, null, null).actualHours()).isZero();
        assertThat(AttendanceCalculator.calculate(null, null, null, null, m(10, 0), m(10, 0) + 1440, DS, DE, null, null).actualHours()).isZero();
    }

    @Test
    @DisplayName("Nghỉ phép theo giờ 14:00–16:00 trừ khỏi giờ làm")
    void hourLeave() {
        var r = AttendanceCalculator.calculate(m(8, 0), m(17, 0), m(12, 0), m(13, 0), m(8, 0), m(17, 0), DS, DE, m(14, 0), m(16, 0));
        assertThat(r.actualHours()).isEqualTo(6.0);
    }

    @Test
    @DisplayName("Làm tròn phút trên trục tuyệt đối: lên / xuống không quấn qua nửa đêm")
    void roundingOnAbsoluteMinutes() {
        assertThat(AttendanceCalculationService.roundUpMinutes(m(23, 55), 15)).isEqualTo(m(24, 0));
        assertThat(AttendanceCalculationService.roundDownMinutesAbs(1440 + m(0, 7), 15)).isEqualTo(1440);
        assertThat(AttendanceCalculationService.roundUpMinutes(-10, 15)).isZero();
        assertThat(AttendanceCalculationService.roundUpMinutes(m(8, 3), 1)).isEqualTo(m(8, 3));
    }
}
