package com.bosskin.service;

import com.bosskin.dto.ShiftSwapDTO;
import com.bosskin.entity.Employee;
import com.bosskin.entity.ShiftAssignment;
import com.bosskin.entity.ShiftSwapRequest;
import com.bosskin.entity.User;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import com.bosskin.repository.ShiftSwapRequestRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Set;

/**
 * Đổi ca / nhường ca (Mốc 2b). Nhân viên gửi yêu cầu với đồng nghiệp, người có quyền
 * SHIFT_SWAP_APPROVE duyệt. Khi duyệt mới chuyển phân ca: kiểm tra lại kỳ chưa khoá, ca chưa
 * có dữ liệu công, và sau khi đổi không ai bị trùng giờ.
 */
@Service
@RequiredArgsConstructor
public class ShiftSwapService {

    private static final DateTimeFormatter HM = DateTimeFormatter.ofPattern("HH:mm");

    private final ShiftSwapRequestRepository swapRepo;
    private final ShiftAssignmentRepository assignRepo;
    private final EmployeeRepository employeeRepo;
    private final WorkShiftService shiftService;
    private final PeriodLockService periodLockService;
    private final com.bosskin.repository.AttendanceRepository attendanceRepository;
    private final Clock clock;
    private final ManagerApprovalService managerApproval;

    @Transactional(readOnly = true)
    public List<ShiftSwapDTO.Response> list(User user, String statusStr) {
        ShiftSwapRequest.Status status = statusStr == null || statusStr.isBlank()
            ? null : ShiftSwapRequest.Status.valueOf(statusStr.toUpperCase());
        Long onlyEmployee = canApprove(user) ? null : selfEmployee(user).getId();
        return swapRepo.search(user.getCompany().getId(), status, onlyEmployee).stream().map(this::toResponse).toList();
    }

