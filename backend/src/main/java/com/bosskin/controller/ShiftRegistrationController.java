package com.bosskin.controller;

import com.bosskin.dto.ShiftRegistrationDTO;
import com.bosskin.entity.User;
import com.bosskin.service.ShiftRegistrationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.List;

/**
 * Đăng ký lịch làm việc (V23). Công ty tắt chức năng → mọi API 403 error.shift_registration.disabled.
 * <pre>
 * GET    /api/v1/shift-registration-rounds                          — SHIFT_REGISTRATION_MANAGE (+ SHIFT_VIEW, phạm vi phòng ban)
 * POST   /api/v1/shift-registration-rounds                          — tạo đợt (open = true: mở luôn)
 * PUT    /api/v1/shift-registration-rounds/{id}                     — sửa đợt
 * DELETE /api/v1/shift-registration-rounds/{id}                     — xoá đợt (khi chưa duyệt đăng ký nào)
 * POST   /api/v1/shift-registration-rounds/{id}/open|close          — mở / đóng
 * GET    /api/v1/shift-registration-rounds/{id}/board               — lưới người × ngày
 * POST   /api/v1/shift-registration-rounds/{id}/days/{date}/approve — duyệt cả ngày → phân ca {anyShiftId?}
 * POST   /api/v1/shift-registrations/{id}/approve                   — duyệt một ô {shiftId? | startTime + endTime?}
 * POST   /api/v1/shift-registrations/{id}/reject                    — từ chối một ô
 * GET    /api/v1/shift-registrations/self/rounds                    — SHIFT_REGISTRATION_SELF: đợt của tôi
 * GET    /api/v1/shift-registrations/self/rounds/{id}               — đăng ký của tôi trong đợt + ca có sẵn
 * PUT    /api/v1/shift-registrations/self/rounds/{id}               — ghi cả lịch của tôi trong đợt {slots}
 * </pre>
 */
@RestController
@RequiredArgsConstructor
public class ShiftRegistrationController {

    private final ShiftRegistrationService service;

    @GetMapping("/api/v1/shift-registration-rounds")
    public ResponseEntity<List<ShiftRegistrationDTO.RoundResponse>> rounds(@AuthenticationPrincipal User user) {
        requirePermission(user, "SHIFT_VIEW", "SHIFT_REGISTRATION_MANAGE");
        return ResponseEntity.ok(service.listRounds(user));
    }

    @PostMapping("/api/v1/shift-registration-rounds")
    public ResponseEntity<ShiftRegistrationDTO.RoundResponse> create(@AuthenticationPrincipal User user,
                                                                    @Valid @RequestBody ShiftRegistrationDTO.RoundUpsert req) {
        requirePermission(user, "SHIFT_VIEW", "SHIFT_REGISTRATION_MANAGE");
        return ResponseEntity.ok(service.createRound(user, req));
    }

    @PutMapping("/api/v1/shift-registration-rounds/{id}")
    public ResponseEntity<ShiftRegistrationDTO.RoundResponse> update(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                                    @Valid @RequestBody ShiftRegistrationDTO.RoundUpsert req) {
        requirePermission(user, "SHIFT_VIEW", "SHIFT_REGISTRATION_MANAGE");
        return ResponseEntity.ok(service.updateRound(user, id, req));
    }

    @DeleteMapping("/api/v1/shift-registration-rounds/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal User user, @PathVariable Long id) {
        requirePermission(user, "SHIFT_VIEW", "SHIFT_REGISTRATION_MANAGE");
        service.deleteRound(user, id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/api/v1/shift-registration-rounds/{id}/open")
    public ResponseEntity<ShiftRegistrationDTO.RoundResponse> open(@AuthenticationPrincipal User user, @PathVariable Long id) {
        requirePermission(user, "SHIFT_VIEW", "SHIFT_REGISTRATION_MANAGE");
        return ResponseEntity.ok(service.open(user, id));
    }

    @PostMapping("/api/v1/shift-registration-rounds/{id}/close")
    public ResponseEntity<ShiftRegistrationDTO.RoundResponse> close(@AuthenticationPrincipal User user, @PathVariable Long id) {
        requirePermission(user, "SHIFT_VIEW", "SHIFT_REGISTRATION_MANAGE");
        return ResponseEntity.ok(service.close(user, id));
    }

    @GetMapping("/api/v1/shift-registration-rounds/{id}/board")
    public ResponseEntity<ShiftRegistrationDTO.BoardResponse> board(@AuthenticationPrincipal User user, @PathVariable Long id) {
        requirePermission(user, "SHIFT_VIEW", "SHIFT_REGISTRATION_MANAGE");
        return ResponseEntity.ok(service.board(user, id));
    }

    @PostMapping("/api/v1/shift-registration-rounds/{id}/days/{date}/approve")
    public ResponseEntity<ShiftRegistrationDTO.DecideResult> approveDay(
        @AuthenticationPrincipal User user, @PathVariable Long id,
        @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
        @RequestBody(required = false) ShiftRegistrationDTO.ApproveDayRequest body) {
        requirePermission(user, "SHIFT_VIEW", "SHIFT_REGISTRATION_MANAGE");
        return ResponseEntity.ok(service.approveDay(user, id, date, body != null ? body.getAnyShiftId() : null));
    }

    @PostMapping("/api/v1/shift-registrations/{id}/approve")
    public ResponseEntity<ShiftRegistrationDTO.RegistrationResponse> approve(
        @AuthenticationPrincipal User user, @PathVariable Long id,
        @RequestBody(required = false) ShiftRegistrationDTO.ApproveOneRequest body) {
        requirePermission(user, "SHIFT_VIEW", "SHIFT_REGISTRATION_MANAGE");
        return ResponseEntity.ok(service.approve(user, id, body));
    }

    @PostMapping("/api/v1/shift-registrations/{id}/reject")
    public ResponseEntity<ShiftRegistrationDTO.RegistrationResponse> reject(@AuthenticationPrincipal User user, @PathVariable Long id) {
        requirePermission(user, "SHIFT_VIEW", "SHIFT_REGISTRATION_MANAGE");
        return ResponseEntity.ok(service.reject(user, id));
    }

    @GetMapping("/api/v1/shift-registrations/self/rounds")
    public ResponseEntity<List<ShiftRegistrationDTO.RoundResponse>> myRounds(@AuthenticationPrincipal User user) {
        requirePermission(user, "SHIFT_REGISTRATION_SELF");
        return ResponseEntity.ok(service.myRounds(user));
    }

    @GetMapping("/api/v1/shift-registrations/self/rounds/{id}")
    public ResponseEntity<ShiftRegistrationDTO.SelfRoundResponse> myRound(@AuthenticationPrincipal User user, @PathVariable Long id) {
        requirePermission(user, "SHIFT_REGISTRATION_SELF");
        return ResponseEntity.ok(service.myRound(user, id));
    }

    @PutMapping("/api/v1/shift-registrations/self/rounds/{id}")
    public ResponseEntity<ShiftRegistrationDTO.SelfRoundResponse> saveMine(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                                          @Valid @RequestBody ShiftRegistrationDTO.SelfSaveRequest req) {
        requirePermission(user, "SHIFT_REGISTRATION_SELF");
        return ResponseEntity.ok(service.saveMine(user, id, req));
    }

    /** Cần đủ mọi quyền liệt kê. Quản lý đăng ký cần cả SHIFT_VIEW (quyền tiên quyết, phạm vi phòng ban lấy theo nó). */
    private static void requirePermission(User user, String... perms) {
        for (String p : perms) {
            if (user == null || !user.hasPermission(p)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
            }
        }
    }
}
