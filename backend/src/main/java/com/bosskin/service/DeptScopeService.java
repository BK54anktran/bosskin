package com.bosskin.service;

import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.UserPermDeptScopeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
@RequiredArgsConstructor
public class DeptScopeService {

    public static final long SCOPE_SELF_ONLY = -1L;
    public static final long SCOPE_MY_DEPARTMENT_ONLY = -2L;
    public static final long SCOPE_MY_DEPARTMENT_AND_DESC = -3L;

    private final UserPermDeptScopeRepository deptScopeRepo;
    private final DepartmentRepository departmentRepo;
    private final EmployeeRepository employeeRepository;

    /**
     * D12: phạm vi phòng ban gửi lên (vai trò / người dùng) chỉ được chứa phòng ban của chính công ty
     * hoặc các giá trị đặc biệt (chỉ bản thân, phòng tôi, phòng tôi và cấp dưới). Bảng scope không có
     * khoá ngoại nên kiểm ở đây.
     */
    public void requireValidScopeIds(Long companyId, Map<String, ? extends java.util.Collection<Long>> scopes) {
        if (scopes == null) return;
        Set<Long> companyDepts = null;
        for (var ids : scopes.values()) {
            if (ids == null) continue;
            for (Long id : ids) {
                if (id == null) throw invalidScope();
                if (id <= 0) {
                    if (id != SCOPE_SELF_ONLY && id != SCOPE_MY_DEPARTMENT_ONLY && id != SCOPE_MY_DEPARTMENT_AND_DESC)
                        throw invalidScope();
                    continue;
                }
                if (companyDepts == null) {
                    companyDepts = departmentRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
                        .map(com.bosskin.entity.Department::getId).collect(java.util.stream.Collectors.toSet());
                }
                if (!companyDepts.contains(id)) throw invalidScope();
            }
        }
    }

    private static org.springframework.web.server.ResponseStatusException invalidScope() {
        return new org.springframework.web.server.ResponseStatusException(
            org.springframework.http.HttpStatus.BAD_REQUEST, "error.role.scope_department_invalid");
    }

    /**
     * Returns the resolved set of allowed department IDs for a user+permission,
     * expanding every root ID to include all its descendants via BFS.
     * Empty result means unrestricted (no scope defined).
     */
    public Set<Long> resolvedScopes(Long userId, String permCode) {
        if (userId == null) return Collections.emptySet(); // sysadmin impersonate → no scope restriction
        Set<Long> rawIds = deptScopeRepo.findDeptIds(userId, permCode);
        if (rawIds.isEmpty()) return Collections.emptySet();

        boolean selfOnly = rawIds.contains(SCOPE_SELF_ONLY);
        boolean myDeptOnly = rawIds.contains(SCOPE_MY_DEPARTMENT_ONLY);
        boolean myDeptAndDesc = rawIds.contains(SCOPE_MY_DEPARTMENT_AND_DESC);

        Set<Long> explicitDeptRoots = rawIds.stream()
            .filter(id -> id != null && id > 0)
            .collect(java.util.stream.Collectors.toSet());

        Set<Long> resolved = new HashSet<>();
        if (!explicitDeptRoots.isEmpty()) {
            resolved.addAll(expandDescendants(explicitDeptRoots));
        }

        Long myDeptId = employeeRepository.findByUserIdFetch(userId)
            .map(e -> e.getDepartment() != null ? e.getDepartment().getId() : null)
            .orElse(null);
        if (myDeptId != null) {
            if (myDeptOnly) {
                resolved.add(myDeptId);
            }
            if (myDeptAndDesc) {
                resolved.addAll(expandDescendants(Set.of(myDeptId)));
            }
        }

        if (selfOnly) {
            resolved.add(SCOPE_SELF_ONLY);
        }
        // S6: có cấu hình phạm vi nhưng không phân giải ra phòng ban nào (vd. "phòng tôi" mà
        // người dùng chưa gắn nhân viên/phòng ban). Tập rỗng ở đây bị hiểu là "toàn công ty",
        // nên thu hẹp về "chỉ mình tôi" thay vì mở toàn quyền.
        if (resolved.isEmpty()) {
            resolved.add(SCOPE_SELF_ONLY);
        }
        return resolved;
    }

    /**
     * Expands root department IDs to include all descendants via BFS.
     */
    public Set<Long> expandDepartmentsWithDescendants(Set<Long> rootIds) {
        Set<Long> normalized = rootIds == null
            ? Collections.emptySet()
            : rootIds.stream().filter(id -> id != null && id > 0).collect(java.util.stream.Collectors.toSet());
        if (normalized.isEmpty()) return Collections.emptySet();
        return expandDescendants(normalized);
    }

    private Set<Long> expandDescendants(Set<Long> rootIds) {
        Set<Long> result = new HashSet<>(rootIds);
        Queue<Long> queue = new ArrayDeque<>(rootIds);
        while (!queue.isEmpty()) {
            List<Long> batch = new ArrayList<>();
            while (!queue.isEmpty()) batch.add(queue.poll());
            departmentRepo.findByParentIdIn(batch).forEach(d -> {
                if (result.add(d.getId())) queue.add(d.getId());
            });
        }
        return result;
    }
}
