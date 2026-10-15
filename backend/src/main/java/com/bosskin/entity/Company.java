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

    /** V25: ngày không được xếp ca vẫn được chấm vào / ra (công không gắn ca, tính giờ theo giờ thực tế). */
    @Column(name = "check_in_without_shift", nullable = false)
    @Builder.Default
    private boolean checkInWithoutShift = false;

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

    /** Bước J: true = công chuẩn kỳ lương đếm theo lịch tuần + ngày lễ; false = số cố định standardWorkDays. */
    @Column(name = "standard_days_from_calendar", nullable = false)
    @Builder.Default
    private boolean standardDaysFromCalendar = false;

    /** Bước K: chế độ duyệt đơn nghỉ / sửa giờ / đổi ca. */
    public enum ApprovalMode { PERMISSION, MANAGER_THEN_HR }

    @Enumerated(EnumType.STRING)
    @Column(name = "approval_mode", nullable = false, length = 20)
    @Builder.Default
    private ApprovalMode approvalMode = ApprovalMode.PERMISSION;

    /** V26: tính năng đang tắt (core/CompanyFeatures), cách nhau dấu phẩy; NULL = bật hết. Thay disabled_modules của V24. */
    @Column(name = "disabled_features", length = 1000)
    private String disabledFeatures;

    public java.util.Set<String> disabledFeatureSet() {
        return com.bosskin.core.CompanyFeatures.parse(disabledFeatures);
    }

    /** V26: tính năng còn bật cho công ty này. */
    public boolean hasFeature(String feature) {
        return !disabledFeatureSet().contains(feature);
    }

    // "Hiệu lực" = cài đặt đang bật VÀ tính năng của công ty còn bật. Cài đặt của tính năng tắt bị ẩn ở màn Cài đặt nên
    // không được áp lên người dùng (kẹt giá trị cũ không sửa được) và không được hưởng tính năng chưa đăng ký.
    public boolean locationCheckActive() {
        return locationCheckEnabled && hasFeature(com.bosskin.core.CompanyFeatures.ATT_GEOFENCE);
    }

    public boolean deviceBindingActive() {
        return deviceBindingEnabled && hasFeature(com.bosskin.core.CompanyFeatures.ATT_DEVICE);
    }

    public boolean checkInWithoutShiftActive() {
        return checkInWithoutShift && hasFeature(com.bosskin.core.CompanyFeatures.ATT_NOSHIFT);
    }

    public boolean shiftRegistrationActive() {
        return shiftRegistrationEnabled && hasFeature(com.bosskin.core.CompanyFeatures.SHIFT_REGISTRATION);
    }

    /** Chế độ duyệt hiệu lực: tính năng duyệt 2 cấp tắt → duyệt theo quyền như thường (tránh đơn kẹt chờ quản lý). */
    public ApprovalMode effectiveApprovalMode() {
        return hasFeature(com.bosskin.core.CompanyFeatures.HR_MANAGER_APPROVAL) ? approvalMode : ApprovalMode.PERMISSION;
    }

    /** V23: cho nhân viên đăng ký lịch làm việc theo đợt (ẩn menu / tab và chặn API khi tắt). */
    @Column(name = "shift_registration_enabled", nullable = false)
    @Builder.Default
    private boolean shiftRegistrationEnabled = false;

    /** Bước L: báo trước hợp đồng sắp hết hạn (ngày). */
    @Column(name = "contract_expiry_warning_days", nullable = false)
    @Builder.Default
    private int contractExpiryWarningDays = 30;

    @Column(name = "payroll_cutoff_day", nullable = false)
    @Builder.Default
    private int payrollCutoffDay = 1;

    /** Vùng lương tối thiểu 1–4 (NĐ 293/2025) — trần đóng BHTN = 20 × lương tối thiểu vùng (V13). */
    @Column(name = "min_wage_region", nullable = false)
    @Builder.Default
    private int minWageRegion = 1;

    /** Bước M — tỷ lệ bảo hiểm công ty đóng. */
    @Column(name = "employer_social_rate", nullable = false, precision = 6, scale = 4)
    @Builder.Default
    private java.math.BigDecimal employerSocialRate = new java.math.BigDecimal("0.1750");

    @Column(name = "employer_health_rate", nullable = false, precision = 6, scale = 4)
    @Builder.Default
    private java.math.BigDecimal employerHealthRate = new java.math.BigDecimal("0.0300");

    @Column(name = "employer_unemployment_rate", nullable = false, precision = 6, scale = 4)
    @Builder.Default
    private java.math.BigDecimal employerUnemploymentRate = new java.math.BigDecimal("0.0100");
}
