package com.bosskin.security;

import com.bosskin.entity.SystemAdmin;
import com.bosskin.entity.User;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.SystemAdminRepository;
import com.bosskin.repository.UserRepository;
import java.util.Set;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;
    private final SystemAdminRepository systemAdminRepository;
    private final CompanyRepository companyRepository;

    @Override
    protected void doFilterInternal(
        @NonNull HttpServletRequest request,
        @NonNull HttpServletResponse response,
        @NonNull FilterChain filterChain
    ) throws ServletException, IOException {

        final String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        final String jwt = authHeader.substring(7);
        try {
            final String email = jwtUtil.extractUsername(jwt);
            final String type  = jwtUtil.extractType(jwt);

            if (email != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                if (JwtUtil.TYPE_SYSTEM.equals(type)) {
                    SystemAdmin admin = systemAdminRepository.findByEmail(email).orElse(null);
                    if (admin != null && admin.isEnabled() && jwtUtil.isTokenValid(jwt, admin)) {
                        setAuth(admin, request);
                    }
                } else if (!JwtUtil.TYPE_COMPANY.equals(type)) {
                    // Refresh token (type REFRESH) hoặc token lạ: không dùng làm access token
                } else if (jwtUtil.isImpersonateToken(jwt)) {
                    // Sysadmin impersonate: full quyền, không gắn với employee nào.
                    // Kiểm lại trong DB: email phải là system admin còn hoạt động.
                    Long companyId = jwtUtil.extractCompanyId(jwt);
                    boolean sysAdminActive = systemAdminRepository.findByEmail(email)
                        .map(SystemAdmin::isEnabled).orElse(false);
                    if (sysAdminActive && companyId != null && !jwtUtil.isTokenExpired(jwt)) {
                        com.bosskin.entity.Company company = companyRepository.findById(companyId).orElse(null);
                        if (company != null && company.isActive()) {
                            Set<String> perms = jwtUtil.extractPermissions(jwt);
                            setAuth(new SysAdminImpersonateUser(email, companyId, company, perms), request);
                        }
                    }
                } else {
                    Long companyId = jwtUtil.extractCompanyId(jwt);
                    User user = (companyId != null)
                        ? userRepository.findByEmailAndCompanyId(email, companyId).orElse(null)
                        : userRepository.findByEmail(email).orElse(null);
                    if (user != null && user.isEnabled() && !user.isDeleted()
                            && jwtUtil.isTokenValid(jwt, user)
                            && user.getCompanyId() != null
                            && companyRepository.existsByIdAndActiveTrue(user.getCompanyId())) {
                        if (user.isMustChangePassword() && !allowedBeforePasswordChange(request)) {
                            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                            response.setContentType("application/json;charset=UTF-8");
                            response.getWriter().write(
                                "{\"status\":403,\"message\":\"error.auth.password_change_required\"}");
                            return;
                        }
                        companyRepository.findById(user.getCompanyId())
                            .ifPresent(co -> {
                                user.setDisabledFeaturesLoaded(co.disabledFeatureSet());
                                user.setCompanyTimezoneLoaded(co.getTimezone());
                            });
                        setAuth(user, request);
                    }
                }
            }
        } catch (Exception ignored) { }

        filterChain.doFilter(request, response);
    }

    /** Khi còn phải đổi mật khẩu (V7): chỉ cho xem hồ sơ, đổi mật khẩu và các API /auth. */
    static boolean allowedBeforePasswordChange(HttpServletRequest req) {
        String path = req.getRequestURI();
        String m = req.getMethod();
        if (path.startsWith("/api/v1/auth/")) return true;
        if ("GET".equals(m) && path.equals("/api/v1/profile")) return true;
        return "PATCH".equals(m) && path.equals("/api/v1/profile/password");
    }

    private void setAuth(org.springframework.security.core.userdetails.UserDetails principal,
                         HttpServletRequest request) {
        var auth = new UsernamePasswordAuthenticationToken(
            principal, null, principal.getAuthorities()
        );
        auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
        SecurityContextHolder.getContext().setAuthentication(auth);
    }
}
