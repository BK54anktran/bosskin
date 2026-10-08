package com.bosskin.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Chống dò mật khẩu (S10): sai mật khẩu quá {@code maxFailures} lần trong cửa sổ
 * {@code window} thì tạm khoá đăng nhập tài khoản đó trong {@code lockDuration}.
 *
 * Lưu trong bộ nhớ của một instance — đủ cho Elastic Beanstalk 1 instance.
 * Khi chạy nhiều instance cần chuyển sang bộ đếm dùng chung (DB/Redis) hoặc WAF.
 */
@Component
public class LoginAttemptService {

    private record Attempts(int failures, Instant windowStart, Instant lockedUntil) {}

    private final Map<String, Attempts> attempts = new ConcurrentHashMap<>();
    private final Clock clock;
    private final int maxFailures;
    private final Duration window;
    private final Duration lockDuration;

    @org.springframework.beans.factory.annotation.Autowired
    public LoginAttemptService(
        @Value("${app.security.login.max-failures:5}") int maxFailures,
        @Value("${app.security.login.window-minutes:15}") long windowMinutes,
        @Value("${app.security.login.lock-minutes:15}") long lockMinutes
    ) {
        this(Clock.systemUTC(), maxFailures, Duration.ofMinutes(windowMinutes), Duration.ofMinutes(lockMinutes));
    }

    LoginAttemptService(Clock clock, int maxFailures, Duration window, Duration lockDuration) {
        this.clock = clock;
        this.maxFailures = maxFailures;
        this.window = window;
        this.lockDuration = lockDuration;
    }

    /** Gọi trước khi kiểm mật khẩu: ném 429 nếu tài khoản đang bị tạm khoá. */
    public void checkNotLocked(String email) {
        Attempts a = attempts.get(key(email));
        if (a != null && a.lockedUntil() != null && clock.instant().isBefore(a.lockedUntil())) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "error.auth.too_many_attempts");
        }
    }

    public void recordFailure(String email) {
        Instant now = clock.instant();
        attempts.compute(key(email), (k, a) -> {
            if (a == null || now.isAfter(a.windowStart().plus(window))) {
                a = new Attempts(0, now, null);
            }
            int failures = a.failures() + 1;
            Instant lockedUntil = failures >= maxFailures ? now.plus(lockDuration) : a.lockedUntil();
            return new Attempts(failures, a.windowStart(), lockedUntil);
        });
    }

    public void recordSuccess(String email) {
        attempts.remove(key(email));
    }

    private static String key(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }
}
