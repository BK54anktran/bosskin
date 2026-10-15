package com.bosskin.service;

import com.bosskin.core.WorkFlagCalculator;
import com.bosskin.entity.Attendance;
import com.bosskin.entity.AttendanceRequest;
import com.bosskin.entity.Company;
import com.bosskin.entity.Department;
import com.bosskin.entity.Employee;
import com.bosskin.entity.LeaveRequest;
import com.bosskin.entity.ShiftAssignment;
import org.springframework.stereotype.Service;

import com.bosskin.core.AttendanceTimes;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Shared attendance calculation logic used by both AttendanceController and DashboardService.
 * Single source of truth for: policy resolution, row data computation, hours computation, work flags.
 */
@Service
public class AttendanceCalculationService {

    private static final Set<Integer> ALLOWED_ROUNDING = Set.of(1, 5, 15, 30, 60);

    private final Clock clock;

    public AttendanceCalculationService(Clock clock) {
        this.clock = clock;
    }

    // ── Public records ────────────────────────────────────────────────────────

    public record AttendancePolicy(
        Integer checkInToleranceMinutes,
        Integer checkOutToleranceMinutes,
        Integer roundingCheckInMinutes,
        Integer roundingCheckOutMinutes,
        Integer roundingWorkMinutes
    ) {}

    public record ComputedHours(
        double actualHours,
        double regularDayHours,
        double otDayHours,
        double regularNightHours,
        double otNightHours
    ) {}

    public record AttendanceRowData(
        String shiftName,
        String shiftColor,
        LocalTime shiftStart,
        LocalTime shiftEnd,
        int breakMinutes,
        LocalTime checkIn,
        LocalTime checkOut,
        LocalTime effectiveCheckIn,
        LocalTime effectiveCheckOut,
        LocalTime flagCheckIn,
        LocalTime flagCheckOut,
        Attendance.Status status,
        LocalTime requestedCheckIn,
        AttendanceRequest.Status requestedCheckInStatus,
        LocalTime requestedCheckOut,
        AttendanceRequest.Status requestedCheckOutStatus,
        Integer requestedOvertimeMinutes,
        AttendanceRequest.OvertimeScope requestedOvertimeScope,
        AttendanceRequest.OvertimePeriod requestedOvertimePeriod,
        AttendanceRequest.Status requestedOvertimeStatus,
        Long attendanceId,
        double actualHours,
        double regularDayHours,
        double otDayHours,
        double regularNightHours,
        double otNightHours,
        /** Ca linh hoạt: số phút phải làm; null = ca cố định (Mốc 2b). */
        Integer flexRequiredMinutes
    ) {}

    // ── Policy ────────────────────────────────────────────────────────────────

    public AttendancePolicy resolvePolicy(Employee employee) {
        Integer checkInTolerance = null, checkOutTolerance = null;
        Integer roundingCheckIn = null, roundingCheckOut = null, roundingWork = null;

        Department dept = employee != null ? employee.getDepartment() : null;
        while (dept != null) {
            if (checkInTolerance  == null && dept.getCheckInToleranceMinutes()  != null) checkInTolerance  = dept.getCheckInToleranceMinutes();
            if (checkOutTolerance == null && dept.getCheckOutToleranceMinutes() != null) checkOutTolerance = dept.getCheckOutToleranceMinutes();
            if (roundingCheckIn   == null && dept.getRoundingCheckInMinutes()   != null) roundingCheckIn   = dept.getRoundingCheckInMinutes();
            if (roundingCheckOut  == null && dept.getRoundingCheckOutMinutes()  != null) roundingCheckOut  = dept.getRoundingCheckOutMinutes();
            if (roundingWork      == null && dept.getRoundingWorkMinutes()      != null) roundingWork      = dept.getRoundingWorkMinutes();
            dept = dept.getParent();
        }

        Company company = employee != null ? employee.getCompany() : null;
        if (company != null) {
            if (checkInTolerance  == null) checkInTolerance  = company.getCheckInToleranceMinutes();
            if (checkOutTolerance == null) checkOutTolerance = company.getCheckOutToleranceMinutes();
            if (roundingCheckIn   == null) roundingCheckIn   = company.getRoundingCheckInMinutes();
            if (roundingCheckOut  == null) roundingCheckOut  = company.getRoundingCheckOutMinutes();
            if (roundingWork      == null) roundingWork      = company.getRoundingWorkMinutes();
        }

        return new AttendancePolicy(
            normalizeTolerance(checkInTolerance),
            normalizeTolerance(checkOutTolerance),
            normalizeRounding(roundingCheckIn),
            normalizeRounding(roundingCheckOut),
            normalizeRounding(roundingWork)
        );
    }

    // ── Shift times ───────────────────────────────────────────────────────────

