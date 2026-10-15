package com.bosskin.service;

import java.util.ArrayList;
import java.util.List;

/**
 * Tính giờ công trên trục thời gian TUYỆT ĐỐI: mọi mốc là số phút kể từ 00:00 của ngày công (có thể âm hoặc ≥ 1440),
 * nên giờ làm = giờ ra − giờ vào bằng hiệu số thật, không phải đoán "giờ ra nhỏ hơn giờ vào thì là qua đêm".
 * Ghép giờ-trong-ngày thành mốc tuyệt đối do {@link com.bosskin.core.AttendanceTimes} và {@link AttendanceCalculationService} làm.
 */
public class AttendanceCalculator {

    private static final int MINS = 1440;

    public record Result(
        double actualHours,
        double regularDayHours,
        double regularNightHours,
        double otDayHours,
        double otNightHours,
        /** Thời gian có mặt ngoài giờ ca (đã trừ nghỉ, nghỉ phép) — trần cho OT ngoài ca (A15). */
        double outsideShiftHours
    ) {
        static final Result ZERO = new Result(0, 0, 0, 0, 0, 0);

        public Result(double actualHours, double regularDayHours, double regularNightHours,
                      double otDayHours, double otNightHours) {
            this(actualHours, regularDayHours, regularNightHours, otDayHours, otNightHours, 0);
        }
    }

    /**
     * @param shiftStart / shiftEnd  khung ca (shiftEnd &gt; shiftStart); null = không có ca
     * @param breakStart / breakEnd  giờ nghỉ giữa ca cùng trục với ca; null = không nghỉ
     * @param checkIn / checkOut     giờ vào / ra (đã làm tròn); ra không sau vào → 0 giờ
     * @param dayStart / dayEnd      khung giờ "ban ngày" trong ngày (phút trong ngày) — phần còn lại là giờ đêm
     * @param leaveFrom / leaveTo    giờ nghỉ phép trong ngày, cùng trục; null = không có
     */
    public static Result calculate(
        Integer shiftStart, Integer shiftEnd,
        Integer breakStart, Integer breakEnd,
        int checkIn, int checkOut,
        int dayStart, int dayEnd,
        Integer leaveFrom, Integer leaveTo
    ) {
        // Khoảng vào → ra hợp lệ là (0, 24 giờ): ra không sau vào, hoặc từ 24 giờ trở lên (vd. vào = ra cùng phút bị ghép sang hôm sau) → 0 giờ
        if (checkOut <= checkIn || checkOut - checkIn >= MINS) return Result.ZERO;

        int[] actual = {checkIn, checkOut};
        List<int[]> actualNet = (breakStart != null && breakEnd != null)
            ? subtract(actual, new int[]{breakStart, breakEnd})
            : List.of(actual);

        if (leaveFrom != null && leaveTo != null && leaveTo > leaveFrom) {
            actualNet = subtractAll(actualNet, List.of(new int[]{leaveFrom, leaveTo}));
        }

        double actualHours = toHours(actualNet);

        if (shiftStart == null || shiftEnd == null) {
            double regDay = dayHours(actualNet, dayStart, dayEnd);
            return new Result(actualHours, regDay, actualHours - regDay, 0, 0);
        }

        List<int[]> shiftNet = (breakStart != null && breakEnd != null)
            ? subtract(new int[]{shiftStart, shiftEnd}, new int[]{breakStart, breakEnd})
            : List.of(new int[]{shiftStart, shiftEnd});

        // Chỉ tính giờ trong ca — thời gian ngoài ca bỏ qua hoàn toàn.
        // OT ngoài ca chỉ được tính khi có approved OT request (xử lý ở tầng controller).
        List<int[]> regular = intersectAll(actualNet, shiftNet);

        double regDay   = dayHours(regular, dayStart, dayEnd);
        double regNight = toHours(regular) - regDay;
        double inShiftHours = toHours(regular);

        return new Result(inShiftHours, regDay, regNight, 0, 0, Math.max(0, actualHours - inShiftHours));
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private static List<int[]> subtract(int[] a, int[] b) {
        if (b[1] <= a[0] || b[0] >= a[1]) return List.of(a);
        var r = new ArrayList<int[]>();
        if (a[0] < b[0]) r.add(new int[]{a[0], b[0]});
        if (a[1] > b[1]) r.add(new int[]{b[1], a[1]});
        return r;
    }

    private static List<int[]> subtractAll(List<int[]> src, List<int[]> remove) {
        var cur = new ArrayList<>(src);
        for (int[] rm : remove) {
            var next = new ArrayList<int[]>();
            for (int[] c : cur) next.addAll(subtract(c, rm));
            cur = next;
        }
        return cur;
    }

    private static int[] intersect(int[] a, int[] b) {
        int s = Math.max(a[0], b[0]), e = Math.min(a[1], b[1]);
        return s < e ? new int[]{s, e} : null;
    }

    private static List<int[]> intersectAll(List<int[]> a, List<int[]> b) {
        var r = new ArrayList<int[]>();
        for (int[] ai : a) for (int[] bi : b) {
            var x = intersect(ai, bi);
            if (x != null) r.add(x);
        }
        return r;
    }

    private static double toHours(List<int[]> iv) {
        return iv.stream().mapToInt(i -> i[1] - i[0]).sum() / 60.0;
    }

    /** Giờ ban ngày: giao với khung [ds, de] của mọi ngày mà khoảng chạm tới (từ hôm trước tới hai ngày sau ngày công). */
    private static double dayHours(List<int[]> intervals, int ds, int de) {
        var daySlots = new ArrayList<int[]>();
        for (int k = -1; k <= 2; k++) daySlots.add(new int[]{ds + k * MINS, de + k * MINS});
        return toHours(intersectAll(intervals, daySlots));
    }
}
