package com.bosskin.dto;

import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

public class ShiftSwapDTO {

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class CreateRequest {
        /** Phân ca của chính người gửi muốn đổi / nhường */
        @NotNull private Long requesterAssignmentId;
        @NotNull private Long targetEmployeeId;
        /** Phân ca của người kia để đổi lấy; null = nhường ca (người kia nhận làm thay) */
        private Long targetAssignmentId;
        private String reason;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ProcessRequest {
        private String adminNote;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class Response {
        private Long id;
        private String status;
        private Long requesterId;
        private String requesterName;
        private Long requesterAssignmentId;
        private LocalDate requesterDate;
        private String requesterShift;
        private Long targetEmployeeId;
        private String targetEmployeeName;
        private Long targetAssignmentId;
        private LocalDate targetDate;
        private String targetShift;
        /** SWAP = đổi ca cho nhau, GIVE = nhường ca */
        private String kind;
        private String reason;
        private String adminNote;
        private String processedByName;
        private LocalDateTime processedAt;
        private LocalDateTime createdAt;
        /** Bước K: bước quản lý trực tiếp. */
        private LocalDateTime managerApprovedAt;
        private String managerApprovedByName;
        private String managerNote;
        private String awaitingManagerName;
    }

    /** Một phân ca hiển thị trong form đổi ca */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ShiftOption {
        private Long assignmentId;
        private LocalDate date;
        private String label;
    }

    /** Đồng nghiệp có thể đổi / nhận ca cùng ngày */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Colleague {
        private Long employeeId;
        private String fullName;
        private String departmentName;
        private java.util.List<ShiftOption> shifts;
    }
}