    public record ShiftTimes(
        String name, String color,
        LocalTime start, LocalTime end,
        LocalTime breakStart, LocalTime breakEnd,
        int breakMinutes
    ) {}

    /** Lay gio ca tu ShiftAssignment (ke ca custom). */
    public ShiftTimes resolveShiftTimes(ShiftAssignment assignment) {
        if (assignment == null) return new ShiftTimes(null, null, null, null, null, null, 0);
        LocalTime shiftStart, shiftEnd, breakStart = null, breakEnd = null;
        String shiftName, shiftColor = null;
        if (assignment.isCustom()) {
            shiftStart = assignment.getCustomStartTime();
            shiftEnd   = assignment.getCustomEndTime();
            breakStart = assignment.getCustomBreakStart();
            breakEnd   = assignment.getCustomBreakEnd();
            shiftName  = "Tuy chinh";
        } else if (assignment.getShift() != null) {
            var s = assignment.getShift();
            shiftStart = assignment.effectiveStartTime();
            shiftEnd   = assignment.effectiveEndTime();
            breakStart = assignment.effectiveBreakStart();
            breakEnd   = assignment.effectiveBreakEnd();
            shiftName  = s.getName();
            shiftColor = s.getColor();
        } else {
            return new ShiftTimes(null, null, null, null, null, null, 0);
        }
        int breakMinutes = 0;
        if (breakStart != null && breakEnd != null) {
            int bs = breakStart.toSecondOfDay() / 60, be = breakEnd.toSecondOfDay() / 60;
            if (be < bs) be += 1440;
            breakMinutes = be - bs;
        }
        return new ShiftTimes(shiftName, shiftColor, shiftStart, shiftEnd, breakStart, breakEnd, breakMinutes);
    }

    // ── Requests ──────────────────────────────────────────────────────────────

    public record ResolvedRequests(
        AttendanceRequest checkInRequest,
        AttendanceRequest appliedCheckInRequest,
        AttendanceRequest checkOutRequest,
        AttendanceRequest appliedCheckOutRequest,
        List<AttendanceRequest> overtimeRequests,
        List<AttendanceRequest> appliedOvertimeRequests,
        List<AttendanceRequest> appliedExtraRequests
    ) {}

    /** Phan loai va loc AttendanceRequest theo slot/ca. */
    public ResolvedRequests resolveRequests(List<AttendanceRequest> requests,
                                            ShiftAssignment assignment, int slotIndex) {
        AttendanceRequest checkInReq = null, appliedCheckInReq = null;
        AttendanceRequest checkOutReq = null, appliedCheckOutReq = null;
        List<AttendanceRequest> otReqs = new ArrayList<>(), appliedOtReqs = new ArrayList<>(), appliedExtraReqs = new ArrayList<>();
        if (requests != null) {
            for (AttendanceRequest r : requests) {
                if (r.getStatus() != AttendanceRequest.Status.APPROVED) continue;
                Long reqShiftId = r.getShiftAssignment() != null ? r.getShiftAssignment().getId() : null;
                if (assignment != null) {
                    if (reqShiftId != null && !reqShiftId.equals(assignment.getId())) continue;
                    if (reqShiftId == null && slotIndex > 0) continue;
                }
                switch (r.getRequestType()) {
                    case CHECK_IN  -> { checkInReq  = r; if (r.isApplied()) appliedCheckInReq  = r; }
                    case CHECK_OUT -> { checkOutReq = r; if (r.isApplied()) appliedCheckOutReq = r; }
                    case OT        -> { otReqs.add(r);   if (r.isApplied()) appliedOtReqs.add(r); }
                    case EXTRA     -> { otReqs.add(r);   if (r.isApplied()) appliedExtraReqs.add(r); }
                }
            }
        }
        return new ResolvedRequests(checkInReq, appliedCheckInReq, checkOutReq, appliedCheckOutReq,
            otReqs, appliedOtReqs, appliedExtraReqs);
    }

    // ── Effective check-in / check-out ────────────────────────────────────────

    /**
     * Check-in hiệu quả: đơn sửa giờ đã duyệt và áp dụng THAY THẾ giờ thực (A16) — để sửa
     * được cả trường hợp bấm nhầm/giờ thực sai; không có đơn thì dùng giờ thực.
     */
    public LocalTime resolveEffectiveCheckIn(Attendance att, ResolvedRequests req, ShiftTimes shift) {
        LocalTime actualCheckIn    = att != null && att.getCheckIn()  != null ? att.getCheckIn().toLocalTime()  : null;
        LocalTime requestedCheckIn = req.appliedCheckInRequest() != null ? req.appliedCheckInRequest().getRequestedCheckIn() : null;
        return requestedCheckIn != null ? requestedCheckIn : actualCheckIn;
    }

