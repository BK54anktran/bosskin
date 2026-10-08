package com.bosskin.controller;

import com.bosskin.dto.LeaveDTO;
import com.bosskin.entity.User;
import com.bosskin.service.LeaveService;
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
import java.util.Map;

@RestController
@RequestMapping("/api/v1/leaves")
@RequiredArgsConstructor
public class LeaveController {

    private final LeaveService leaveService;

    @GetMapping("/types")
    public ResponseEntity<List<LeaveDTO.LeaveTypeResponse>> getTypes(@AuthenticationPrincipal User user) {
        requirePermission(user, "LEAVE_VIEW");
        return ResponseEntity.ok(leaveService.getTypes(user.getCompanyId()));
    }

    @PostMapping("/types")
    public ResponseEntity<LeaveDTO.LeaveTypeResponse> createType(
        @AuthenticationPrincipal User user,
        @Valid @RequestBody LeaveDTO.LeaveTypeUpsert body
    ) {
        requirePermission(user, "LEAVE_TYPE_MANAGE");
        return ResponseEntity.status(HttpStatus.CREATED).body(leaveService.createType(user.getCompanyId(), body));
    }

    @PutMapping("/types/{id}")
    public ResponseEntity<LeaveDTO.LeaveTypeResponse> updateType(
        @AuthenticationPrincipal User user,
        @PathVariable Long id,
        @Valid @RequestBody LeaveDTO.LeaveTypeUpsert body
    ) {
        requirePermission(user, "LEAVE_TYPE_MANAGE");
        return ResponseEntity.ok(leaveService.updateType(user.getCompanyId(), id, body));
    }

    @DeleteMapping("/types/{id}")
    public ResponseEntity<Void> deleteType(
        @AuthenticationPrincipal User user,
        @PathVariable Long id
    ) {
        requirePermission(user, "LEAVE_TYPE_MANAGE");
        leaveService.deleteType(user.getCompanyId(), id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/requests")
    public ResponseEntity<List<LeaveDTO.LeaveRequestResponse>> getRequests(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) String status,
        @RequestParam(required = false) Long departmentId
    ) {
        requirePermission(user, "LEAVE_VIEW");
        return ResponseEntity.ok(leaveService.getRequests(user, status, departmentId));
    }

    /** Danh sách đơn có phân trang + tìm kiếm phía server (F9). */
    @GetMapping("/requests/page")
    public ResponseEntity<com.bosskin.dto.PageResponse<LeaveDTO.LeaveRequestResponse>> searchRequests(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) String status,
        @RequestParam(required = false) Long departmentId,
        @RequestParam(required = false) String q,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        requirePermission(user, "LEAVE_VIEW");
        return ResponseEntity.ok(leaveService.searchRequests(user, status, departmentId, q, page, size));
    }

    @PostMapping("/requests")
    public ResponseEntity<LeaveDTO.LeaveRequestResponse> createRequest(
        @AuthenticationPrincipal User user,
        @Valid @RequestBody LeaveDTO.CreateLeaveRequest body
    ) {
        requirePermission(user, "LEAVE_REQUEST_CREATE");
        return ResponseEntity.status(HttpStatus.CREATED).body(leaveService.createRequest(user, body));
    }

    @PutMapping("/requests/{id}/approve")
    public ResponseEntity<LeaveDTO.LeaveRequestResponse> approve(
        @AuthenticationPrincipal User user,
        @PathVariable Long id,
        @RequestBody(required = false) LeaveDTO.ProcessLeaveRequest body
    ) {
        requirePermission(user, "LEAVE_REQUEST_APPROVE");
        return ResponseEntity.ok(leaveService.approveRequest(id, user, body));
    }

    @PutMapping("/requests/{id}/reject")
    public ResponseEntity<LeaveDTO.LeaveRequestResponse> reject(
        @AuthenticationPrincipal User user,
        @PathVariable Long id,
        @RequestBody(required = false) LeaveDTO.ProcessLeaveRequest body
    ) {
        requirePermission(user, "LEAVE_REQUEST_APPROVE");
        return ResponseEntity.ok(leaveService.rejectRequest(id, user, body));
    }

    @PostMapping("/requests/{id}/cancel")
    public ResponseEntity<LeaveDTO.LeaveRequestResponse> cancel(
        @AuthenticationPrincipal User user,
        @PathVariable Long id
    ) {
        requirePermission(user, "LEAVE_VIEW");
        return ResponseEntity.ok(leaveService.cancelRequest(id, user));
    }

