package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Entity
@Table(name = "attendance_requests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AttendanceRequest extends BaseEntity implements ManagerApprovable {

    public enum Type { CHECK_IN, CHECK_OUT, OT, EXTRA }

    public enum OvertimeScope { IN_SHIFT, OUTSIDE_SHIFT }

    public enum OvertimePeriod { DAY, NIGHT }

    public enum Status { PENDING, APPROVED, REJECTED, CANCELLED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shift_assignment_id")
    private ShiftAssignment shiftAssignment;

    @Column(name = "request_date", nullable = false)
    private LocalDate requestDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "request_type", nullable = false, length = 20)
    private Type requestType;

    @Column(name = "requested_check_in")
    private LocalTime requestedCheckIn;

    @Column(name = "requested_check_out")
    private LocalTime requestedCheckOut;

    @Column(name = "requested_overtime_minutes")
    private Integer requestedOvertimeMinutes;

    @Enumerated(EnumType.STRING)
    @Column(name = "requested_overtime_scope", length = 20)
    private OvertimeScope requestedOvertimeScope;

    @Enumerated(EnumType.STRING)
    @Column(name = "requested_overtime_period", length = 20)
    private OvertimePeriod requestedOvertimePeriod;

    @Column(name = "applied", nullable = false)
    @Builder.Default
    private boolean applied = true;

    @Column(name = "note", columnDefinition = "TEXT")
    private String note;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private Status status = Status.PENDING;

    @Column(name = "admin_note", columnDefinition = "TEXT")
    private String adminNote;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "processed_by")
    private User processedBy;

    @Column(name = "processed_at")
    private LocalDateTime processedAt;

    // Bước K — quản lý trực tiếp duyệt trước (chế độ MANAGER_THEN_HR)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "manager_approved_by")
    private User managerApprovedBy;

    @Column(name = "manager_approved_at")
    private java.time.LocalDateTime managerApprovedAt;

    @Column(name = "manager_note", length = 500)
    private String managerNote;
}