    /** Check-out hiệu quả: đơn đã áp dụng thay thế giờ thực (A16). */
    public LocalTime resolveEffectiveCheckOut(Attendance att, ResolvedRequests req, ShiftTimes shift) {
        LocalTime actualCheckOut    = att != null && att.getCheckOut() != null ? att.getCheckOut().toLocalTime() : null;
        LocalTime requestedCheckOut = req.appliedCheckOutRequest() != null ? req.appliedCheckOutRequest().getRequestedCheckOut() : null;
        return requestedCheckOut != null ? requestedCheckOut : actualCheckOut;
    }

    // ── Work hours ────────────────────────────────────────────────────────────

    /**
     * Tinh gio cong: thuc te, ngay thuong, OT ngay, dem thuong, OT dem.
     * Nhan check-in/out da round va approved OT requests.
     */
    public ComputedHours computeWorkHours(
        ShiftTimes shift,
        Integer checkInMin,
        Integer checkOutMin,
        LocalTime dayStart,
        LocalTime dayEnd,
        LocalTime leaveFrom,
        LocalTime leaveTo,
        ResolvedRequests req,
        boolean otEnabled,
        AttendancePolicy policy
    ) {
        ShiftAbs sa = ShiftAbs.of(shift);
        Integer[] leave = sa.leaveAbs(leaveFrom, leaveTo);
        var calc = (checkInMin == null || checkOutMin == null)
            ? AttendanceCalculator.Result.ZERO
            : AttendanceCalculator.calculate(
                sa.start(), sa.end(), sa.breakStart(), sa.breakEnd(),
                checkInMin, checkOutMin, minuteOfDay(dayStart), minuteOfDay(dayEnd), leave[0], leave[1]);

        int actualMin   = hoursToMinutes(calc.actualHours());
        int regDayMin   = hoursToMinutes(calc.regularDayHours());
        int regNightMin = hoursToMinutes(calc.regularNightHours());
        int otDayMin    = hoursToMinutes(calc.otDayHours());
        int otNightMin  = hoursToMinutes(calc.otNightHours());
        // A15: OT ngoài ca không vượt quá thời gian thực sự có mặt ngoài giờ ca
        int outsideBudget = hoursToMinutes(calc.outsideShiftHours());

        for (AttendanceRequest r : req.appliedOvertimeRequests()) {
            if (r.getRequestedOvertimeMinutes() == null) continue;
            int overtimeMinutes = Math.max(0, r.getRequestedOvertimeMinutes());
            if (r.getRequestedOvertimeScope() == AttendanceRequest.OvertimeScope.IN_SHIFT) {
                if (r.getRequestedOvertimePeriod() == AttendanceRequest.OvertimePeriod.NIGHT) {
                    int moved = Math.min(overtimeMinutes, regNightMin); regNightMin -= moved; otNightMin += moved;
                } else {
                    int moved = Math.min(overtimeMinutes, regDayMin);   regDayMin   -= moved; otDayMin   += moved;
                }
            } else if (r.getRequestedOvertimeScope() == AttendanceRequest.OvertimeScope.OUTSIDE_SHIFT) {
                overtimeMinutes = Math.min(overtimeMinutes, outsideBudget);
                outsideBudget -= overtimeMinutes;
                actualMin += overtimeMinutes;
                if (r.getRequestedOvertimePeriod() == AttendanceRequest.OvertimePeriod.NIGHT) otNightMin += overtimeMinutes;
                else otDayMin += overtimeMinutes;
            }
        }
        for (AttendanceRequest r : req.appliedExtraRequests()) {
            if (r.getRequestedOvertimeMinutes() == null) continue;
            int extraMinutes = Math.max(0, r.getRequestedOvertimeMinutes());
            actualMin += extraMinutes;
            if (r.getRequestedOvertimePeriod() == AttendanceRequest.OvertimePeriod.NIGHT) regNightMin += extraMinutes;
            else regDayMin += extraMinutes;
        }
        if (!otEnabled) {
            regDayMin += otDayMin; regNightMin += otNightMin;
            otDayMin = 0; otNightMin = 0;
        }
        if (policy.roundingWorkMinutes() != null) {
            regDayMin   = roundDownMinutes(regDayMin,   policy.roundingWorkMinutes());
            regNightMin = roundDownMinutes(regNightMin, policy.roundingWorkMinutes());
            otDayMin    = roundDownMinutes(otDayMin,    policy.roundingWorkMinutes());
            otNightMin  = roundDownMinutes(otNightMin,  policy.roundingWorkMinutes());
        }
        return new ComputedHours(actualMin / 60.0, regDayMin / 60.0, otDayMin / 60.0, regNightMin / 60.0, otNightMin / 60.0);
    }

    // ── Display status ────────────────────────────────────────────────────────

