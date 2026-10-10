package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Yêu cầu đổi ca / nhường ca (Mốc 2b). targetAssignment = null nghĩa là nhường ca:
 * người nhận (targetEmployee) làm thay ca của người gửi. Quản lý duyệt mới có hiệu lực.
 */
@Entity
@Table(name = "shift_swap_requests")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ShiftSwapRequest extends BaseEntity implements ManagerApprovable {

    public enum Status { PENDING, APPROVED, REJECTED, CANCELLED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requester_id")
    private Employee requester;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requester_assignment_id")
    private ShiftAssignment requesterAssignment;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "target_employee_id")
    private Employee targetEmployee;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "target_assignment_id")
    private ShiftAssignment targetAssignment;

    @Column(length = 500)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private Status status = Status.PENDING;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "processed_by_id")
    private User processedBy;

    @Column(name = "processed_at")
    private LocalDateTime processedAt;

    @Column(name = "admin_note", length = 500)
    private String adminNote;

    // Bước K — quản lý trực tiếp duyệt trước (chế độ MANAGER_THEN_HR)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "manager_approved_by")
    private User managerApprovedBy;

    @Column(name = "manager_approved_at")
    private java.time.LocalDateTime managerApprovedAt;

    @Column(name = "manager_note", length = 500)
    private String managerNote;
}
