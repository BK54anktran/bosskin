package com.bosskin.controller;

import com.bosskin.dto.DependentDTO;
import com.bosskin.entity.User;
import com.bosskin.service.DependentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/**
 * Bước M — người phụ thuộc (giảm trừ gia cảnh).
 * <pre>
 * GET    /api/v1/dependents?employeeId=   — EMPLOYEE_VIEW (+ phạm vi phòng ban)
 * GET    /api/v1/dependents/self          — nhân viên xem của mình
 * POST   /api/v1/dependents               — EMPLOYEE_VIEW + EMPLOYEE_UPDATE
 * PUT    /api/v1/dependents/{id}          — EMPLOYEE_VIEW + EMPLOYEE_UPDATE
 * DELETE /api/v1/dependents/{id}          — EMPLOYEE_VIEW + EMPLOYEE_UPDATE
 * </pre>
 */
@RestController
@RequestMapping("/api/v1/dependents")
@RequiredArgsConstructor
public class DependentController {

    private final DependentService service;

    @GetMapping
    public List<DependentDTO.Response> list(@AuthenticationPrincipal User user, @RequestParam Long employeeId) {
        require(user, "EMPLOYEE_VIEW");
        return service.listByEmployee(user.getCompanyId(), user.getId(), employeeId);
    }

    @GetMapping("/self")
    public List<DependentDTO.Response> self(@AuthenticationPrincipal User user) {
        if (user == null || user.getCompanyId() == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return service.listSelf(user.getId());
    }

    @PostMapping
    public ResponseEntity<DependentDTO.Response> create(@AuthenticationPrincipal User user,
                                                        @Valid @RequestBody DependentDTO.Upsert req) {
        require(user, "EMPLOYEE_VIEW", "EMPLOYEE_UPDATE");
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(user.getCompanyId(), user.getId(), req));
    }

    @PutMapping("/{id}")
    public DependentDTO.Response update(@AuthenticationPrincipal User user, @PathVariable Long id,
                                        @Valid @RequestBody DependentDTO.Upsert req) {
        require(user, "EMPLOYEE_VIEW", "EMPLOYEE_UPDATE");
        return service.update(user.getCompanyId(), user.getId(), id, req);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal User user, @PathVariable Long id) {
        require(user, "EMPLOYEE_VIEW", "EMPLOYEE_UPDATE");
        service.delete(user.getCompanyId(), user.getId(), id);
        return ResponseEntity.noContent().build();
    }

    private static void require(User user, String... perms) {
        if (user == null || user.getCompanyId() == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        for (String p : perms) {
            if (!user.hasPermission(p)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }
}