    /**
     * Suy ra trang thai hien thi tu du lieu thuc te (khong luu DB).
     * - Approved  -> dung status da luu.
     * - Chua approved:
     *   + Co check-in + co ca + di tre qua tolerance -> LATE
     *   + Co check-in -> PRESENT
     *   + Khong check-in + co ca da ket thuc -> ABSENT
     *   + Khong check-in + ca chua ket thuc (chua toi gio / dang trong ca) -> null (chua tinh vang)
     *   + Khong co ca -> null
     */
    public Attendance.Status deriveDisplayStatus(
        Attendance att,
        ShiftAssignment assignment,
        LocalTime effectiveCheckIn,
        LocalTime flagCheckIn,
        LocalTime flagCheckOut,
        ShiftTimes shift,
        AttendancePolicy policy
    ) {
        if (att == null) return null;
        if (att.isApproved()) return att.getStatus();
        boolean hasCheckIn = effectiveCheckIn != null
            || (att.getOverrideCheckIn() != null)
            || (att.getCheckIn() != null);
        if (!hasCheckIn) {
            return assignment != null && shiftEnded(att.getDate(), shift) ? Attendance.Status.ABSENT : null;
        }
        if (shift.start() != null && shift.end() != null && flagCheckIn != null) {
            var flags = WorkFlagCalculator.calculate(
                shift.start(), shift.end(), flagCheckIn, flagCheckOut,
                0, 0, false,
                policy.checkInToleranceMinutes(), policy.checkOutToleranceMinutes());
            if (flags.contains(WorkFlagCalculator.Flag.LATE_IN)) return Attendance.Status.LATE;
        }
        return Attendance.Status.PRESENT;
    }

    /** Ca đã kết thúc chưa (ca qua đêm kết thúc hôm sau; không rõ giờ kết thúc → hết ngày). */
    public boolean shiftEnded(LocalDate date, ShiftTimes shift) {
        if (date == null) return true;
        LocalDateTime end;
        if (shift.end() == null) {
            end = date.plusDays(1).atStartOfDay();
        } else {
            boolean overnight = shift.start() != null && !shift.end().isAfter(shift.start());
            end = (overnight ? date.plusDays(1) : date).atTime(shift.end());
        }
        return !LocalDateTime.now(clock).isBefore(end);
    }

    // ── Row data (composite — dung cac ham tren, giu nguyen cho controller) ───

    public AttendanceRowData computeRowData(
        Attendance att,
        ShiftAssignment assignment,
        int slotIndex,
        List<AttendanceRequest> requests,
        LocalTime leaveFrom,
        LocalTime leaveTo,
        LocalTime dayStart,
        LocalTime dayEnd,
        boolean otEnabled,
        AttendancePolicy policy
    ) {
        ShiftTimes shift        = resolveShiftTimes(assignment);
        ResolvedRequests req    = resolveRequests(requests, assignment, slotIndex);

        LocalTime actualCheckIn  = att != null && att.getCheckIn()  != null ? att.getCheckIn().toLocalTime()  : null;
        LocalTime actualCheckOut = att != null && att.getCheckOut() != null ? att.getCheckOut().toLocalTime() : null;

        LocalTime effectiveCheckIn  = resolveEffectiveCheckIn(att, req, shift);
        LocalTime effectiveCheckOut = resolveEffectiveCheckOut(att, req, shift);
        // Giờ làm tính trên ngày giờ thật (hiệu số), làm tròn trên số phút tuyệt đối từ 00:00 ngày công
        LocalDateTime[] span = resolveEffectiveSpan(att, req, shift);
        Integer checkInMin  = span[0] == null ? null
            : roundUpMinutes(AttendanceTimes.minutesFrom(att.getDate(), span[0]), policy.roundingCheckInMinutes());
        Integer checkOutMin = span[1] == null ? null
            : roundDownMinutesAbs(AttendanceTimes.minutesFrom(att.getDate(), span[1]), policy.roundingCheckOutMinutes());
        LocalTime flagCheckIn       = roundUp  (req.appliedCheckInRequest()  != null ? req.appliedCheckInRequest().getRequestedCheckIn()   : actualCheckIn,  policy.roundingCheckInMinutes());
        LocalTime flagCheckOut      = roundDown(req.appliedCheckOutRequest() != null ? req.appliedCheckOutRequest().getRequestedCheckOut() : actualCheckOut, policy.roundingCheckOutMinutes());

        ComputedHours workHours = capFlexible(computeWorkHours(shift, checkInMin, checkOutMin,
            dayStart, dayEnd, leaveFrom, leaveTo, req, otEnabled, policy),
            assignment != null ? assignment.flexibleRequiredMinutes() : null);

        List<AttendanceRequest> otRequests = req.overtimeRequests();
        return new AttendanceRowData(
            shift.name(), shift.color(), shift.start(), shift.end(), shift.breakMinutes(),
            actualCheckIn, actualCheckOut, effectiveCheckIn, effectiveCheckOut, flagCheckIn, flagCheckOut,
            att != null ? att.getStatus() : null,
            req.checkInRequest()  != null ? req.checkInRequest().getRequestedCheckIn()   : null,
            req.checkInRequest()  != null ? req.checkInRequest().getStatus()             : null,
            req.checkOutRequest() != null ? req.checkOutRequest().getRequestedCheckOut() : null,
            req.checkOutRequest() != null ? req.checkOutRequest().getStatus()            : null,
            otRequests.isEmpty() ? null : otRequests.stream().mapToInt(r -> r.getRequestedOvertimeMinutes() != null ? r.getRequestedOvertimeMinutes() : 0).sum(),
            otRequests.isEmpty() ? null : otRequests.get(0).getRequestedOvertimeScope(),
            otRequests.isEmpty() ? null : otRequests.get(0).getRequestedOvertimePeriod(),
            otRequests.isEmpty() ? null : otRequests.get(0).getStatus(),
            att != null ? att.getId() : null,
            workHours.actualHours(), workHours.regularDayHours(), workHours.otDayHours(),
            workHours.regularNightHours(), workHours.otNightHours(),
            assignment != null ? assignment.flexibleRequiredMinutes() : null
        );
    }

