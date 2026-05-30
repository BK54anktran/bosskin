package com.bosskin.dto;

import com.bosskin.entity.Employee;
import com.bosskin.entity.ProfileEditRequest;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

public class ProfileDTO {

    /** Thông tin profile trả về cho client */
    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class ProfileResponse {
        private Long id;
        private String employeeCode;
        private String fullName;
        private String workEmail;
        private String personalEmail;
        private String phone;
        private String avatar;
        private Employee.Gender gender;
        private LocalDate dateOfBirth;
        private LocalDate joinDate;
        private String departmentName;
        private String positionName;
        private Employee.Status status;
        private boolean canEdit;        // true nếu user có quyền EMPLOYEE_UPDATE
    }

    /** Admin cập nhật trực tiếp */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class AdminUpdateRequest {
        @Size(max = 100)
        private String fullName;

        private Employee.Gender gender;

        private LocalDate dateOfBirth;

        @Size(max = 15)
        private String phone;

        @Email @Size(max = 100)
        private String personalEmail;

        @Size(max = 255)
        private String avatar;
    }

    /** User gửi yêu cầu chỉnh sửa */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class EditRequestCreate {
        @Size(max = 100)
        private String fullName;

        private Employee.Gender gender;

        private LocalDate dateOfBirth;

        @Size(max = 15)
        private String phone;

        @Email @Size(max = 100)
        private String personalEmail;
    }

    /** Response cho danh sách yêu cầu (admin xem) */
    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class EditRequestResponse {
        private Long id;
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private Long departmentId;
        private String departmentName;

        // Giá trị hiện tại
        private String currentFullName;
        private Employee.Gender currentGender;
        private LocalDate currentDateOfBirth;
        private String currentPhone;
        private String currentPersonalEmail;

        // Giá trị yêu cầu thay đổi (null = không yêu cầu đổi)
        private String requestedFullName;
        private Employee.Gender requestedGender;
        private LocalDate requestedDateOfBirth;
        private String requestedPhone;
        private String requestedPersonalEmail;

        private ProfileEditRequest.Status status;
        private String adminNote;
        private LocalDateTime createdAt;
        private LocalDateTime processedAt;
    }

    /** Admin phê duyệt hoặc từ chối */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ProcessRequest {
        private String adminNote;
    }

    /** Cập nhật avatar (tất cả user) */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class AvatarUpdateRequest {
        @Size(max = 255)
        private String avatarUrl;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ChangePasswordRequest {
        @NotBlank @Size(min = 6, max = 100)
        private String currentPassword;

        @NotBlank @Size(min = 6, max = 100)
        private String newPassword;

        @NotBlank @Size(min = 6, max = 100)
        private String confirmPassword;
    }

    /** Số lượng yêu cầu pending (cho badge) */
    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class PendingCount {
        private long count;
    }
}
