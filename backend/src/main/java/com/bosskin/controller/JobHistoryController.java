package com.bosskin.controller;

import com.bosskin.dto.JobHistoryDTO;
import com.bosskin.entity.User;
import com.bosskin.service.JobHistoryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/**
 * Bước K — quá trình công tác và sơ đồ tổ chức.
 * <pre>
 * GET    /api/v1/employees/{id}/job-histories         — EMPLOYEE_VIEW (+ phạm vi phòng ban)
 * POST   /api/v1/employees/{id}/job-histories         — EMPLOYEE_VIEW + EMPLOYEE_UPDATE
 * DELETE /api/v1/employees/job-histories/{historyId}  — EMPLOYEE_VIEW + EMPLOYEE_UPDATE (chỉ mốc chưa tới ngày)
 * GET    /api/v1/org-chart                            — EMPLOYEE_VIEW (lọc theo phạm vi)
 * </pre>
 */
@RestController
@RequiredArgsConstructor
public class JobHistoryController {

    private final JobHistoryService service;

    @GetMapping("/api/v1/employees/{id}/job-histories")
    public ResponseEntity<List<JobHistoryDTO.Response>> list(@AuthenticationPrincipal User user, @PathVariable Long id) {
        require(user, "EMPLOYEE_VIEW");
        return ResponseEntity.ok(service.list(user.getCompanyId(), user.getId(), id));
    }

    @PostMapping("/api/v1/employees/{id}/job-histories")
    public ResponseEntity<JobHistoryDTO.Response> create(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                         @Valid @RequestBody JobHistoryDTO.Upsert req) {
        require(user, "EMPLOYEE_VIEW");
        require(user, "EMPLOYEE_UPDATE");
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(user.getCompanyId(), user, id, req));
    }

    @DeleteMapping("/api/v1/employees/job-histories/{historyId}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal User user, @PathVariable Long historyId) {
        require(user, "EMPLOYEE_VIEW");
        require(user, "EMPLOYEE_UPDATE");
        service.delete(user.getCompanyId(), user, historyId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/v1/org-chart")
    public ResponseEntity<List<JobHistoryDTO.OrgNode>> orgChart(@AuthenticationPrincipal User user) {
        require(user, "EMPLOYEE_VIEW");
        return ResponseEntity.ok(service.orgChart(user.getCompanyId(), user.getId()));
    }

    private static void require(User user, String perm) {
        if (user == null || user.getCompanyId() == null || !user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }
}
