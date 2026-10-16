package com.bosskin.service;

import com.bosskin.entity.Company;
import com.bosskin.entity.User;
import com.bosskin.repository.UserRepository;
import com.bosskin.security.SysAdminImpersonateUser;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** V30: admin đầu tiên của công ty không bị người dùng công ty (kể cả Admin khác) tác động; system admin thì được. */
class AccountGuardTest {

    private static User user(Long id, Company company) {
        User u = new User();
        u.setId(id);
        u.setCompany(company);
        return u;
    }

    @Test
    @DisplayName("Chỉ tài khoản có id nhỏ nhất của công ty là admin đầu tiên; admin khác bị chặn, system admin thì không")
    void firstAdminLocked() {
        Company company = new Company();
        company.setId(7L);
        User first = user(10L, company), second = user(11L, company);
        UserRepository repo = mock(UserRepository.class);
        when(repo.findFirstByCompanyIdOrderByIdAsc(7L)).thenReturn(Optional.of(first));
        AccountGuard guard = new AccountGuard(repo, new GrantGuard());

        assertThat(guard.isFirstAdmin(first)).isTrue();
        assertThat(guard.isFirstAdmin(second)).isFalse();
        assertThat(guard.isFirstAdmin(null)).isFalse();
        assertThat(guard.isFirstAdmin(user(null, company))).isFalse();

        assertThatThrownBy(() -> guard.requireNotFirstAdmin(second, first))
            .isInstanceOf(ResponseStatusException.class).hasMessageContaining("error.user.first_admin_locked");
        guard.requireNotFirstAdmin(first, second);
        guard.requireNotFirstAdmin(new SysAdminImpersonateUser("sys@bosskin", 7L, company, Set.of()), first);
    }
}
