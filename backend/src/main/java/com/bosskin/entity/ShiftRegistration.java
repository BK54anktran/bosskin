package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLRestriction;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

/**
 * Một khung nhân viên đăng ký trong một ngày của đợt (V23): theo ca có sẵn (SHIFT, giờ chụp lại của ca),
 * giờ tuỳ chỉnh (CUSTOM) hoặc rảnh cả ngày — xếp sao cũng được (ANY, không có giờ).
 * Duyệt → tạo phân ca, lưu assignmentId.
 */
@Entity
@Table(name = "shift_registrations")
@SQLRestriction("deleted = false")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ShiftRegistration extends BaseEntity {

    public enum Kind { SHIFT, CUSTOM, ANY }
    public enum Status { PENDING, APPROVED, REJECTED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "round_id", nullable = false)
    private Long roundId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Kind kind;

    @Column(name = "shift_id")
    private Long shiftId;

    @Column(name = "start_time")
    private LocalTime startTime;

    @Column(name = "end_time")
    private LocalTime endTime;

    @Column(length = 255)
    private String note;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    @Builder.Default
    private Status status = Status.PENDING;

    @Column(name = "assignment_id")
    private Long assignmentId;

    @Column(name = "decided_by")
    private Long decidedBy;

    @Column(name = "decided_at")
    private LocalDateTime decidedAt;

    @Column(nullable = false)
    @Builder.Default
    private boolean deleted = false;
}