    // ── Hours ─────────────────────────────────────────────────────────────────

    public ComputedHours computeHours(
        Attendance att,
        AttendanceRowData data,
        AttendancePolicy policy,
        LocalTime dayStart,
        LocalTime dayEnd,
        boolean useSnapshot
    ) {
        if (useSnapshot && att != null && att.isApproved()) {
            return new ComputedHours(
                att.getSnapActualHours()  != null ? att.getSnapActualHours()  : data.actualHours(),
                att.getSnapDayHours()     != null ? att.getSnapDayHours()     : data.regularDayHours(),
                att.getSnapDayOt()        != null ? att.getSnapDayOt()        : data.otDayHours(),
                att.getSnapNightHours()   != null ? att.getSnapNightHours()   : data.regularNightHours(),
                att.getSnapNightOt()      != null ? att.getSnapNightOt()      : data.otNightHours()
            );
        }
        boolean hasOverride = att != null && (att.getOverrideCheckIn() != null || att.getOverrideCheckOut() != null
            || att.getOverrideOtDayMinutes() != null || att.getOverrideOtNightMinutes() != null);
        if (hasOverride) {
            // Giờ sửa tay là ngày giờ đầy đủ; đầu không sửa lấy giờ thật. Hiệu số thật, không đoán qua đêm.
            LocalDateTime ovInAt  = att.getOverrideCheckInAt()  != null ? att.getOverrideCheckInAt()  : att.getCheckIn();
            LocalDateTime ovOutAt = att.getOverrideCheckOutAt() != null ? att.getOverrideCheckOutAt() : att.getCheckOut();
            int ovBreakMin = att.getOverrideBreakMinutes() != null ? att.getOverrideBreakMinutes() : data.breakMinutes();
            double actual, regDay, regNight;
            if (ovInAt != null && ovOutAt != null) {
                int ovCI = roundUpMinutes(AttendanceTimes.minutesFrom(att.getDate(), ovInAt), policy.roundingCheckInMinutes());
                int ovCO = roundDownMinutesAbs(AttendanceTimes.minutesFrom(att.getDate(), ovOutAt), policy.roundingCheckOutMinutes());
                int brkStart = ovCI + (Math.max(0, ovCO - ovCI) - ovBreakMin) / 2;
                ShiftAbs sa = ShiftAbs.of(data.shiftStart(), data.shiftEnd(), null, null);
                var c = AttendanceCalculator.calculate(sa.start(), sa.end(),
                    ovBreakMin > 0 ? brkStart : null, ovBreakMin > 0 ? brkStart + ovBreakMin : null,
                    ovCI, ovCO, minuteOfDay(dayStart), minuteOfDay(dayEnd), null, null);
                actual = c.actualHours(); regDay = c.regularDayHours(); regNight = c.regularNightHours();
            } else { actual = regDay = regNight = 0; }
            double otDay   = att.getOverrideOtDayMinutes()   != null ? att.getOverrideOtDayMinutes()   / 60.0 : data.otDayHours();
            double otNight = att.getOverrideOtNightMinutes() != null ? att.getOverrideOtNightMinutes() / 60.0 : data.otNightHours();
            if (policy.roundingWorkMinutes() != null) {
                regDay   = roundDownHours(regDay,   policy.roundingWorkMinutes());
                regNight = roundDownHours(regNight, policy.roundingWorkMinutes());
                otDay    = roundDownHours(otDay,    policy.roundingWorkMinutes());
                otNight  = roundDownHours(otNight,  policy.roundingWorkMinutes());
            }
            return capFlexible(new ComputedHours(actual, regDay, otDay, regNight, otNight), data.flexRequiredMinutes());
        }
        return new ComputedHours(data.actualHours(), data.regularDayHours(), data.otDayHours(), data.regularNightHours(), data.otNightHours());
    }

