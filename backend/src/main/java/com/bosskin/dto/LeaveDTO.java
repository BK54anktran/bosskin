package com.bosskin.dto;

import com.bosskin.entity.LeaveAccrualRule;
import com.bosskin.entity.LeaveGrant;
import com.bosskin.entity.LeaveRequest;
import com.bosskin.entity.LeaveType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

public class LeaveDTO {

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class LeaveTypeResponse {
        private Long id;
        private String code;
        private String name;
        private LeaveType.Unit unit;
        private BigDecimal deductPerDay;
        private boolean paid;
        private boolean requiresBalance;
        private boolean active;
        private String description;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class LeaveTypeUpsert {
        @NotBlank private String code;
        @NotBlank private String name;
        @NotNull private LeaveType.Unit unit;
        @NotNull private BigDecimal deductPerDay;
        @NotNull private Boolean paid;
        /** Trừ quỹ phép hay không; bỏ trống thì theo "có lương" (có lương → trừ). */
        private Boolean requiresBalance;
        @NotNull private Boolean active;
        private String description;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class LeaveGrantResponse {
        private Long id;
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private Long departmentId;
        private String departmentName;
        private Long leaveTypeId;
        private String leaveTypeName;
        private LeaveType.Unit leaveUnit;
        private LeaveGrant.Source source;
        private BigDecimal grantDays;
        private BigDecimal grantHours;
        private BigDecimal usedDays;
        private BigDecimal usedHours;
        private BigDecimal remainingDays;
        private BigDecimal remainingHours;
        private LocalDate grantedAt;
        private LocalDate validFrom;
        private LocalDate validTo;
        private String note;
    }

    /** L13 — một dòng sổ trừ/hoàn phép. */
    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class LedgerEntryResponse {
        private Long id;
        private String kind;              // DEDUCT | REFUND
        private Long grantId;
        private String grantLeaveTypeName; // null = quỹ chung
        private LocalDate grantedAt;
        private Long requestId;
        private String requestLeaveTypeName;
        private LocalDate requestFromDate;
        private LocalDate requestToDate;
        private BigDecimal days;
        private BigDecimal hours;
        private java.time.LocalDateTime createdAt;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ManualGrantRequest {
        @NotNull private Long employeeId;
        private Long leaveTypeId;
        private BigDecimal grantDays;
        private BigDecimal grantHours;
        private LocalDate grantedAt;
        private LocalDate validFrom;
        private LocalDate validTo;
        private Integer expireAfterDays;
        @NotBlank private String note;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class LeaveRequestResponse {
        private Long id;
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private Long departmentId;
        private String departmentName;
        private Long leaveTypeId;
        private String leaveTypeName;
        private LeaveType.Unit leaveUnit;
        private LeaveRequest.Mode mode;
        private LocalDate fromDate;
        private LocalDate toDate;
        private LocalTime fromTime;
        private LocalTime toTime;
        private BigDecimal requestedAmount;
        private LeaveRequest.Status status;
        private boolean applied;
        private String reason;
        private String adminNote;
        private String processedByName;
        private LocalDateTime createdAt;
        private LocalDateTime processedAt;
        private Long parentId;
        private List<LeaveRequestResponse> children;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class CreateLeaveRequest {
        private Long employeeId;
        @NotNull private Long leaveTypeId;
        @NotNull private LeaveRequest.Mode mode;
        @NotNull private LocalDate fromDate;
        @NotNull private LocalDate toDate;
        private LocalTime fromTime;
        private LocalTime toTime;
        private String reason;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ProcessLeaveRequest {
        private String adminNote;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class UpdateAppliedRequest {
        private boolean applied;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class LeaveAccrualRuleResponse {
        private Long id;
        private String name;
        private Long departmentId;
        private String departmentName;
        private BigDecimal grantDays;
        private BigDecimal grantHours;
        private LeaveAccrualRule.Frequency frequency;
        private Integer dayOfMonth;
        private Integer monthOfYear;
        private Integer minTenureYears;
        private LocalDate validFrom;
        private LocalDate validTo;
        private Integer expireAfterDays;
        private boolean active;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class LeaveAccrualRuleUpsert {
        @NotBlank private String name;
        private Long departmentId;
        private BigDecimal grantDays;
        private BigDecimal grantHours;
        @NotNull private LeaveAccrualRule.Frequency frequency;
        private Integer dayOfMonth;
        private Integer monthOfYear;
        private Integer minTenureYears;
        private LocalDate validFrom;
        private LocalDate validTo;
        private Integer expireAfterDays;
        @NotNull private Boolean active;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class LeaveOverviewResponse {
        private List<LeaveRequestResponse> requests;
        private List<LeaveGrantResponse> grants;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class LeaveSettingResponse {
        private BigDecimal leaveHoursPerDay;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class LeaveSettingUpsert {
        @NotNull private BigDecimal leaveHoursPerDay;
    }
}
