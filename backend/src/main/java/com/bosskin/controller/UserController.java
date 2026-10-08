package com.bosskin.controller;

import com.bosskin.dto.UserDTO;
import com.bosskin.entity.Employee;
import com.bosskin.entity.Permission;
import com.bosskin.entity.Role;
import com.bosskin.entity.User;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.PermissionRepository;
import com.bosskin.repository.RoleRepository;
import com.bosskin.repository.UserPermDeptScopeRepository;
import com.bosskin.repository.UserRepository;
import com.bosskin.service.DeptScopeService;
import com.bosskin.service.EmployeeService;
import com.bosskin.service.PermissionConsistencyService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PermissionRepository permissionRepository;
    private final EmployeeRepository employeeRepository;
    private final UserPermDeptScopeRepository deptScopeRepo;
    private final EmployeeService employeeService;
    private final PermissionConsistencyService permissionConsistencyService;
    private final DeptScopeService deptScopeService;
    private final PasswordEncoder passwordEncoder;
    private final com.bosskin.repository.UserSessionRepository userSessionRepository;

    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> listUsers(@AuthenticationPrincipal User caller) {
        requirePermission(caller, "USER_MANAGE");
        Set<Long> manageScope = deptScopeService.resolvedScopes(caller.getId(), "USER_MANAGE");
        Long selfEmployeeId = caller.getEmployee() != null ? caller.getEmployee().getId() : null;
        List<User> users = userRepository.findByCompanyId(caller.getCompany().getId());
        List<Map<String, Object>> result = users.stream()
            .filter(u -> canManageTarget(caller, u, manageScope, selfEmployeeId))
            .map(this::toUserMap)
            .toList();
        return ResponseEntity.ok(result);
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> createUser(
        @AuthenticationPrincipal User caller,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(caller, "USER_MANAGE");
        String email    = (String) body.get("email");
        String password = (String) body.get("password");
        if (email == null || password == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "email và password là bắt buộc");
        }
        if (userRepository.existsByEmail(email)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email đã được sử dụng");
        }
        @SuppressWarnings("unchecked")
        List<Integer> roleIds = (List<Integer>) body.getOrDefault("roleIds", Collections.emptyList());
        Set<Role> roles = resolveRoles(roleIds, caller.getCompany().getId());

        Employee employee = null;
        Object empIdObj = body.get("employeeId");
        if (empIdObj != null) {
            Long empId = ((Number) empIdObj).longValue();
            employee = employeeRepository.findByIdAndCompanyId(empId, caller.getCompany().getId()).orElse(null);
            if (employee == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found");
        }
        Set<Long> manageScope = deptScopeService.resolvedScopes(caller.getId(), "USER_MANAGE");
        if (!canManageTarget(caller, employee, manageScope)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền thao tác người dùng phòng ban này");
        }

        User user = User.builder()
            .email(email)
            .password(passwordEncoder.encode(password))
            .company(caller.getCompany())
            .roles(roles)
            .employee(employee)
            .enabled(true)
            .build();
        User saved = userRepository.save(user);
        return ResponseEntity.status(HttpStatus.CREATED).body(toUserMap(saved));
    }

    @PostMapping("/sync-from-employees")
    public ResponseEntity<UserDTO.SyncEmployeesResponse> syncFromEmployees(
        @AuthenticationPrincipal User caller,
        @RequestBody UserDTO.SyncEmployeesRequest body
    ) {
        requirePermission(caller, "USER_MANAGE");
        Set<Long> manageScope = deptScopeService.resolvedScopes(caller.getId(), "USER_MANAGE");
        if (!manageScope.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Đồng bộ hàng loạt chỉ cho phép khi USER_MANAGE ở phạm vi toàn công ty");
        }
        return ResponseEntity.ok(
            employeeService.syncMissingUserAccounts(caller.getCompany().getId(), body.getInitialPassword())
        );
    }

    @PutMapping("/{id}/roles")
    public ResponseEntity<Map<String, Object>> updateRoles(
        @PathVariable Long id,
        @AuthenticationPrincipal User caller,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(caller, "USER_MANAGE");
        User user = findUserInCompanyAndScope(id, caller);
        @SuppressWarnings("unchecked")
        List<Integer> roleIds = (List<Integer>) body.getOrDefault("roleIds", Collections.emptyList());
        user.setRoles(resolveRoles(roleIds, caller.getCompany().getId()));
        return ResponseEntity.ok(toUserMap(userRepository.save(user)));
    }

    @PutMapping("/{id}/permissions")
    public ResponseEntity<Map<String, Object>> updateDirectPermissions(
        @PathVariable Long id,
        @AuthenticationPrincipal User caller,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(caller, "USER_MANAGE");
        User user = findUserInCompanyAndScope(id, caller);
        @SuppressWarnings("unchecked")
        List<String> codes = (List<String>) body.getOrDefault("permissionCodes", Collections.emptyList());
        Set<String> normalizedCodes = permissionConsistencyService.normalizePermissionCodes(codes);
        Set<Permission> perms = new HashSet<>();
        for (String code : normalizedCodes) {
            permissionRepository.findByCode(code).ifPresent(perms::add);
        }
        user.setDirectPermissions(perms);
        User saved = userRepository.save(user);
        deptScopeRepo.pruneByPermissionCodes(saved.getId(), normalizedCodes);
        return ResponseEntity.ok(toUserMap(saved));
    }

    /** GET /users/{id}/dept-scopes → { "EMPLOYEE_VIEW": [1,2], "PAYROLL_VIEW": [] } */
    @GetMapping("/{id}/dept-scopes")
    public ResponseEntity<Map<String, Set<Long>>> getDeptScopes(
        @PathVariable Long id,
        @AuthenticationPrincipal User caller
    ) {
        requirePermission(caller, "USER_MANAGE");
        findUserInCompanyAndScope(id, caller);
        return ResponseEntity.ok(deptScopeRepo.findScopesMap(id));
    }

    /** PUT /users/{id}/dept-scopes  body: { "EMPLOYEE_VIEW": [1,2], "PAYROLL_VIEW": [1] } */
    @PutMapping("/{id}/dept-scopes")
    public ResponseEntity<Void> updateDeptScopes(
        @PathVariable Long id,
        @AuthenticationPrincipal User caller,
        @RequestBody Map<String, List<Integer>> body
    ) {
        requirePermission(caller, "USER_MANAGE");
        User targetUser = findUserInCompanyAndScope(id, caller);
        Set<String> directCodes = targetUser.getDirectPermissions().stream()
            .map(Permission::getCode)
            .collect(Collectors.toSet());
        Map<String, List<Long>> converted = new java.util.HashMap<>();
        body.forEach((perm, ids) -> converted.put(perm,
            ids.stream().map(Integer::longValue).collect(Collectors.toList())));
        deptScopeRepo.replaceAll(
            id,
            permissionConsistencyService.filterScopesByPermissionCodes(converted, directCodes)
        );
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{id}/enabled")
    public ResponseEntity<Map<String, Object>> setEnabled(
        @PathVariable Long id,
        @AuthenticationPrincipal User caller,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(caller, "USER_MANAGE");
        User user = findUserInCompanyAndScope(id, caller);
        Boolean enabled = (Boolean) body.get("enabled");
        if (enabled == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "enabled là bắt buộc");
        if (!enabled && user.getId().equals(caller.getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.user.cannot_disable_self");
        }
        user.setEnabled(enabled);
        User saved = userRepository.save(user);
        if (!enabled) userSessionRepository.revokeAllByUserId(saved.getId());
        return ResponseEntity.ok(toUserMap(saved));
    }

    private User findUserInCompanyAndScope(Long userId, User caller) {
        User user = findUserInCompany(userId, caller.getCompany().getId());
        Set<Long> manageScope = deptScopeService.resolvedScopes(caller.getId(), "USER_MANAGE");
        Long selfEmployeeId = caller.getEmployee() != null ? caller.getEmployee().getId() : null;
        if (!canManageTarget(caller, user, manageScope, selfEmployeeId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền thao tác người dùng phòng ban này");
        }
        return user;
    }

    private boolean canManageTarget(User caller, Employee targetEmployee, Set<Long> scope) {
        Long selfEmployeeId = caller.getEmployee() != null ? caller.getEmployee().getId() : null;
        if (scope == null || scope.isEmpty()) return true;
        if (scope.contains(DeptScopeService.SCOPE_SELF_ONLY)) {
            return targetEmployee != null
                && selfEmployeeId != null
                && selfEmployeeId.equals(targetEmployee.getId());
        }
        return targetEmployee != null
            && targetEmployee.getDepartment() != null
            && scope.contains(targetEmployee.getDepartment().getId());
    }

    private boolean canManageTarget(User caller, User targetUser, Set<Long> scope, Long selfEmployeeId) {
        if (scope == null || scope.isEmpty()) return true;
        if (scope.contains(DeptScopeService.SCOPE_SELF_ONLY)) {
            return targetUser.getEmployee() != null
                && selfEmployeeId != null
                && selfEmployeeId.equals(targetUser.getEmployee().getId());
        }
        return targetUser.getEmployee() != null
            && targetUser.getEmployee().getDepartment() != null
            && scope.contains(targetUser.getEmployee().getDepartment().getId());
    }

    private User findUserInCompany(Long userId, Long companyId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Người dùng không tồn tại"));
        if (!user.getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền thao tác với người dùng này");
        }
        return user;
    }

    private Set<Role> resolveRoles(List<Integer> roleIds, Long companyId) {
        if (roleIds == null || roleIds.isEmpty()) return new HashSet<>();
        Set<Role> roles = new HashSet<>();
        for (Integer rid : roleIds) {
            Role role = roleRepository.findById(rid.longValue())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Vai trò không hợp lệ: " + rid));
            if (!role.getCompany().getId().equals(companyId)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Vai trò không thuộc công ty này");
            }
            roles.add(role);
        }
        return roles;
    }

    private Map<String, Object> toUserMap(User user) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", user.getId());
        map.put("email", user.getEmail());
        String fullName = user.getEmployee() != null ? user.getEmployee().getFullName() : null;
        map.put("fullName", fullName);
        String avatar = user.getEmployee() != null ? user.getEmployee().getAvatar() : null;
        map.put("avatar", avatar);
        Long departmentId = user.getEmployee() != null && user.getEmployee().getDepartment() != null
            ? user.getEmployee().getDepartment().getId() : null;
        map.put("departmentId", departmentId);
        map.put("enabled", user.isEnabled());
        List<Map<String, Object>> roleList = user.getRoles().stream()
            .map(r -> {
                Map<String, Object> rm = new LinkedHashMap<>();
                rm.put("id", r.getId());
                rm.put("name", r.getName());
                return rm;
            })
            .collect(Collectors.toList());
        map.put("roles", roleList);
        List<String> directPerms = user.getDirectPermissions().stream()
            .map(Permission::getCode)
            .collect(Collectors.toList());
        map.put("directPermissions", directPerms);
        map.put("deptScopes", deptScopeRepo.findScopesMap(user.getId()));
        return map;
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }
}
