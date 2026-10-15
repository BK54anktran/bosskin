package com.bosskin.core;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;

/**
 * Ghép giờ-trong-ngày thành ngày giờ đầy đủ để tính công bằng hiệu số thật, không đoán qua đêm.
 * Giờ vào / ra thật lưu sẵn ngày giờ; giờ sửa tay (và đơn chấm công) chỉ có HH:mm nên cần chọn ngày:
 * <ul>
 *   <li>Có ca: giờ vào lấy ngày (hôm trước / ngày công / hôm sau) gần giờ bắt đầu ca nhất; giờ ra lấy ngày gần giờ kết thúc ca nhất
 *       mà sau giờ vào và cách giờ vào dưới 24 giờ.</li>
 *   <li>Không ca: giờ vào = ngày công; giờ ra = ngày của giờ vào, cộng 1 ngày nếu không sau giờ vào ("nhỏ hơn thì +1 ngày").</li>
 * </ul>
 * "Số ngày lệch" = số ngày giờ đó cách ngày công (0 = cùng ngày, 1 = hôm sau, -1 = hôm trước); app hiện chú thích nhỏ "+N".
 */
public final class AttendanceTimes {

    public static final int DAY_MINUTES = 1440;
    private static final Duration MAX_SPAN = Duration.ofHours(24);

    private AttendanceTimes() {}

    public static LocalDateTime at(LocalDate workDate, int dayOffset, LocalTime time) {
        return workDate.plusDays(dayOffset).atTime(time);
    }

    public static int dayOffset(LocalDate workDate, LocalDateTime t) {
        return t == null ? 0 : (int) ChronoUnit.DAYS.between(workDate, t.toLocalDate());
    }

    /** Số phút từ 00:00 ngày công tới t (có thể âm hoặc ≥ 1440). */
    public static int minutesFrom(LocalDate workDate, LocalDateTime t) {
        return (int) Duration.between(workDate.atStartOfDay(), t.truncatedTo(ChronoUnit.MINUTES)).toMinutes();
    }

    /** Khoảng vào → ra hợp lệ: ra sau vào và dưới 24 giờ. */
    public static boolean validSpan(LocalDateTime in, LocalDateTime out) {
        if (in == null || out == null) return true;
        Duration d = Duration.between(in.truncatedTo(ChronoUnit.MINUTES), out.truncatedTo(ChronoUnit.MINUTES));
        return d.compareTo(Duration.ZERO) > 0 && d.compareTo(MAX_SPAN) < 0;
    }

    /** Giờ vào: ngày gần giờ bắt đầu ca nhất (hôm trước / ngày công / hôm sau); không ca → ngày công. */
    public static LocalDateTime resolveIn(LocalDate workDate, LocalTime time, LocalTime shiftStart) {
        if (time == null) return null;
        LocalDateTime base = workDate.atTime(time);
        if (shiftStart == null) return base;
        LocalDateTime target = workDate.atTime(shiftStart);
        LocalDateTime best = base;
        for (int d = -1; d <= 1; d++) {
            LocalDateTime cand = workDate.plusDays(d).atTime(time);
            if (distance(cand, target) < distance(best, target)) best = cand;
        }
        return best;
    }

    /**
     * Giờ ra: sau giờ vào {@code in} và cách dưới 24 giờ. Có ca → ngày gần giờ kết thúc ca nhất; không ca → ngày đầu tiên sau giờ vào.
     * Chưa biết giờ vào → ngày công (hoặc ngày kết thúc ca nếu ca qua đêm).
     */
    public static LocalDateTime resolveOut(LocalDate workDate, LocalTime time, LocalDateTime in, LocalTime shiftStart, LocalTime shiftEnd) {
        if (time == null) return null;
        LocalDateTime shiftEndAt = null;
        if (shiftStart != null && shiftEnd != null) {
            shiftEndAt = (shiftEnd.isAfter(shiftStart) ? workDate : workDate.plusDays(1)).atTime(shiftEnd);
        }
        if (in == null) {
            return shiftEndAt != null ? workDate.plusDays(dayOffset(workDate, shiftEndAt)).atTime(time) : workDate.atTime(time);
        }
        LocalDateTime best = null;
        for (int d = 0; d <= 2; d++) {
            LocalDateTime cand = in.toLocalDate().plusDays(d).atTime(time);
            if (!validSpan(in, cand)) continue;
            if (shiftEndAt == null) { best = cand; break; } // không ca: ngày đầu tiên sau giờ vào
            if (best == null || distance(cand, shiftEndAt) < distance(best, shiftEndAt)) best = cand;
        }
        return best != null ? best : in.toLocalDate().plusDays(1).atTime(time);
    }

    /**
     * Số ngày lệch cho cặp giờ sửa tay. Chỉ sửa một đầu thì đầu kia lấy giờ thật ({@code rawIn} / {@code rawOut}).
     * Trả {inDay, outDay} (0 cho đầu không sửa).
     */
    public static int[] overrideDays(LocalDate workDate, LocalTime ovIn, LocalTime ovOut,
                                     LocalDateTime rawIn, LocalDateTime rawOut, LocalTime shiftStart, LocalTime shiftEnd) {
        LocalDateTime in = ovIn != null ? resolveIn(workDate, ovIn, shiftStart) : rawIn;
        LocalDateTime out = ovOut != null ? resolveOut(workDate, ovOut, in, shiftStart, shiftEnd) : rawOut;
        return new int[]{
            ovIn != null ? dayOffset(workDate, in) : 0,
            ovOut != null ? dayOffset(workDate, out) : 0};
    }
}
