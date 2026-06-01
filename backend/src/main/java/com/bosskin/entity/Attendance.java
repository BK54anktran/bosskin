package com.bosskin.entity;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Entity
@Table(name = "attendances",
    uniqueConstraints = @UniqueConstraint(columnNames = {"employee_id", "date"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Attendance extends BaseEntity {

    public enum Status { PRESENT, ABSENT, LATE, HALF_DAY, LEAVE }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler", "company", "position", "department"})
    private Employee employee;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shift_assignment_id")
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private ShiftAssignment shiftAssignment;

    @Column(name = "date", nullable = false)
    private LocalDate date;

    @Column(name = "check_in")
    private LocalDateTime checkIn;

    @Column(name = "check_out")
    private LocalDateTime checkOut;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private Status status;

    @Column(name = "note", columnDefinition = "TEXT")
    private String note;

    @Column(name = "approved", nullable = false)
    @Builder.Default
    private boolean approved = false;

    @Column(name = "approved_at")
    private LocalDateTime approvedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "approved_by_id")
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private User approvedBy;

    @Column(name = "snap_actual_hours")
    private Double snapActualHours;

    @Column(name = "snap_day_hours")
    private Double snapDayHours;

    @Column(name = "snap_day_ot")
    private Double snapDayOt;

    @Column(name = "snap_night_hours")
    private Double snapNightHours;

    @Column(name = "snap_night_ot")
    private Double snapNightOt;

    @Column(name = "work_flags", length = 120)
    private String workFlags;

    // ── Admin override fields ─────────────────────────────────────────────────
    @Column(name = "override_check_in")
    private LocalTime overrideCheckIn;

    @Column(name = "override_check_out")
    private LocalTime overrideCheckOut;

    @Column(name = "override_break_minutes")
    private Integer overrideBreakMinutes;

    @Column(name = "override_ot_day_minutes")
    private Integer overrideOtDayMinutes;

    @Column(name = "override_ot_night_minutes")
    private Integer overrideOtNightMinutes;

    @Column(name = "override_note", length = 255)
    private String overrideNote;
    // ─────────────────────────────────────────────────────────────────────────

    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "deleted_by_id")
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private User deletedBy;

    @Column(name = "check_in_latitude")
    private Double checkInLatitude;

    @Column(name = "check_in_longitude")
    private Double checkInLongitude;

    @Column(name = "check_out_latitude")
    private Double checkOutLatitude;

    @Column(name = "check_out_longitude")
    private Double checkOutLongitude;
}
