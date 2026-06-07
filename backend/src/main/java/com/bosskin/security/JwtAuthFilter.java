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
                    if (admin != null && jwtUtil.isTokenValid(jwt, admin)) {
                        setAuth(admin, request);
                    }
                } else if (jwtUtil.isImpersonateToken(jwt)) {
                    // Sysadmin impersonate: full quyền, không gắn với employee nào
                    Long companyId = jwtUtil.extractCompanyId(jwt);
                    if (companyId != null && !jwtUtil.isTokenExpired(jwt)) {
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
                    if (user != null && jwtUtil.isTokenValid(jwt, user)
                            && user.getCompanyId() != null
                            && companyRepository.existsByIdAndActiveTrue(user.getCompanyId())) {
                        setAuth(user, request);
                    }
                }
            }
        } catch (Exception ignored) { }

        filterChain.doFilter(request, response);
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
