package com.bosskin.dto;

import com.bosskin.entity.Employee;
import jakarta.validation.constraints.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

public class EmployeeDTO {

    /** Một hàng từ file Excel (gộp sheet 1 + sheet 2 theo employeeCode). */
    @lombok.Data
    public static class ImportRow {
        /** D9: Excel lưu SĐT / CCCD dạng số làm mất số 0 đầu — bù lại khi đọc. */
        public void setPhone(String v) { this.phone = com.bosskin.util.ExcelText.phone(v); }
        public void setIdentityCard(String v) { this.identityCard = com.bosskin.util.ExcelText.identityCard(v); }

        // Sheet 1 — cơ bản
        private String employeeCode;
        private String fullName;
        private String email;
        private String phone;
        private String gender;        // "Nam" | "Nữ" | "Khác" | MALE | FEMALE | OTHER
        private String dateOfBirth;   // dd/MM/yyyy
        private String joinDate;      // dd/MM/yyyy
        private String leaveDate;     // dd/MM/yyyy
        private String departmentCode;
        private String departmentName;
        private String positionCode;
        private String positionName;
        private String salaryGradeCode;
        private String status;        // "Đang làm" | "Nghỉ việc" | ...
        /** Mật khẩu mặc định khi tạo mới — để trống thì BE dùng password mặc định. */
        private String defaultPassword;

        // Sheet 2 — cá nhân (merge theo employeeCode)
        private String identityCard;
        private String address;
        private String personalEmail;
        private String bankAccount;
        private String bankName;
        private String contractSalary;
        // Bước M — thuế / bảo hiểm
        private String taxCode;
        private String socialInsuranceNo;
        private String healthInsurancePlace;
        private String insuranceJoinDate;   // dd/MM/yyyy
    }

    @lombok.Data
    @lombok.Builder
    public static class ImportDiff {
        /** "CREATE" | "UPDATE" | "NO_CHANGE" */
        private String action;
        private String employeeCode;
        private String fullName;
        private String email;
        private String departmentCode;
        private java.util.List<DepartmentDTO.FieldChange> changes;
        private java.util.List<String> warnings;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        /** Đã gắn thiết bị chấm công (V6) */
        private boolean deviceBound;
        private java.time.LocalDateTime boundDeviceAt;
        private Long id;
        private String employeeCode;
        private String fullName;
        private String email;
        private String phone;
        private String personalEmail;
        private String avatar;
        private Employee.Gender gender;
        private LocalDate dateOfBirth;
        private LocalDate joinDate;
        private LocalDate leaveDate;
        private Employee.Status status;
        private Long departmentId;
        private String departmentName;
        private Long positionId;
        private String positionName;
        private Long salaryGradeId;
        private String salaryGradeCode;
        private String salaryGradeName;
        /** Bước K — quản lý trực tiếp. */
        private Long managerId;
        private String managerName;
        private String address;
        private String identityCard;
        private String bankAccount;
        private String bankName;
        private java.math.BigDecimal contractSalary;
        /** Bước M — thuế / bảo hiểm. */
        private String taxCode;
        private String socialInsuranceNo;
        private String healthInsurancePlace;
        private LocalDate insuranceJoinDate;
        private LocalDateTime createdAt;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class CreateRequest {
        @NotBlank @Size(max = 100)
        private String fullName;

        @NotBlank @Email
        private String email;

        @NotBlank @Size(min = 6, max = 100)
        private String password;

        @Size(max = 15)
        private String phone;

        @NotNull
        private Employee.Gender gender;

        private LocalDate dateOfBirth;

        @NotNull
        private LocalDate joinDate;

        @NotNull
        private Long departmentId;

        private Long positionId;

        /** Bước K — quản lý trực tiếp (tuỳ chọn). */
        private Long managerId;

        private String address;
        private String identityCard;
        private String bankAccount;
        private String bankName;
        /** Bước M — thuế / bảo hiểm. */
        @Size(max = 20)
        private String taxCode;
        @Size(max = 20)
        private String socialInsuranceNo;
        private String healthInsurancePlace;
        private LocalDate insuranceJoinDate;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class UpdateRequest {
        @Size(max = 100)
        private String fullName;

        @Size(max = 15)
        private String phone;

        private Employee.Gender gender;
        private LocalDate dateOfBirth;
        private LocalDate joinDate;
        private LocalDate leaveDate;
        private Long departmentId;
        private Long positionId;
        private Long salaryGradeId;
        private Employee.Status status;
        private String address;
        private String identityCard;
        private String personalEmail;
        private String bankAccount;
        private String bankName;
        private java.math.BigDecimal contractSalary;
        /** Bước M — thuế / bảo hiểm (null = giữ nguyên). */
        @Size(max = 20)
        private String taxCode;
        @Size(max = 20)
        private String socialInsuranceNo;
        private String healthInsurancePlace;
        private LocalDate insuranceJoinDate;

        /** Bước K — quản lý trực tiếp; có gửi trường (kể cả null = bỏ quản lý) mới đổi. */
        private Long managerId;
        @com.fasterxml.jackson.annotation.JsonIgnore
        private boolean managerIdPresent;

        public void setManagerId(Long managerId) {
            this.managerId = managerId;
            this.managerIdPresent = true;
        }
    }
}
