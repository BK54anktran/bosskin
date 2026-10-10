package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Hợp đồng lao động (V16, bước L). "Hết hạn" không lưu: ACTIVE có {@code endDate} trước hôm nay.
 * Khoảng hiệu lực = startDate → (TERMINATED ? terminationDate : endDate), endDate null = không thời hạn.
 */
@Entity
@Table(name = "labor_contracts")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LaborContract extends BaseEntity {

    public enum Type { PROBATION, FIXED_TERM, INDEFINITE, SEASONAL, SERVICE }

    public enum Status { DRAFT, ACTIVE, TERMINATED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "contract_no", nullable = false, length = 50)
    private String contractNo;

    @Enumerated(EnumType.STRING)
    @Column(name = "contract_type", nullable = false)
    private Type contractType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private Status status = Status.DRAFT;

    @Column(name = "sign_date")
    private LocalDate signDate;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Column(name = "base_salary", nullable = false, precision = 15, scale = 2)
    private BigDecimal baseSalary;

    @Column(name = "insurance_salary", precision = 15, scale = 2)
    private BigDecimal insuranceSalary;

    @Column(name = "position_title", length = 150)
    private String positionTitle;

    @Column(length = 1000)
    private String note;

    @Column(name = "termination_date")
    private LocalDate terminationDate;

    @Column(name = "termination_reason", length = 500)
    private String terminationReason;

    @Column(name = "created_by")
    private Long createdBy;

    @Column(nullable = false)
    @Builder.Default
    private boolean deleted = false;

    /** Ngày cuối còn hiệu lực (null = không thời hạn). */
    public LocalDate effectiveEnd() {
        if (status == Status.TERMINATED && terminationDate != null) {
            return endDate != null && endDate.isBefore(terminationDate) ? endDate : terminationDate;
        }
        return endDate;
    }

    /** Hợp đồng không nháp phủ ngày {@code d}. */
    public boolean covers(LocalDate d) {
        if (status == Status.DRAFT || deleted) return false;
        LocalDate end = effectiveEnd();
        return !d.isBefore(startDate) && (end == null || !d.isAfter(end));
    }

    /** ACTIVE nhưng đã qua ngày kết thúc. */
    public boolean isExpired(LocalDate today) {
        return status == Status.ACTIVE && endDate != null && endDate.isBefore(today);
    }
}
