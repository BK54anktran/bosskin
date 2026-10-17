package com.bosskin.security;

import com.bosskin.core.CompanyZone;
import com.bosskin.entity.User;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/** V32: đặt múi giờ của công ty người dùng cho cả request (đồng hồ chấm công, ngày công, hôm nay…). */
@Component
public class CompanyZoneInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof User u) {
            CompanyZone.set(CompanyZone.parseOrDefault(u.companyTimezoneId()));
        } else {
            CompanyZone.clear();
        }
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) {
        CompanyZone.clear();
    }
}
