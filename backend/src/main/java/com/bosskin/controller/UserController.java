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
    private final com.bosskin.service.GrantGuard grantGuard;
    private final com.bosskin.service.AccountGuard accountGuard;
    private final com.bosskin.repository.UserSessionRepository userSessionRepository;
    private final com.bosskin.audit.AuditService audit;
    private final com.bosskin.util.ExcelI18n excelI18n;
    private final com.bosskin.repository.CompanyRepository companyRepository;

    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> listUsers(@AuthenticationPrincipal User caller) {
        requirePermission(caller, "USER_MANAGE");
        Set<Long> manageScope = deptScopeService.resolvedScopes(caller.getId(), "USER_MANAGE");
        Long selfEmployeeId = caller.getEmployee() != null ? caller.getEmployee().getId() : null;
        List<User> users = userRepository.findForListing(caller.getCompany().getId()).stream()
            .filter(u -> canManageTarget(caller, u, manageScope, selfEmployeeId))
            .toList();
        Map<Long, Map<String, Set<Long>>> scopes = deptScopeRepo.findScopesMaps(users.stream().map(User::getId).toList());
        List<Map<String, Object>> result = users.stream()
            .map(u -> toUserMap(u, scopes.getOrDefault(u.getId(), Map.of())))
            .toList();
        return ResponseEntity.ok(result);
    }

    /**
     * D9 — quản trị đặt lại mật khẩu cho một tài khoản: sinh mật khẩu tạm (chỉ trả về một lần),
     * bắt đổi ở lần đăng nhập tới, thu hồi mọi phiên đang mở.
     */
    @PostMapping("/{id}/reset-password")
    public ResponseEntity<Map<String, String>> resetPassword(@PathVariable Long id, @AuthenticationPrincipal User caller) {
        requirePermission(caller, "USER_MANAGE");
        return resetPasswordOf(findUserInCompanyAndScope(id, caller), caller);
    }

    /** Như /{id}/reset-password nhưng tìm tài khoản theo nhân viên (nút 🔑 ở màn Nhân viên). */
    @PostMapping("/by-employee/{employeeId}/reset-password")
    public ResponseEntity<Map<String, String>> resetPasswordByEmployee(@PathVariable Long employeeId,
                                                                       @AuthenticationPrincipal User caller) {
        requirePermission(caller, "USER_MANAGE");
        User user = userRepository.findByEmployeeId(employeeId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.no_account"));
        return resetPasswordOf(findUserInCompanyAndScope(user.getId(), caller), caller);
    }

    private ResponseEntity<Map<String, String>> resetPasswordOf(User user, User caller) {
        if (user.getId().equals(caller.getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.user.cannot_reset_self");
        }
        accountGuard.requireNotFirstAdmin(caller, user);
        String pw = issueTemporaryPassword(user);
        audit.log("USER_RESET_PASSWORD").entity("USER", user.getId()).summary(user.getEmail()).save();
        return ResponseEntity.ok(Map.of("password", pw));
    }

    /**
     * D9 — cấp mật khẩu tạm mới cho mọi tài khoản trong phạm vi còn đang chờ đổi mật khẩu lần đầu
     * (vd. vừa nhập từ Excel), trả về file Excel để phát cho nhân viên. Mật khẩu tạm cấp trước đó hết hiệu lực.
     */
    @PostMapping("/initial-passwords")
    public ResponseEntity<byte[]> issueInitialPasswords(@AuthenticationPrincipal User caller, Locale locale) throws java.io.IOException {
        requirePermission(caller, "USER_MANAGE");
        Set<Long> manageScope = deptScopeService.resolvedScopes(caller.getId(), "USER_MANAGE");
        Long selfEmployeeId = caller.getEmployee() != null ? caller.getEmployee().getId() : null;
        List<User> targets = userRepository.findForListing(caller.getCompany().getId()).stream()
            .filter(u -> u.isEnabled() && u.isMustChangePassword() && !u.getId().equals(caller.getId()))
            .filter(u -> canManageTarget(caller, u, manageScope, selfEmployeeId))
            .sorted(Comparator.comparing((User u) -> u.getEmployee() == null ? "" : u.getEmployee().getEmployeeCode()))
            .toList();
        if (targets.isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.user.no_pending_accounts");

        String[] cols = {"employeeCode", "fullName", "department", "email", "password"};
        try (org.apache.poi.ss.usermodel.Workbook wb = new org.apache.poi.xssf.usermodel.XSSFWorkbook();
             java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream()) {
            var sh = wb.createSheet(excelI18n.resolve("excel.initialPasswords.sheet", locale));
            var head = wb.createCellStyle();
            var bold = wb.createFont(); bold.setBold(true); head.setFont(bold);
            var h = sh.createRow(0);
            for (int i = 0; i < cols.length; i++) {
                var c = h.createCell(i);
                c.setCellValue(excelI18n.resolve("excel.initialPasswords.col." + cols[i], locale));
                c.setCellStyle(head);
            }
            int r = 1;
            for (User u : targets) {
                String pw = issueTemporaryPassword(u);
                Employee e = u.getEmployee();
                var row = sh.createRow(r++);
                String[] v = {e == null ? "" : e.getEmployeeCode(), e == null ? "" : e.getFullName(),
                    e == null || e.getDepartment() == null ? "" : e.getDepartment().getName(), u.getEmail(), pw};
                for (int i = 0; i < v.length; i++) row.createCell(i).setCellValue(v[i] == null ? "" : v[i]);
            }
            for (int i = 0; i < cols.length; i++) sh.autoSizeColumn(i);
            sh.createFreezePane(0, 1);
            wb.write(out);
            audit.log("USER_ISSUE_INITIAL_PASSWORDS").entity("COMPANY", caller.getCompany().getId())
                .summary(String.valueOf(targets.size())).save();
            return com.bosskin.util.ExcelUtils.buildFileResponse("initial-passwords", out.toByteArray());
        }
    }

    private String issueTemporaryPassword(User user) {
        String pw = com.bosskin.core.PasswordPolicy.generate(10);
        user.setPassword(passwordEncoder.encode(pw));
        user.setMustChangePassword(true);
        userRepository.save(user);
        userSessionRepository.revokeAllByUserId(user.getId());
        return pw;
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> createUser(
        @AuthenticationPrincipal User caller,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(caller, "USER_MANAGE");
        String email    = (String) body.get("email");
        String password = (String) body.get("password");
        if (password != null) com.bosskin.core.PasswordPolicy.require(password);
        if (email == null || password == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.user.email_password_required");
        }
        // V22: tài khoản mới phải theo đuôi email công ty
        // (công ty của principal là proxy lazy ngoài phiên JPA → nạp lại theo id)
        com.bosskin.core.CompanyIdentity.requireEmail(companyRepository.findById(caller.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found")), email);
        if (userRepository.existsByEmail(email)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.email.in_use");
        }
        @SuppressWarnings("unchecked")
        List<Integer> roleIds = (List<Integer>) body.getOrDefault("roleIds", Collections.emptyList());
        Set<Role> roles = resolveRoles(roleIds, caller.getCompany().getId());
        grantGuard.requireCanGrantRoles(caller, roles);

        Employee employee = null;
        Object empIdObj = body.get("employeeId");
        if (empIdObj != null) {
            Long empId = ((Number) empIdObj).longValue();
            employee = employeeRepository.findByIdAndCompanyId(empId, caller.getCompany().getId()).orElse(null);
            if (employee == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found");
        }
        Set<Long> manageScope = deptScopeService.resolvedScopes(caller.getId(), "USER_MANAGE");
        if (!canManageTarget(caller, employee, manageScope)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
        }

        User user = User.builder()
            .email(email)
            .password(passwordEncoder.encode(password))
            .mustChangePassword(true)
            .company(caller.getCompany())
            .roles(roles)
            .employee(employee)
            .enabled(true)
            .build();
        User saved = userRepository.save(user);
        audit.log("USER_CREATE").entity("USER", saved.getId()).summary(saved.getEmail())
            .detail(com.bosskin.audit.AuditService.map("roles", roles.stream().map(Role::getName).sorted().toList(),
                "employeeId", employee != null ? employee.getId() : null)).save();
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
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.user.sync_requires_company_scope");
        }
        var synced = employeeService.syncMissingUserAccounts(caller.getCompany().getId(), body.getInitialPassword());
        audit.log("USER_SYNC_FROM_EMPLOYEES").detail(synced).save();
        return ResponseEntity.ok(synced);
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
        grantGuard.requireNotSelf(caller, user.getId());
        accountGuard.requireNotFirstAdmin(caller, user);
        Set<Role> newRoles = resolveRoles(roleIds, caller.getCompany().getId());
        grantGuard.requireCanGrantRoles(caller, newRoles);
        var beforeRoles = user.getRoles().stream().map(Role::getName).sorted().toList();
        user.setRoles(newRoles);
        User saved = userRepository.save(user);
        audit.log("USER_ROLES").entity("USER", saved.getId()).summary(saved.getEmail())
            .detail(com.bosskin.audit.AuditService.map("before", beforeRoles, "after", newRoles.stream().map(Role::getName).sorted().toList())).save();
        return ResponseEntity.ok(toUserMap(saved));
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
        grantGuard.requireNotSelf(caller, user.getId());
        accountGuard.requireNotFirstAdmin(caller, user);
        Set<String> submittedCodes = permissionConsistencyService.normalizePermissionCodes(codes);
        grantGuard.requireCanGrant(caller, submittedCodes);
        // V26: giữ quyền riêng của tính năng đang tắt (bị ẩn ở màn Phân quyền)
        Set<String> normalizedCodes = permissionConsistencyService.keepHiddenFeaturePermissions(submittedCodes,
            user.getDirectPermissions().stream().map(Permission::getCode).toList(), caller.disabledFeatureSet());
        Set<Permission> perms = new HashSet<>();
        for (String code : normalizedCodes) {
            permissionRepository.findByCode(code).ifPresent(perms::add);
        }
        var beforePerms = user.getDirectPermissions().stream().map(Permission::getCode).sorted().toList();
        user.setDirectPermissions(perms);
        User saved = userRepository.save(user);
        deptScopeRepo.pruneByPermissionCodes(saved.getId(), normalizedCodes);
        audit.log("USER_PERMISSIONS").entity("USER", saved.getId()).summary(saved.getEmail())
            .detail(com.bosskin.audit.AuditService.map("before", beforePerms, "after", normalizedCodes.stream().sorted().toList())).save();
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
        grantGuard.requireNotSelf(caller, targetUser.getId());
        accountGuard.requireNotFirstAdmin(caller, targetUser);
        Set<String> directCodes = targetUser.getDirectPermissions().stream()
            .map(Permission::getCode)
            .collect(Collectors.toSet());
        Map<String, List<Long>> converted = new java.util.HashMap<>();
        body.forEach((perm, ids) -> converted.put(perm,
            ids.stream().map(Integer::longValue).collect(Collectors.toList())));
        deptScopeService.requireValidScopeIds(caller.getCompany().getId(), converted);
        var beforeScopes = deptScopeRepo.findScopesMap(id);
        // V26: giữ phạm vi của quyền thuộc tính năng đang tắt (bị ẩn ở màn Phân quyền)
        deptScopeRepo.replaceAll(
            id,
            permissionConsistencyService.filterScopesByPermissionCodes(
                permissionConsistencyService.keepHiddenFeatureScopes(converted, beforeScopes, caller.disabledFeatureSet()), directCodes)
        );
        audit.log("USER_DEPT_SCOPES").entity("USER", id).summary(targetUser.getEmail())
            .detail(com.bosskin.audit.AuditService.map("before", beforeScopes, "after", deptScopeRepo.findScopesMap(id))).save();
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
        if (enabled == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.bad_request");
        if (!enabled && user.getId().equals(caller.getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.user.cannot_disable_self");
        }
        accountGuard.requireNotFirstAdmin(caller, user);
        user.setEnabled(enabled);
        User saved = userRepository.save(user);
        if (!enabled) userSessionRepository.revokeAllByUserId(saved.getId());
        audit.log(enabled ? "USER_ENABLE" : "USER_DISABLE").entity("USER", saved.getId()).summary(saved.getEmail()).save();
        return ResponseEntity.ok(toUserMap(saved));
    }

    private User findUserInCompanyAndScope(Long userId, User caller) {
        User user = findUserInCompany(userId, caller.getCompany().getId());
        Set<Long> manageScope = deptScopeService.resolvedScopes(caller.getId(), "USER_MANAGE");
        Long selfEmployeeId = caller.getEmployee() != null ? caller.getEmployee().getId() : null;
        if (!canManageTarget(caller, user, manageScope, selfEmployeeId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
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
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.user.not_found"));
        if (!user.getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return user;
    }

    private Set<Role> resolveRoles(List<Integer> roleIds, Long companyId) {
        if (roleIds == null || roleIds.isEmpty()) return new HashSet<>();
        Set<Role> roles = new HashSet<>();
        for (Integer rid : roleIds) {
            Role role = roleRepository.findById(rid.longValue())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.role.invalid|" + rid));
            if (!role.getCompany().getId().equals(companyId)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.role.not_in_company");
            }
            roles.add(role);
        }
        return roles;
    }

    private Map<String, Object> toUserMap(User user) {
        return toUserMap(user, deptScopeRepo.findScopesMap(user.getId()));
    }

    private Map<String, Object> toUserMap(User user, Map<String, Set<Long>> deptScopes) {
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
        map.put("totpEnabled", user.isTotpEnabled());
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
        map.put("deptScopes", deptScopes);
        return map;
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }
}
