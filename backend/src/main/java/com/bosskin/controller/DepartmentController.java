package com.bosskin.controller;

import com.bosskin.dto.DepartmentDTO;
import com.bosskin.entity.User;
import com.bosskin.service.DepartmentService;
import com.bosskin.service.DeptScopeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Set;

@RestController
@RequestMapping("/api/v1/departments")
@RequiredArgsConstructor
public class DepartmentController {

    private final DepartmentService departmentService;
    private final DeptScopeService  deptScopeService;

    @GetMapping
    public ResponseEntity<List<DepartmentDTO.Response>> getTree(@AuthenticationPrincipal User user) {
        requirePermission(user, "DEPARTMENT_VIEW");
        return ResponseEntity.ok(departmentService.getTree(user.getCompany().getId(), user.getId()));
    }

    @GetMapping("/flat")
    public ResponseEntity<List<DepartmentDTO.FlatItem>> getFlat(
            @AuthenticationPrincipal User user,
            @RequestParam(defaultValue = "DEPARTMENT_VIEW") String permission) {
        requirePermission(user, "DEPARTMENT_VIEW");
        return ResponseEntity.ok(departmentService.getFlat(user.getCompany().getId(), user.getId(), permission));
    }

    @PostMapping
    public ResponseEntity<DepartmentDTO.Response> create(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody DepartmentDTO.CreateRequest req) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "DEPARTMENT_VIEW");
        if (!scope.isEmpty()) {
            if (req.getParentId() == null)
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Chỉ được tạo phòng ban con trong phạm vi được phép");
            if (!scope.contains(req.getParentId()))
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Phòng ban cha không nằm trong phạm vi được phép");
        }
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(departmentService.create(user.getCompany().getId(), req));
    }

    @PutMapping("/{id}")
    public ResponseEntity<DepartmentDTO.Response> update(
            @AuthenticationPrincipal User user,
            @PathVariable Long id,
            @Valid @RequestBody DepartmentDTO.CreateRequest req) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        requireViewScope(user, id);
        return ResponseEntity.ok(departmentService.update(user.getCompany().getId(), id, req));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        requireViewScope(user, id);
        departmentService.delete(user.getCompany().getId(), id);
        return ResponseEntity.noContent().build();
    }

    private void requirePermission(User user, String perm) {
        if (!user.hasPermission(perm))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền: " + perm);
    }

    private void requireViewScope(User user, Long deptId) {
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "DEPARTMENT_VIEW");
        if (!scope.isEmpty() && !scope.contains(deptId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền thao tác phòng ban này");
    }
}