    // ── Ca linh hoạt (Mốc 2b) ───────────────────────────────────────────────

    /**
     * Ca linh hoạt: giờ công thường không vượt quá số phút phải làm (phần dư trong khung không
     * tự thành tăng ca — tăng ca vẫn cần đơn). Chia lại tỉ lệ ngày/đêm theo phần được tính.
     */
    public static ComputedHours capFlexible(ComputedHours h, Integer requiredMinutes) {
        if (requiredMinutes == null || requiredMinutes <= 0) return h;
        double regular = h.regularDayHours() + h.regularNightHours();
        double cap = requiredMinutes / 60.0;
        if (regular <= cap || regular <= 0) return h;
        double f = cap / regular;
        return new ComputedHours(h.actualHours(), h.regularDayHours() * f, h.otDayHours(),
            h.regularNightHours() * f, h.otNightHours());
    }

    /** Ca linh hoạt thiếu giờ quá dung sai vào ca → coi là đi muộn (thiếu giờ). */
    public static boolean flexibleShort(double regularHours, Integer requiredMinutes, Integer toleranceMinutes) {
        if (requiredMinutes == null) return false;
        int tol = toleranceMinutes != null ? toleranceMinutes : 15;
        return regularHours * 60 < requiredMinutes - tol - 0.5;
    }

    /**
     * Trạng thái + cờ khi duyệt cho ca linh hoạt: không so giờ vào với giờ bắt đầu khung,
     * chỉ xét đủ số phút. Trả null nếu không phải ca linh hoạt (giữ cách tính ca cố định).
     */
    public FlexOutcome flexibleOutcome(AttendanceRowData data, ComputedHours snap, boolean onLeave,
                                       Attendance.Status computedStatus, AttendancePolicy policy) {
        if (data.flexRequiredMinutes() == null) return null;
        double regular = snap.regularDayHours() + snap.regularNightHours();
        boolean shortHours = flexibleShort(regular, data.flexRequiredMinutes(), policy.checkInToleranceMinutes());
        java.util.Set<WorkFlagCalculator.Flag> flags = java.util.EnumSet.noneOf(WorkFlagCalculator.Flag.class);
        if (snap.otDayHours() + snap.otNightHours() > 0) flags.add(WorkFlagCalculator.Flag.OVERTIME);
        Attendance.Status status = computedStatus;
        if (computedStatus == Attendance.Status.PRESENT || computedStatus == Attendance.Status.LATE) {
            status = shortHours && !onLeave ? Attendance.Status.LATE : Attendance.Status.PRESENT;
            flags.add(status == Attendance.Status.LATE ? WorkFlagCalculator.Flag.LATE_IN : WorkFlagCalculator.Flag.ON_TIME);
        }
        return new FlexOutcome(status, WorkFlagCalculator.serialize(flags));
    }

    public record FlexOutcome(Attendance.Status status, String workFlags) {}

    // ── Work flags ────────────────────────────────────────────────────────────

    public String resolveWorkFlags(Attendance att, AttendanceRowData data, LeaveRequest leave, AttendancePolicy policy) {
        if (att != null && att.isApproved() && att.getWorkFlags() != null) {
            return att.getWorkFlags();
        }
        LocalTime flagCheckIn;
        if (att != null && att.getOverrideCheckIn() != null) flagCheckIn = att.getOverrideCheckIn();
        else if (data.flagCheckIn() != null) flagCheckIn = data.flagCheckIn();
        else flagCheckIn = data.effectiveCheckIn() != null ? roundUp(data.effectiveCheckIn(), policy.roundingCheckInMinutes()) : null;

        LocalTime flagCheckOut;
        if (att != null && att.getOverrideCheckOut() != null) flagCheckOut = att.getOverrideCheckOut();
        else if (data.flagCheckOut() != null) flagCheckOut = data.flagCheckOut();
        else flagCheckOut = data.effectiveCheckOut() != null ? roundDown(data.effectiveCheckOut(), policy.roundingCheckOutMinutes()) : null;

        if (flagCheckIn == null || flagCheckOut == null) {
            double otDay   = att != null && att.getOverrideOtDayMinutes()   != null ? att.getOverrideOtDayMinutes()   / 60.0 : data.otDayHours();
            double otNight = att != null && att.getOverrideOtNightMinutes() != null ? att.getOverrideOtNightMinutes() / 60.0 : data.otNightHours();
            return (otDay > 0 || otNight > 0) ? "OVERTIME" : null;
        }
        double otDay   = att != null && att.getOverrideOtDayMinutes()   != null ? att.getOverrideOtDayMinutes()   / 60.0 : data.otDayHours();
        double otNight = att != null && att.getOverrideOtNightMinutes() != null ? att.getOverrideOtNightMinutes() / 60.0 : data.otNightHours();
        if (data.flexRequiredMinutes() != null) {
            var h = new ComputedHours(data.actualHours(), data.regularDayHours(), otDay, data.regularNightHours(), otNight);
            return flexibleOutcome(data, h, leave != null, Attendance.Status.PRESENT, policy).workFlags();
        }
        var flags = WorkFlagCalculator.calculate(
            data.shiftStart(), data.shiftEnd(), flagCheckIn, flagCheckOut,
            otDay, otNight, leave != null, policy.checkInToleranceMinutes(), policy.checkOutToleranceMinutes());
        return WorkFlagCalculator.serialize(flags);
    }

