package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

/** Khoá kỳ công của một công ty cho một tháng (theo ngày chốt công). */
@Entity
@Table(name = "attendance_period_locks")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class AttendancePeriodLock extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @Column(nullable = false)
    private int year;

    @Column(nullable = false)
    private int month;

    @Column(name = "period_from", nullable = false)
    private LocalDate periodFrom;

    @Column(name = "period_to", nullable = false)
    private LocalDate periodTo;

    @Column(nullable = false)
    private boolean locked;

    @Column(name = "locked_at")
    private LocalDateTime lockedAt;

    @Column(name = "locked_by_id")
    private Long lockedById;

    @Column(name = "unlocked_at")
    private LocalDateTime unlockedAt;

    @Column(name = "unlocked_by_id")
    private Long unlockedById;

    @Column(name = "unlock_reason", length = 500)
    private String unlockReason;
}
