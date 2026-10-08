package com.bosskin.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Bước 2 — mỗi request một mã (request-id): nhận từ header {@code X-Request-ID} (load balancer / app gửi)
 * hoặc tự sinh, đưa vào MDC ({@code rid}) để mọi dòng log của request đó có cùng mã, trả lại trong header
 * và trong body lỗi để người dùng báo lỗi kèm mã tra log được. Nhật ký thao tác cũng lưu mã này.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestIdFilter extends OncePerRequestFilter {

    public static final String HEADER = "X-Request-ID";
    public static final String MDC_KEY = "rid";
    private static final Pattern SAFE = Pattern.compile("[A-Za-z0-9._-]{1,64}");

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain chain) throws ServletException, IOException {
        String rid = request.getHeader(HEADER);
        if (rid == null || !SAFE.matcher(rid).matches()) {
            rid = UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        }
        MDC.put(MDC_KEY, rid);
        response.setHeader(HEADER, rid);
        try {
            chain.doFilter(request, response);
        } finally {
            MDC.remove(MDC_KEY);
        }
    }

    /** Mã request hiện tại (null khi chạy ngoài request, vd. job định kỳ). */
    public static String current() {
        return MDC.get(MDC_KEY);
    }
}
