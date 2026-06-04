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

    // ── Row data ──────────────────────────────────────────────────────────────

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
        LocalTime shiftStart = null, shiftEnd = null, breakStart = null, breakEnd = null;
        String shiftName = null, shiftColor = null;

        if (assignment != null) {
            if (assignment.isCustom()) {
                shiftStart = assignment.getCustomStartTime();
                shiftEnd   = assignment.getCustomEndTime();
                breakStart = assignment.getCustomBreakStart();
                breakEnd   = assignment.getCustomBreakEnd();
                shiftName  = "Tùy chỉnh";
            } else if (assignment.getShift() != null) {
                var s = assignment.getShift();
                shiftStart = assignment.getCustomStartTime() != null ? assignment.getCustomStartTime() : s.getStartTime();
                shiftEnd   = assignment.getCustomEndTime()   != null ? assignment.getCustomEndTime()   : s.getEndTime();
                breakStart = assignment.getCustomBreakStart() != null ? assignment.getCustomBreakStart() : s.getBreakStart();
                breakEnd   = assignment.getCustomBreakEnd()   != null ? assignment.getCustomBreakEnd()   : s.getBreakEnd();
                shiftName  = s.getName();
                shiftColor = s.getColor();
            }
        }

        int breakMinutes = 0;
        if (breakStart != null && breakEnd != null) {
            int bs = breakStart.toSecondOfDay() / 60, be = breakEnd.toSecondOfDay() / 60;
            if (be < bs) be += 1440;
            breakMinutes = be - bs;
        }

        LocalTime checkIn  = att != null && att.getCheckIn()  != null ? att.getCheckIn().toLocalTime()  : null;
        LocalTime checkOut = att != null && att.getCheckOut() != null ? att.getCheckOut().toLocalTime() : null;
        Long attendanceId  = att != null ? att.getId() : null;

        AttendanceRequest requestCheckIn = null, appliedRequestCheckIn = null;
        AttendanceRequest requestCheckOut = null, appliedRequestCheckOut = null;
        List<AttendanceRequest> requestOts = new ArrayList<>();
        List<AttendanceRequest> appliedRequestOts = new ArrayList<>();
        List<AttendanceRequest> appliedRequestExtras = new ArrayList<>();

        if (requests != null) {
            for (AttendanceRequest r : requests) {
                if (r.getStatus() != AttendanceRequest.Status.APPROVED) continue;
                Long requestShiftId = r.getShiftAssignment() != null ? r.getShiftAssignment().getId() : null;
                if (assignment != null) {
                    Long currentShiftId = assignment.getId();
                    if (requestShiftId != null && !requestShiftId.equals(currentShiftId)) continue;
                    if (requestShiftId == null && slotIndex > 0) continue;
                }
                if (r.getRequestType() == AttendanceRequest.Type.CHECK_IN) {
                    requestCheckIn = r;
                    if (r.isApplied()) appliedRequestCheckIn = r;
                }
                if (r.getRequestType() == AttendanceRequest.Type.CHECK_OUT) {
                    requestCheckOut = r;
                    if (r.isApplied()) appliedRequestCheckOut = r;
                }
                if (r.getRequestType() == AttendanceRequest.Type.OT) {
                    requestOts.add(r);
                    if (r.isApplied()) appliedRequestOts.add(r);
                }
                if (r.getRequestType() == AttendanceRequest.Type.EXTRA) {
                    requestOts.add(r);
                    if (r.isApplied()) appliedRequestExtras.add(r);
                }
            }
        }

        LocalTime effectiveCheckIn  = chooseEarlier(checkIn,  appliedRequestCheckIn  != null ? appliedRequestCheckIn.getRequestedCheckIn()   : null, shiftStart, shiftEnd);
        LocalTime effectiveCheckOut = chooseLater  (checkOut, appliedRequestCheckOut != null ? appliedRequestCheckOut.getRequestedCheckOut() : null, shiftStart, shiftEnd);

        LocalTime roundedCheckIn  = roundUp  (effectiveCheckIn,  policy.roundingCheckInMinutes());
        LocalTime roundedCheckOut = roundDown(effectiveCheckOut, policy.roundingCheckOutMinutes());
        var calc = AttendanceCalculator.calculate(
            shiftStart, shiftEnd, breakStart, breakEnd, roundedCheckIn, roundedCheckOut, dayStart, dayEnd, leaveFrom, leaveTo);

        int actualMinutes       = hoursToMinutes(calc.actualHours());
        int regularDayMinutes   = hoursToMinutes(calc.regularDayHours());
        int regularNightMinutes = hoursToMinutes(calc.regularNightHours());
        int otDayMinutes        = hoursToMinutes(calc.otDayHours());
        int otNightMinutes      = hoursToMinutes(calc.otNightHours());

        for (AttendanceRequest r : appliedRequestOts) {
            if (r.getRequestedOvertimeMinutes() == null) continue;
            int ot = Math.max(0, r.getRequestedOvertimeMinutes());
            var scope = r.getRequestedOvertimeScope();
            var period = r.getRequestedOvertimePeriod();
            if (scope == AttendanceRequest.OvertimeScope.IN_SHIFT) {
                if (period == AttendanceRequest.OvertimePeriod.NIGHT) { int m = Math.min(ot, regularNightMinutes); regularNightMinutes -= m; otNightMinutes += m; }
                else { int m = Math.min(ot, regularDayMinutes); regularDayMinutes -= m; otDayMinutes += m; }
            } else if (scope == AttendanceRequest.OvertimeScope.OUTSIDE_SHIFT) {
                actualMinutes += ot;
                if (period == AttendanceRequest.OvertimePeriod.NIGHT) otNightMinutes += ot;
                else otDayMinutes += ot;
            }
        }

        for (AttendanceRequest r : appliedRequestExtras) {
            if (r.getRequestedOvertimeMinutes() == null) continue;
            int extra = Math.max(0, r.getRequestedOvertimeMinutes());
            actualMinutes += extra;
            if (r.getRequestedOvertimePeriod() == AttendanceRequest.OvertimePeriod.NIGHT) regularNightMinutes += extra;
            else regularDayMinutes += extra;
        }

        if (!otEnabled) {
            regularDayMinutes += otDayMinutes; regularNightMinutes += otNightMinutes;
            otDayMinutes = 0; otNightMinutes = 0;
        }

        if (policy.roundingWorkMinutes() != null) {
            regularDayMinutes   = roundDownMinutes(regularDayMinutes,   policy.roundingWorkMinutes());
            regularNightMinutes = roundDownMinutes(regularNightMinutes, policy.roundingWorkMinutes());
            otDayMinutes        = roundDownMinutes(otDayMinutes,        policy.roundingWorkMinutes());
            otNightMinutes      = roundDownMinutes(otNightMinutes,      policy.roundingWorkMinutes());
        }

        LocalTime flagCheckIn  = roundUp  (appliedRequestCheckIn  != null ? appliedRequestCheckIn.getRequestedCheckIn()   : checkIn,  policy.roundingCheckInMinutes());
        LocalTime flagCheckOut = roundDown(appliedRequestCheckOut != null ? appliedRequestCheckOut.getRequestedCheckOut() : checkOut, policy.roundingCheckOutMinutes());

        return new AttendanceRowData(
            shiftName, shiftColor, shiftStart, shiftEnd, breakMinutes,
            checkIn, checkOut, effectiveCheckIn, effectiveCheckOut, flagCheckIn, flagCheckOut,
            att != null ? att.getStatus() : null,
            requestCheckIn  != null ? requestCheckIn.getRequestedCheckIn()   : null,
            requestCheckIn  != null ? requestCheckIn.getStatus()             : null,
            requestCheckOut != null ? requestCheckOut.getRequestedCheckOut() : null,
            requestCheckOut != null ? requestCheckOut.getStatus()            : null,
            requestOts.isEmpty() ? null : requestOts.stream().mapToInt(r -> r.getRequestedOvertimeMinutes() != null ? r.getRequestedOvertimeMinutes() : 0).sum(),
            requestOts.isEmpty() ? null : requestOts.get(0).getRequestedOvertimeScope(),
            requestOts.isEmpty() ? null : requestOts.get(0).getRequestedOvertimePeriod(),
            requestOts.isEmpty() ? null : requestOts.get(0).getStatus(),
            attendanceId,
            actualMinutes / 60.0, regularDayMinutes / 60.0, otDayMinutes / 60.0,
            regularNightMinutes / 60.0, otNightMinutes / 60.0
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
