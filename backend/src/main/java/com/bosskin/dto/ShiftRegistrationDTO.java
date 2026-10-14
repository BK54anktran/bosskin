package com.bosskin.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

/** Đăng ký lịch làm việc (V23). */
public class ShiftRegistrationDTO {

    // ── Đợt ─────────────────────────────────────────────────────────────

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class RoundUpsert {
        @NotBlank private String name;
        @NotNull private LocalDate fromDate;
        @NotNull private LocalDate toDate;
        @NotEmpty private List<Long> departmentIds;
        /** Hạn chót — tới giờ thì tự đóng. Trống = không tự đóng. */
        private LocalDateTime closesAt;
        @JsonFormat(pattern = "HH:mm") private LocalTime earliestTime;
        @JsonFormat(pattern = "HH:mm") private LocalTime latestTime;
        private BigDecimal minHours;
        private BigDecimal maxHours;
        private Integer minDays;
        private Integer neededPerDay;
        private String note;
        /** Chỉ khi tạo: true = mở đăng ký luôn. */
        private boolean open;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class RoundResponse {
        private Long id;
        private String name;
        private LocalDate fromDate;
        private LocalDate toDate;
        private String status;
        private LocalDateTime closesAt;
        @JsonFormat(pattern = "HH:mm") private LocalTime earliestTime;
        @JsonFormat(pattern = "HH:mm") private LocalTime latestTime;
        private BigDecimal minHours;
        private BigDecimal maxHours;
        private Integer minDays;
        private Integer neededPerDay;
        private String note;
        private List<ShiftDTO.DeptRef> departments;
        /** Số nhân viên đã đăng ký ít nhất một ngày / số nhân viên thuộc đợt. */
        private int registeredCount;
        private int employeeCount;
        private String createdByName;
    }

    // ── Đăng ký ─────────────────────────────────────────────────────────

    /** Một khung nhân viên gửi lên. kind: SHIFT (shiftId) | CUSTOM (startTime–endTime) | ANY (rảnh cả ngày). */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class SlotInput {
        @NotNull private LocalDate workDate;
        @NotBlank private String kind;
        private Long shiftId;
        @JsonFormat(pattern = "HH:mm") private LocalTime startTime;
        @JsonFormat(pattern = "HH:mm") private LocalTime endTime;
        private String note;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class SelfSaveRequest {
        @Valid @NotNull private List<SlotInput> slots;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class RegistrationResponse {
        private Long id;
        private Long employeeId;
        private LocalDate workDate;
        private String kind;
        private Long shiftId;
        private String shiftCode;
        @JsonFormat(pattern = "HH:mm") private LocalTime startTime;
        @JsonFormat(pattern = "HH:mm") private LocalTime endTime;
        private String note;
        private String status;
        private Long assignmentId;
        /** Đã duyệt: ca / giờ thực tế của phân ca đã tạo (null khi phân ca đã bị xoá). */
        private String assignedShiftCode;
        @JsonFormat(pattern = "HH:mm") private LocalTime assignedStartTime;
        @JsonFormat(pattern = "HH:mm") private LocalTime assignedEndTime;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class ShiftOption {
        private Long id;
        private String code;
        private String name;
        @JsonFormat(pattern = "HH:mm") private LocalTime startTime;
        @JsonFormat(pattern = "HH:mm") private LocalTime endTime;
        private String color;
    }

    /** Màn nhân viên: đợt + đăng ký của tôi + ca có sẵn để chọn. */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class SelfRoundResponse {
        private RoundResponse round;
        private boolean editable;
        private List<RegistrationResponse> registrations;
        private List<ShiftOption> shifts;
    }

    // ── Lưới quản lý ────────────────────────────────────────────────────

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class BoardEmployee {
        private Long id;
        private String code;
        private String name;
        private String departmentName;
        private int days;
        private List<RegistrationResponse> registrations;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class BoardResponse {
        private RoundResponse round;
        private List<BoardEmployee> employees;
        private List<ShiftOption> shifts;
    }

    /** Duyệt một ngày. anyShiftId: ca gán cho người đăng ký "rảnh cả ngày" (trống = bỏ qua họ). */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ApproveDayRequest {
        private Long anyShiftId;
    }

    /** Duyệt một ô; được đổi sang ca khác / giờ khác (bắt buộc với "rảnh cả ngày"). */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ApproveOneRequest {
        private Long shiftId;
        @JsonFormat(pattern = "HH:mm") private LocalTime startTime;
        @JsonFormat(pattern = "HH:mm") private LocalTime endTime;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class DecideResult {
        private int approved;
        private List<Skipped> skipped;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Skipped {
        private Long registrationId;
        private String employeeName;
        private LocalDate workDate;
        /** Mã lỗi (có thể kèm tham số "|…"). */
        private String reason;
    }
}
