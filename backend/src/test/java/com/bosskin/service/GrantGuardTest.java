package com.bosskin.service;

import com.bosskin.entity.Company;
import com.bosskin.entity.Permission;
import com.bosskin.entity.Role;
import com.bosskin.entity.User;
import com.bosskin.security.SysAdminImpersonateUser;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Chặn leo thang quyền: chỉ cấp được quyền mình đang có — quyền của tính năng công ty đang tắt không tính. */
class GrantGuardTest {

    private final GrantGuard guard = new GrantGuard();

    private static Permission perm(String code, String module) {
        return Permission.builder().code(code).description(code).module(module).build();
    }

    /** Công ty tắt tính năng "Đăng ký ca"; vai trò Admin vẫn giữ đủ mọi quyền, kể cả quyền của tính năng đã tắt. */
    private static User adminOfCompanyWithDisabledFeature() {
        Company c = new Company();
        c.setDisabledFeatures("SHIFT_REGISTRATION");
        Role admin = Role.builder().name("Admin").permissions(new HashSet<>(Set.of(
            perm("USER_MANAGE", "USER"), perm("PAYROLL_VIEW", "PAYROLL"), perm("SHIFT_REGISTRATION_SELF", "SHIFT")))).build();
        User u = new User();
        u.setId(1L);
        u.setCompany(c);
        u.setRoles(new HashSet<>(Set.of(admin)));
        u.setDirectPermissions(new HashSet<>());
        return u;
    }

    @Test
    @DisplayName("Admin cấp được vai trò Admin dù công ty đang tắt một tính năng (quyền của tính năng tắt không bị tính là 'vượt quyền')")
    void adminCanGrantAdminRoleWhenFeatureDisabled() {
        User admin = adminOfCompanyWithDisabledFeature();
        assertThat(admin.getPermissions()).doesNotContain("SHIFT_REGISTRATION_SELF");
        guard.requireCanGrantRoles(admin, List.copyOf(admin.getRoles()));
        guard.requireCanGrant(admin, Set.of("USER_MANAGE", "SHIFT_REGISTRATION_SELF"));
    }

    @Test
    @DisplayName("Vẫn chặn cấp quyền mà mình không có (tính năng còn bật)")
    void stillBlocksPermissionNotOwned() {
        User admin = adminOfCompanyWithDisabledFeature();
        Role bigger = Role.builder().name("Lớn hơn").permissions(new HashSet<>(Set.of(perm("PAYROLL_APPROVE", "PAYROLL")))).build();
        assertThatThrownBy(() -> guard.requireCanGrantRoles(admin, List.of(bigger)))
            .isInstanceOf(ResponseStatusException.class).hasMessageContaining("error.permission.grant_exceeds_own");
    }

    @Test
    @DisplayName("Không tự đổi quyền của chính mình")
    void notSelf() {
        User admin = adminOfCompanyWithDisabledFeature();
        assertThatThrownBy(() -> guard.requireNotSelf(admin, 1L)).isInstanceOf(ResponseStatusException.class);
        guard.requireNotSelf(admin, 2L);
    }

    @Test
    @DisplayName("V30: vai trò hệ thống (Admin mặc định) bị khoá với admin công ty, system admin vẫn sửa được; vai trò thường không bị chặn")
    void systemRoleLockedForCompanyAdmin() {
        User admin = adminOfCompanyWithDisabledFeature();
        Role system = Role.builder().name("Admin").isSystem(true).build();
        Role normal = Role.builder().name("Kế toán").build();
        assertThatThrownBy(() -> guard.requireRoleEditable(admin, system))
            .isInstanceOf(ResponseStatusException.class).hasMessageContaining("error.role.system_locked");
        guard.requireRoleEditable(admin, normal);
        guard.requireRoleEditable(admin, null);
        guard.requireRoleEditable(new SysAdminImpersonateUser("sys@bosskin", 1L, new Company(), Set.of()), system);
    }

    @Test
    @DisplayName("V30: không đổi vai trò / quyền / trạng thái của tài khoản admin đầu tiên; system admin vẫn được")
    void firstAdminLockedForCompanyAdmin() {
        User admin = adminOfCompanyWithDisabledFeature();
        assertThatThrownBy(() -> guard.requireNotFirstAdmin(admin, true))
            .isInstanceOf(ResponseStatusException.class).hasMessageContaining("error.user.first_admin_locked");
        guard.requireNotFirstAdmin(admin, false);
        guard.requireNotFirstAdmin(new SysAdminImpersonateUser("sys@bosskin", 1L, new Company(), Set.of()), true);
    }
}
