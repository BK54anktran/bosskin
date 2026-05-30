package com.bosskin.dto;

import com.bosskin.entity.Employee;
import jakarta.validation.constraints.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

public class EmployeeDTO {

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
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
        private String address;
        private java.math.BigDecimal contractSalary;
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

        private String address;
        private String identityCard;
        private String bankAccount;
        private String bankName;
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
        private Long departmentId;
        private Long positionId;
        private Long salaryGradeId;
        private Employee.Status status;
        private String address;
        private String bankAccount;
        private String bankName;
        private java.math.BigDecimal contractSalary;
    }
}
