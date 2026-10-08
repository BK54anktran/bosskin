package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;

@Entity
@Table(name = "leave_types", uniqueConstraints = {
    @UniqueConstraint(name = "uk_leave_type_company_code", columnNames = {"company_id", "code"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LeaveType extends BaseEntity {

    public enum Unit { DAY, HOUR }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "company_id", nullable = false)
    private Company company;

    @Column(name = "code", nullable = false, length = 50)
    private String code;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "unit", nullable = false, length = 10)
    private Unit unit;

    @Column(name = "deduct_per_day", nullable = false, precision = 10, scale = 2)
    @Builder.Default
    private BigDecimal deductPerDay = BigDecimal.ONE;

    @Column(name = "is_paid", nullable = false)
    @Builder.Default
    private boolean paid = true;

    /** Có trừ quỹ phép (số dư) hay không. Nghỉ không lương / ốm thường không trừ (L8). */
    @Column(name = "requires_balance", nullable = false)
    @Builder.Default
    private boolean requiresBalance = true;

    @Column(name = "active", nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;

    @Column(name = "description", length = 255)
    private String description;
}
