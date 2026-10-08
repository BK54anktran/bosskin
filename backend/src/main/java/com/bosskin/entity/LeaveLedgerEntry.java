package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

/**
 * L13 — một dòng trong sổ trừ/hoàn phép: phần đã đổi trên một quỹ ({@link LeaveGrant}) do một đơn gây ra.
 * {@code days}/{@code hours} là mức thay đổi của usedDays/usedHours (có thể âm khi giờ được gộp thành ngày).
 */
@Entity
@Table(name = "leave_ledger_entries")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LeaveLedgerEntry extends BaseEntity {

    public enum Kind { DEDUCT, REFUND }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @Column(name = "employee_id", nullable = false)
    private Long employeeId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "grant_id", nullable = false)
    private LeaveGrant grant;

    /** Đơn gốc đã trừ phép: đơn lẻ, hoặc đơn cha của nhóm nhiều ngày. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "request_id", nullable = false)
    private LeaveRequest request;

    @Enumerated(EnumType.STRING)
    @Column(name = "kind", nullable = false)
    private Kind kind;

    @Column(name = "days", nullable = false, precision = 10, scale = 4)
    private BigDecimal days;

    @Column(name = "hours", nullable = false, precision = 10, scale = 4)
    private BigDecimal hours;
}
