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
        private boolean checkInWithoutShift;
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
        /** Vùng lương tối thiểu 1–4 (trần BHTN), V13. */
        private int minWageRegion;
        /** Bước J: công chuẩn đếm theo lịch tuần + ngày lễ thay cho số cố định. */
        private boolean standardDaysFromCalendar;
        /** Bước M: tỷ lệ BH công ty đóng, đơn vị % (17.5 = 17,5%). */
        private BigDecimal employerSocialPercent;
        private BigDecimal employerHealthPercent;
        private BigDecimal employerUnemploymentPercent;
    }

    /** Bước K: ai duyệt đơn nghỉ / sửa công / đổi ca. */
    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class ApprovalSetting {
        /** PERMISSION (mặc định: người có quyền duyệt + phạm vi) | MANAGER_THEN_HR. */
        private String mode;
    }

    /** Bước L: báo trước hợp đồng sắp hết hạn. */
    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class ContractSetting {
        private int expiryWarningDays;
    }

    /** V23: đăng ký lịch làm việc. */
    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class ShiftRegistrationSetting {
        private boolean enabled;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        private AttendanceSetting attendance;
        private LeaveSetting leaves;
        private PayrollSetting payroll;
        private ApprovalSetting approval;
        private ContractSetting contract;
        private ShiftRegistrationSetting shiftRegistration;
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
        private Boolean checkInWithoutShift;
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
        /** Không gửi = giữ nguyên. */
        private Integer minWageRegion;
        /** Không gửi = giữ nguyên. */
        private Boolean standardDaysFromCalendar;
        /** Bước M: tỷ lệ BH công ty đóng (%, 0–50). Không gửi = giữ nguyên. */
        private BigDecimal employerSocialPercent;
        private BigDecimal employerHealthPercent;
        private BigDecimal employerUnemploymentPercent;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ApprovalUpsert {
        @NotNull private String mode;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ContractUpsert {
        @NotNull private Integer expiryWarningDays;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Upsert {
        @Valid @NotNull private AttendanceUpsert attendance;
        @Valid @NotNull private LeaveUpsert leaves;
        @Valid private PayrollUpsert payroll;
        /** Không gửi = giữ nguyên. */
        @Valid private ApprovalUpsert approval;
        /** Không gửi = giữ nguyên. */
        @Valid private ContractUpsert contract;
        /** V23. Không gửi = giữ nguyên. */
        private ShiftRegistrationSetting shiftRegistration;
    }
}
