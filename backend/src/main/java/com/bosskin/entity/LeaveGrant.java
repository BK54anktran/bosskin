package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "leave_grants")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LeaveGrant extends BaseEntity {

    public enum Source { MANUAL, AUTO }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Khoá lạc quan: 2 đơn trừ cùng một quỹ phép đồng thời thì đơn sau thất bại (L17). */
    @Version
    @Column(name = "version", nullable = false)
    private long version;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "company_id", nullable = false)
    private Company company;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "leave_type_id")
    private LeaveType leaveType;

    @Enumerated(EnumType.STRING)
    @Column(name = "source", nullable = false, length = 10)
    private Source source;

    @Column(name = "grant_days", precision = 10, scale = 2)
    private BigDecimal grantDays;

    @Column(name = "grant_hours", precision = 10, scale = 2)
    private BigDecimal grantHours;

    @Column(name = "used_days", nullable = false, precision = 10, scale = 2)
    @Builder.Default
    private BigDecimal usedDays = BigDecimal.ZERO;

    @Column(name = "used_hours", nullable = false, precision = 10, scale = 2)
    @Builder.Default
    private BigDecimal usedHours = BigDecimal.ZERO;

    @Column(name = "granted_at", nullable = false)
    private LocalDate grantedAt;

    @Column(name = "valid_from")
    private LocalDate validFrom;

    @Column(name = "valid_to")
    private LocalDate validTo;

    @Column(name = "note", length = 500)
    private String note;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "accrual_rule_id")
    private LeaveAccrualRule accrualRule;
}
