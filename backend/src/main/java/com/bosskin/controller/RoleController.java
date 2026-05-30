package com.bosskin.controller;

import com.bosskin.entity.Permission;
import com.bosskin.entity.Role;
import com.bosskin.entity.User;
import com.bosskin.repository.PermissionRepository;
import com.bosskin.repository.RolePermDeptScopeRepository;
import com.bosskin.service.DeptScopeService;
import com.bosskin.service.PermissionConsistencyService;
import com.bosskin.service.RoleService;
import org.springframework.transaction.annotation.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Set;

@RestController
@RequestMapping("/api/v1/roles")
@RequiredArgsConstructor
public class RoleController {

    private final RoleService roleService;
    private final PermissionRepository permissionRepository;
    private final RolePermDeptScopeRepository rolePermDeptScopeRepo;
    private final PermissionConsistencyService permissionConsistencyService;
    private final DeptScopeService deptScopeService;

    @GetMapping
    public ResponseEntity<List<Role>> getAll(@AuthenticationPrincipal User user) {
        requirePermission(user, "ROLE_VIEW");
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "ROLE_VIEW");
        List<Role> roles = roleService.findByCompany(user.getCompany().getId());
        if (!scope.isEmpty()) {
            roles = roles.stream()
                .filter(r -> r.isRoleViewAllCompany()
                    || (r.getRoleViewDepartment() != null && scope.contains(r.getRoleViewDepartment().getId())))
                .toList();
        }
        return ResponseEntity.ok(roles);
    }

    @GetMapping("/permissions")
    @Transactional
    public ResponseEntity<List<Permission>> getAllPermissions() {
        ensurePermission("DASHBOARD_VIEW", "Hiển thị mục Tổng quan trên menu", "DASHBOARD");
        ensurePermission("SHIFT_VIEW", "Xem ca làm", "SHIFT");
        ensurePermission("SHIFT_MANAGE", "Quản lý ca làm", "SHIFT");
        return ResponseEntity.ok(permissionRepository.findAll());
    }

    @GetMapping("/{id}/dept-scopes")
    public ResponseEntity<Map<String, Set<Long>>> getDeptScopes(
        @PathVariable Long id,
        @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "ROLE_MANAGE");
        return ResponseEntity.ok(rolePermDeptScopeRepo.findScopesMap(id));
    }

    @PostMapping
    public ResponseEntity<Role> create(
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(user, "ROLE_MANAGE");
        String name = (String) body.get("name");
        String desc = (String) body.get("description");
        @SuppressWarnings("unchecked")
        List<String> codes = (List<String>) body.get("permissions");
        Boolean roleViewAllCompany = (Boolean) body.get("roleViewAllCompany");
        Number roleViewDeptIdRaw = (Number) body.get("roleViewDepartmentId");
        Long roleViewDeptId = roleViewDeptIdRaw != null ? roleViewDeptIdRaw.longValue() : null;
        Set<String> normalizedCodes = permissionConsistencyService.normalizePermissionCodes(codes);
        @SuppressWarnings("unchecked")
        Map<String, List<Integer>> rawScopes = (Map<String, List<Integer>>) body.get("deptScopes");
        Role role = roleService.create(
            user.getCompany().getId(),
            name,
            desc,
            List.copyOf(normalizedCodes),
            roleViewAllCompany,
            roleViewDeptId
        );
        if (rawScopes != null) {
            Map<String, List<Long>> scopes = new java.util.HashMap<>();
            rawScopes.forEach((k, v) -> scopes.put(k, v.stream().map(Integer::longValue).toList()));
            rolePermDeptScopeRepo.replaceAll(
                role.getId(),
                permissionConsistencyService.filterScopesByPermissionCodes(scopes, normalizedCodes)
            );
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(role);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Role> update(
        @PathVariable Long id,
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(user, "ROLE_MANAGE");
        String name = (String) body.get("name");
        String desc = (String) body.get("description");
        @SuppressWarnings("unchecked")
        List<String> codes = (List<String>) body.get("permissions");
        Boolean roleViewAllCompany = (Boolean) body.get("roleViewAllCompany");
        Number roleViewDeptIdRaw = (Number) body.get("roleViewDepartmentId");
        Long roleViewDeptId = roleViewDeptIdRaw != null ? roleViewDeptIdRaw.longValue() : null;
        Set<String> normalizedCodes = codes == null
            ? null
            : permissionConsistencyService.normalizePermissionCodes(codes);
        @SuppressWarnings("unchecked")
        Map<String, List<Integer>> rawScopes = (Map<String, List<Integer>>) body.get("deptScopes");
        Role role = roleService.update(
            id,
            user.getCompany().getId(),
            name,
            desc,
            normalizedCodes == null ? null : List.copyOf(normalizedCodes),
            roleViewAllCompany,
            roleViewDeptId
        );
        if (rawScopes != null) {
            Map<String, List<Long>> scopes = new java.util.HashMap<>();
            rawScopes.forEach((k, v) -> scopes.put(k, v.stream().map(Integer::longValue).toList()));
            Set<String> allowedCodes = normalizedCodes != null
                ? normalizedCodes
                : role.getPermissions().stream().map(Permission::getCode).collect(java.util.stream.Collectors.toSet());
            rolePermDeptScopeRepo.replaceAll(
                role.getId(),
                permissionConsistencyService.filterScopesByPermissionCodes(scopes, allowedCodes)
            );
        } else if (normalizedCodes != null) {
            Map<String, Set<Long>> currentScopes = rolePermDeptScopeRepo.findScopesMap(role.getId());
            rolePermDeptScopeRepo.replaceAll(
                role.getId(),
                permissionConsistencyService.filterScopesByPermissionCodes(currentScopes, normalizedCodes)
            );
        }
        return ResponseEntity.ok(role);
    }

    @PutMapping("/{id}/permissions")
    public ResponseEntity<Role> updatePermissions(
        @PathVariable Long id,
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, List<String>> body
    ) {
        requirePermission(user, "ROLE_MANAGE");
        Set<String> normalizedCodes = permissionConsistencyService.normalizePermissionCodes(body.get("permissions"));
        Role role = roleService.updatePermissions(id, user.getCompany().getId(), List.copyOf(normalizedCodes));
        Map<String, Set<Long>> currentScopes = rolePermDeptScopeRepo.findScopesMap(role.getId());
        rolePermDeptScopeRepo.replaceAll(
            role.getId(),
            permissionConsistencyService.filterScopesByPermissionCodes(currentScopes, normalizedCodes)
        );
        return ResponseEntity.ok(role);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id, @AuthenticationPrincipal User user) {
        requirePermission(user, "ROLE_MANAGE");
        roleService.delete(id, user.getCompany().getId());
        return ResponseEntity.noContent().build();
    }

    private void requirePermission(User user, String perm) {
        if (!user.hasPermission(perm)) {
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.FORBIDDEN, "Không có quyền: " + perm);
        }
    }

    private void ensurePermission(String code, String description, String module) {
        permissionRepository.findByCode(code).orElseGet(() ->
            permissionRepository.save(Permission.builder()
                .code(code)
                .description(description)
                .module(module)
                .build())
        );
    }
}