    // ── Status helpers ────────────────────────────────────────────────────────

    /**
     * Có mặt thực sự:
     * - Đã approved → dùng snapshot
     * - Chưa approved → có checkIn hoặc overrideCheckIn
     */
    public boolean isActuallyPresent(Attendance a) {
        if (a.isApproved()) {
            if (a.getStatus() == Attendance.Status.ABSENT || a.getStatus() == Attendance.Status.LEAVE) return false;
            double snap = (a.getSnapActualHours()  != null ? a.getSnapActualHours()  : 0)
                        + (a.getSnapDayHours()     != null ? a.getSnapDayHours()     : 0)
                        + (a.getSnapDayOt()        != null ? a.getSnapDayOt()        : 0)
                        + (a.getSnapNightHours()   != null ? a.getSnapNightHours()   : 0)
                        + (a.getSnapNightOt()      != null ? a.getSnapNightOt()      : 0);
            return snap > 0 || a.getStatus() == Attendance.Status.PRESENT || a.getStatus() == Attendance.Status.LATE;
        }
        return a.getCheckIn() != null || a.getOverrideCheckIn() != null;
    }

    /**
     * Đi muộn:
     * - Đã approved → đọc workFlags (LATE_IN)
     * - Chưa approved → không thể biết chắc (workFlags chưa được tính)
     */
    public boolean isLate(Attendance a) {
        if (a.isApproved() && a.getWorkFlags() != null) {
            return WorkFlagCalculator.deserialize(a.getWorkFlags()).contains(WorkFlagCalculator.Flag.LATE_IN);
        }
        return false;
    }

    /**
     * Vang mat:
     * - Da approved -> status == ABSENT
     * - Chua approved -> co ca (hasShift=true) ma khong co check-in/override
     */
    public boolean isAbsent(Attendance a, boolean hasShift) {
        if (a.isApproved()) return Attendance.Status.ABSENT == a.getStatus();
        return hasShift && a.getCheckIn() == null && a.getOverrideCheckIn() == null;
    }

    // ── Trục thời gian tuyệt đối ──────────────────────────────────────────────

    /** Giờ vào / ra hiệu quả bằng ngày giờ thật: đơn đã duyệt thay giờ thật (A16); giờ trong đơn chỉ có HH:mm nên ghép ngày theo ca / giờ vào. */
    LocalDateTime[] resolveEffectiveSpan(Attendance att, ResolvedRequests req, ShiftTimes shift) {
        if (att == null || att.getDate() == null) return new LocalDateTime[]{null, null};
        LocalDateTime in = att.getCheckIn();
        LocalTime reqIn = req.appliedCheckInRequest() != null ? req.appliedCheckInRequest().getRequestedCheckIn() : null;
        if (reqIn != null) in = AttendanceTimes.resolveIn(att.getDate(), reqIn, shift.start());
        LocalDateTime out = att.getCheckOut();
        LocalTime reqOut = req.appliedCheckOutRequest() != null ? req.appliedCheckOutRequest().getRequestedCheckOut() : null;
        if (reqOut != null) out = AttendanceTimes.resolveOut(att.getDate(), reqOut, in, shift.start(), shift.end());
        return new LocalDateTime[]{in, out};
    }

    private static int minuteOfDay(LocalTime t) {
        return t.getHour() * 60 + t.getMinute();
    }

    /** Ca + giờ nghỉ + giờ nghỉ phép quy về số phút tuyệt đối từ 00:00 ngày công (ca qua đêm: kết thúc &gt; 1440). */
    private record ShiftAbs(Integer start, Integer end, Integer breakStart, Integer breakEnd) {
        static ShiftAbs of(ShiftTimes s) {
            return of(s.start(), s.end(), s.breakStart(), s.breakEnd());
        }

