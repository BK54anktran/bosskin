package com.bosskin.controller;

import com.bosskin.dto.TeamApprovalDTO;
import com.bosskin.entity.User;
import com.bosskin.service.TeamApprovalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * Bước K — quản lý trực tiếp duyệt đơn của cấp dưới.
 * <pre>
 * GET  /api/v1/team-approvals                       — đơn chờ quản lý (rỗng nếu không có cấp dưới / chế độ tắt)
 * GET  /api/v1/team-approvals/count                 — số đơn chờ (badge menu)
 * POST /api/v1/team-approvals/{kind}/{id}/approve   — kind = LEAVE | ATTENDANCE | SWAP
 * POST /api/v1/team-approvals/{kind}/{id}/reject
 * </pre>
 * Quyền: là quản lý trực tiếp của người gửi đơn (kiểm ở ManagerApprovalService.requireManagerCanProcess).
 */
@RestController
@RequestMapping("/api/v1/team-approvals")
@RequiredArgsConstructor
public class TeamApprovalController {

    private final TeamApprovalService service;

    @GetMapping
    public ResponseEntity<TeamApprovalDTO.Response> list(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(service.list(user));
    }

    @GetMapping("/count")
    public ResponseEntity<TeamApprovalDTO.Count> count(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(service.count(user));
    }

    @PostMapping("/{kind}/{id}/approve")
    public ResponseEntity<Object> approve(@AuthenticationPrincipal User user, @PathVariable String kind,
                                          @PathVariable Long id, @Valid @RequestBody(required = false) TeamApprovalDTO.ProcessRequest body) {
        return ResponseEntity.ok(service.process(user, kind, id, true, body != null ? body.getNote() : null));
    }

    @PostMapping("/{kind}/{id}/reject")
    public ResponseEntity<Object> reject(@AuthenticationPrincipal User user, @PathVariable String kind,
                                         @PathVariable Long id, @Valid @RequestBody(required = false) TeamApprovalDTO.ProcessRequest body) {
        return ResponseEntity.ok(service.process(user, kind, id, false, body != null ? body.getNote() : null));
    }
}
