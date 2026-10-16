package com.bosskin.service;

import com.bosskin.entity.User;
import com.bosskin.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * V30 — tài khoản admin đầu tiên của công ty (id nhỏ nhất, tạo cùng công ty) là quyền cao nhất: người dùng công ty,
 * kể cả Admin khác, không tác động lên nó được (vai trò, quyền riêng, phạm vi, khoá / mở, đặt lại mật khẩu, gỡ 2FA).
 * System admin (impersonate) vẫn xử lý được. Tự đổi của chính mình do {@link GrantGuard#requireNotSelf} lo.
 */
@Component
@RequiredArgsConstructor
public class AccountGuard {

    private final UserRepository userRepository;
    private final GrantGuard grantGuard;

    public boolean isFirstAdmin(User target) {
        if (target == null || target.getId() == null || target.getCompany() == null) return false;
        return userRepository.findFirstByCompanyIdOrderByIdAsc(target.getCompany().getId())
            .map(first -> first.getId().equals(target.getId())).orElse(false);
    }

    /** 403 {@code error.user.first_admin_locked} nếu {@code target} là admin đầu tiên và người gọi không phải system admin. */
    public void requireNotFirstAdmin(User caller, User target) {
        grantGuard.requireNotFirstAdmin(caller, isFirstAdmin(target));
    }
}