        static ShiftAbs of(LocalTime start, LocalTime end, LocalTime bs, LocalTime be) {
            if (start == null || end == null) return new ShiftAbs(null, null, null, null);
            int ss = minuteOfDay(start), se = minuteOfDay(end);
            if (se <= ss) se += AttendanceTimes.DAY_MINUTES;
            Integer b1 = null, b2 = null;
            if (bs != null && be != null) {
                int x = minuteOfDay(bs);
                int dur = (minuteOfDay(be) - x + AttendanceTimes.DAY_MINUTES) % AttendanceTimes.DAY_MINUTES;
                if (x < ss) x += AttendanceTimes.DAY_MINUTES; // nghỉ sau nửa đêm của ca qua đêm
                if (dur > 0) { b1 = x; b2 = x + dur; }
            }
            return new ShiftAbs(ss, se, b1, b2);
        }

        Integer[] leaveAbs(LocalTime from, LocalTime to) {
            if (from == null || to == null) return new Integer[]{null, null};
            int lf = minuteOfDay(from);
            int dur = (minuteOfDay(to) - lf + AttendanceTimes.DAY_MINUTES) % AttendanceTimes.DAY_MINUTES;
            if (dur == 0) return new Integer[]{null, null};
            if (start != null && end != null && end > AttendanceTimes.DAY_MINUTES && lf < start) lf += AttendanceTimes.DAY_MINUTES;
            return new Integer[]{lf, lf + dur};
        }
    }

    /** Làm tròn LÊN theo bước phút trên số phút tuyệt đối (không quấn qua nửa đêm như LocalTime). */
    static int roundUpMinutes(int minutes, Integer step) {
        if (step == null || step <= 1) return minutes;
        return Math.floorDiv(minutes + step - 1, step) * step;
    }

    /** Làm tròn XUỐNG theo bước phút trên số phút tuyệt đối. */
    static int roundDownMinutesAbs(int minutes, Integer step) {
        if (step == null || step <= 1) return minutes;
        return Math.floorDiv(minutes, step) * step;
    }

    // ── Time helpers ──────────────────────────────────────────────────────────

    public LocalTime roundUp(LocalTime value, Integer stepMinutes) {
        if (value == null || stepMinutes == null || stepMinutes <= 1) return value;
        int total = value.getHour() * 60 + value.getMinute();
        int rounded = ((total + stepMinutes - 1) / stepMinutes) * stepMinutes;
        rounded = rounded % (24 * 60);
        return LocalTime.of(rounded / 60, rounded % 60);
    }

    public LocalTime roundDown(LocalTime value, Integer stepMinutes) {
        if (value == null || stepMinutes == null || stepMinutes <= 1) return value;
        int total = value.getHour() * 60 + value.getMinute();
        int rounded = (total / stepMinutes) * stepMinutes;
        rounded = rounded % (24 * 60);
        return LocalTime.of(rounded / 60, rounded % 60);
    }

    public int roundDownMinutes(int minutes, Integer stepMinutes) {
        if (stepMinutes == null || stepMinutes <= 1) return Math.max(0, minutes);
        return Math.max(0, (minutes / stepMinutes) * stepMinutes);
    }

    public double roundDownHours(double hours, Integer stepMinutes) {
        if (stepMinutes == null || stepMinutes <= 1) return hours;
        int mins = (int) Math.floor(hours * 60.0 + 1e-9);
        return roundDownMinutes(mins, stepMinutes) / 60.0;
    }

    public int hoursToMinutes(double hours) {
        return (int) Math.round(hours * 60.0);
    }

    public LocalTime chooseEarlier(LocalTime actual, LocalTime requested, LocalTime shiftStart, LocalTime shiftEnd) {
        if (actual == null) return requested;
        if (requested == null) return actual;
        return compareTimeline(actual, requested, shiftStart, shiftEnd) <= 0 ? actual : requested;
    }

    public LocalTime chooseLater(LocalTime actual, LocalTime requested, LocalTime shiftStart, LocalTime shiftEnd) {
        if (actual == null) return requested;
        if (requested == null) return actual;
        return compareTimeline(actual, requested, shiftStart, shiftEnd) >= 0 ? actual : requested;
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    private int compareTimeline(LocalTime a, LocalTime b, LocalTime shiftStart, LocalTime shiftEnd) {
        return Integer.compare(toTimelineMinutes(a, shiftStart, shiftEnd), toTimelineMinutes(b, shiftStart, shiftEnd));
    }

    private int toTimelineMinutes(LocalTime time, LocalTime shiftStart, LocalTime shiftEnd) {
        int minutes = time.toSecondOfDay() / 60;
        boolean overnight = shiftStart != null && shiftEnd != null && !shiftEnd.isAfter(shiftStart);
        if (overnight && time.isBefore(shiftStart)) minutes += 1440;
        return minutes;
    }

    private Integer normalizeTolerance(Integer minutes) {
        return (minutes == null || minutes < 0) ? null : minutes;
    }

    private Integer normalizeRounding(Integer minutes) {
        return (minutes != null && ALLOWED_ROUNDING.contains(minutes)) ? minutes : null;
    }
}
