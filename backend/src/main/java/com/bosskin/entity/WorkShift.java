package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "work_shifts")
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class WorkShift extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "company_id", nullable = false)
    private Company company;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false, length = 20)
    private String code;

    @Column(name = "start_time")
    private LocalTime startTime;

    @Column(name = "end_time")
    private LocalTime endTime;

    @Column(name = "break_start")
    private LocalTime breakStart;

    @Column(name = "break_end")
    private LocalTime breakEnd;

    @Column(name = "work_minutes")
    private Integer workMinutes;

    @Column(name = "group_name", length = 100)
    private String groupName;

    @Column(nullable = false, length = 7)
    @Builder.Default
    private String color = "#1976D2";

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;

    /** FIXED: giờ vào/ra cố định. FLEXIBLE: chỉ cần đủ requiredMinutes trong khung [startTime, endTime] (Mốc 2b). */
    @Enumerated(EnumType.STRING)
    @Column(name = "shift_type", nullable = false, length = 20)
    @Builder.Default
    private ShiftType shiftType = ShiftType.FIXED;

    /** Số phút phải làm của ca linh hoạt (đã trừ nghỉ). */
    @Column(name = "required_minutes")
    private Integer requiredMinutes;

    public enum ShiftType { FIXED, FLEXIBLE }

    public boolean isFlexible() { return shiftType == ShiftType.FLEXIBLE; }

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "department_shifts",
        joinColumns = @JoinColumn(name = "shift_id"),
        inverseJoinColumns = @JoinColumn(name = "department_id")
    )
    @Builder.Default
    private List<Department> departments = new ArrayList<>();
}
