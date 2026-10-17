package com.bosskin.service;

import com.bosskin.dto.AttendanceRequestDTO;
import com.bosskin.entity.Attendance;
import com.bosskin.entity.AttendanceRequest;
import com.bosskin.entity.Employee;
import com.bosskin.entity.ShiftAssignment;
import com.bosskin.entity.User;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.AttendanceRequestRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.hibernate.Hibernate;

import java.time.LocalTime;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AttendanceRequestService {

    private final AttendanceRequestRepository requestRepository;
    private final PeriodLockService periodLockService;
    private final AttendanceRepository attendanceRepository;
    private final EmployeeRepository employeeRepository;
    private final ShiftAssignmentRepository shiftAssignmentRepository;
    private final DeptScopeService deptScopeService;
    private final com.bosskin.audit.AuditService audit;
    private final ManagerApprovalService managerApproval;

    public List<AttendanceRequestDTO.Response> getRequests(User user, String statusStr, String typeStr, Long departmentId) {
        AttendanceRequest.Status status = parseStatus(statusStr);
        AttendanceRequest.Type type = parseType(typeStr);
        Set<Long> selectedDeptScope = null;
        if (departmentId != null) {
            selectedDeptScope = deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId));
            if (selectedDeptScope.isEmpty()) {
                return List.of();
            }
        }

        List<AttendanceRequest> requests;
        if (isManager(user)) {
            requests = requestRepository.findByCompanyId(user.getCompany().getId(), status, type);
            requests = filterByAttendanceViewScope(requests, user, selectedDeptScope);
        } else {
            Employee emp = getEmployeeOrThrow(user);
            if (selectedDeptScope != null && (emp.getDepartment() == null
                || !selectedDeptScope.contains(emp.getDepartment().getId()))) {
                return List.of();
            }
            requests = requestRepository.findByEmployeeId(emp.getId())
                .stream()
                .filter(r -> status == null || r.getStatus() == status)
                .filter(r -> type == null || r.getRequestType() == type)
                .sorted((a, b) -> b.getRequestDate().compareTo(a.getRequestDate()))
                .collect(Collectors.toList());
        }
        return requests.stream().map(this::toResponse).collect(Collectors.toList());
    }

    /** Như {@link #getRequests} nhưng lọc + phân trang ở DB (F9). */
    @Transactional(readOnly = true)
    public com.bosskin.dto.PageResponse<AttendanceRequestDTO.Response> searchRequests(
            User user, Boolean pendingOnly, String typeStr, Long departmentId,
            java.time.LocalDate from, java.time.LocalDate to, String q, int page, int size) {
        AttendanceRequest.Type type = parseType(typeStr);
        var pageable = org.springframework.data.domain.PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 200));
        var empty = com.bosskin.dto.PageResponse.of(
            org.springframework.data.domain.Page.<AttendanceRequestDTO.Response>empty(pageable));

        Long employeeId = null;
        Set<Long> deptIds = Set.of();
        boolean anyDept = true;
        if (!isManager(user)) {
            employeeId = getEmployeeOrThrow(user).getId();
        } else {
            Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
            if (scope.contains(-1L)) {
                employeeId = getEmployeeOrThrow(user).getId();
            }
            deptIds = scope.stream().filter(id -> id > 0).collect(Collectors.toSet());
            anyDept = deptIds.isEmpty() || employeeId != null;
        }
        if (departmentId != null) {
            Set<Long> selected = new java.util.HashSet<>(deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId)));
            if (!anyDept) selected.retainAll(deptIds);
            deptIds = selected;
            anyDept = false;
            if (deptIds.isEmpty()) return empty;
        }
        String like = q == null || q.isBlank() ? null : "%" + q.trim().toLowerCase() + "%";
        var result = requestRepository.searchPage(user.getCompany().getId(), pendingOnly, type, employeeId,
            anyDept, anyDept ? Set.of(-1L) : deptIds, from, to, like, pageable);
        return com.bosskin.dto.PageResponse.of(result.map(this::toResponse));
    }

    @Transactional
    public List<AttendanceRequestDTO.Response> createRequest(User user, AttendanceRequestDTO.CreateRequest req) {
        Employee emp = getEmployeeOrThrow(user);
        validateRequest(req);
        periodLockService.requireOpen(emp.getCompany().getId(), req.getRequestDate());

        ShiftAssignment shift = resolveShiftAssignment(emp, req);
        List<AttendanceRequest> created = new java.util.ArrayList<>();

        AttendanceRequest.Type type = req.getRequestType();
        if (type == AttendanceRequest.Type.OT || type == AttendanceRequest.Type.EXTRA) {
            created.add(AttendanceRequest.builder()
                .employee(emp)
                .shiftAssignment(shift)
                .requestDate(req.getRequestDate())
                .requestType(type)
                .requestedOvertimeMinutes(req.getRequestedOvertimeMinutes())
                .requestedOvertimeScope(req.getRequestedOvertimeScope())
                .requestedOvertimePeriod(req.getRequestedOvertimePeriod())
                .note(req.getNote())
                .build());
        } else {
            if (req.getRequestedCheckIn() != null) {
                created.add(AttendanceRequest.builder()
                    .employee(emp)
                    .shiftAssignment(shift)
                    .requestDate(req.getRequestDate())
                    .requestType(AttendanceRequest.Type.CHECK_IN)
                    .requestedCheckIn(req.getRequestedCheckIn())
                    .note(req.getNote())
                    .build());
            }
            if (req.getRequestedCheckOut() != null) {
                created.add(AttendanceRequest.builder()
                    .employee(emp)
                    .shiftAssignment(shift)
                    .requestDate(req.getRequestDate())
                    .requestType(AttendanceRequest.Type.CHECK_OUT)
                    .requestedCheckOut(req.getRequestedCheckOut())
                    .note(req.getNote())
                    .build());
            }
        }
        if (created.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.check_in_or_out_required");
        }
        List<AttendanceRequest> saved = requestRepository.saveAll(created);
        managerApproval.notifyManager(emp, "ATTENDANCE", "push.attReq.title", "push.attReq.body",
            emp.getFullName(), String.valueOf(req.getRequestDate()));
        return saved.stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional
    public AttendanceRequestDTO.Response updateApplied(Long requestId, User admin, boolean applied) {
        requireApprovePermission(admin);
        AttendanceRequest request = getRequestOrThrow(requestId, admin.getCompany().getId());
        periodLockService.requireOpen(admin.getCompany().getId(), request.getRequestDate());
        requireAttendanceViewScope(admin, request.getEmployee());
        requireNotOwnRequest(admin, request);
        requireApproved(request);
        request.setApplied(applied);
        requestRepository.save(request);
        if (applied) {
            disableOlderAppliedRequests(request);
        }
        clearAttendanceSnapIfApproved(request.getEmployee().getId(), request.getRequestDate());
        return toResponse(getRequestOrThrow(requestId, admin.getCompany().getId()));
    }

    @Transactional
    public AttendanceRequestDTO.Response cancelRequest(Long requestId, User user) {
        AttendanceRequest request = getRequestOrThrow(requestId, user.getCompany().getId());
        periodLockService.requireOpen(user.getCompany().getId(), request.getRequestDate());
        Employee emp = getEmployeeOrThrow(user);
        if (request.getEmployee() == null || !request.getEmployee().getId().equals(emp.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.request.cancel_own_only");
        }
        requirePending(request);
        request.setStatus(AttendanceRequest.Status.CANCELLED);
        request.setApplied(false);
        request.setAdminNote("Người dùng đã hủy yêu cầu");
        request.setProcessedBy(user);
        request.setProcessedAt(com.bosskin.core.CompanyZone.now());
        requestRepository.save(request);
        return toResponse(getRequestOrThrow(requestId, user.getCompany().getId()));
    }

    @Transactional
    public AttendanceRequestDTO.Response approveRequest(Long requestId, User admin, AttendanceRequestDTO.ProcessRequest body) {
        requireApprovePermission(admin);
        AttendanceRequest request = getRequestOrThrow(requestId, admin.getCompany().getId());
        periodLockService.requireOpen(admin.getCompany().getId(), request.getRequestDate());
        requireAttendanceViewScope(admin, request.getEmployee());
        requireNotOwnRequest(admin, request);
        requirePending(request);
        managerApproval.beforeFinalApprove(admin, request.getEmployee(), request);
        request.setStatus(AttendanceRequest.Status.APPROVED);
        request.setApplied(true);
        request.setAdminNote(body != null ? body.getAdminNote() : null);
        request.setProcessedBy(admin);
        request.setProcessedAt(com.bosskin.core.CompanyZone.now());
        requestRepository.save(request);
        disableOlderAppliedRequests(request);
        approvePairedRequest(request, admin, body != null ? body.getAdminNote() : null);
        clearAttendanceSnapIfApproved(request.getEmployee().getId(), request.getRequestDate());
        auditRequest("ATTENDANCE_REQUEST_APPROVE", request);
        return toResponse(getRequestOrThrow(requestId, admin.getCompany().getId()));
    }

    @Transactional
    public AttendanceRequestDTO.Response rejectRequest(Long requestId, User admin, AttendanceRequestDTO.ProcessRequest body) {
        requireApprovePermission(admin);
        AttendanceRequest request = getRequestOrThrow(requestId, admin.getCompany().getId());
        periodLockService.requireOpen(admin.getCompany().getId(), request.getRequestDate());
        requireAttendanceViewScope(admin, request.getEmployee());
        requireNotOwnRequest(admin, request);
        requirePending(request);
        doReject(request, admin, body != null ? body.getAdminNote() : null);
        return toResponse(getRequestOrThrow(requestId, admin.getCompany().getId()));
    }

    private void doReject(AttendanceRequest request, User admin, String note) {
        request.setStatus(AttendanceRequest.Status.REJECTED);
        request.setApplied(false);
        request.setAdminNote(note);
        request.setProcessedBy(admin);
        request.setProcessedAt(com.bosskin.core.CompanyZone.now());
        requestRepository.save(request);
        rejectPairedRequest(request, admin, note);
        clearAttendanceSnapIfApproved(request.getEmployee().getId(), request.getRequestDate());
        auditRequest("ATTENDANCE_REQUEST_REJECT", request);
    }

    /** Bước K: quản lý trực tiếp duyệt bước 1 (kèm đơn vào/ra đi cặp). */
    @Transactional
    public AttendanceRequestDTO.Response managerApprove(Long requestId, User manager, String note) {
        AttendanceRequest request = getRequestOrThrow(requestId, manager.getCompany().getId());
        managerApproval.requireManagerCanProcess(manager, request.getEmployee(), request,
            request.getStatus() == AttendanceRequest.Status.PENDING);
        managerApproval.mark(request, manager, note);
        requestRepository.save(request);
        AttendanceRequest.Type pairedType = pairedType(request.getRequestType());
        if (pairedType != null) {
            Long shiftId = request.getShiftAssignment() != null ? request.getShiftAssignment().getId() : null;
            for (AttendanceRequest peer : requestRepository.findPendingPaired(
                    request.getEmployee().getId(), request.getRequestDate(), pairedType, request.getId(), shiftId)) {
                if (peer.getManagerApprovedAt() == null) {
                    managerApproval.mark(peer, manager, note);
                    requestRepository.save(peer);
                }
            }
        }
        return toResponse(getRequestOrThrow(requestId, manager.getCompany().getId()));
    }

    /** Bước K: quản lý trực tiếp từ chối → đơn bị từ chối như HR từ chối. */
    @Transactional
    public AttendanceRequestDTO.Response managerReject(Long requestId, User manager, String note) {
        AttendanceRequest request = getRequestOrThrow(requestId, manager.getCompany().getId());
        managerApproval.requireManagerCanProcess(manager, request.getEmployee(), request,
            request.getStatus() == AttendanceRequest.Status.PENDING);
        periodLockService.requireOpen(manager.getCompany().getId(), request.getRequestDate());
        request.setManagerNote(note != null && !note.isBlank() ? note.trim() : null);
        doReject(request, manager, note);
        return toResponse(getRequestOrThrow(requestId, manager.getCompany().getId()));
    }

    @Transactional(readOnly = true)
    public List<AttendanceRequestDTO.Response> pendingForEmployees(java.util.Collection<Long> employeeIds) {
        if (employeeIds.isEmpty()) return List.of();
        return requestRepository.findPendingForEmployees(employeeIds).stream().map(this::toResponse).toList();
    }

    /** Bước 2 — nhật ký duyệt/từ chối đơn sửa giờ (đơn duyệt thay giờ chấm công thực). */
    private void auditRequest(String action, AttendanceRequest r) {
        audit.log(action).entity("ATTENDANCE_REQUEST", r.getId())
            .summary(r.getEmployee().getFullName() + " · " + r.getRequestDate())
            .detail(com.bosskin.audit.AuditService.map("employeeId", r.getEmployee().getId(),
                "date", r.getRequestDate(), "checkIn", r.getRequestedCheckIn(),
                "checkOut", r.getRequestedCheckOut(), "note", r.getAdminNote()))
            .save();
    }

    public AttendanceRequestDTO.PendingCount getPendingCount(User user) {
        if (!isManager(user)) {
            return AttendanceRequestDTO.PendingCount.builder().count(0).build();
        }
        List<AttendanceRequest> pending = requestRepository.findByCompanyId(
            user.getCompany().getId(), AttendanceRequest.Status.PENDING, null);
        long count = filterByAttendanceViewScope(pending, user, null).size();
        return AttendanceRequestDTO.PendingCount.builder().count(count).build();
    }

    private Employee getEmployeeOrThrow(User user) {
        return employeeRepository.findByUserIdFetch(user.getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                "error.user.employee_not_linked"));
    }

    private AttendanceRequest getRequestOrThrow(Long id, Long companyId) {
        return requestRepository.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.request.not_found"));
    }

    private void requirePending(AttendanceRequest request) {
        if (request.getStatus() != AttendanceRequest.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.request.not_pending");
        }
    }

    private void requireApproved(AttendanceRequest request) {
        if (request.getStatus() != AttendanceRequest.Status.APPROVED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.request.not_approved");
        }
    }

    private void requireApprovePermission(User user) {
        if (user == null || !user.hasPermission("ATTENDANCE_REQUEST_APPROVE")) {
            throw new ResponseStatusException(
                HttpStatus.FORBIDDEN,
                "error.permission.denied"
            );
        }
    }

    private void disableOlderAppliedRequests(AttendanceRequest approvedRequest) {
        if (approvedRequest == null || approvedRequest.getEmployee() == null) {
            return;
        }
        if (approvedRequest.getRequestType() != AttendanceRequest.Type.CHECK_IN
            && approvedRequest.getRequestType() != AttendanceRequest.Type.CHECK_OUT) {
            return;
        }
        Long shiftId = approvedRequest.getShiftAssignment() != null
            ? approvedRequest.getShiftAssignment().getId() : null;
        List<AttendanceRequest> olderApplied = requestRepository.findAppliedSameTypeSameDateExcluding(
            approvedRequest.getEmployee().getId(),
            approvedRequest.getRequestDate(),
            approvedRequest.getRequestType(),
            approvedRequest.getId(),
            shiftId
        );
        for (AttendanceRequest older : olderApplied) {
            older.setApplied(false);
        }
        if (!olderApplied.isEmpty()) {
            requestRepository.saveAll(olderApplied);
        }
    }

    private boolean isManager(User user) {
        return user != null && (
            user.hasPermission("ATTENDANCE_MANAGE") ||
            user.hasPermission("ATTENDANCE_REQUEST_APPROVE")
        );
    }

    private List<AttendanceRequest> filterByAttendanceViewScope(
        List<AttendanceRequest> requests, User user, Set<Long> selectedDeptScope
    ) {
        if (requests == null || requests.isEmpty()) {
            return List.of();
        }
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        if (scope.isEmpty()) {
            if (selectedDeptScope == null) return requests;
            return requests.stream()
                .filter(r ->
                    r.getEmployee() != null
                        && r.getEmployee().getDepartment() != null
                        && selectedDeptScope.contains(r.getEmployee().getDepartment().getId()))
                .collect(Collectors.toList());
        }
        if (scope.contains(-1L)) {
            Long selfEmployeeId = getEmployeeOrThrow(user).getId();
            List<AttendanceRequest> filtered = requests.stream()
                .filter(r -> r.getEmployee() != null && selfEmployeeId.equals(r.getEmployee().getId()))
                .collect(Collectors.toList());
            if (selectedDeptScope == null) return filtered;
            return filtered.stream()
                .filter(r ->
                    r.getEmployee() != null
                        && r.getEmployee().getDepartment() != null
                        && selectedDeptScope.contains(r.getEmployee().getDepartment().getId()))
                .collect(Collectors.toList());
        }
        return requests.stream()
            .filter(r ->
                r.getEmployee() != null
                    && r.getEmployee().getDepartment() != null
                    && scope.contains(r.getEmployee().getDepartment().getId())
                    && (selectedDeptScope == null
                        || selectedDeptScope.contains(r.getEmployee().getDepartment().getId())))
            .collect(Collectors.toList());
    }

    private void requireAttendanceViewScope(User user, Employee employee) {
        if (employee == null || employee.getDepartment() == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        if (scope.isEmpty()) {
            return;
        }
        if (scope.contains(-1L)) {
            Long selfEmployeeId = getEmployeeOrThrow(user).getId();
            if (!selfEmployeeId.equals(employee.getId())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
            }
            return;
        }
        if (!scope.contains(employee.getDepartment().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    private AttendanceRequest.Status parseStatus(String statusStr) {
        if (statusStr == null || statusStr.isBlank()) return null;
        return AttendanceRequest.Status.valueOf(statusStr.toUpperCase());
    }

    private AttendanceRequest.Type parseType(String typeStr) {
        if (typeStr == null || typeStr.isBlank()) return null;
        return AttendanceRequest.Type.valueOf(typeStr.toUpperCase());
    }

    private void validateRequest(AttendanceRequestDTO.CreateRequest req) {
        if (req.getRequestDate() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.date_required");
        }
        if (req.getRequestedCheckIn() == null && req.getRequestedCheckOut() == null
                && req.getRequestedOvertimeMinutes() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.check_in_or_out_required");
        }
        if (req.getRequestedOvertimeMinutes() != null) {
            if (req.getRequestedOvertimeMinutes() <= 0) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.ot_duration_invalid");
            }
            if (req.getRequestType() == AttendanceRequest.Type.OT && req.getRequestedOvertimeScope() == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.ot_scope_required");
            }
            if (req.getRequestedOvertimePeriod() == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.ot_period_required");
            }
        }
    }

    private ShiftAssignment resolveShiftAssignment(Employee emp, AttendanceRequestDTO.CreateRequest req) {
        List<ShiftAssignment> assignments = shiftAssignmentRepository
            .findByEmployeeIdAndWorkDateWithShift(emp.getId(), req.getRequestDate())
            .stream()
            .sorted(this::compareAssignments)
            .toList();
        if (assignments.isEmpty()) {
            return null;
        }

        Long requestedId = req.getShiftAssignmentId();
        if (requestedId != null) {
            return assignments.stream()
                .filter(a -> requestedId.equals(a.getId()))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift.invalid"));
        }

        if (assignments.size() > 1 && req.getRequestType() != null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift.choose_for_multi_shift_day");
        }

        return assignments.get(0);
    }

    private LocalTime assignmentStartTime(ShiftAssignment assignment) {
        if (assignment == null) {
            return null;
        }
        if (assignment.isCustom()) {
            return assignment.getCustomStartTime();
        }
        if (assignment.getShift() != null) {
            return assignment.getCustomStartTime() != null
                ? assignment.getCustomStartTime()
                : assignment.getShift().getStartTime();
        }
        return null;
    }

    private int compareAssignments(ShiftAssignment a, ShiftAssignment b) {
        int cmp = compareNullable(assignmentStartTime(a), assignmentStartTime(b));
        if (cmp != 0) {
            return cmp;
        }
        return compareNullable(a != null ? a.getId() : null, b != null ? b.getId() : null);
    }

    private <T extends Comparable<T>> int compareNullable(T a, T b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
    }

    private void approvePairedRequest(AttendanceRequest request, User admin, String adminNote) {
        AttendanceRequest.Type pairedType = pairedType(request.getRequestType());
        if (pairedType == null) return;
        Long shiftId = request.getShiftAssignment() != null ? request.getShiftAssignment().getId() : null;
        List<AttendanceRequest> paired = requestRepository.findPendingPaired(
            request.getEmployee().getId(), request.getRequestDate(), pairedType, request.getId(), shiftId);
        if (paired.isEmpty()) return;
        AttendanceRequest peer = paired.get(0);
        peer.setStatus(AttendanceRequest.Status.APPROVED);
        peer.setApplied(true);
        peer.setAdminNote(adminNote);
        peer.setProcessedBy(admin);
        peer.setProcessedAt(com.bosskin.core.CompanyZone.now());
        requestRepository.save(peer);
        disableOlderAppliedRequests(peer);
    }

    private void rejectPairedRequest(AttendanceRequest request, User admin, String adminNote) {
        AttendanceRequest.Type pairedType = pairedType(request.getRequestType());
        if (pairedType == null) return;
        Long shiftId = request.getShiftAssignment() != null ? request.getShiftAssignment().getId() : null;
        List<AttendanceRequest> paired = requestRepository.findPendingPaired(
            request.getEmployee().getId(), request.getRequestDate(), pairedType, request.getId(), shiftId);
        if (paired.isEmpty()) return;
        AttendanceRequest peer = paired.get(0);
        peer.setStatus(AttendanceRequest.Status.REJECTED);
        peer.setApplied(false);
        peer.setAdminNote(adminNote);
        peer.setProcessedBy(admin);
        peer.setProcessedAt(com.bosskin.core.CompanyZone.now());
        requestRepository.save(peer);
    }

    private AttendanceRequest.Type pairedType(AttendanceRequest.Type type) {
        if (type == AttendanceRequest.Type.CHECK_IN) return AttendanceRequest.Type.CHECK_OUT;
        if (type == AttendanceRequest.Type.CHECK_OUT) return AttendanceRequest.Type.CHECK_IN;
        return null;
    }

    private void clearAttendanceSnapIfApproved(Long employeeId, java.time.LocalDate date) {
        for (var att : attendanceRepository.findByEmployeeIdAndDate(employeeId, date)) {
            if (!att.isApproved()) continue;
            att.setApproved(false);
            att.setApprovedAt(null);
            att.setApprovedBy(null);
            att.setSnapActualHours(null);
            att.setSnapDayHours(null);
            att.setSnapDayOt(null);
            att.setSnapNightHours(null);
            att.setSnapNightOt(null);
            att.setWorkFlags(null);
            attendanceRepository.save(att);
        }
    }

    private AttendanceRequestDTO.Response toResponse(AttendanceRequest r) {
        Employee emp = r.getEmployee();
        return AttendanceRequestDTO.Response.builder()
            .id(r.getId())
            .employeeId(emp.getId())
            .employeeCode(emp.getEmployeeCode())
            .employeeName(emp.getFullName())
            .departmentId(emp.getDepartment().getId())
            .departmentName(emp.getDepartment().getName())
            .requestDate(r.getRequestDate())
            .requestType(r.getRequestType())
            .requestedCheckIn(r.getRequestedCheckIn())
            .requestedCheckOut(r.getRequestedCheckOut())
            .requestedOvertimeMinutes(r.getRequestedOvertimeMinutes())
            .requestedOvertimeScope(r.getRequestedOvertimeScope())
            .requestedOvertimePeriod(r.getRequestedOvertimePeriod())
            .applied(r.isApplied())
            .note(r.getNote())
            .status(r.getStatus())
            .adminNote(r.getAdminNote())
            .processedByName(resolveProcessedByName(r.getProcessedBy()))
            .createdAt(r.getCreatedAt())
            .processedAt(r.getProcessedAt())
            .managerApprovedAt(r.getManagerApprovedAt())
            .managerApprovedByName(resolveProcessedByName(r.getManagerApprovedBy()))
            .managerNote(r.getManagerNote())
            .awaitingManagerName(managerApproval.awaitingManager(emp, r, r.getStatus() == AttendanceRequest.Status.PENDING)
                ? managerApproval.managerOf(emp).getFullName() : null)
            .build();
    }

    private String resolveProcessedByName(User processedBy) {
        if (processedBy == null) {
            return null;
        }
        try {
            if (processedBy.getEmployee() != null && Hibernate.isInitialized(processedBy.getEmployee())) {
                String fullName = processedBy.getEmployee().getFullName();
                if (fullName != null && !fullName.isBlank()) {
                    return fullName;
                }
            }
        } catch (Exception ignored) {
            // Fallback to email below
        }
        return processedBy.getEmail();
    }

    /** Người duyệt không tự duyệt / đổi áp dụng đơn của chính mình. */
    private void requireNotOwnRequest(User admin, AttendanceRequest request) {
        if (admin.getEmployee() != null && request.getEmployee() != null
                && admin.getEmployee().getId().equals(request.getEmployee().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.attendance_request.cannot_process_own");
        }
    }
}
