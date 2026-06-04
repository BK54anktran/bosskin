package com.bosskin.dto;

import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

public class DashboardDTO {

    @Getter @Builder
    public static class Response {
        private TodayStats todayStats;
        private List<AttendanceRow> todayAttendance;
        private RecentPayroll recentPayroll;
        private LocalDate date;
    }

    @Getter @Builder
    public static class TodayStats {
        private long totalEmployees;
        private long present;
        private long onLeave;
        private long absent;
        private long late;
    }

    @Getter @Builder
    public static class AttendanceRow {
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String departmentName;
        private LocalDateTime checkIn;
        private LocalDateTime checkOut;
        private String status;
        private boolean late;
    }

    @Getter @Builder
    public static class RecentPayroll {
        private Integer year;
        private Integer month;
        private BigDecimal totalNetSalary;
        private long employeeCount;
        private String status;
    }
}
