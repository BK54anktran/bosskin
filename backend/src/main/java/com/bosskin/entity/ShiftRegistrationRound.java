package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLRestriction;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.HashSet;
import java.util.Set;

/**
 * Đợt đăng ký lịch làm việc (V23): khoảng ngày + phòng ban, quản lý mở / đóng, tới hạn chót tự đóng.
 * Giới hạn (khung giờ, độ dài khung, số ngày tối thiểu) để trống = không giới hạn.
 */
@Entity
@Table(name = "shift_registration_rounds")
@SQLRestriction("deleted = false")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ShiftRegistrationRound extends BaseEntity {

    public enum Status { DRAFT, OPEN, CLOSED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "from_date", nullable = false)
    private LocalDate fromDate;

    @Column(name = "to_date", nullable = false)
    private LocalDate toDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    @Builder.Default
    private Status status = Status.DRAFT;

    @Column(name = "closes_at")
    private LocalDateTime closesAt;

    @Column(name = "earliest_time")
    private LocalTime earliestTime;

    @Column(name = "latest_time")
    private LocalTime latestTime;

    @Column(name = "min_hours", precision = 4, scale = 2)
    private BigDecimal minHours;

    @Column(name = "max_hours", precision = 4, scale = 2)
    private BigDecimal maxHours;

    @Column(name = "min_days")
    private Integer minDays;

    @Column(name = "needed_per_day")
    private Integer neededPerDay;

    @Column(length = 500)
    private String note;

    @Column(name = "created_by")
    private Long createdBy;

    @Column(nullable = false)
    @Builder.Default
    private boolean deleted = false;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "shift_registration_round_departments", joinColumns = @JoinColumn(name = "round_id"))
    @Column(name = "department_id")
    @Builder.Default
    private Set<Long> departmentIds = new HashSet<>();
}
