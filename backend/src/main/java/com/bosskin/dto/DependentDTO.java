package com.bosskin.dto;

import com.bosskin.entity.EmployeeDependent;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.time.LocalDate;

/** Bước M — người phụ thuộc. Tháng giảm trừ gửi bằng ngày bất kỳ trong tháng, lưu ngày 01. */
public class DependentDTO {

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        private Long id;
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String fullName;
        private EmployeeDependent.Relationship relationship;
        private LocalDate dateOfBirth;
        private String taxCode;
        private String identityNo;
        private LocalDate deductionFrom;
        private LocalDate deductionTo;
        private EmployeeDependent.RegistrationStatus registrationStatus;
        private String note;
        /** Đang được giảm trừ ở tháng hiện tại. */
        private boolean activeNow;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Upsert {
        @NotNull private Long employeeId;
        @NotBlank @Size(max = 100) private String fullName;
        @NotNull private EmployeeDependent.Relationship relationship;
        private LocalDate dateOfBirth;
        @Size(max = 20) private String taxCode;
        @Size(max = 20) private String identityNo;
        @NotNull private LocalDate deductionFrom;
        private LocalDate deductionTo;
        private EmployeeDependent.RegistrationStatus registrationStatus;
        @Size(max = 500) private String note;
    }
}
