package com.bosskin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public class ShiftDTO {

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ShiftRequest {
        @NotBlank
        private String name;
        @NotBlank
        private String code;
        private LocalTime startTime;
        private LocalTime endTime;
        private LocalTime breakStart;
        private LocalTime breakEnd;
        private String groupName;
        private String color;
        private List<Long> departmentIds;
        /** FIXED (mặc định) | FLEXIBLE */
        private String shiftType;
        /** Ca linh hoạt: số phút phải làm trong khung giờ */
        private Integer requiredMinutes;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class ShiftResponse {
        private Long   id;
        private String name;
        private String code;
        private String startTime;
        private String endTime;
        private String breakStart;
        private String breakEnd;
        private Integer workMinutes;
        private String  groupName;
        private String  color;
        private boolean active;
        private List<DeptRef> departments;
        private String  shiftType;
        private Integer requiredMinutes;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class DeptRef {
        private Long   id;
        private String name;
    }

    // ── Assignment ──────────────────────────────────────────────────────

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class AssignRequest {
        @NotNull private Long      employeeId;
        private Long               shiftId;          // null for custom hours
        @NotNull private LocalDate workDate;
        private String             note;
        private LocalTime          customStartTime;  // set when shiftId is null
        private LocalTime          customEndTime;
        private LocalTime          customBreakStart;
        private LocalTime          customBreakEnd;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class BulkAssignRequest {
        @NotNull private List<Long>      employeeIds;
        @NotNull private Long            shiftId;
        @NotNull private LocalDate       startDate;
        @NotNull private LocalDate       endDate;
        private List<Integer> excludeWeekdays; // 1=Mon … 7=Sun
        private String note;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class AssignResponse {
        private Long   id;
        private Long   employeeId;
        private String employeeName;
        private Long   shiftId;
        private String shiftName;
        private String shiftCode;
        private String shiftColor;
        private String workDate;
        private String note;
        private String customStartTime;
        private String customEndTime;
        private String customBreakStart;
        private String customBreakEnd;
        private boolean custom;
        private boolean hasAttendance;
        private boolean approved;
    }
}
