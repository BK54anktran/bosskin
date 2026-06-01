package com.bosskin.core;

import java.time.LocalTime;
import java.util.LinkedHashSet;
import java.util.Set;

/**
 * Tính các trạng thái làm việc của 1 ngày chấm công.
 * Nhiều flag có thể đồng thời.
 *
 * Tolerance: ±5 phút được coi là ON_TIME.
 */
public class WorkFlagCalculator {

    public enum Flag {
        LATE_IN,    // đi muộn hơn ca (> tolerance)
        EARLY_OUT,  // về sớm hơn ca (> tolerance)
        ON_TIME,    // check-in và check-out đều trong tolerance
        OVERTIME,   // có approved OT (otDayHours + otNightHours > 0)
        LEAVE,      // có nghỉ phép trong ngày
    }

    public static Set<Flag> calculate(
        LocalTime shiftStart,
        LocalTime shiftEnd,
        LocalTime checkIn,
        LocalTime checkOut,
        double otDayHours,
        double otNightHours,
        boolean hasLeave
    ) {
        return calculate(shiftStart, shiftEnd, checkIn, checkOut, otDayHours, otNightHours, hasLeave, 5, 5);
    }

    public static Set<Flag> calculate(
        LocalTime shiftStart,
        LocalTime shiftEnd,
        LocalTime checkIn,
        LocalTime checkOut,
        double otDayHours,
        double otNightHours,
        boolean hasLeave,
        Integer inToleranceMinutes,
        Integer outToleranceMinutes
    ) {
        Set<Flag> flags = new LinkedHashSet<>();
        int inTol = inToleranceMinutes != null ? Math.max(0, inToleranceMinutes) : 0;
        int outTol = outToleranceMinutes != null ? Math.max(0, outToleranceMinutes) : 0;

        if (hasLeave) flags.add(Flag.LEAVE);
        if (otDayHours + otNightHours > 0) flags.add(Flag.OVERTIME);

        if (shiftStart == null || shiftEnd == null || checkIn == null || checkOut == null) {
            return flags;
        }

        int shiftStartMin = shiftStart.toSecondOfDay() / 60;
        int shiftEndMin   = shiftEnd.toSecondOfDay() / 60;
        if (shiftEndMin <= shiftStartMin) shiftEndMin += 1440; // overnight

        int checkInMin  = checkIn.toSecondOfDay() / 60;
        int checkOutMin = checkOut.toSecondOfDay() / 60;
        // Wrap checkout chỉ khi thực sự qua ngày — dùng shift làm anchor
        // Nếu checkout < checkin trong cùng ngày, không wrap vì đây là 2 thời điểm độc lập
        // (check-in từ actual, check-out từ request hoặc ngược lại)
        if (checkOutMin < checkInMin && (shiftEndMin <= shiftStartMin)) {
            // Ca overnight: checkout hợp lệ sau nửa đêm
            checkOutMin += 1440;
        }

        int inDiff  = checkInMin  - shiftStartMin;  // >0 = late, <0 = early
        int outDiff = checkOutMin - shiftEndMin;     // >0 = late out, <0 = early out

        // Nếu checkout trước khi ca bắt đầu → hoàn toàn ngoài ca (trước ca)
        // Nếu checkin sau khi ca kết thúc → hoàn toàn ngoài ca (sau ca)
        // Các trường hợp này không có giờ trong ca nên không tính EARLY_OUT / LATE_IN tương ứng
        // Chỉ tính flags khi có giờ giao nhau với ca
        boolean fullyBeforeShift = checkOutMin <= shiftStartMin + outTol;
        boolean fullyAfterShift  = checkInMin  >= shiftEndMin   - inTol;

        if (!fullyBeforeShift && !fullyAfterShift) {
            boolean inOnTime  = inDiff  <= inTol;   // sớm hoặc đúng giờ
            boolean outOnTime = outDiff >= -outTol;  // trễ hoặc đúng giờ
            if (inDiff >  inTol)  flags.add(Flag.LATE_IN);
            if (outDiff < -outTol) flags.add(Flag.EARLY_OUT);
            if (inOnTime && outOnTime) flags.add(Flag.ON_TIME);
        } else if (fullyAfterShift) {
            if (inDiff > inTol) flags.add(Flag.LATE_IN);
        }

        return flags;
    }

    public static String serialize(Set<Flag> flags) {
        if (flags == null || flags.isEmpty()) return null;
        StringBuilder sb = new StringBuilder();
        for (Flag f : flags) {
            if (!sb.isEmpty()) sb.append(',');
            sb.append(f.name());
        }
        return sb.toString();
    }

    public static Set<Flag> deserialize(String raw) {
        Set<Flag> flags = new LinkedHashSet<>();
        if (raw == null || raw.isBlank()) return flags;
        for (String part : raw.split(",")) {
            try { flags.add(Flag.valueOf(part.trim())); } catch (IllegalArgumentException ignored) {}
        }
        return flags;
    }
}
