package com.bosskin.entity;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Entity
// Unique thật nằm ở DB: uq_attendance_slot(employee_id, date, slot_key) — xem V1__baseline.sql
@Table(name = "attendances")
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
    @Column(name = "status")
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
    /** Giờ vào / ra sửa tay: ngày giờ đầy đủ (V27) — ngày chọn theo {@link com.bosskin.core.AttendanceTimes}. */
    @Column(name = "override_check_in")
    private LocalDateTime overrideCheckInAt;

    @Column(name = "override_check_out")
    private LocalDateTime overrideCheckOutAt;

    // Giao diện HH:mm cho code cũ (Excel, Tổng quan, DTO…): đọc trả giờ trong ngày, ghi tự chọn ngày theo ngày công + ca + giờ thật.

    public LocalTime getOverrideCheckIn() {
        return overrideCheckInAt != null ? overrideCheckInAt.toLocalTime() : null;
    }

    public LocalTime getOverrideCheckOut() {
        return overrideCheckOutAt != null ? overrideCheckOutAt.toLocalTime() : null;
    }

    public void setOverrideCheckIn(LocalTime time) {
        overrideCheckInAt = time == null ? null
            : com.bosskin.core.AttendanceTimes.resolveIn(date, time, overrideShiftStart());
    }

    /** Đặt sau giờ vào (nếu cần đặt cả hai thì gọi {@link #setOverrideTimes}): giờ ra tính theo giờ vào sửa tay, không có thì giờ vào thật. */
    public void setOverrideCheckOut(LocalTime time) {
        overrideCheckOutAt = time == null ? null
            : com.bosskin.core.AttendanceTimes.resolveOut(date, time,
                overrideCheckInAt != null ? overrideCheckInAt : checkIn, overrideShiftStart(), overrideShiftEnd());
    }

    public void setOverrideTimes(LocalTime in, LocalTime out) {
        setOverrideCheckIn(in);
        setOverrideCheckOut(out);
    }

    /** Khoảng vào → ra (sửa tay hoặc giờ thật) phải dương và dưới 24 giờ. */
    public boolean overrideSpanValid() {
        return com.bosskin.core.AttendanceTimes.validSpan(
            overrideCheckInAt != null ? overrideCheckInAt : checkIn,
            overrideCheckOutAt != null ? overrideCheckOutAt : checkOut);
    }

    /**
     * Bản ghi sửa tay tạo từ bảng công thường chưa gắn ca dù ngày đó nhân viên có đúng một ca; người gọi đặt "gợi ý ca" này trước khi
     * đặt giờ để chọn ngày đúng (vd. ca đêm đến muộn 00:30 → hôm sau). Chỉ dùng lúc đặt giờ, không lưu.
     */
    public void setShiftHint(LocalTime start, LocalTime end) {
        this.shiftHintStart = start;
        this.shiftHintEnd = end;
    }

    @Transient
    private LocalTime shiftHintStart;
    @Transient
    private LocalTime shiftHintEnd;

    private LocalTime overrideShiftStart() {
        return shiftAssignment != null ? shiftAssignment.effectiveStartTime() : shiftHintStart;
    }

    private LocalTime overrideShiftEnd() {
        return shiftAssignment != null ? shiftAssignment.effectiveEndTime() : shiftHintEnd;
    }

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
