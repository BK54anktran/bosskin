package com.bosskin.dto;

import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
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
    public static class RangeResponse {
        private LocalDate from;
        private LocalDate to;
        private RangeStats stats;
        private List<RangeEmployeeRow> rows;
        private List<RangeDailyPoint> dailyTrend;
    }

    @Getter @Builder
    public static class RangeDailyPoint {
        private LocalDate date;
        private long present;
        private long late;
        private long absent;
        private long onLeave;
    }

    @Getter @Builder
    public static class RangeStats {
        private long totalEmployees;
        private long totalWorkDays;   // tổng ngày có mặt (present + late)
        private long totalLateDays;
        private long totalAbsentDays;
        private long totalLeaveDays;
    }

    @Getter @Builder
    public static class RangeEmployeeRow {
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String departmentName;
        private long presentDays;
        private long lateDays;
        private long absentDays;
        private long leaveDays;
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

    // ── Analytics ─────────────────────────────────────────────────────────────

    @Getter @Builder
    public static class AnalyticsResponse {
        private int year;
        private List<MonthlySalaryStat> salaryTrend;      // 12 tháng
        private List<DailyAttendanceStat> attendanceTrend; // N ngày gần nhất
        private List<TopLateEmployee> topLate;            // top 10 muộn
        private RangeStats overallStats;                  // tổng hợp năm
    }

    @Getter @Builder
    public static class MonthlySalaryStat {
        private int month;
        private BigDecimal totalNetSalary;
        private long employeeCount;
    }

    @Getter @Builder
    public static class DailyAttendanceStat {
        private LocalDate date;
        private long present;
        private long late;
        private long absent;
        private double totalHours;       // tổng giờ công thực tế
        private BigDecimal estimatedCost; // ước tính chi phí lương ngày đó
        private List<DailyAttendanceGradeBreakdown> gradeBreakdown;
    }

    @Getter @Builder
    public static class DailyAttendanceGradeBreakdown {
        private Long salaryGradeId;
        private String salaryGradeCode;
        private String salaryGradeName;
        private String payType;
        private double totalHours;
        private BigDecimal estimatedCost;
        private long employeeCount;
    }

    @Getter @Builder
    public static class TopLateEmployee {
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String departmentName;
        private long lateDays;
    }

    // ── KPI Summary (Overview tab) ─────────────────────────────────────────────

    @Getter @Builder
    public static class KpiResponse {
        private int totalActiveEmployees;
        private int newHiresThisMonth;
        private int newHiresLastMonth;
        private int resignedThisMonth;
        private double attritionRate;
        private long todayPresent;
        private long todayAbsent;
        private long todayOnLeave;
        private long todayLate;
        private double todayAttendanceRate;
        private BigDecimal currentMonthPayroll;
        private long currentMonthPayrollCount;
        private String currentMonthPayrollStatus;
        /** Kỳ của số liệu lương ở trên (kỳ gần nhất đã chốt). */
        private Integer currentMonthPayrollYear;
        private Integer currentMonthPayrollMonth;
        private LocalDate date;
    }

    // ── Risk & Warning Summary (Overview tab) ──────────────────────────────────

    @Getter @Builder
    public static class RiskResponse {
        private List<RepeatedLateRisk> repeatedLate;
        private List<MissingCheckoutRisk> missingCheckout;
        private List<ProbationEndingRisk> probationEnding;
        private List<NoSalaryGradeRisk> noSalaryGrade;
        /** Bước L: hợp đồng cần gia hạn (chỉ khi có CONTRACT_VIEW). */
        private List<ContractExpiringRisk> contractExpiring;
        /** Bước N: tài liệu nhân sự sắp / đã hết hạn (chỉ khi có EMPLOYEE_DOCUMENT_VIEW). */
        private List<DocumentExpiringRisk> documentExpiring;
        private int totalWarnings;
    }

    @Getter @Builder
    public static class DocumentExpiringRisk {
        private Long documentId;
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String departmentName;
        private String typeName;
        private LocalDate expiresOn;
        /** Âm = đã quá hạn. */
        private int daysLeft;
    }

    @Getter @Builder
    public static class ContractExpiringRisk {
        private Long contractId;
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String departmentName;
        private String contractNo;
        private LocalDate endDate;
        /** Âm = đã quá hạn. */
        private int daysLeft;
    }

    @Getter @Builder
    public static class RepeatedLateRisk {
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String departmentName;
        private int lateDaysThisMonth;
    }

    @Getter @Builder
    public static class MissingCheckoutRisk {
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String departmentName;
        private LocalTime checkInTime;
    }

    @Getter @Builder
    public static class ProbationEndingRisk {
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String departmentName;
        private LocalDate joinDate;
        private LocalDate probationEnd;
        private int daysLeft;
    }

    @Getter @Builder
    public static class NoSalaryGradeRisk {
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String departmentName;
    }
}
