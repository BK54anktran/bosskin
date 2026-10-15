package com.bosskin.security;

import com.bosskin.core.FeatureRoutes;
import com.bosskin.entity.User;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.lang.NonNull;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * V26: chặn API của tính năng mà công ty đã tắt (bảng {@link FeatureRoutes}) → 403 {@code error.company.feature_disabled}.
 * Chỉ áp cho tài khoản công ty (và system admin đang đăng nhập thay công ty); system admin thuần không bị chặn.
 */
@Component
public class FeatureRouteInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(@NonNull HttpServletRequest request, @NonNull HttpServletResponse response, @NonNull Object handler) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof User user)) return true;
        String feature = FeatureRoutes.featureOf(request.getMethod(), request.getRequestURI());
        if (feature != null && user.isFeatureDisabled(feature)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.company.feature_disabled");
        }
        return true;
    }
}
