package com.bosskin.controller;

import com.bosskin.dto.ShiftRotationDTO;
import com.bosskin.dto.ShiftSwapDTO;
import com.bosskin.entity.User;
import com.bosskin.service.ShiftRotationService;
import com.bosskin.service.ShiftSwapService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/**
 * Ca xoay vòng và đổi ca (Mốc 2b).
 * <pre>
 * GET    /api/v1/shift-rotations                     — SHIFT_VIEW
 * POST   /api/v1/shift-rotations                     — SHIFT_MANAGE
 * PUT    /api/v1/shift-rotations/{id}                — SHIFT_MANAGE
 * DELETE /api/v1/shift-rotations/{id}                — SHIFT_MANAGE
 * POST   /api/v1/shift-rotations/{id}/generate       — SHIFT_MANAGE: sinh phân ca theo mẫu
 * GET    /api/v1/shift-swaps?status=                 — người duyệt thấy cả công ty, nhân viên thấy đơn của mình
 * POST   /api/v1/shift-swaps                         — ATTENDANCE_SELF: gửi yêu cầu đổi / nhường ca
 * PUT    /api/v1/shift-swaps/{id}/approve|reject     — SHIFT_SWAP_APPROVE
 * PUT    /api/v1/shift-swaps/{id}/cancel             — người gửi
 * </pre>
 */
@RestController
@RequiredArgsConstructor
public class ShiftPlanController {

    private final ShiftRotationService rotationService;
    private final ShiftSwapService swapService;

    // ── Rotations ────────────────────────────────────────────────────────────

    @GetMapping("/api/v1/shift-rotations")
    public ResponseEntity<List<ShiftRotationDTO.Response>> rotations(@AuthenticationPrincipal User user) {
        requireAny(user, "SHIFT_VIEW", "SHIFT_MANAGE");
        return ResponseEntity.ok(rotationService.list(user.getCompany().getId()));
    }

    @PostMapping("/api/v1/shift-rotations")
    public ResponseEntity<ShiftRotationDTO.Response> createRotation(@AuthenticationPrincipal User user,
                                                                    @Valid @RequestBody ShiftRotationDTO.Upsert req) {
        requireAny(user, "SHIFT_MANAGE");
        return ResponseEntity.ok(rotationService.create(user.getCompany().getId(), req));
    }

    @PutMapping("/api/v1/shift-rotations/{id}")
    public ResponseEntity<ShiftRotationDTO.Response> updateRotation(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                                    @Valid @RequestBody ShiftRotationDTO.Upsert req) {
        requireAny(user, "SHIFT_MANAGE");
        return ResponseEntity.ok(rotationService.update(user.getCompany().getId(), id, req));
    }

    @DeleteMapping("/api/v1/shift-rotations/{id}")
    public ResponseEntity<Void> deleteRotation(@AuthenticationPrincipal User user, @PathVariable Long id) {
        requireAny(user, "SHIFT_MANAGE");
        rotationService.delete(user.getCompany().getId(), id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/api/v1/shift-rotations/{id}/generate")
    public ResponseEntity<ShiftRotationDTO.GenerateResult> generate(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                                    @Valid @RequestBody ShiftRotationDTO.GenerateRequest req) {
        requireAny(user, "SHIFT_MANAGE");
        return ResponseEntity.ok(rotationService.generate(user.getCompany().getId(), id, req, user.getId()));
    }

    // ── Swaps ────────────────────────────────────────────────────────────────

    @GetMapping("/api/v1/shift-swaps")
    public ResponseEntity<List<ShiftSwapDTO.Response>> swaps(@AuthenticationPrincipal User user,
                                                             @RequestParam(required = false) String status) {
        requireAny(user, "ATTENDANCE_SELF", "SHIFT_SWAP_APPROVE");
        return ResponseEntity.ok(swapService.list(user, status));
    }

    @GetMapping("/api/v1/shift-swaps/my-shifts")
    public ResponseEntity<List<ShiftSwapDTO.ShiftOption>> myShifts(@AuthenticationPrincipal User user) {
        requireAny(user, "ATTENDANCE_SELF");
        return ResponseEntity.ok(swapService.myUpcoming(user));
    }

    @GetMapping("/api/v1/shift-swaps/colleagues")
    public ResponseEntity<List<ShiftSwapDTO.Colleague>> colleagues(@AuthenticationPrincipal User user,
                                                                  @RequestParam Long assignmentId) {
        requireAny(user, "ATTENDANCE_SELF");
        return ResponseEntity.ok(swapService.colleagues(user, assignmentId));
    }

    @PostMapping("/api/v1/shift-swaps")
    public ResponseEntity<ShiftSwapDTO.Response> createSwap(@AuthenticationPrincipal User user,
                                                            @Valid @RequestBody ShiftSwapDTO.CreateRequest req) {
        requireAny(user, "ATTENDANCE_SELF");
        return ResponseEntity.ok(swapService.create(user, req));
    }

    @PutMapping("/api/v1/shift-swaps/{id}/approve")
    public ResponseEntity<ShiftSwapDTO.Response> approveSwap(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                             @RequestBody(required = false) ShiftSwapDTO.ProcessRequest body) {
        return ResponseEntity.ok(swapService.approve(user, id, body != null ? body.getAdminNote() : null));
    }

    @PutMapping("/api/v1/shift-swaps/{id}/reject")
    public ResponseEntity<ShiftSwapDTO.Response> rejectSwap(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                            @RequestBody(required = false) ShiftSwapDTO.ProcessRequest body) {
        return ResponseEntity.ok(swapService.reject(user, id, body != null ? body.getAdminNote() : null));
    }

    @PutMapping("/api/v1/shift-swaps/{id}/cancel")
    public ResponseEntity<ShiftSwapDTO.Response> cancelSwap(@AuthenticationPrincipal User user, @PathVariable Long id) {
        return ResponseEntity.ok(swapService.cancel(user, id));
    }

    private static void requireAny(User user, String... perms) {
        if (user != null) for (String p : perms) if (user.hasPermission(p)) return;
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }
}
