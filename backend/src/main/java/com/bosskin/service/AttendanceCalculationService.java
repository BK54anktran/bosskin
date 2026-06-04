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
        double otNightHours
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
            shiftStart = assignment.getCustomStartTime()  != null ? assignment.getCustomStartTime()  : s.getStartTime();
            shiftEnd   = assignment.getCustomEndTime()    != null ? assignment.getCustomEndTime()    : s.getEndTime();
            breakStart = assignment.getCustomBreakStart() != null ? assignment.getCustomBreakStart() : s.getBreakStart();
            breakEnd   = assignment.getCustomBreakEnd()   != null ? assignment.getCustomBreakEnd()   : s.getBreakEnd();
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
     * Check-in hieu qua: som nhat giua thuc te va request da applied.
     */
    public LocalTime resolveEffectiveCheckIn(Attendance att, ResolvedRequests req, ShiftTimes shift) {
        LocalTime actualCheckIn    = att != null && att.getCheckIn()  != null ? att.getCheckIn().toLocalTime()  : null;
        LocalTime requestedCheckIn = req.appliedCheckInRequest() != null ? req.appliedCheckInRequest().getRequestedCheckIn() : null;
        return chooseEarlier(actualCheckIn, requestedCheckIn, shift.start(), shift.end());
    }

    /**
     * Check-out hieu qua: tre nhat giua thuc te va request da applied.
     */
    public LocalTime resolveEffectiveCheckOut(Attendance att, ResolvedRequests req, ShiftTimes shift) {
        LocalTime actualCheckOut    = att != null && att.getCheckOut() != null ? att.getCheckOut().toLocalTime() : null;
        LocalTime requestedCheckOut = req.appliedCheckOutRequest() != null ? req.appliedCheckOutRequest().getRequestedCheckOut() : null;
        return chooseLater(actualCheckOut, requestedCheckOut, shift.start(), shift.end());
    }

    // ── Work hours ────────────────────────────────────────────────────────────

    /**
     * Tinh gio cong: thuc te, ngay thuong, OT ngay, dem thuong, OT dem.
     * Nhan check-in/out da round va approved OT requests.
     */
    public ComputedHours computeWorkHours(
        ShiftTimes shift,
        LocalTime roundedCheckIn,
        LocalTime roundedCheckOut,
        LocalTime dayStart,
        LocalTime dayEnd,
        LocalTime leaveFrom,
        LocalTime leaveTo,
        ResolvedRequests req,
        boolean otEnabled,
        AttendancePolicy policy
    ) {
        var calc = AttendanceCalculator.calculate(
            shift.start(), shift.end(), shift.breakStart(), shift.breakEnd(),
            roundedCheckIn, roundedCheckOut, dayStart, dayEnd, leaveFrom, leaveTo);

        int actualMin   = hoursToMinutes(calc.actualHours());
        int regDayMin   = hoursToMinutes(calc.regularDayHours());
        int regNightMin = hoursToMinutes(calc.regularNightHours());
        int otDayMin    = hoursToMinutes(calc.otDayHours());
        int otNightMin  = hoursToMinutes(calc.otNightHours());

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
     *   + Khong check-in + co ca -> ABSENT
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
        if (!hasCheckIn) return assignment != null ? Attendance.Status.ABSENT : null;
        if (shift.start() != null && shift.end() != null && flagCheckIn != null) {
            var flags = WorkFlagCalculator.calculate(
                shift.start(), shift.end(), flagCheckIn, flagCheckOut,
                0, 0, false,
                policy.checkInToleranceMinutes(), policy.checkOutToleranceMinutes());
            if (flags.contains(WorkFlagCalculator.Flag.LATE_IN)) return Attendance.Status.LATE;
        }
        return Attendance.Status.PRESENT;
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
        LocalTime roundedCheckIn    = roundUp  (effectiveCheckIn,  policy.roundingCheckInMinutes());
        LocalTime roundedCheckOut   = roundDown(effectiveCheckOut, policy.roundingCheckOutMinutes());
        LocalTime flagCheckIn       = roundUp  (req.appliedCheckInRequest()  != null ? req.appliedCheckInRequest().getRequestedCheckIn()   : actualCheckIn,  policy.roundingCheckInMinutes());
        LocalTime flagCheckOut      = roundDown(req.appliedCheckOutRequest() != null ? req.appliedCheckOutRequest().getRequestedCheckOut() : actualCheckOut, policy.roundingCheckOutMinutes());

        ComputedHours workHours = computeWorkHours(shift, roundedCheckIn, roundedCheckOut,
            dayStart, dayEnd, leaveFrom, leaveTo, req, otEnabled, policy);

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
            workHours.regularNightHours(), workHours.otNightHours()
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
            LocalTime ovCI = roundUp  (att.getOverrideCheckIn()  != null ? att.getOverrideCheckIn()  : data.checkIn(),  policy.roundingCheckInMinutes());
            LocalTime ovCO = roundDown(att.getOverrideCheckOut() != null ? att.getOverrideCheckOut() : data.checkOut(), policy.roundingCheckOutMinutes());
            int ovBreakMin = att.getOverrideBreakMinutes() != null ? att.getOverrideBreakMinutes() : data.breakMinutes();
            double actual, regDay, regNight;
            if (ovCI != null && ovCO != null) {
                LocalTime brkStart = ovCI.plusMinutes(((ovCO.toSecondOfDay()/60 - ovCI.toSecondOfDay()/60 + 1440) % 1440 - ovBreakMin) / 2);
                LocalTime brkEnd   = ovBreakMin > 0 ? brkStart.plusMinutes(ovBreakMin) : null;
                var c = AttendanceCalculator.calculate(data.shiftStart(), data.shiftEnd(),
                    ovBreakMin > 0 ? brkStart : null, ovBreakMin > 0 ? brkEnd : null, ovCI, ovCO, dayStart, dayEnd);
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
            return new ComputedHours(actual, regDay, otDay, regNight, otNight);
        }
        return new ComputedHours(data.actualHours(), data.regularDayHours(), data.otDayHours(), data.regularNightHours(), data.otNightHours());
    }

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
