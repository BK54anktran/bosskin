package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

/**
 * Bước K — một mốc trong quá trình công tác (V15): phòng ban, chức vụ, bậc lương, quản lý trực tiếp
 * áp dụng từ {@code effectiveFrom}. Bản hiện hành = dòng mới nhất có ngày hiệu lực ≤ hôm nay.
 */
@Entity
@Table(name = "employee_job_histories")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class EmployeeJobHistory extends BaseEntity {

    public enum ChangeType { HIRE, TRANSFER, PROMOTION, SALARY_CHANGE, MANAGER_CHANGE, OTHER }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Enumerated(EnumType.STRING)
    @Column(name = "change_type", nullable = false, length = 20)
    @Builder.Default
    private ChangeType changeType = ChangeType.OTHER;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id", nullable = false)
    private Department department;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "position_id")
    private Position position;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "salary_grade_id")
    private SalaryGrade salaryGrade;

    /** Quản lý có thể đã nghỉ (xoá mềm) — vẫn đọc được lịch sử. */
    @ManyToOne
    @JoinColumn(name = "manager_id")
    @org.hibernate.annotations.NotFound(action = org.hibernate.annotations.NotFoundAction.IGNORE)
    private Employee manager;

    @Column(length = 500)
    private String note;

    @Column(nullable = false)
    @Builder.Default
    private boolean applied = false;

    @Column(name = "created_by")
    private Long createdBy;

    @Column(nullable = false)
    @Builder.Default
    private boolean deleted = false;
}
