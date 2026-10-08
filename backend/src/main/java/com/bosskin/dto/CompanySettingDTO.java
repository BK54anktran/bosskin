package com.bosskin.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalTime;

public class CompanySettingDTO {

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class AttendanceSetting {
        private boolean dayNightMode;
        private boolean otEnabled;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime dayStartTime;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime dayEndTime;
        private boolean locationCheckEnabled;
        private boolean deviceBindingEnabled;
        private Double checkInLatitude;
        private Double checkInLongitude;
        private int checkInRadiusMeters;
        private int checkInBeforeMinutes;
        private int checkInAfterMinutes;
        private int checkOutBeforeMinutes;
        private int checkOutAfterMinutes;
        private Integer checkInToleranceMinutes;
        private Integer checkOutToleranceMinutes;
        private Integer roundingCheckInMinutes;
        private Integer roundingCheckOutMinutes;
        private Integer roundingWorkMinutes;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class LeaveSetting {
        private BigDecimal hoursPerDay;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class PayrollSetting {
        private int standardWorkDays;
        private int payrollCutoffDay;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        private AttendanceSetting attendance;
        private LeaveSetting leaves;
        private PayrollSetting payroll;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class AttendanceUpsert {
        @NotNull private Boolean dayNightMode;
        @NotNull private Boolean otEnabled;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime dayStartTime;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime dayEndTime;
        private Boolean locationCheckEnabled;
        private Boolean deviceBindingEnabled;
        private Double checkInLatitude;
        private Double checkInLongitude;
        private Integer checkInRadiusMeters;
        private Integer checkInBeforeMinutes;
        private Integer checkInAfterMinutes;
        private Integer checkOutBeforeMinutes;
        private Integer checkOutAfterMinutes;
        private Integer checkInToleranceMinutes;
        private Integer checkOutToleranceMinutes;
        private Integer roundingCheckInMinutes;
        private Integer roundingCheckOutMinutes;
        private Integer roundingWorkMinutes;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class LeaveUpsert {
        @NotNull private BigDecimal hoursPerDay;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class PayrollUpsert {
        @NotNull private Integer standardWorkDays;
        @NotNull private Integer payrollCutoffDay;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Upsert {
        @Valid @NotNull private AttendanceUpsert attendance;
        @Valid @NotNull private LeaveUpsert leaves;
        @Valid private PayrollUpsert payroll;
    }
}
