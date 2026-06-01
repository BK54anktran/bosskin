package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLDelete;
import org.hibernate.annotations.Where;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Entity
@Table(name = "shift_assignments")
@SQLDelete(sql = "UPDATE shift_assignments SET deleted = true WHERE id = ?")
@Where(clause = "deleted = false")
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class ShiftAssignment {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shift_id")
    private WorkShift shift;

    // ── Snapshot fields — copied from WorkShift at assign time ───────────────
    @Column(name = "snapshot_name", length = 100)
    private String snapshotName;

    @Column(name = "snapshot_code", length = 20)
    private String snapshotCode;

    @Column(name = "snapshot_start_time")
    private LocalTime snapshotStartTime;

    @Column(name = "snapshot_end_time")
    private LocalTime snapshotEndTime;

    @Column(name = "snapshot_break_start")
    private LocalTime snapshotBreakStart;

    @Column(name = "snapshot_break_end")
    private LocalTime snapshotBreakEnd;

    @Column(name = "snapshot_work_minutes")
    private Integer snapshotWorkMinutes;

    @Column(name = "snapshot_color", length = 7)
    private String snapshotColor;
    // ─────────────────────────────────────────────────────────────────────────

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Column(length = 255)
    private String note;

    @Column(name = "custom_start_time")
    private LocalTime customStartTime;

    @Column(name = "custom_end_time")
    private LocalTime customEndTime;

    @Column(name = "custom_break_start")
    private LocalTime customBreakStart;

    @Column(name = "custom_break_end")
    private LocalTime customBreakEnd;

    @Column(name = "created_by")
    private Long createdBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "approved", nullable = false)
    @Builder.Default
    private boolean approved = false;

    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;

    @PrePersist
    void prePersist() { createdAt = LocalDateTime.now(); }

    public boolean isCustom() {
        return shift == null && customStartTime != null;
    }

    public boolean isDeleted() {
        return deleted;
    }

    public void setDeleted(boolean deleted) {
        this.deleted = deleted;
    }
}
