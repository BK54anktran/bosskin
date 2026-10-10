package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.dto.TeamApprovalDTO;
import com.bosskin.entity.Company;
import com.bosskin.entity.Employee;
import com.bosskin.entity.User;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/**
 * Bước K — quản lý trực tiếp duyệt bước 1 đơn nghỉ / sửa công / đổi ca của cấp dưới.
 * Không cần quyền duyệt: quyền đến từ quan hệ quản lý (employees.manager_id) khi công ty bật MANAGER_THEN_HR.
 * HR (người có quyền duyệt + phạm vi) duyệt cuối như cũ.
 */
@Service
@RequiredArgsConstructor
public class TeamApprovalService {

    public enum Kind { LEAVE, ATTENDANCE, SWAP }

    private final EmployeeRepository employeeRepository;
    private final CompanyRepository companyRepository;
    private final LeaveService leaveService;
    private final AttendanceRequestService attendanceRequestService;
    private final ShiftSwapService shiftSwapService;
    private final ManagerApprovalService managerApproval;
    private final AuditService audit;

    @Transactional(readOnly = true)
    public TeamApprovalDTO.Response list(User user) {
        boolean enabled = enabled(user);
        List<Long> reports = reportIds(user);
        if (!enabled || reports.isEmpty()) {
            return TeamApprovalDTO.Response.builder().enabled(enabled).reportCount(reports.size())
                .leaves(List.of()).attendances(List.of()).swaps(List.of()).build();
        }
        return TeamApprovalDTO.Response.builder()
            .enabled(true).reportCount(reports.size())
            .leaves(leaveService.pendingForEmployees(reports).stream()
                .filter(r -> r.getManagerApprovedAt() == null).toList())
            .attendances(attendanceRequestService.pendingForEmployees(reports).stream()
                .filter(r -> r.getManagerApprovedAt() == null).toList())
            .swaps(shiftSwapService.pendingForEmployees(reports).stream()
                .filter(r -> r.getManagerApprovedAt() == null).toList())
            .build();
    }

    @Transactional(readOnly = true)
    public TeamApprovalDTO.Count count(User user) {
        TeamApprovalDTO.Response r = list(user);
        return TeamApprovalDTO.Count.builder().enabled(r.isEnabled()).reportCount(r.getReportCount())
            .count(r.getLeaves().size() + r.getAttendances().size() + r.getSwaps().size()).build();
    }

    @Transactional
    public Object process(User user, String kindStr, Long id, boolean approve, String note) {
        Kind kind = parseKind(kindStr);
        Object result = switch (kind) {
            case LEAVE -> approve ? leaveService.managerApprove(id, user, note) : leaveService.managerReject(id, user, note);
            case ATTENDANCE -> approve ? attendanceRequestService.managerApprove(id, user, note)
                : attendanceRequestService.managerReject(id, user, note);
            case SWAP -> approve ? shiftSwapService.managerApprove(user, id, note) : shiftSwapService.managerReject(user, id, note);
        };
        String entity = switch (kind) {
            case LEAVE -> "LEAVE_REQUEST";
            case ATTENDANCE -> "ATTENDANCE_REQUEST";
            case SWAP -> "SHIFT_SWAP";
        };
        audit.log(approve ? "MANAGER_APPROVE" : "MANAGER_REJECT").entity(entity, id)
            .summary(kind.name() + " #" + id)
            .detail(AuditService.map("kind", kind.name(), "note", note))
            .save();
        return result;
    }

    private boolean enabled(User user) {
        Company c = companyRepository.findById(user.getCompanyId()).orElse(null);
        return managerApproval.enabled(c);
    }

    private List<Long> reportIds(User user) {
        if (user.getEmployeeId() == null) return List.of();
        return employeeRepository.findDirectReports(user.getEmployeeId()).stream().map(Employee::getId).toList();
    }

    private static Kind parseKind(String s) {
        try {
            return Kind.valueOf(s.toUpperCase());
        } catch (RuntimeException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.approval.kind_invalid");
        }
    }
}
