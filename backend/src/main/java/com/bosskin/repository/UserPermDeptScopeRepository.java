package com.bosskin.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Repository
public class UserPermDeptScopeRepository {

    private final JdbcTemplate jdbc;

    public UserPermDeptScopeRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Mã quyền mà người dùng có qua ít nhất một vai trò KHÔNG giới hạn phạm vi
     * (vai trò cấp quyền đó mà không có dòng scope nào). Nhiều vai trò cộng dồn theo
     * hướng rộng nhất: "Nhân viên" (chỉ bản thân) + "Quản lý" (toàn công ty) = toàn công ty.
     */
    private Set<String> unrestrictedRolePermCodes(Long userId) {
        return new java.util.HashSet<>(jdbc.queryForList(
            "SELECT DISTINCT p.code FROM user_roles ur " +
            "INNER JOIN role_permissions rp ON rp.role_id = ur.role_id " +
            "INNER JOIN permissions p ON p.id = rp.permission_id " +
            "WHERE ur.user_id = ? AND NOT EXISTS (SELECT 1 FROM role_permission_dept_scopes s " +
            "  WHERE s.role_id = ur.role_id AND s.permission_code = p.code)",
            String.class, userId));
    }

    private String moduleOf(String permCode) {
        List<String> m = jdbc.queryForList("SELECT module FROM permissions WHERE code = ?", String.class, permCode);
        return m.isEmpty() ? null : m.get(0);
    }

    /** Returns map of permissionCode → set of allowed departmentIds (user direct + roles). Empty set = unrestricted. */
    public Map<String, Set<Long>> findScopesMap(Long userId) {
        Set<String> directModules = new java.util.HashSet<>(jdbc.queryForList(
            "SELECT DISTINCT p.module FROM user_permissions up " +
            "INNER JOIN permissions p ON p.id = up.permission_id " +
            "WHERE up.user_id = ?",
            String.class, userId));

        Map<String, Set<Long>> result = new java.util.HashMap<>();
        // User direct scopes
        jdbc.queryForList(
            "SELECT permission_code, department_id FROM user_permission_dept_scopes WHERE user_id = ?", userId)
            .forEach(r -> result
                .computeIfAbsent((String) r.get("permission_code"), k -> new java.util.HashSet<>())
                .add(((Number) r.get("department_id")).longValue()));
        // Role scopes
        jdbc.queryForList(
            "SELECT DISTINCT r.permission_code, r.department_id, p.module FROM role_permission_dept_scopes r " +
            "INNER JOIN user_roles ur ON ur.role_id = r.role_id " +
            "INNER JOIN permissions p ON p.code = r.permission_code " +
            "WHERE ur.user_id = ?", userId)
            .forEach(r -> {
                String module = (String) r.get("module");
                if (module != null && directModules.contains(module)) return;
                result
                    .computeIfAbsent((String) r.get("permission_code"), k -> new java.util.HashSet<>())
                    .add(((Number) r.get("department_id")).longValue());
            });
        // Vai trò không giới hạn thắng vai trò giới hạn (trừ module đã cấu hình quyền trực tiếp)
        Set<String> unrestricted = unrestrictedRolePermCodes(userId);
        result.entrySet().removeIf(e -> unrestricted.contains(e.getKey())
            && !directModules.contains(moduleOf(e.getKey())));
        return result;
    }

    /** Returns allowed departmentIds for a specific permission (user direct + roles). Empty = unrestricted. */
    public Set<Long> findDeptIds(Long userId, String permCode) {
        String module = jdbc.queryForObject(
            "SELECT module FROM permissions WHERE code = ?",
            String.class, permCode);
        Long directCount = jdbc.queryForObject(
            "SELECT COUNT(*) FROM user_permissions up " +
            "INNER JOIN permissions p ON p.id = up.permission_id " +
            "WHERE up.user_id = ? AND p.module = ?",
            Long.class, userId, module);

        Set<Long> result = new java.util.HashSet<>(jdbc.queryForList(
            "SELECT department_id FROM user_permission_dept_scopes WHERE user_id = ? AND permission_code = ?",
            Long.class, userId, permCode));
        if (directCount != null && directCount > 0) {
            return result;
        }
        if (unrestrictedRolePermCodes(userId).contains(permCode)) {
            return java.util.Collections.emptySet();
        }
        result.addAll(jdbc.queryForList(
            "SELECT DISTINCT r.department_id FROM role_permission_dept_scopes r " +
            "INNER JOIN user_roles ur ON ur.role_id = r.role_id " +
            "WHERE ur.user_id = ? AND r.permission_code = ?",
            Long.class, userId, permCode));
        return result;
    }

    /** Replace all scopes for a user atomically. scopeMap: permCode → [deptId, ...] */
    public void replaceAll(Long userId, Map<String, List<Long>> scopeMap) {
        jdbc.update("DELETE FROM user_permission_dept_scopes WHERE user_id = ?", userId);
        for (Map.Entry<String, List<Long>> e : scopeMap.entrySet()) {
            for (Long deptId : e.getValue()) {
                jdbc.update(
                    "INSERT INTO user_permission_dept_scopes (user_id, permission_code, department_id) VALUES (?, ?, ?)",
                    userId, e.getKey(), deptId);
            }
        }
    }

    /** Remove direct user scopes whose permission code is no longer in allowedCodes. */
    public void pruneByPermissionCodes(Long userId, Set<String> allowedCodes) {
        if (allowedCodes == null || allowedCodes.isEmpty()) {
            jdbc.update("DELETE FROM user_permission_dept_scopes WHERE user_id = ?", userId);
            return;
        }
        String placeholders = String.join(",", java.util.Collections.nCopies(allowedCodes.size(), "?"));
        String sql = "DELETE FROM user_permission_dept_scopes WHERE user_id = ? AND permission_code NOT IN (" + placeholders + ")";
        Object[] args = new Object[allowedCodes.size() + 1];
        args[0] = userId;
        int idx = 1;
        for (String code : allowedCodes) {
            args[idx++] = code;
        }
        jdbc.update(sql, args);
    }
}