    @Transactional
    public ShiftSwapDTO.Response create(User user, ShiftSwapDTO.CreateRequest req) {
        Long companyId = user.getCompany().getId();
        Employee me = selfEmployee(user);
        ShiftAssignment mine = activeAssignment(req.getRequesterAssignmentId());
        if (!mine.getEmployee().getId().equals(me.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.swap.not_your_shift");
        }
        Employee target = employeeRepo.findByIdAndCompanyId(req.getTargetEmployeeId(), companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        if (target.getId().equals(me.getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.swap.same_employee");
        }
        ShiftAssignment theirs = null;
        if (req.getTargetAssignmentId() != null) {
            theirs = activeAssignment(req.getTargetAssignmentId());
            if (!theirs.getEmployee().getId().equals(target.getId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.swap.target_shift_mismatch");
            }
        }
        requireSwappable(companyId, mine);
        if (theirs != null) requireSwappable(companyId, theirs);
        if (swapRepo.countPendingForAssignment(mine.getId()) > 0
            || (theirs != null && swapRepo.countPendingForAssignment(theirs.getId()) > 0)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.swap.already_pending");
        }
        checkFits(mine, theirs, me, target);   // báo sớm nếu chắc chắn trùng giờ

        ShiftSwapRequest r = ShiftSwapRequest.builder()
            .companyId(companyId).requester(me).requesterAssignment(mine)
            .targetEmployee(target).targetAssignment(theirs)
            .reason(req.getReason() != null && !req.getReason().isBlank() ? req.getReason().trim() : null)
            .build();
        ShiftSwapRequest saved = swapRepo.save(r);
        managerApproval.notifyManager(me, "SWAP", "Yêu cầu đổi ca chờ bạn duyệt",
            me.getFullName() + " xin đổi ca ngày " + mine.getWorkDate());
        return toResponse(saved);
    }

    @Transactional
    public ShiftSwapDTO.Response approve(User user, Long id, String note) {
        if (!canApprove(user)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        ShiftSwapRequest r = pending(user, id);
        Long myEmpId = employeeRepo.findByUserIdFetch(user.getId()).map(Employee::getId).orElse(null);
        if (myEmpId != null && (r.getRequester().getId().equals(myEmpId) || r.getTargetEmployee().getId().equals(myEmpId))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.swap.self_approve");
        }
        managerApproval.beforeFinalApprove(user, r.getRequester(), r);
        Long companyId = user.getCompany().getId();
        ShiftAssignment mine = activeAssignment(r.getRequesterAssignment().getId());
        ShiftAssignment theirs = r.getTargetAssignment() != null ? activeAssignment(r.getTargetAssignment().getId()) : null;
        if (!mine.getEmployee().getId().equals(r.getRequester().getId())
            || (theirs != null && !theirs.getEmployee().getId().equals(r.getTargetEmployee().getId()))) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.swap.shift_changed");
        }
        requireSwappable(companyId, mine);
        if (theirs != null) requireSwappable(companyId, theirs);
        checkFits(mine, theirs, r.getRequester(), r.getTargetEmployee());

        dropEmptyAttendance(mine);
        if (theirs != null) dropEmptyAttendance(theirs);
        // Ca sang người khác → người nhận ca cũng được nhắc (dấu "đã nhắc" là của người cũ)
        mine.setEmployee(r.getTargetEmployee());
        mine.resetReminders();
        assignRepo.save(mine);
        if (theirs != null) {
            theirs.setEmployee(r.getRequester());
            theirs.resetReminders();
            assignRepo.save(theirs);
        }
        r.setStatus(ShiftSwapRequest.Status.APPROVED);
        r.setProcessedBy(user);
        r.setProcessedAt(LocalDateTime.now(clock));
        r.setAdminNote(note);
        return toResponse(swapRepo.save(r));
    }

    @Transactional
    public ShiftSwapDTO.Response reject(User user, Long id, String note) {
        if (!canApprove(user)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        ShiftSwapRequest r = pending(user, id);
        return doReject(r, user, note);
    }

    private ShiftSwapDTO.Response doReject(ShiftSwapRequest r, User user, String note) {
        r.setStatus(ShiftSwapRequest.Status.REJECTED);
        r.setProcessedBy(user);
        r.setProcessedAt(LocalDateTime.now(clock));
        r.setAdminNote(note);
        return toResponse(swapRepo.save(r));
    }

    /** Bước K: quản lý trực tiếp của người xin đổi duyệt bước 1. */
    @Transactional
    public ShiftSwapDTO.Response managerApprove(User manager, Long id, String note) {
        ShiftSwapRequest r = byId(manager, id);
        managerApproval.requireManagerCanProcess(manager, r.getRequester(), r,
            r.getStatus() == ShiftSwapRequest.Status.PENDING);
        managerApproval.mark(r, manager, note);
        return toResponse(swapRepo.save(r));
    }

    @Transactional
    public ShiftSwapDTO.Response managerReject(User manager, Long id, String note) {
        ShiftSwapRequest r = byId(manager, id);
        managerApproval.requireManagerCanProcess(manager, r.getRequester(), r,
            r.getStatus() == ShiftSwapRequest.Status.PENDING);
        r.setManagerNote(note != null && !note.isBlank() ? note.trim() : null);
        return doReject(r, manager, note);
    }

    @Transactional(readOnly = true)
    public List<ShiftSwapDTO.Response> pendingForEmployees(java.util.Collection<Long> employeeIds) {
        if (employeeIds.isEmpty()) return List.of();
        return swapRepo.findPendingForEmployees(employeeIds).stream().map(this::toResponse).toList();
    }

    @Transactional
    public ShiftSwapDTO.Response cancel(User user, Long id) {
        ShiftSwapRequest r = pending(user, id);
        Long myEmpId = employeeRepo.findByUserIdFetch(user.getId()).map(Employee::getId).orElse(null);
        if (myEmpId == null || !r.getRequester().getId().equals(myEmpId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        r.setStatus(ShiftSwapRequest.Status.CANCELLED);
        r.setProcessedAt(LocalDateTime.now(clock));
        return toResponse(swapRepo.save(r));
    }

    /** Ca sắp tới (hôm nay → +31 ngày) của chính người dùng, chưa có dữ liệu công — để chọn đổi. */
    @Transactional(readOnly = true)
    public List<ShiftSwapDTO.ShiftOption> myUpcoming(User user) {
        Employee me = selfEmployee(user);
        LocalDate today = LocalDate.now(clock);
        return assignRepo.findByEmployeeAndDateRange(me.getId(), today, today.plusDays(31)).stream()
            .filter(a -> !a.isDeleted() && !shiftService.assignmentHasAttendance(a))
            .map(a -> new ShiftSwapDTO.ShiftOption(a.getId(), a.getWorkDate(), label(a)))
            .toList();
    }

    /** Đồng nghiệp cùng phòng ban và ca của họ trong ngày của phân ca được chọn. */
    @Transactional(readOnly = true)
    public List<ShiftSwapDTO.Colleague> colleagues(User user, Long assignmentId) {
        Employee me = selfEmployee(user);
        ShiftAssignment mine = activeAssignment(assignmentId);
        if (!mine.getEmployee().getId().equals(me.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.swap.not_your_shift");
        }
        Long deptId = me.getDepartment() != null ? me.getDepartment().getId() : null;
        return employeeRepo.findAllByCompanyIdFetchDepartment(user.getCompany().getId()).stream()
            .filter(e -> !e.getId().equals(me.getId()) && e.getStatus() == Employee.Status.ACTIVE)
            .filter(e -> deptId == null || (e.getDepartment() != null && deptId.equals(e.getDepartment().getId())))
            .map(e -> new ShiftSwapDTO.Colleague(e.getId(), e.getFullName(),
                e.getDepartment() != null ? e.getDepartment().getName() : null,
                assignRepo.findByEmployeeIdAndWorkDateWithShift(e.getId(), mine.getWorkDate()).stream()
                    .filter(a -> !a.isDeleted() && !shiftService.assignmentHasAttendance(a))
                    .map(a -> new ShiftSwapDTO.ShiftOption(a.getId(), a.getWorkDate(), label(a))).toList()))
            .toList();
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private boolean canApprove(User user) {
        return user.hasPermission("SHIFT_SWAP_APPROVE");
    }

    private Employee selfEmployee(User user) {
        return employeeRepo.findByUserIdFetch(user.getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "error.user.employee_not_linked"));
    }

    private ShiftSwapRequest byId(User user, Long id) {
        return swapRepo.findById(id)
            .filter(x -> x.getCompanyId().equals(user.getCompany().getId()))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.swap.not_found"));
    }

    private ShiftSwapRequest pending(User user, Long id) {
        ShiftSwapRequest r = byId(user, id);
        if (r.getStatus() != ShiftSwapRequest.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.swap.not_pending");
        }
        return r;
    }

    private ShiftAssignment activeAssignment(Long id) {
        return assignRepo.findById(id).filter(a -> !a.isDeleted())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shiftAssignment.not_found"));
    }

    /** Ca chưa qua, kỳ chưa khoá, chưa có dữ liệu chấm công. */
    private void requireSwappable(Long companyId, ShiftAssignment a) {
        if (!a.getEmployee().getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        if (a.getWorkDate().isBefore(LocalDate.now(clock))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.swap.past_shift");
        }
        periodLockService.requireOpen(companyId, a.getWorkDate());
        if (shiftService.assignmentHasAttendance(a)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shiftAssignment.has_attendance");
        }
    }

    /** Sau khi đổi: người nhận không trùng giờ với ca khác của họ (bỏ qua chính 2 ca đang đổi). */
    private void checkFits(ShiftAssignment mine, ShiftAssignment theirs, Employee requester, Employee target) {
        Set<Long> ignore = theirs != null ? Set.of(mine.getId(), theirs.getId()) : Set.of(mine.getId());
        shiftService.validatePlacement(target.getId(), mine.getWorkDate(),
            mine.effectiveStartTime(), mine.effectiveEndTime(), ignore);
        if (theirs != null) {
            shiftService.validatePlacement(requester.getId(), theirs.getWorkDate(),
                theirs.effectiveStartTime(), theirs.effectiveEndTime(), ignore);
        }
    }

    /** Dòng công rỗng (chưa check-in) của ca sắp đổi chủ được xoá mềm để không lệch nhân viên. */
    private void dropEmptyAttendance(ShiftAssignment a) {
        attendanceRepository.findByEmployeeIdAndDateAndShift(a.getEmployee().getId(), a.getWorkDate(), a.getId())
            .ifPresent(att -> {
                att.setDeleted(true);
                att.setDeletedAt(LocalDateTime.now(clock));
                attendanceRepository.save(att);
            });
    }

    private static String label(ShiftAssignment a) {
        if (a == null) return null;
        String code = a.getSnapshotCode() != null ? a.getSnapshotCode()
            : a.getShift() != null ? a.getShift().getCode() : "";
        String s = a.effectiveStartTime() != null ? a.effectiveStartTime().format(HM) : "";
        String e = a.effectiveEndTime() != null ? a.effectiveEndTime().format(HM) : "";
        return (code + " " + s + "–" + e).trim();
    }

    private ShiftSwapDTO.Response toResponse(ShiftSwapRequest r) {
        ShiftAssignment ta = r.getTargetAssignment();
        return ShiftSwapDTO.Response.builder()
            .id(r.getId()).status(r.getStatus().name())
            .requesterId(r.getRequester().getId()).requesterName(r.getRequester().getFullName())
            .requesterAssignmentId(r.getRequesterAssignment().getId())
            .requesterDate(r.getRequesterAssignment().getWorkDate())
            .requesterShift(label(r.getRequesterAssignment()))
            .targetEmployeeId(r.getTargetEmployee().getId()).targetEmployeeName(r.getTargetEmployee().getFullName())
            .targetAssignmentId(ta != null ? ta.getId() : null)
            .targetDate(ta != null ? ta.getWorkDate() : null)
            .targetShift(label(ta))
            .kind(ta != null ? "SWAP" : "GIVE")
            .reason(r.getReason()).adminNote(r.getAdminNote())
            .processedByName(r.getProcessedBy() != null
                ? employeeRepo.findByUserIdFetch(r.getProcessedBy().getId()).map(Employee::getFullName)
                    .orElse(r.getProcessedBy().getEmail())
                : null)
            .processedAt(r.getProcessedAt()).createdAt(r.getCreatedAt())
            .managerApprovedAt(r.getManagerApprovedAt())
            .managerApprovedByName(r.getManagerApprovedBy() != null
                ? employeeRepo.findByUserIdFetch(r.getManagerApprovedBy().getId()).map(Employee::getFullName)
                    .orElse(r.getManagerApprovedBy().getEmail())
                : null)
            .managerNote(r.getManagerNote())
            .awaitingManagerName(managerApproval.awaitingManager(r.getRequester(), r,
                    r.getStatus() == ShiftSwapRequest.Status.PENDING)
                ? managerApproval.managerOf(r.getRequester()).getFullName() : null)
            .build();
    }
}
