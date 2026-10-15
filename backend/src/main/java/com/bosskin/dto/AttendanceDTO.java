package com.bosskin.dto;

import com.bosskin.entity.Attendance;
import com.bosskin.entity.AttendanceRequest;
import com.bosskin.entity.LeaveRequest;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

public class AttendanceDTO {

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        private Long id;
        private Long employeeId;
        private String employeeCode;
        private String employeeFullName;
        private Long departmentId;
        private String departmentName;
        private LocalDate date;
        private LocalDateTime checkIn;
        private LocalDateTime checkOut;
        private Attendance.Status status;
        private String note;

        public static Response from(Attendance a) {
            var employee = a.getEmployee();
            var department = employee != null ? employee.getDepartment() : null;
            return Response.builder()
                .id(a.getId())
                .employeeId(employee != null ? employee.getId() : null)
                .employeeCode(employee != null ? employee.getEmployeeCode() : null)
                .employeeFullName(employee != null ? employee.getFullName() : null)
                .departmentId(department != null ? department.getId() : null)
                .departmentName(department != null ? department.getName() : null)
                .date(a.getDate())
                .checkIn(a.getCheckIn())
                .checkOut(a.getCheckOut())
                .status(a.getStatus())
                .note(a.getNote())
                .build();
        }
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class ShiftSlot {
        private Long shiftAssignmentId;
        private String shiftName;
        private String shiftColor;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime shiftStart;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime shiftEnd;
        private int breakMinutes;

        @JsonFormat(pattern = "HH:mm")
        private LocalTime checkIn;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime checkOut;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime checkInRaw;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime checkOutRaw;
        private boolean checkInRounded;
        private boolean checkOutRounded;
        private Attendance.Status status;

        @JsonFormat(pattern = "HH:mm")
        private LocalTime requestedCheckIn;
        private AttendanceRequest.Status requestedCheckInStatus;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime requestedCheckOut;
        private AttendanceRequest.Status requestedCheckOutStatus;
        private Integer requestedOvertimeMinutes;
        private AttendanceRequest.OvertimeScope requestedOvertimeScope;
        private AttendanceRequest.OvertimePeriod requestedOvertimePeriod;
        private AttendanceRequest.Status requestedOvertimeStatus;

        private double actualHours;
        private double regularDayHours;
        private double otDayHours;
        private double regularNightHours;
        private double otNightHours;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class TimesheetRow {
        private LocalDate date;
        private String dayLabel;   // T2..CN
        /** Ngày nghỉ theo lịch làm việc của phòng hoặc ngày lễ (bước J). */
        private boolean weekend;
        /** Tên ngày lễ / nghỉ bù / làm bù nếu có (bước J). */
        private String holidayName;

        // Shift
        private Long shiftAssignmentId;
        private String shiftName;
        private String shiftColor;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime shiftStart;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime shiftEnd;
        private int breakMinutes;

        // Actual attendance
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime checkIn;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime checkOut;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime checkInRaw;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime checkOutRaw;
        private boolean checkInRounded;
        private boolean checkOutRounded;
        private Attendance.Status status;

        @JsonFormat(pattern = "HH:mm")
        private LocalTime requestedCheckIn;
        private AttendanceRequest.Status requestedCheckInStatus;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime requestedCheckOut;
        private AttendanceRequest.Status requestedCheckOutStatus;
        private Integer requestedOvertimeMinutes;
        private AttendanceRequest.OvertimeScope requestedOvertimeScope;
        private AttendanceRequest.OvertimePeriod requestedOvertimePeriod;
        private AttendanceRequest.Status requestedOvertimeStatus;
        private List<AttendanceRequestDTO.Response> requests;
        private List<ShiftSlot> slots;

        // Attendance record ID (null if no record for this day)
        private Long attendanceId;
        private boolean approved;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime approvedAt;
        private String approvedByName;
        private String workFlags; // comma-separated: EARLY_IN,LATE_IN,EARLY_OUT,LATE_OUT,ON_TIME,OVERTIME,LEAVE

        // Computed hours
        private double actualHours;
        private double totalHours;
        private double regularDayHours;
        private double otDayHours;
        private double regularNightHours;
        private double otNightHours;

        // Leave info (approved leave for this day/slot)
        private Long leaveRequestId;
        private String leaveCode;
        private String leaveMode;   // DAY_RANGE or HOUR_RANGE
        private LeaveRequest.Status leaveStatus;
        private Boolean leaveApplied;
        private String leaveProcessedByName;
        private LocalDateTime leaveProcessedAt;
        private LocalDateTime leaveCreatedAt;
        private BigDecimal leaveAmount;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime leaveFromTime;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime leaveToTime;

        // Admin override
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime overrideCheckIn;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime overrideCheckOut;
        private Integer overrideBreakMinutes;
        private Integer overrideOtDayMinutes;
        private Integer overrideOtNightMinutes;
        private String overrideNote;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class DayViewRow {
        private Long employeeId;
        private String employeeCode;
        private String employeeFullName;
        private Long departmentId;
        private String departmentName;
        private LocalDate date;
        private String dayLabel;   // T2..CN
        /** Ngày nghỉ theo lịch làm việc của phòng hoặc ngày lễ (bước J). */
        private boolean weekend;
        /** Tên ngày lễ / nghỉ bù / làm bù nếu có (bước J). */
        private String holidayName;

        // Shift
        private Long shiftAssignmentId;
        private String shiftName;
        private String shiftColor;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime shiftStart;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime shiftEnd;
        private int breakMinutes;

        // Actual attendance
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime checkIn;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime checkOut;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime checkInRaw;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime checkOutRaw;
        private boolean checkInRounded;
        private boolean checkOutRounded;
        private Attendance.Status status;

        @JsonFormat(pattern = "HH:mm")
        private LocalTime requestedCheckIn;
        private AttendanceRequest.Status requestedCheckInStatus;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime requestedCheckOut;
        private AttendanceRequest.Status requestedCheckOutStatus;
        private Integer requestedOvertimeMinutes;
        private AttendanceRequest.OvertimeScope requestedOvertimeScope;
        private AttendanceRequest.OvertimePeriod requestedOvertimePeriod;
        private AttendanceRequest.Status requestedOvertimeStatus;
        private List<AttendanceRequestDTO.Response> requests;
        private List<ShiftSlot> slots;

        private Long attendanceId;

        private double actualHours;
        private double totalHours;
        private double regularDayHours;
        private double otDayHours;
        private double regularNightHours;
        private double otNightHours;

        // Leave info
        private Long leaveRequestId;
        private String leaveCode;
        private String leaveMode;
        private LeaveRequest.Status leaveStatus;
        private Boolean leaveApplied;
        private String leaveProcessedByName;
        private LocalDateTime leaveProcessedAt;
        private LocalDateTime leaveCreatedAt;
        private BigDecimal leaveAmount;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime leaveFromTime;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime leaveToTime;

        // Admin override fields
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime overrideCheckIn;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm")
        private LocalDateTime overrideCheckOut;
        private Integer overrideBreakMinutes;
        private Integer overrideOtDayMinutes;
        private Integer overrideOtNightMinutes;
        private String overrideNote;

        // Approve snapshot
        private boolean approved;
        private LocalDateTime approvedAt;
        private String approvedByName;
        private String workFlags;

        // Tất cả leave trong ngày (để hiển thị nhiều badge)
        private List<LeaveInfo> leaves;

        @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
        public static class LeaveInfo {
            private Long leaveRequestId;
            private String leaveCode;
            private String leaveMode;
            private LeaveRequest.Status leaveStatus;
            private Boolean leaveApplied;
            private String leaveProcessedByName;
            private LocalDateTime leaveProcessedAt;
            private LocalDateTime leaveCreatedAt;
            private BigDecimal leaveAmount;
            @JsonFormat(pattern = "HH:mm")
            private LocalTime leaveFromTime;
            @JsonFormat(pattern = "HH:mm")
            private LocalTime leaveToTime;
        }
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class AllowedLocation {
        private double latitude;
        private double longitude;
        private int radiusMeters;
        private String source; // "employee", "department", "company"
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class SelfTodayResponse {
        private boolean enabled;
        private String message;
        private Long employeeId;
        private String employeeName;
        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDate date; // ngày hiệu lực của ca (có thể là hôm qua nếu ca tràn đêm)
        private ShiftInfo shift;
        private List<ShiftInfo> shifts;
        private Response attendance;
        private boolean canCheckIn;
        private boolean canCheckOut;
        private List<AllowedLocation> allowedLocations; // null = free (no restriction)
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class ShiftInfo {
        private Long id;
        private String name;
        private String color;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime startTime;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime endTime;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime checkInFrom;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime checkInTo;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime checkOutFrom;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime checkOutTo;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class OverrideRequest {
        @JsonFormat(pattern = "HH:mm")
        private LocalTime overrideCheckIn;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime overrideCheckOut;
        private Integer overrideBreakMinutes;
        private Integer overrideOtDayMinutes;
        private Integer overrideOtNightMinutes;
        private String overrideNote;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ImportRow {
        private String date;                   // dd/MM/yyyy
        private String employeeCode;
        private String employeeName;           // read-only
        private String departmentName;         // read-only
        private String status;                 // PRESENT | ABSENT | LATE | HALF_DAY | LEAVE
        private String checkIn;                // HH:mm
        private String checkOut;               // HH:mm
        private String note;
        private String overrideCheckIn;        // HH:mm
        private String overrideCheckOut;       // HH:mm
        private String overrideBreakMinutes;
        private String overrideOtDayMinutes;
        private String overrideOtNightMinutes;
        private String snapActualHours;        // read-only
        private String snapDayOt;              // read-only
        private String snapNightOt;            // read-only
        private String approved;               // read-only
    }
}
