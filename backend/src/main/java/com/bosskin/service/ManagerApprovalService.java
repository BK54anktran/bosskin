package com.bosskin.service;

import com.bosskin.entity.Company;
import com.bosskin.entity.Employee;
import com.bosskin.entity.ManagerApprovable;
import com.bosskin.entity.User;
import com.bosskin.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Map;

/**
 * Bước K — chế độ duyệt "quản lý trực tiếp trước, rồi HR" ({@link Company.ApprovalMode#MANAGER_THEN_HR}).
 * Chế độ PERMISSION (mặc định) giữ nguyên cách cũ: ai có quyền duyệt + phạm vi thì duyệt.
 * Khi bật: đơn của nhân viên có quản lý trực tiếp (còn làm) phải được quản lý duyệt trước; HR duyệt cuối.
 * Người duyệt cuối chính là quản lý trực tiếp → ghi luôn cả bước quản lý.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ManagerApprovalService {

    private final UserRepository userRepository;
    private final FcmService fcmService;
    private final Clock clock;

    public boolean enabled(Company company) {
        return company != null && company.effectiveApprovalMode() == Company.ApprovalMode.MANAGER_THEN_HR;
    }

    /** Quản lý trực tiếp còn làm việc của nhân viên; null nếu không có. */
    public Employee managerOf(Employee e) {
        if (e == null) return null;
        Employee m = e.getManager();
        return m != null && m.getStatus() != Employee.Status.INACTIVE ? m : null;
    }

    /** Đơn của nhân viên này có cần bước quản lý duyệt không. */
    public boolean requiresManagerStep(Employee requester) {
        return requester != null && enabled(requester.getCompany()) && managerOf(requester) != null;
    }

    /** Đơn đang chờ quản lý trực tiếp duyệt (để hiện nhãn ở danh sách HR). */
    public boolean awaitingManager(Employee requester, ManagerApprovable r, boolean pending) {
        return pending && r.getManagerApprovedAt() == null && requiresManagerStep(requester);
    }

    public boolean isDirectManagerOf(User user, Employee requester) {
        Employee m = managerOf(requester);
        return user != null && user.getEmployeeId() != null && m != null && m.getId().equals(user.getEmployeeId());
    }

    /** Gọi trước khi HR duyệt cuối. Chặn 409 nếu quản lý chưa duyệt (trừ khi người duyệt chính là quản lý). */
    public void beforeFinalApprove(User approver, Employee requester, ManagerApprovable r) {
        if (r.getManagerApprovedAt() != null || !requiresManagerStep(requester)) return;
        if (isDirectManagerOf(approver, requester)) {
            mark(r, approver, null);
            return;
        }
        throw new ResponseStatusException(HttpStatus.CONFLICT, "error.approval.manager_pending");
    }

    /** Quản lý trực tiếp xử lý bước 1: chế độ phải bật, đúng quản lý, đơn đang chờ, chưa duyệt bước này. */
    public void requireManagerCanProcess(User manager, Employee requester, ManagerApprovable r, boolean pending) {
        if (!enabled(requester.getCompany())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.approval.mode_off");
        }
        if (!isDirectManagerOf(manager, requester)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.approval.not_direct_manager");
        }
        if (!pending) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.request.not_pending");
        }
        if (r.getManagerApprovedAt() != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.approval.already_manager_approved");
        }
    }

    public void mark(ManagerApprovable r, User manager, String note) {
        r.setManagerApprovedBy(manager);
        r.setManagerApprovedAt(LocalDateTime.now(clock));
        r.setManagerNote(note != null && !note.isBlank() ? note.trim() : null);
    }

    /** Báo quản lý trực tiếp có đơn mới chờ duyệt (khi chế độ bật). Lỗi gửi không làm hỏng việc tạo đơn. */
    public void notifyManager(Employee requester, String kind, String title, String body) {
        try {
            if (!requiresManagerStep(requester)) return;
            userRepository.findByEmployeeId(managerOf(requester).getId())
                .filter(u -> u.getFcmToken() != null && u.isEnabled())
                .ifPresent(u -> fcmService.sendSimple(u.getFcmToken(), title, body,
                    Map.of("type", "TEAM_APPROVAL", "kind", kind)));
        } catch (RuntimeException ex) {
            log.warn("Không gửi được thông báo cho quản lý trực tiếp: {}", ex.getMessage());
        }
    }
}
