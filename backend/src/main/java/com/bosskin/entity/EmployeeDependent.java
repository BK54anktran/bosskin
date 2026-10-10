package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.YearMonth;

/**
 * Người phụ thuộc của nhân viên (V17, bước M). Giảm trừ theo tháng: {@code deductionFrom} / {@code deductionTo}
 * là ngày 01 của tháng, {@code deductionTo} null = chưa kết thúc. NOT_REGISTERED không được tính giảm trừ.
 */
@Entity
@Table(name = "employee_dependents")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class EmployeeDependent extends BaseEntity {

    public enum Relationship { CHILD, SPOUSE, PARENT, OTHER }

    public enum RegistrationStatus { NOT_REGISTERED, PENDING, REGISTERED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "full_name", nullable = false, length = 100)
    private String fullName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Relationship relationship;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(name = "tax_code", length = 20)
    private String taxCode;

    @Column(name = "identity_no", length = 20)
    private String identityNo;

    @Column(name = "deduction_from", nullable = false)
    private LocalDate deductionFrom;

    @Column(name = "deduction_to")
    private LocalDate deductionTo;

    @Enumerated(EnumType.STRING)
    @Column(name = "registration_status", nullable = false)
    @Builder.Default
    private RegistrationStatus registrationStatus = RegistrationStatus.PENDING;

    @Column(length = 500)
    private String note;

    @Column(nullable = false)
    @Builder.Default
    private boolean deleted = false;

    /** Được giảm trừ trong tháng {@code ym}. */
    public boolean deductibleIn(YearMonth ym) {
        if (registrationStatus == RegistrationStatus.NOT_REGISTERED) return false;
        LocalDate m = ym.atDay(1);
        return !deductionFrom.isAfter(m) && (deductionTo == null || !deductionTo.isBefore(m));
    }
}
