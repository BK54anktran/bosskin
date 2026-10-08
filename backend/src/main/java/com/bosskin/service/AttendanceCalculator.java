package com.bosskin.service;

import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

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

    public static Result calculate(
        LocalTime shiftStart, LocalTime shiftEnd,
        LocalTime breakStart, LocalTime breakEnd,
        LocalTime checkIn,    LocalTime checkOut,
        LocalTime dayStart,   LocalTime dayEnd
    ) {
        return calculate(shiftStart, shiftEnd, breakStart, breakEnd, checkIn, checkOut, dayStart, dayEnd, null, null);
    }

    public static Result calculate(
        LocalTime shiftStart, LocalTime shiftEnd,
        LocalTime breakStart, LocalTime breakEnd,
        LocalTime checkIn,    LocalTime checkOut,
        LocalTime dayStart,   LocalTime dayEnd,
        LocalTime leaveFrom,  LocalTime leaveTo
    ) {
        if (checkIn == null || checkOut == null) return Result.ZERO;

        int[] actual = range(checkIn, checkOut);

        List<int[]> actualNet = (breakStart != null && breakEnd != null)
            ? subtract(actual, range(breakStart, breakEnd))
            : List.of(actual);

        if (leaveFrom != null && leaveTo != null) {
            actualNet = subtractAll(actualNet, List.of(range(leaveFrom, leaveTo)));
        }

        double actualHours = toHours(actualNet);
        int ds = dayStart.toSecondOfDay() / 60;
        int de = dayEnd.toSecondOfDay() / 60;

        if (shiftStart == null || shiftEnd == null) {
            double regDay = dayHours(actualNet, ds, de);
            return new Result(actualHours, regDay, actualHours - regDay, 0, 0);
        }

        List<int[]> shiftNet = (breakStart != null && breakEnd != null)
            ? subtract(range(shiftStart, shiftEnd), range(breakStart, breakEnd))
            : List.of(range(shiftStart, shiftEnd));

        // Chỉ tính giờ trong ca — thời gian ngoài ca bỏ qua hoàn toàn.
        // OT ngoài ca chỉ được tính khi có approved OT request (xử lý ở tầng controller).
        List<int[]> regular = intersectAll(actualNet, shiftNet);

        double regDay   = dayHours(regular, ds, de);
        double regNight = toHours(regular) - regDay;
        double inShiftHours = toHours(regular);

        return new Result(inShiftHours, regDay, regNight, 0, 0, Math.max(0, actualHours - inShiftHours));
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private static int[] range(LocalTime s, LocalTime e) {
        int sm = s.toSecondOfDay() / 60, em = e.toSecondOfDay() / 60;
        if (em <= sm) em += MINS;
        return new int[]{sm, em};
    }

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

    private static double dayHours(List<int[]> intervals, int ds, int de) {
        // Check against [ds,de] and [ds+1440, de+1440] (for overnight shifts)
        var daySlots = List.of(new int[]{ds, de}, new int[]{ds + MINS, de + MINS});
        return toHours(intersectAll(intervals, daySlots));
    }
}
