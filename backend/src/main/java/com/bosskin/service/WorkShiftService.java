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
    private final ShiftAssignmentRepository assignRepo;
    private final DepartmentRepository    deptRepo;
    private final EmployeeRepository      employeeRepo;
    private final AttendanceRepository    attendanceRepository;
    private final AttendanceRequestRepository attendanceRequestRepository;

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    // ── Shift CRUD ──────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ShiftDTO.ShiftResponse> listShifts(Long companyId) {
        return shiftRepo.findAll()
            .stream()
            .filter(s -> s.isActive() && s.getCompany() != null && companyId.equals(s.getCompany().getId()))
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
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy phòng ban"));
        }
        return shiftRepo.findAll()
            .stream()
            .filter(s -> s.isActive()
                && s.getCompany() != null
                && companyId.equals(s.getCompany().getId())
                && s.getDepartments().stream().anyMatch(d -> deptIds.contains(d.getId())))
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

    @Transactional
    public ShiftDTO.ShiftResponse createShift(Long companyId, ShiftDTO.ShiftRequest req) {
        boolean codeExists = shiftRepo.findAll().stream().anyMatch(s ->
            s.isActive()
                && s.getCompany() != null
                && companyId.equals(s.getCompany().getId())
                && s.getCode() != null
                && s.getCode().equalsIgnoreCase(req.getCode()));
        if (codeExists) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Mã ca đã tồn tại");
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

        applyDepartments(shift, req.getDepartmentIds(), companyId);
        return toResponse(shiftRepo.save(shift));
    }

    @Transactional
    public ShiftDTO.ShiftResponse updateShift(Long id, Long companyId, ShiftDTO.ShiftRequest req) {
        WorkShift shift = shiftRepo.findById(id)
            .filter(s -> s.isActive() && s.getCompany() != null && companyId.equals(s.getCompany().getId()))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy ca làm"));

        boolean codeExists = shiftRepo.findAll().stream().anyMatch(s ->
            s.isActive()
                && s.getCompany() != null
                && companyId.equals(s.getCompany().getId())
                && !s.getId().equals(id)
                && s.getCode() != null
                && s.getCode().equalsIgnoreCase(req.getCode()));
        if (codeExists) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Mã ca đã tồn tại");
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

        applyDepartments(shift, req.getDepartmentIds(), companyId);
        return toResponse(shiftRepo.save(shift));
    }

    @Transactional
    public void deleteShift(Long id, Long companyId) {
        WorkShift shift = shiftRepo.findById(id)
            .filter(s -> s.isActive() && s.getCompany() != null && companyId.equals(s.getCompany().getId()))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy ca làm"));
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
        return assignRepo.findByCompanyAndDateRange(companyId, from, to)
            .stream().map(this::toAssignResponse).toList();
    }

    public List<ShiftDTO.AssignResponse> listAssignmentsByEmployee(Long employeeId, Long companyId,
                                                                    LocalDate from, LocalDate to) {
        employeeRepo.findByIdAndCompanyId(employeeId, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên"));
        return assignRepo.findByEmployeeAndDateRange(employeeId, from, to)
            .stream().map(this::toAssignResponse).toList();
    }

    @Transactional
    public ShiftDTO.AssignResponse assign(Long companyId, ShiftDTO.AssignRequest req, Long createdBy) {
        Employee employee = employeeRepo.findByIdAndCompanyId(req.getEmployeeId(), companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên"));

        WorkShift shift = null;
        if (req.getShiftId() != null) {
            shift = shiftRepo.findById(req.getShiftId())
                .filter(s -> s.isActive() && s.getCompany() != null && companyId.equals(s.getCompany().getId()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy ca làm"));
        } else if (req.getCustomStartTime() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Phải chọn ca hoặc nhập giờ tùy chỉnh");
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

        if (existing.size() >= 2) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Tối đa 2 ca mỗi ngày");
        }

        // Resolve new shift's time range
        LocalTime newStart = shift != null ? shift.getStartTime() : req.getCustomStartTime();
        LocalTime newEnd   = shift != null ? shift.getEndTime()   : req.getCustomEndTime();

        // Validate no overlap with existing assignments on same day
        if (newStart != null && newEnd != null) {
            for (ShiftAssignment ex : existing) {
                LocalTime exStart = ex.getShift() != null ? ex.getShift().getStartTime() : ex.getCustomStartTime();
                LocalTime exEnd   = ex.getShift() != null ? ex.getShift().getEndTime()   : ex.getCustomEndTime();
                if (exStart != null && exEnd != null && timesOverlap(newStart, newEnd, exStart, exEnd)) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "Trùng ca " + exStart.format(TIME_FMT) + "–" + exEnd.format(TIME_FMT) + " trong ngày");
                }
            }

            // Check if previous day has an overnight shift that spills into today
            List<ShiftAssignment> prevDay = assignRepo
                .findByEmployeeIdAndWorkDate(req.getEmployeeId(), req.getWorkDate().minusDays(1));
            for (ShiftAssignment prev : prevDay) {
                LocalTime ps = prev.getShift() != null ? prev.getShift().getStartTime() : prev.getCustomStartTime();
                LocalTime pe = prev.getShift() != null ? prev.getShift().getEndTime()   : prev.getCustomEndTime();
                // Overnight: ends next day (endTime < startTime)
                if (ps != null && pe != null && pe.isBefore(ps)) {
                    // Spill on today is [00:00, pe]; new shift starts before pe → overlap
                    if (toMin(newStart) < toMin(pe)) {
                        throw new ResponseStatusException(HttpStatus.CONFLICT,
                            "Ca " + ps.format(TIME_FMT) + "–" + pe.format(TIME_FMT)
                            + " ngày hôm trước kéo sang " + pe.format(TIME_FMT) + ", trùng với ca mới");
                    }
                }
            }

            // If new shift is overnight, check if next day already has shifts that start before it ends
            boolean newIsOvernight = newEnd.isBefore(newStart);
            if (newIsOvernight) {
                List<ShiftAssignment> nextDay = assignRepo
                    .findByEmployeeIdAndWorkDate(req.getEmployeeId(), req.getWorkDate().plusDays(1));
                for (ShiftAssignment next : nextDay) {
                    LocalTime ns = next.getShift() != null ? next.getShift().getStartTime() : next.getCustomStartTime();
                    if (ns != null && toMin(ns) < toMin(newEnd)) {
                        throw new ResponseStatusException(HttpStatus.CONFLICT,
                            "Ca mới kéo sang hôm sau đến " + newEnd.format(TIME_FMT)
                            + ", trùng với ca " + ns.format(TIME_FMT) + " ngày hôm sau");
                    }
                }
            }
        }

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

    @Transactional
    public void deleteAssignmentById(Long id, Long companyId) {
        ShiftAssignment a = assignRepo.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shiftAssignment.not_found"));
        if (!a.getEmployee().getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
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
    public int bulkAssign(Long companyId, ShiftDTO.BulkAssignRequest req, Long createdBy) {
        WorkShift shift = shiftRepo.findById(req.getShiftId())
            .filter(s -> s.isActive() && s.getCompany() != null && companyId.equals(s.getCompany().getId()))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy ca làm"));

        List<Integer> excluded = req.getExcludeWeekdays() != null ? req.getExcludeWeekdays() : List.of();
        int count = 0;

        for (Long empId : req.getEmployeeIds()) {
            Employee emp = employeeRepo.findByIdAndCompanyId(empId, companyId).orElse(null);
            if (emp == null) continue;

            LocalDate d = req.getStartDate();
            while (!d.isAfter(req.getEndDate())) {
                int dow = d.getDayOfWeek().getValue(); // 1=Mon…7=Sun
                if (!excluded.contains(dow)) {
                    List<ShiftAssignment> existingList = assignRepo.findByEmployeeIdAndWorkDate(empId, d);
                    ShiftAssignment existing = existingList.isEmpty() ? null : existingList.get(0);
                    ShiftAssignment archived = assignRepo.findAllByEmployeeIdAndWorkDateIncludingDeleted(empId, d)
                        .stream()
                        .filter(ShiftAssignment::isDeleted)
                        .findFirst()
                        .orElse(null);
                    if (existing != null) {
                        existing.setShift(shift);
                        applySnapshot(existing, shift);
                        existing.setNote(req.getNote());
                        assignRepo.save(existing);
                    } else if (archived != null) {
                        archived.setDeleted(false);
                        archived.setEmployee(emp);
                        archived.setShift(shift);
                        applySnapshot(archived, shift);
                        archived.setWorkDate(d);
                        archived.setNote(req.getNote());
                        archived.setCreatedBy(createdBy);
                        assignRepo.save(archived);
                    } else {
                        ShiftAssignment bulk = ShiftAssignment.builder()
                            .employee(emp).shift(shift).workDate(d)
                            .note(req.getNote()).createdBy(createdBy).build();
                        applySnapshot(bulk, shift);
                        assignRepo.save(bulk);
                    }
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
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên"));
        for (ShiftAssignment a : assignRepo.findByEmployeeIdAndWorkDate(employeeId, workDate)) {
            requireNoAttendanceData(employeeId, workDate, a.getId());
        }
        assignRepo.softDeleteByEmployeeIdAndWorkDate(employeeId, workDate);
    }

    /**
     * A7: không xoá phân ca khi đã có dữ liệu chấm công (check-in/out, đã duyệt, hoặc đơn
     * chấm công) — trước đây xoá cứng làm mất bằng chứng chấm công.
     */
    private void requireNoAttendanceData(Long employeeId, LocalDate workDate, Long assignmentId) {
        boolean hasAttendance = attendanceRepository.findByEmployeeIdAndDateAndShift(employeeId, workDate, assignmentId)
            .filter(att -> att.isApproved() || att.getCheckIn() != null || att.getCheckOut() != null
                || att.getOverrideCheckIn() != null || att.getOverrideCheckOut() != null)
            .isPresent();
        boolean hasRequests = !attendanceRequestRepository.findByShiftAssignment_Id(assignmentId).isEmpty();
        if (hasAttendance || hasRequests) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shiftAssignment.has_attendance");
        }
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

        int total = (int) java.time.Duration.between(req.getStartTime(), req.getEndTime()).toMinutes();
        if (req.getBreakStart() != null && req.getBreakEnd() != null) {
            total -= (int) java.time.Duration.between(req.getBreakStart(), req.getBreakEnd()).toMinutes();
        }
        return total;
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
            .build();
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
