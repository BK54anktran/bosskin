package com.bosskin.core;

import java.time.LocalDate;

/**
 * Tính kỳ lương dựa theo ngày chốt (cutoffDay).
 *
 * cutoffDay = 1  → kỳ tháng T = 01/T .. cuối/T  (hành vi mặc định)
 * cutoffDay = 25 → kỳ tháng T = 25/(T-1) .. 24/T
 */
public record PayrollPeriod(LocalDate from, LocalDate to) {

    public static PayrollPeriod of(int year, int month, int cutoffDay) {
        if (cutoffDay <= 1) {
            LocalDate from = LocalDate.of(year, month, 1);
            return new PayrollPeriod(from, from.withDayOfMonth(from.lengthOfMonth()));
        }
        // from = cutoffDay của tháng trước
        LocalDate base = LocalDate.of(year, month, 1);
        LocalDate prevMonth = base.minusMonths(1);
        int maxDayPrev = prevMonth.lengthOfMonth();
        LocalDate from = prevMonth.withDayOfMonth(Math.min(cutoffDay, maxDayPrev));
        // to = cutoffDay - 1 của tháng hiện tại
        LocalDate to = base.withDayOfMonth(Math.min(cutoffDay - 1, base.lengthOfMonth()));
        return new PayrollPeriod(from, to);
    }
}
