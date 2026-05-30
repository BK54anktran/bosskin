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
    private final AttendanceRepository attendanceRepository;
    private final EmployeeRepository employeeRepository;
    private final ShiftAssignmentRepository shiftAssignmentRepository;
    private final DeptScopeService deptScopeService;

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

    @Transactional
    public AttendanceRequestDTO.Response createRequest(User user, AttendanceRequestDTO.CreateRequest req) {
        Employee emp = getEmployeeOrThrow(user);
        validateRequest(req);

        AttendanceRequest request = AttendanceRequest.builder()
            .employee(emp)
            .shiftAssignment(resolveShiftAssignment(emp, req))
            .requestDate(req.getRequestDate())
            .requestType(req.getRequestType())
            .requestedCheckIn(req.getRequestedCheckIn())
            .requestedCheckOut(req.getRequestedCheckOut())
            .requestedOvertimeMinutes(req.getRequestedOvertimeMinutes())
            .requestedOvertimeScope(req.getRequestedOvertimeScope())
            .requestedOvertimePeriod(req.getRequestedOvertimePeriod())
            .note(req.getNote())
            .build();
        return toResponse(requestRepository.save(request));
    }

    @Transactional
    public AttendanceRequestDTO.Response updateApplied(Long requestId, User admin, boolean applied) {
        AttendanceRequest request = getRequestOrThrow(requestId, admin.getCompany().getId());
        requireAttendanceViewScope(admin, request.getEmployee());
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
        Employee emp = getEmployeeOrThrow(user);
        if (request.getEmployee() == null || !request.getEmployee().getId().equals(emp.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Chỉ được hủy yêu cầu của chính mình");
        }
        requirePending(request);
        request.setStatus(AttendanceRequest.Status.CANCELLED);
        request.setApplied(false);
        request.setAdminNote("Người dùng đã hủy yêu cầu");
        request.setProcessedBy(user);
        request.setProcessedAt(java.time.LocalDateTime.now());
        requestRepository.save(request);
        return toResponse(getRequestOrThrow(requestId, user.getCompany().getId()));
    }

    @Transactional
    public AttendanceRequestDTO.Response approveRequest(Long requestId, User admin, AttendanceRequestDTO.ProcessRequest body) {
        requireApprovePermission(admin);
        AttendanceRequest request = getRequestOrThrow(requestId, admin.getCompany().getId());
        requireAttendanceViewScope(admin, request.getEmployee());
        requirePending(request);
        request.setStatus(AttendanceRequest.Status.APPROVED);
        request.setApplied(true);
        request.setAdminNote(body != null ? body.getAdminNote() : null);
        request.setProcessedBy(admin);
        request.setProcessedAt(java.time.LocalDateTime.now());
        requestRepository.save(request);
        disableOlderAppliedRequests(request);
        clearAttendanceSnapIfApproved(request.getEmployee().getId(), request.getRequestDate());
        return toResponse(getRequestOrThrow(requestId, admin.getCompany().getId()));
    }

    @Transactional
    public AttendanceRequestDTO.Response rejectRequest(Long requestId, User admin, AttendanceRequestDTO.ProcessRequest body) {
        requireApprovePermission(admin);
        AttendanceRequest request = getRequestOrThrow(requestId, admin.getCompany().getId());
        requireAttendanceViewScope(admin, request.getEmployee());
        requirePending(request);
        request.setStatus(AttendanceRequest.Status.REJECTED);
        request.setApplied(false);
        request.setAdminNote(body != null ? body.getAdminNote() : null);
        request.setProcessedBy(admin);
        request.setProcessedAt(java.time.LocalDateTime.now());
        requestRepository.save(request);
        clearAttendanceSnapIfApproved(request.getEmployee().getId(), request.getRequestDate());
        return toResponse(getRequestOrThrow(requestId, admin.getCompany().getId()));
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
                "Tài khoản chưa được liên kết với nhân viên nào"));
    }

    private AttendanceRequest getRequestOrThrow(Long id, Long companyId) {
        return requestRepository.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy yêu cầu"));
    }

    private void requirePending(AttendanceRequest request) {
        if (request.getStatus() != AttendanceRequest.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Chỉ được thao tác trên yêu cầu đang chờ duyệt");
        }
    }

    private void requireApproved(AttendanceRequest request) {
        if (request.getStatus() != AttendanceRequest.Status.APPROVED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Chỉ được thao tác trên yêu cầu đã duyệt");
        }
    }

    private void requireApprovePermission(User user) {
        if (user == null || !user.hasPermission("ATTENDANCE_REQUEST_APPROVE")) {
            throw new ResponseStatusException(
                HttpStatus.FORBIDDEN,
                "Không có quyền: ATTENDANCE_REQUEST_APPROVE"
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
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền thao tác phòng ban này");
        }
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        if (scope.isEmpty()) {
            return;
        }
        if (scope.contains(-1L)) {
            Long selfEmployeeId = getEmployeeOrThrow(user).getId();
            if (!selfEmployeeId.equals(employee.getId())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Chỉ được thao tác dữ liệu của chính mình");
            }
            return;
        }
        if (!scope.contains(employee.getDepartment().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền thao tác phòng ban này");
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
        if (req.getRequestDate() == null || req.getRequestType() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Thiếu thông tin ngày hoặc loại yêu cầu");
        }
        switch (req.getRequestType()) {
            case CHECK_IN -> {
                if (req.getRequestedCheckIn() == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Vui lòng nhập giờ check-in");
                }
            }
            case CHECK_OUT -> {
                if (req.getRequestedCheckOut() == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Vui lòng nhập giờ check-out");
                }
            }
            case OT -> {
                if (req.getRequestedOvertimeMinutes() == null || req.getRequestedOvertimeMinutes() <= 0) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Vui lòng nhập thời lượng OT hợp lệ");
                }
                if (req.getRequestedOvertimeScope() == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Vui lòng chọn phạm vi OT");
                }
                if (req.getRequestedOvertimePeriod() == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Vui lòng chọn OT ngày hoặc đêm");
                }
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
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Ca làm không hợp lệ"));
        }

        if (assignments.size() > 1 && req.getRequestType() != null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Vui lòng chọn ca làm cho ngày có nhiều ca");
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
}
