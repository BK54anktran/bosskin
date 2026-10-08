package com.bosskin.controller;

import com.bosskin.entity.User;
import com.bosskin.service.PeriodLockService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

/**
 * Khoá / mở kỳ công (A12).
 * <pre>
 * GET  /api/v1/attendance-periods?year=2026                 — trạng thái 12 kỳ (ATTENDANCE_VIEW)
 * POST /api/v1/attendance-periods/{year}/{month}/lock       — khoá kỳ (ATTENDANCE_PERIOD_LOCK)
 * POST /api/v1/attendance-periods/{year}/{month}/unlock     — mở lại, body {"reason": "..."} (ATTENDANCE_PERIOD_LOCK)
 * </pre>
 */
@RestController
@RequestMapping("/api/v1/attendance-periods")
@RequiredArgsConstructor
public class AttendancePeriodController {

    private final PeriodLockService periodLockService;

    @GetMapping
    public ResponseEntity<List<PeriodLockService.PeriodStatus>> list(
            @AuthenticationPrincipal User user, @RequestParam int year) {
        requirePermission(user, "ATTENDANCE_VIEW");
        return ResponseEntity.ok(periodLockService.listYear(user.getCompany().getId(), year));
    }

    @PostMapping("/{year}/{month}/lock")
    public ResponseEntity<PeriodLockService.PeriodStatus> lock(
            @AuthenticationPrincipal User user, @PathVariable int year, @PathVariable int month) {
        requirePermission(user, "ATTENDANCE_PERIOD_LOCK");
        return ResponseEntity.ok(periodLockService.lock(user.getCompany().getId(), user.getId(), year, month));
    }

    @PostMapping("/{year}/{month}/unlock")
    public ResponseEntity<PeriodLockService.PeriodStatus> unlock(
            @AuthenticationPrincipal User user, @PathVariable int year, @PathVariable int month,
            @RequestBody(required = false) Map<String, String> body) {
        requirePermission(user, "ATTENDANCE_PERIOD_LOCK");
        String reason = body != null ? body.get("reason") : null;
        return ResponseEntity.ok(periodLockService.unlock(user.getCompany().getId(), user.getId(), year, month, reason));
    }

    private static void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }
}
