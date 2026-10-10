package com.bosskin.service;

import com.bosskin.dto.ShiftDTO;
import com.bosskin.entity.*;
import com.bosskin.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class WorkShiftService {

    private final WorkShiftRepository     shiftRepo;
    private final PeriodLockService periodLockService;
    private final ShiftAssignmentRepository assignRepo;
    private final DepartmentRepository    deptRepo;
    private final EmployeeRepository      employeeRepo;
    private final AttendanceRepository    attendanceRepository;
    private final AttendanceRequestRepository attendanceRequestRepository;

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    // ── Shift CRUD ──────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ShiftDTO.ShiftResponse> listShifts(Long companyId) {
        // A20: truy vấn theo công ty thay vì tải ca của mọi công ty rồi lọc
        return shiftRepo.findByCompanyIdAndActiveTrue(companyId)
            .stream()
            .map(this::toResponse)
            .toList();
    }

    @Transactional(readOnly = true)
    public List<ShiftDTO.ShiftResponse> listByDepartment(Long deptId, Long companyId) {
        return listByDepartments(Set.of(deptId), companyId);
    }

    @Transactional(readOnly = true)
    public List<ShiftDTO.ShiftResponse> listByDepartments(Collection<Long> deptIds, Long companyId) {
        if (deptIds == null || deptIds.isEmpty()) {
            return List.of();
        }
        // Validate root departments belong to company
        for (Long deptId : deptIds) {
            deptRepo.findByIdAndCompanyId(deptId, companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.department.not_found"));
        }
        return shiftRepo.findByCompanyIdAndActiveTrue(companyId)
            .stream()
            .filter(s -> s.getDepartments().stream().anyMatch(d -> deptIds.contains(d.getId())))
            .map(this::toResponse)
            .toList();
    }

    @Transactional(readOnly = true)
    public List<ShiftDTO.ShiftResponse> listAssignedShiftsForEmployee(Long companyId, Long employeeId) {
        return assignRepo.findDistinctActiveShiftsByEmployeeAndCompany(employeeId, companyId)
            .stream()
            .map(this::toResponse)
            .toList();
    }

    /** Số ca tối đa trong một ngày của một nhân viên (Mốc 2b: trước đây 2). Các ca không được chồng giờ. */
    public static final int MAX_SHIFTS_PER_DAY = 4;

    @Transactional
    public ShiftDTO.ShiftResponse createShift(Long companyId, ShiftDTO.ShiftRequest req) {
        boolean codeExists = shiftRepo.findByCompanyIdAndActiveTrue(companyId).stream().anyMatch(s ->
            s.getCode() != null
                && s.getCode().equalsIgnoreCase(req.getCode()));
        if (codeExists) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shift.code_duplicate");
        }

        WorkShift shift = WorkShift.builder()
            .company(companyRef(companyId))
            .name(req.getName())
            .code(req.getCode().toUpperCase())
            .startTime(req.getStartTime())
            .endTime(req.getEndTime())
            .breakStart(req.getBreakStart())
            .breakEnd(req.getBreakEnd())
            .workMinutes(calcWorkMinutes(req))
            .groupName(req.getGroupName() != null && !req.getGroupName().isBlank() ? req.getGroupName().trim() : null)
            .color(req.getColor() != null ? req.getColor() : "#1976D2")
            .build();
        applyShiftType(shift, req);

        applyDepartments(shift, req.getDepartmentIds(), companyId);
        return toResponse(shiftRepo.save(shift));
    }

    @Transactional
    public ShiftDTO.ShiftResponse updateShift(Long id, Long companyId, ShiftDTO.ShiftRequest req) {
        WorkShift shift = shiftRepo.findById(id)
            .filter(s -> s.isActive() && s.getCompany() != null && companyId.equals(s.getCompany().getId()))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shift.not_found"));

        boolean codeExists = shiftRepo.findByCompanyIdAndActiveTrue(companyId).stream().anyMatch(s ->
            !s.getId().equals(id)
                && s.getCode() != null
                && s.getCode().equalsIgnoreCase(req.getCode()));
        if (codeExists) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shift.code_duplicate");
        }

        shift.setName(req.getName());
        shift.setCode(req.getCode().toUpperCase());
        shift.setStartTime(req.getStartTime());
        shift.setEndTime(req.getEndTime());
        shift.setBreakStart(req.getBreakStart());
        shift.setBreakEnd(req.getBreakEnd());
        shift.setWorkMinutes(calcWorkMinutes(req));
        shift.setGroupName(req.getGroupName() != null && !req.getGroupName().isBlank() ? req.getGroupName().trim() : null);
        if (req.getColor() != null) shift.setColor(req.getColor());
        applyShiftType(shift, req);

        applyDepartments(shift, req.getDepartmentIds(), companyId);
        WorkShift saved = shiftRepo.save(shift);

        // A11: phân ca từ hôm nay trở đi chưa có dữ liệu chấm công nhận giờ mới của ca;
        // ngày đã qua / đã chấm giữ nguyên ảnh chụp giờ cũ để không đổi công hồi tố.
        for (ShiftAssignment a : assignRepo.findByShift_IdAndWorkDateGreaterThanEqual(saved.getId(), LocalDate.now())) {
            if (a.isDeleted() || a.isApproved()
                || hasAttendanceData(a.getEmployee().getId(), a.getWorkDate(), a.getId())) continue;
            applySnapshot(a, saved);
            assignRepo.save(a);
        }
        return toResponse(saved);
    }

    @Transactional
    public void deleteShift(Long id, Long companyId) {
        WorkShift shift = shiftRepo.findById(id)
            .filter(s -> s.isActive() && s.getCompany() != null && companyId.equals(s.getCompany().getId()))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shift.not_found"));
        shift.setCode(buildArchivedShiftCode(shift));
        shift.setActive(false);
        shiftRepo.save(shift);
    }

    private String buildArchivedShiftCode(WorkShift shift) {
        String original = shift.getCode() != null ? shift.getCode().trim().toUpperCase() : "SHIFT";
        String suffix = "~" + Long.toString(shift.getId(), 36).toUpperCase();
        int maxBaseLen = Math.max(1, 20 - suffix.length());
        String base = original.length() > maxBaseLen ? original.substring(0, maxBaseLen) : original;
        return base + suffix;
    }

    // ── Assignments ─────────────────────────────────────────────────────

    public List<ShiftDTO.AssignResponse> listAssignments(Long companyId, LocalDate from, LocalDate to) {
        return listAssignments(companyId, from, to, Set.of(), null);
    }

    /**
     * A20: lọc theo phạm vi SHIFT_VIEW của người xem (rỗng = toàn công ty; "chỉ bản thân" =
     * phân ca của chính mình), giống danh sách nhân viên ở lưới phân ca.
     */
    public List<ShiftDTO.AssignResponse> listAssignments(Long companyId, LocalDate from, LocalDate to,
                                                         Set<Long> scope, Long selfEmployeeId) {
        return assignRepo.findByCompanyAndDateRange(companyId, from, to)
            .stream()
            .filter(sa -> scope.isEmpty() || inShiftScope(sa.getEmployee(), scope, selfEmployeeId))
            .map(this::toAssignResponse).toList();
    }

    public static boolean inShiftScope(Employee e, Set<Long> scope, Long selfEmployeeId) {
        if (scope.isEmpty()) return true;
        if (e == null) return false;
        if (scope.contains(DeptScopeService.SCOPE_SELF_ONLY) && e.getId().equals(selfEmployeeId)) return true;
        return e.getDepartment() != null && scope.contains(e.getDepartment().getId());
    }

    public List<ShiftDTO.AssignResponse> listAssignmentsByEmployee(Long employeeId, Long companyId,
                                                                    LocalDate from, LocalDate to) {
        employeeRepo.findByIdAndCompanyId(employeeId, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        return assignRepo.findByEmployeeAndDateRange(employeeId, from, to)
            .stream().map(this::toAssignResponse).toList();
    }

    @Transactional
    public ShiftDTO.AssignResponse assign(Long companyId, ShiftDTO.AssignRequest req, Long createdBy) {
        periodLockService.requireOpen(companyId, req.getWorkDate());
        Employee employee = employeeRepo.findByIdAndCompanyId(req.getEmployeeId(), companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));

        WorkShift shift = null;
        if (req.getShiftId() != null) {
            shift = shiftRepo.findById(req.getShiftId())
                .filter(s -> s.isActive() && s.getCompany() != null && companyId.equals(s.getCompany().getId()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shift.not_found"));
        } else if (req.getCustomStartTime() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.assignment.shift_required");
        }

        List<ShiftAssignment> existing = assignRepo
            .findByEmployeeIdAndWorkDate(req.getEmployeeId(), req.getWorkDate());
        List<ShiftAssignment> allSameDay = assignRepo
            .findAllByEmployeeIdAndWorkDateIncludingDeleted(req.getEmployeeId(), req.getWorkDate());
        ShiftAssignment archived = allSameDay.stream()
            .filter(ShiftAssignment::isDeleted)
            .findFirst()
            .orElse(null);

        if (existing.isEmpty() && archived != null) {
            archived.setDeleted(false);
            archived.setEmployee(employee);
            archived.setShift(shift);
            applySnapshot(archived, shift);
            archived.setWorkDate(req.getWorkDate());
            archived.setNote(req.getNote());
            archived.setCustomStartTime(req.getCustomStartTime());
            archived.setCustomEndTime(req.getCustomEndTime());
            archived.setCustomBreakStart(req.getCustomBreakStart());
            archived.setCustomBreakEnd(req.getCustomBreakEnd());
            archived.setCreatedBy(createdBy);
            return toAssignResponse(assignRepo.save(archived));
        }

        validatePlacement(req.getEmployeeId(), req.getWorkDate(),
            shift != null ? shift.getStartTime() : req.getCustomStartTime(),
            shift != null ? shift.getEndTime()   : req.getCustomEndTime(),
            java.util.Set.of());

        ShiftAssignment a = ShiftAssignment.builder()
            .employee(employee)
            .shift(shift)
            .workDate(req.getWorkDate())
            .note(req.getNote())
            .customStartTime(req.getCustomStartTime())
            .customEndTime(req.getCustomEndTime())
            .customBreakStart(req.getCustomBreakStart())
            .customBreakEnd(req.getCustomBreakEnd())
            .createdBy(createdBy)
            .build();
        applySnapshot(a, shift);
        return toAssignResponse(assignRepo.save(a));
    }

    /**
     * Kiểm tra đặt một ca [newStart, newEnd] cho nhân viên vào ngày workDate: tối đa
     * MAX_SHIFTS_PER_DAY ca, không chồng giờ với ca cùng ngày, ca đêm hôm trước kéo sang,
     * hay ca hôm sau. ignoreIds: phân ca bỏ qua khi so (vd. ca đang được đổi đi).
     */
    public void validatePlacement(Long employeeId, LocalDate workDate, LocalTime newStart, LocalTime newEnd,
                                  java.util.Set<Long> ignoreIds) {
        List<ShiftAssignment> existing = assignRepo.findByEmployeeIdAndWorkDate(employeeId, workDate).stream()
            .filter(x -> !ignoreIds.contains(x.getId())).toList();
        if (existing.size() >= MAX_SHIFTS_PER_DAY) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift.too_many_per_day");
        }


        // Validate no overlap with existing assignments on same day
        if (newStart != null && newEnd != null) {
            for (ShiftAssignment ex : existing) {
                LocalTime exStart = ex.effectiveStartTime();
                LocalTime exEnd   = ex.effectiveEndTime();
                if (exStart != null && exEnd != null && timesOverlap(newStart, newEnd, exStart, exEnd)) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "error.shift.overlap_same_day|" + exStart.format(TIME_FMT) + "–" + exEnd.format(TIME_FMT));
                }
            }

            // Check if previous day has an overnight shift that spills into today
            List<ShiftAssignment> prevDay = assignRepo
                .findByEmployeeIdAndWorkDate(employeeId, workDate.minusDays(1)).stream()
                .filter(x -> !ignoreIds.contains(x.getId())).toList();
            for (ShiftAssignment prev : prevDay) {
                LocalTime ps = prev.effectiveStartTime();
                LocalTime pe = prev.effectiveEndTime();
                // Overnight: ends next day (endTime < startTime)
                if (ps != null && pe != null && pe.isBefore(ps)) {
                    // Spill on today is [00:00, pe]; new shift starts before pe → overlap
                    if (toMin(newStart) < toMin(pe)) {
                        throw new ResponseStatusException(HttpStatus.CONFLICT,
                            "error.shift.overlap_previous_day|" + ps.format(TIME_FMT) + "–" + pe.format(TIME_FMT));
                    }
                }
            }

            // If new shift is overnight, check if next day already has shifts that start before it ends
            boolean newIsOvernight = newEnd.isBefore(newStart);
            if (newIsOvernight) {
                List<ShiftAssignment> nextDay = assignRepo
                    .findByEmployeeIdAndWorkDate(employeeId, workDate.plusDays(1)).stream()
                    .filter(x -> !ignoreIds.contains(x.getId())).toList();
                for (ShiftAssignment next : nextDay) {
                    LocalTime ns = next.effectiveStartTime();
                    if (ns != null && toMin(ns) < toMin(newEnd)) {
                        throw new ResponseStatusException(HttpStatus.CONFLICT,
                            "error.shift.overlap_next_day|" + newEnd.format(TIME_FMT) + "|" + ns.format(TIME_FMT));
                    }
                }
            }
        }

    }

    /** Kết quả xếp một ngày theo mẫu xoay vòng. */
    public enum DayResult { UNCHANGED, ASSIGNED, CLEARED }

    /**
     * Xếp đúng danh sách ca shiftIds cho nhân viên vào một ngày (Mốc 2b, ca xoay vòng). Giao dịch
     * riêng: lỗi (trùng giờ, đã có công, kỳ khoá) chỉ huỷ ngày này. shiftIds rỗng = ngày nghỉ →
     * gỡ phân ca chưa có dữ liệu công.
     */
    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    public DayResult applyRotationDay(Long companyId, Long employeeId, LocalDate date, List<Long> shiftIds, Long createdBy) {
        periodLockService.requireOpen(companyId, date);
        List<ShiftAssignment> existing = assignRepo.findByEmployeeIdAndWorkDate(employeeId, date);
        List<Long> current = existing.stream()
            .map(a -> a.getShift() != null ? a.getShift().getId() : -1L).sorted().toList();
        List<Long> wanted = shiftIds.stream().sorted().toList();
        if (current.equals(wanted)) return DayResult.UNCHANGED;
        for (ShiftAssignment a : existing) {
            if (a.isApproved() || hasAttendanceData(employeeId, date, a.getId())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shiftAssignment.has_attendance");
            }
            deleteAssignmentById(a.getId(), companyId);
        }
        for (Long shiftId : shiftIds) {
            ShiftDTO.AssignRequest req = new ShiftDTO.AssignRequest();
            req.setEmployeeId(employeeId);
            req.setShiftId(shiftId);
            req.setWorkDate(date);
            assign(companyId, req, createdBy);
        }
        return shiftIds.isEmpty() ? DayResult.CLEARED : DayResult.ASSIGNED;
    }

    @Transactional
    public void deleteAssignmentById(Long id, Long companyId) {
        ShiftAssignment a = assignRepo.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shiftAssignment.not_found"));
        if (!a.getEmployee().getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        periodLockService.requireOpen(companyId, a.getWorkDate());
        if (a.isApproved()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shiftAssignment.approved_cannot_delete");
        }
        requireNoAttendanceData(a.getEmployee().getId(), a.getWorkDate(), id);
        // Dòng công rỗng (chưa check-in, chưa duyệt) được xoá mềm cùng phân ca
        attendanceRepository.findByEmployeeIdAndDateAndShift(a.getEmployee().getId(), a.getWorkDate(), id)
            .ifPresent(att -> {
                att.setDeleted(true);
                att.setDeletedAt(java.time.LocalDateTime.now());
                attendanceRepository.save(att);
            });

        assignRepo.softDeleteById(id);
    }

    private static int toMin(LocalTime t) { return t.getHour() * 60 + t.getMinute(); }

    private static boolean timesOverlap(LocalTime s1, LocalTime e1, LocalTime s2, LocalTime e2) {
        int a = toMin(s1), b = toMin(e1);
        int c = toMin(s2), d = toMin(e2);
        if (b <= a) b += 1440; // overnight shift 1
        if (d <= c) d += 1440; // overnight shift 2
        if (a < d && b > c) return true;
        // Align shift 2 relative to shift 1 for cross-midnight comparison
        if (c < a) { c += 1440; d += 1440; }
        return a < d && b > c;
    }

    @Transactional
    /**
     * Xếp một ca cho một ngày trong phân ca hàng loạt (A8). Dùng chung kiểm tra với phân ca đơn
     * (chồng giờ, tối đa ca/ngày, ca qua đêm); không đè lên phân ca đã có dữ liệu chấm công.
     * Trả về true nếu ngày đó được xếp/đổi ca.
     */
    private boolean applyBulkDay(Long companyId, Employee emp, WorkShift shift, LocalDate d,
                                 String note, Long createdBy) {
        List<ShiftAssignment> existing = assignRepo.findByEmployeeIdAndWorkDate(emp.getId(), d);
        if (existing.stream().anyMatch(a -> a.getShift() != null && a.getShift().getId().equals(shift.getId()))) {
            return false; // đã có đúng ca này
        }
        if (existing.size() == 1) {
            ShiftAssignment only = existing.get(0);
            if (only.isApproved() || hasAttendanceData(emp.getId(), d, only.getId())) return false;
            // Đổi ca của ngày (giữ id phân ca để không mất liên kết)
            only.setShift(shift);
            only.setCustomStartTime(null); only.setCustomEndTime(null);
            only.setCustomBreakStart(null); only.setCustomBreakEnd(null);
            applySnapshot(only, shift);
            only.setNote(note);
            assignRepo.save(only);
            return true;
        }
        if (!existing.isEmpty()) return false; // nhiều ca trong ngày: không tự đè
        ShiftDTO.AssignRequest one = new ShiftDTO.AssignRequest();
        one.setEmployeeId(emp.getId());
        one.setShiftId(shift.getId());
        one.setWorkDate(d);
        one.setNote(note);
        try {
            assign(companyId, one, createdBy);
            return true;
        } catch (ResponseStatusException e) {
            return false; // trùng giờ với ca đêm hôm trước/sau…: bỏ qua ngày này
        }
    }

    public int bulkAssign(Long companyId, ShiftDTO.BulkAssignRequest req, Long createdBy) {
        periodLockService.requireOpen(companyId, req.getStartDate(), req.getEndDate());
        WorkShift shift = shiftRepo.findById(req.getShiftId())
            .filter(s -> s.isActive() && s.getCompany() != null && companyId.equals(s.getCompany().getId()))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shift.not_found"));

        List<Integer> excluded = req.getExcludeWeekdays() != null ? req.getExcludeWeekdays() : List.of();
        int count = 0;

        for (Long empId : req.getEmployeeIds()) {
            Employee emp = employeeRepo.findByIdAndCompanyId(empId, companyId).orElse(null);
            if (emp == null) continue;

            LocalDate d = req.getStartDate();
            while (!d.isAfter(req.getEndDate())) {
                int dow = d.getDayOfWeek().getValue(); // 1=Mon…7=Sun
                if (!excluded.contains(dow) && applyBulkDay(companyId, emp, shift, d, req.getNote(), createdBy)) {
                    count++;
                }
                d = d.plusDays(1);
            }
        }
        return count;
    }

    @Transactional
    public void deleteAssignment(Long employeeId, LocalDate workDate, Long companyId) {
        employeeRepo.findByIdAndCompanyId(employeeId, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        periodLockService.requireOpen(companyId, workDate);
        for (ShiftAssignment a : assignRepo.findByEmployeeIdAndWorkDate(employeeId, workDate)) {
            requireNoAttendanceData(employeeId, workDate, a.getId());
        }
        assignRepo.softDeleteByEmployeeIdAndWorkDate(employeeId, workDate);
    }

    /**
     * A7: không xoá phân ca khi đã có dữ liệu chấm công (check-in/out, đã duyệt, hoặc đơn
     * chấm công) — trước đây xoá cứng làm mất bằng chứng chấm công.
     */
    /** Phân ca đã có dữ liệu chấm công (check-in/out, override, đã duyệt) — không được đổi/xoá. */
    public boolean assignmentHasAttendance(ShiftAssignment a) {
        return a.isApproved() || hasAttendanceData(a.getEmployee().getId(), a.getWorkDate(), a.getId());
    }

    private void requireNoAttendanceData(Long employeeId, LocalDate workDate, Long assignmentId) {
        if (hasAttendanceData(employeeId, workDate, assignmentId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shiftAssignment.has_attendance");
        }
    }

    /** Phân ca đã có check-in/out, đã duyệt, hoặc có đơn chấm công. */
    public boolean hasAttendanceData(Long employeeId, LocalDate workDate, Long assignmentId) {
        boolean hasAttendance = attendanceRepository.findByEmployeeIdAndDateAndShift(employeeId, workDate, assignmentId)
            .filter(att -> att.isApproved() || att.getCheckIn() != null || att.getCheckOut() != null
                || att.getOverrideCheckIn() != null || att.getOverrideCheckOut() != null)
            .isPresent();
        boolean hasRequests = !attendanceRequestRepository.findByShiftAssignment_Id(assignmentId).isEmpty();
        return hasAttendance || hasRequests;
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private void applyDepartments(WorkShift shift, List<Long> deptIds, Long companyId) {
        shift.getDepartments().clear();
        if (deptIds == null || deptIds.isEmpty()) return;
        List<Department> depts = new ArrayList<>();
        for (Long did : deptIds) {
            deptRepo.findByIdAndCompanyId(did, companyId).ifPresent(depts::add);
        }
        shift.getDepartments().addAll(depts);
    }

    private Integer calcWorkMinutes(ShiftDTO.ShiftRequest req) {
        if (req.getStartTime() == null || req.getEndTime() == null) return null;

        // A17: ca qua đêm (giờ kết thúc <= giờ bắt đầu) kết thúc vào ngày hôm sau
        int total = minutesForward(req.getStartTime(), req.getEndTime());
        if (req.getBreakStart() != null && req.getBreakEnd() != null) {
            total -= minutesForward(req.getBreakStart(), req.getBreakEnd());
        }
        return Math.max(0, total);
    }

    /** Số phút từ {@code from} tới {@code to}, qua nửa đêm nếu {@code to <= from}. */
    private static int minutesForward(LocalTime from, LocalTime to) {
        int m = toMin(to) - toMin(from);
        return m <= 0 ? m + 1440 : m;
    }

    private Company companyRef(Long id) {
        Company c = new Company();
        c.setId(id);
        return c;
    }

    private ShiftDTO.ShiftResponse toResponse(WorkShift s) {
        return ShiftDTO.ShiftResponse.builder()
            .id(s.getId())
            .name(s.getName())
            .code(s.getCode())
            .startTime(s.getStartTime() != null ? s.getStartTime().format(TIME_FMT) : null)
            .endTime(s.getEndTime() != null ? s.getEndTime().format(TIME_FMT) : null)
            .breakStart(s.getBreakStart() != null ? s.getBreakStart().format(TIME_FMT) : null)
            .breakEnd(s.getBreakEnd() != null ? s.getBreakEnd().format(TIME_FMT) : null)
            .workMinutes(s.getWorkMinutes())
            .groupName(s.getGroupName())
            .color(s.getColor())
            .active(s.isActive())
            .departments(s.getDepartments().stream()
                .map(d -> new ShiftDTO.DeptRef(d.getId(), d.getName())).toList())
            .shiftType(s.getShiftType() != null ? s.getShiftType().name() : "FIXED")
            .requiredMinutes(s.getRequiredMinutes())
            .build();
    }

    /**
     * Ca linh hoạt (Mốc 2b): khung [startTime, endTime] là giờ được phép làm, requiredMinutes là số
     * phút phải đủ. Khung (trừ nghỉ) phải chứa được số phút yêu cầu.
     */
    private void applyShiftType(WorkShift shift, ShiftDTO.ShiftRequest req) {
        boolean flexible = "FLEXIBLE".equalsIgnoreCase(req.getShiftType());
        if (!flexible) {
            shift.setShiftType(WorkShift.ShiftType.FIXED);
            shift.setRequiredMinutes(null);
            return;
        }
        Integer required = req.getRequiredMinutes();
        if (required == null || required <= 0 || shift.getStartTime() == null || shift.getEndTime() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift.flexible_required_minutes");
        }
        Integer window = shift.getWorkMinutes();
        if (window != null && required > window) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift.flexible_window_too_short");
        }
        shift.setShiftType(WorkShift.ShiftType.FLEXIBLE);
        shift.setRequiredMinutes(required);
    }

    /** Copy shift template fields into snapshot columns at assign time. */
    private void applySnapshot(ShiftAssignment a, WorkShift shift) {
        if (shift == null) {
            a.setSnapshotName(null);
            a.setSnapshotCode(null);
            a.setSnapshotStartTime(null);
            a.setSnapshotEndTime(null);
            a.setSnapshotBreakStart(null);
            a.setSnapshotBreakEnd(null);
            a.setSnapshotWorkMinutes(null);
            a.setSnapshotColor(null);
            a.setSnapshotShiftType(null);
            a.setSnapshotRequiredMinutes(null);
            return;
        }
        a.setSnapshotName(shift.getName());
        a.setSnapshotCode(shift.getCode());
        a.setSnapshotStartTime(shift.getStartTime());
        a.setSnapshotEndTime(shift.getEndTime());
        a.setSnapshotBreakStart(shift.getBreakStart());
        a.setSnapshotBreakEnd(shift.getBreakEnd());
        a.setSnapshotWorkMinutes(shift.getWorkMinutes());
        a.setSnapshotColor(shift.getColor());
        a.setSnapshotShiftType(shift.getShiftType().name());
        a.setSnapshotRequiredMinutes(shift.getRequiredMinutes());
    }

    private ShiftDTO.AssignResponse toAssignResponse(ShiftAssignment a) {
        // Prefer live shift data; fall back to snapshot when shift was deleted
        WorkShift s = a.getShift();
        String name  = s != null ? s.getName()  : a.getSnapshotName();
        String code  = s != null ? s.getCode()  : a.getSnapshotCode();
        String color = s != null ? s.getColor() : (a.getSnapshotColor() != null ? a.getSnapshotColor() : "#607D8B");
        return ShiftDTO.AssignResponse.builder()
            .id(a.getId())
            .employeeId(a.getEmployee().getId())
            .employeeName(a.getEmployee().getFullName())
            .shiftId(s != null ? s.getId() : null)
            .shiftName(name)
            .shiftCode(code)
            .shiftColor(color)
            .workDate(a.getWorkDate().toString())
            .note(a.getNote())
            .customStartTime(a.getCustomStartTime() != null ? a.getCustomStartTime().format(TIME_FMT) : null)
            .customEndTime(a.getCustomEndTime() != null ? a.getCustomEndTime().format(TIME_FMT) : null)
            .customBreakStart(a.getCustomBreakStart() != null ? a.getCustomBreakStart().format(TIME_FMT) : null)
            .customBreakEnd(a.getCustomBreakEnd() != null ? a.getCustomBreakEnd().format(TIME_FMT) : null)
            .custom(a.isCustom())
            .hasAttendance(attendanceRepository.existsByShiftAssignment_Id(a.getId()))
            .approved(a.isApproved())
            .build();
    }
}
