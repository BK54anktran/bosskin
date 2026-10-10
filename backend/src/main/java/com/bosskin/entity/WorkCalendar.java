package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Lịch làm việc tuần (V14). {@code weekPattern} 7 ký tự T2→CN: F cả ngày, H nửa ngày, O nghỉ.
 * Mỗi công ty tối đa một lịch mặc định; phòng ban gán lịch qua {@code departments.work_calendar_id}.
 */
@Entity
@Table(name = "work_calendars")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class WorkCalendar extends BaseEntity {

    public static final String DEFAULT_PATTERN = "FFFFFOO";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "week_pattern", nullable = false, length = 7)
    @Builder.Default
    private String weekPattern = DEFAULT_PATTERN;

    @Column(name = "is_default", nullable = false)
    @Builder.Default
    private boolean isDefault = false;

    @Column(nullable = false)
    @Builder.Default
    private boolean deleted = false;
}