    @PutMapping("/requests/{id}/applied")
    public ResponseEntity<LeaveDTO.LeaveRequestResponse> updateApplied(
        @AuthenticationPrincipal User user,
        @PathVariable Long id,
        @RequestBody LeaveDTO.UpdateAppliedRequest body
    ) {
        requirePermission(user, "LEAVE_REQUEST_APPROVE");
        return ResponseEntity.ok(leaveService.updateApplied(id, user, body.isApplied()));
    }

    /** L13 — sổ trừ/hoàn phép theo từng đơn của một nhân viên. */
    @GetMapping("/ledger")
    public ResponseEntity<List<LeaveDTO.LedgerEntryResponse>> getLedger(
        @AuthenticationPrincipal User user,
        @RequestParam Long employeeId
    ) {
        return ResponseEntity.ok(leaveService.getLedger(user, employeeId));
    }

    @GetMapping("/grants")
    public ResponseEntity<List<LeaveDTO.LeaveGrantResponse>> getGrants(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) Long employeeId,
        @RequestParam(required = false) Long leaveTypeId,
        @RequestParam(required = false) Long departmentId
    ) {
        requirePermission(user, "LEAVE_VIEW");
        return ResponseEntity.ok(leaveService.getGrants(user, employeeId, leaveTypeId, departmentId));
    }

    @PostMapping("/grants/manual")
    public ResponseEntity<LeaveDTO.LeaveGrantResponse> manualGrant(
        @AuthenticationPrincipal User user,
        @Valid @RequestBody LeaveDTO.ManualGrantRequest body
    ) {
        requirePermission(user, "LEAVE_GRANT_MANUAL");
        return ResponseEntity.status(HttpStatus.CREATED).body(leaveService.createManualGrant(user, body));
    }

    @GetMapping("/accrual-rules")
    public ResponseEntity<List<LeaveDTO.LeaveAccrualRuleResponse>> getAccrualRules(@AuthenticationPrincipal User user) {
        requirePermission(user, "LEAVE_VIEW");
        return ResponseEntity.ok(leaveService.getAccrualRules(user.getCompanyId()));
    }

    @PostMapping("/accrual-rules")
    public ResponseEntity<LeaveDTO.LeaveAccrualRuleResponse> createAccrualRule(
        @AuthenticationPrincipal User user,
        @Valid @RequestBody LeaveDTO.LeaveAccrualRuleUpsert body
    ) {
        requirePermission(user, "LEAVE_ACCRUAL_MANAGE");
        return ResponseEntity.status(HttpStatus.CREATED).body(leaveService.createAccrualRule(user.getCompanyId(), body));
    }

    @PutMapping("/accrual-rules/{id}")
    public ResponseEntity<LeaveDTO.LeaveAccrualRuleResponse> updateAccrualRule(
        @AuthenticationPrincipal User user,
        @PathVariable Long id,
        @Valid @RequestBody LeaveDTO.LeaveAccrualRuleUpsert body
    ) {
        requirePermission(user, "LEAVE_ACCRUAL_MANAGE");
        return ResponseEntity.ok(leaveService.updateAccrualRule(user.getCompanyId(), id, body));
    }

    @DeleteMapping("/accrual-rules/{id}")
    public ResponseEntity<Void> deleteAccrualRule(
        @AuthenticationPrincipal User user,
        @PathVariable Long id
    ) {
        requirePermission(user, "LEAVE_ACCRUAL_MANAGE");
        leaveService.deleteAccrualRule(user.getCompanyId(), id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/accrual-rules/run")
    public ResponseEntity<Map<String, Integer>> runAccrual(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        requirePermission(user, "LEAVE_ACCRUAL_MANAGE");
        return ResponseEntity.ok(leaveService.runAccrual(user, date));
    }

    @GetMapping("/settings")
    public ResponseEntity<LeaveDTO.LeaveSettingResponse> getSetting(@AuthenticationPrincipal User user) {
        requirePermission(user, "LEAVE_VIEW");
        return ResponseEntity.ok(leaveService.getSetting(user.getCompanyId()));
    }

    @PutMapping("/settings")
    public ResponseEntity<LeaveDTO.LeaveSettingResponse> updateSetting(
        @AuthenticationPrincipal User user,
        @Valid @RequestBody LeaveDTO.LeaveSettingUpsert body
    ) {
        requirePermission(user, "LEAVE_ACCRUAL_MANAGE");
        return ResponseEntity.ok(leaveService.updateSetting(user.getCompanyId(), body));
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }
}
