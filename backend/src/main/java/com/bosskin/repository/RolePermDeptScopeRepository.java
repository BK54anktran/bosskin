package com.bosskin.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Repository
public class RolePermDeptScopeRepository {

    private final JdbcTemplate jdbc;

    public RolePermDeptScopeRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Map<String, Set<Long>> findScopesMap(Long roleId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT permission_code, department_id FROM role_permission_dept_scopes WHERE role_id = ?", roleId);
        return rows.stream().collect(Collectors.groupingBy(
            r -> (String) r.get("permission_code"),
            Collectors.mapping(r -> ((Number) r.get("department_id")).longValue(), Collectors.toSet())
        ));
    }

    /** Replace all scopes for a role atomically. scopeMap: permCode → [deptId, ...] */
    public void replaceAll(Long roleId, Map<String, List<Long>> scopeMap) {
        jdbc.update("DELETE FROM role_permission_dept_scopes WHERE role_id = ?", roleId);
        for (Map.Entry<String, List<Long>> e : scopeMap.entrySet()) {
            for (Long deptId : e.getValue()) {
                jdbc.update(
                    "INSERT INTO role_permission_dept_scopes (role_id, permission_code, department_id) VALUES (?, ?, ?)",
                    roleId, e.getKey(), deptId);
            }
        }
    }
}
