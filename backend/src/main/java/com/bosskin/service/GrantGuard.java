package com.bosskin.service;

import com.bosskin.core.CompanyFeatures;
import com.bosskin.entity.Permission;
import com.bosskin.entity.Role;
import com.bosskin.entity.User;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Collectors;

/**
 * Chặn leo thang quyền (S6) khi gán vai trò / quyền:
 * <ul>
 *   <li>không tự sửa vai trò, quyền, phạm vi của chính mình;</li>
 *   <li>chỉ cấp được những quyền mình đang có.</li>
 * </ul>
 * System admin impersonate có toàn quyền nên luôn qua được bước 2.
 */
@Component
public class GrantGuard {

    /** Người gọi không được thay đổi quyền của chính mình. */
    public void requireNotSelf(User caller, Long targetUserId) {
        if (caller.getId() != null && caller.getId().equals(targetUserId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.cannot_change_own");
        }
    }

    /**
     * Mọi quyền trong {@code codes} phải nằm trong quyền hiện có của người gọi.
     * Quyền của tính năng công ty đang tắt không tính: {@link User#getPermissions()} đã bỏ chúng, còn vai trò (vd. Admin) vẫn giữ
     * đủ quyền — nếu tính thì Admin không bao giờ cấp lại được vai trò Admin khi công ty tắt một tính năng.
     */
    public void requireCanGrant(User caller, Collection<String> codes) {
        if (codes == null || codes.isEmpty()) return;
        Set<String> own = caller.getPermissions();
        Set<String> wanted = new HashSet<>();
        for (String code : codes) if (code != null) wanted.add(code);
        wanted = CompanyFeatures.filter(wanted, caller.disabledFeatureSet());
        Set<String> missing = new TreeSet<>();
        for (String code : wanted) {
            if (code != null && !own.contains(code)) missing.add(code);
        }
        if (!missing.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "error.permission.grant_exceeds_own");
        }
    }

    /** Như {@link #requireCanGrant} cho toàn bộ quyền của các vai trò sắp gán. */
    public void requireCanGrantRoles(User caller, Collection<Role> roles) {
        if (roles == null) return;
        requireCanGrant(caller, roles.stream()
            .flatMap(r -> r.getPermissions().stream())
            .map(Permission::getCode)
            .collect(Collectors.toSet()));
    }
}
