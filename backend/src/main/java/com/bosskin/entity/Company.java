package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalTime;
import java.math.BigDecimal;

@Entity
@Table(name = "companies")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Company extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "name", nullable = false, length = 200)
    private String name;

    @Column(name = "code", nullable = false, unique = true, length = 50)
    private String code;

    @Column(name = "domain", length = 100)
    private String domain;

    @Column(name = "logo", length = 255)
    private String logo;

    @Column(name = "address", columnDefinition = "TEXT")
    private String address;

    @Column(name = "phone", length = 20)
    private String phone;

    @Column(name = "email", length = 100)
    private String email;

    @Column(name = "active", nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "day_start_time", nullable = false)
    @Builder.Default
    private LocalTime dayStartTime = LocalTime.of(6, 0);

    @Column(name = "day_end_time", nullable = false)
    @Builder.Default
    private LocalTime dayEndTime = LocalTime.of(22, 0);

    @Column(name = "self_attendance_enabled", nullable = false)
    @Builder.Default
    private boolean selfAttendanceEnabled = true;

    @Column(name = "attendance_day_night_mode", nullable = false)
    @Builder.Default
    private boolean attendanceDayNightMode = false;

    @Column(name = "attendance_ot_enabled", nullable = false)
    @Builder.Default
    private boolean attendanceOtEnabled = true;

    @Column(name = "leave_hours_per_day", nullable = false, precision = 10, scale = 2)
    @Builder.Default
    private BigDecimal leaveHoursPerDay = BigDecimal.valueOf(8);

    @Column(name = "location_check_enabled", nullable = false)
    @Builder.Default
    private boolean locationCheckEnabled = false;

    /** Chỉ cho tự chấm công trên thiết bị đã gắn với nhân viên (V6). */
    @Column(name = "device_binding_enabled", nullable = false)
    @Builder.Default
    private boolean deviceBindingEnabled = false;

    /** Bước C — bắt buộc 2FA với người có quyền ROLE_MANAGE (system admin bật). */
    @Column(name = "require_admin_2fa", nullable = false)
    @Builder.Default
    private boolean requireAdmin2fa = false;

    @Column(name = "check_in_latitude")
    private Double checkInLatitude;

    @Column(name = "check_in_longitude")
    private Double checkInLongitude;

    @Column(name = "check_in_radius_meters", nullable = false)
    @Builder.Default
    private int checkInRadiusMeters = 100;

    @Column(name = "check_in_before_minutes", nullable = false)
    @Builder.Default
    private int checkInBeforeMinutes = 30;

    @Column(name = "check_in_after_minutes", nullable = false)
    @Builder.Default
    private int checkInAfterMinutes = 30;

    @Column(name = "check_out_before_minutes", nullable = false)
    @Builder.Default
    private int checkOutBeforeMinutes = 30;

    @Column(name = "check_out_after_minutes", nullable = false)
    @Builder.Default
    private int checkOutAfterMinutes = 30;

    @Column(name = "check_in_tolerance_minutes")
    private Integer checkInToleranceMinutes;

    @Column(name = "check_out_tolerance_minutes")
    private Integer checkOutToleranceMinutes;

    @Column(name = "rounding_check_in_minutes")
    private Integer roundingCheckInMinutes;

    @Column(name = "rounding_check_out_minutes")
    private Integer roundingCheckOutMinutes;

    @Column(name = "rounding_work_minutes")
    private Integer roundingWorkMinutes;

    @Column(name = "standard_work_days", nullable = false)
    @Builder.Default
    private int standardWorkDays = 22;

    @Column(name = "payroll_cutoff_day", nullable = false)
    @Builder.Default
    private int payrollCutoffDay = 1;
}
