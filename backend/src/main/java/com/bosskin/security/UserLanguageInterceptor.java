package com.bosskin.security;

import com.bosskin.entity.User;
import com.bosskin.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Ghi nhớ ngôn ngữ app của người dùng (từ Accept-Language) để gửi thông báo đẩy đúng ngôn ngữ.
 * Chỉ ghi khi request có header và ngôn ngữ khác giá trị đã lưu — thường không tốn truy vấn ghi nào.
 */
@Component
@RequiredArgsConstructor
public class UserLanguageInterceptor implements HandlerInterceptor {

    private final UserRepository userRepository;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        try {
            if (request.getHeader("Accept-Language") == null) return true;
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth == null || !(auth.getPrincipal() instanceof User user)) return true;
            String lang = LocaleContextHolder.getLocale().getLanguage();
            if (!"vi".equals(lang) && !"en".equals(lang)) return true;
            String stored = user.getLanguage() == null ? "vi" : user.getLanguage();
            if (!stored.equals(lang)) {
                userRepository.updateLanguage(user.getId(), lang);
                user.setLanguage(lang);
            }
        } catch (RuntimeException ignored) {
            // ngôn ngữ chỉ phục vụ thông báo đẩy — không bao giờ làm hỏng request
        }
        return true;
    }
}
