package com.bosskin.controller;

import com.bosskin.dto.AttendanceRequestDTO;
import com.bosskin.entity.User;
import com.bosskin.service.AttendanceRequestService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/api/v1/attendance-requests")
@RequiredArgsConstructor
public class AttendanceRequestController {

    private final AttendanceRequestService requestService;

    @GetMapping
    public ResponseEntity<List<AttendanceRequestDTO.Response>> getRequests(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) String status,
        @RequestParam(required = false) String type,
        @RequestParam(required = false) Long departmentId
    ) {
        requireAnyPermission(user, "ATTENDANCE_SELF", "ATTENDANCE_MANAGE", "ATTENDANCE_REQUEST_APPROVE");
        return ResponseEntity.ok(requestService.getRequests(user, status, type, departmentId));
    }

    /** Danh sách đơn có phân trang + tìm kiếm phía server (F9). status = PENDING | RESOLVED | rỗng. */
    @GetMapping("/page")
    public ResponseEntity<com.bosskin.dto.PageResponse<AttendanceRequestDTO.Response>> searchRequests(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) String status,
        @RequestParam(required = false) String type,
        @RequestParam(required = false) Long departmentId,
        @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate from,
        @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate to,
        @RequestParam(required = false) String q,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        requireAnyPermission(user, "ATTENDANCE_SELF", "ATTENDANCE_MANAGE", "ATTENDANCE_REQUEST_APPROVE");
        Boolean pendingOnly = status == null || status.isBlank() ? null : "PENDING".equalsIgnoreCase(status);
        return ResponseEntity.ok(requestService.searchRequests(user, pendingOnly, type, departmentId, from, to, q, page, size));
    }

    @GetMapping("/pending-count")
    public ResponseEntity<AttendanceRequestDTO.PendingCount> pendingCount(@AuthenticationPrincipal User user) {
        requireAnyPermission(user, "ATTENDANCE_SELF", "ATTENDANCE_MANAGE", "ATTENDANCE_REQUEST_APPROVE");
        return ResponseEntity.ok(requestService.getPendingCount(user));
    }

    @PostMapping
    public ResponseEntity<List<AttendanceRequestDTO.Response>> create(
        @AuthenticationPrincipal User user,
        @Valid @RequestBody AttendanceRequestDTO.CreateRequest req
    ) {
        requireAnyPermission(user, "ATTENDANCE_SELF", "ATTENDANCE_MANAGE", "ATTENDANCE_REQUEST_APPROVE");
        return ResponseEntity.ok(requestService.createRequest(user, req));
    }

    @PutMapping("/{id}/approve")
    public ResponseEntity<AttendanceRequestDTO.Response> approve(
        @AuthenticationPrincipal User user,
        @PathVariable Long id,
        @RequestBody(required = false) AttendanceRequestDTO.ProcessRequest body
    ) {
        requirePermission(user, "ATTENDANCE_REQUEST_APPROVE");
        return ResponseEntity.ok(requestService.approveRequest(id, user, body));
    }

    @PutMapping("/{id}/reject")
    public ResponseEntity<AttendanceRequestDTO.Response> reject(
        @AuthenticationPrincipal User user,
        @PathVariable Long id,
        @RequestBody(required = false) AttendanceRequestDTO.ProcessRequest body
    ) {
        requirePermission(user, "ATTENDANCE_REQUEST_APPROVE");
        return ResponseEntity.ok(requestService.rejectRequest(id, user, body));
    }

    @PutMapping("/{id}/cancel")
    public ResponseEntity<AttendanceRequestDTO.Response> cancel(
        @AuthenticationPrincipal User user,
        @PathVariable Long id
    ) {
        requireAnyPermission(user, "ATTENDANCE_SELF", "ATTENDANCE_MANAGE", "ATTENDANCE_REQUEST_APPROVE");
        return ResponseEntity.ok(requestService.cancelRequest(id, user));
    }

    @PutMapping("/{id}/applied")
    public ResponseEntity<AttendanceRequestDTO.Response> toggleApplied(
        @AuthenticationPrincipal User user,
        @PathVariable Long id,
        @RequestBody AttendanceRequestDTO.ToggleAppliedRequest body
    ) {
        requireAnyPermission(user, "ATTENDANCE_MANAGE", "ATTENDANCE_REQUEST_APPROVE");
        return ResponseEntity.ok(requestService.updateApplied(id, user, body != null && body.isApplied()));
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm)) {
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    private void requireAnyPermission(User user, String... perms) {
        if (user == null) {
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        for (String perm : perms) {
            if (user.hasPermission(perm)) return;
        }
        throw new org.springframework.web.server.ResponseStatusException(
            org.springframework.http.HttpStatus.FORBIDDEN,
            "error.permission.denied");
    }
}
