package com.bosskin.service;

import com.bosskin.dto.AuthDTO;
import com.bosskin.entity.SystemAdmin;
import com.bosskin.entity.User;
import com.bosskin.entity.UserSession;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.SystemAdminRepository;
import com.bosskin.repository.UserPermDeptScopeRepository;
import com.bosskin.repository.UserRepository;
import com.bosskin.repository.UserSessionRepository;
import com.bosskin.security.JwtUtil;
import io.jsonwebtoken.Claims;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository              userRepository;
    private final SystemAdminRepository       systemAdminRepository;
    private final UserSessionRepository       userSessionRepository;
    private final UserPermDeptScopeRepository deptScopeRepo;
    private final CompanyRepository           companyRepository;
    private final JwtUtil                     jwtUtil;
    private final PasswordEncoder             passwordEncoder;
    private final com.bosskin.security.LoginAttemptService loginAttemptService;
    private final TwoFactorService twoFactorService;

    /** Bước C: system admin bắt buộc 2FA (tắt được bằng cấu hình, chỉ dùng cho test). */
    @org.springframework.beans.factory.annotation.Value("${app.security.require-sysadmin-2fa:true}")
    private boolean requireSysadmin2fa;

    // ── Company user login ──────────────────────────────────────────────
    @Transactional
    public AuthDTO.LoginResponse login(AuthDTO.LoginRequest req) {
        loginAttemptService.checkNotLocked(req.getEmail());
        User user = userRepository.findByEmail(req.getEmail()).orElse(null);

        if (user == null || !passwordEncoder.matches(req.getPassword(), user.getPassword())) {
            loginAttemptService.recordFailure(req.getEmail());
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.auth.bad_credentials");
        }
        loginAttemptService.recordSuccess(req.getEmail());
        if (!user.isEnabled() || user.isDeleted()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.auth.account_disabled");
        }
        if (!companyRepository.existsByIdAndActiveTrue(user.getCompanyId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.company.inactive");
        }

        String deviceId = req.getDeviceId() != null ? req.getDeviceId() : UUID.randomUUID().toString();
        // Bước C: đã bật 2FA → chờ mã; công ty bắt buộc 2FA với quản trị mà chưa cài → bắt cài
        if (user.isTotpEnabled()) {
            return challenge(user.getEmail(), "COMPANY", "VERIFY", deviceId);
        }
        if (user.getCompany().isRequireAdmin2fa() && user.hasPermission("ROLE_MANAGE")) {
            return challenge(user.getEmail(), "COMPANY", "SETUP", deviceId);
        }
        return issueCompanyTokens(user, deviceId);
    }

    private AuthDTO.LoginResponse challenge(String email, String account, String purpose, String deviceId) {
        return AuthDTO.LoginResponse.builder()
            .twoFactor("VERIFY".equals(purpose) ? "REQUIRED" : "SETUP_REQUIRED")
            .challengeToken(jwtUtil.generateChallengeToken(email, account, purpose, deviceId))
            .build();
    }

    private AuthDTO.LoginResponse issueCompanyTokens(User user, String deviceId) {
        String jti = jwtUtil.newJti();

        String accessToken  = jwtUtil.generateToken(user, deviceId);
        String refreshToken = jwtUtil.generateRefreshToken(user, deviceId, jti);

        LocalDateTime expiresAt = LocalDateTime.ofInstant(
            Instant.now().plusMillis(jwtUtil.getRefreshExpirationMs()), ZoneId.systemDefault());

        userSessionRepository.save(UserSession.builder()
            .user(user)
            .jti(jti)
            .deviceId(deviceId)
            .expiresAt(expiresAt)
            .build());

        return AuthDTO.LoginResponse.builder()
            .accessToken(accessToken)
            .refreshToken(refreshToken)
            .tokenType("Bearer")
            .expiresIn(jwtUtil.getExpiration())
            .user(AuthDTO.UserInfo.builder()
                .id(user.getId())
                .email(user.getEmail())
                .type("COMPANY")
                .companyId(user.getCompany().getId())
                .companyName(user.getCompany().getName())
                .companyCode(user.getCompany().getCode())
                .companyDomain(user.getCompany().getDomain())
                .companyCurrency(user.getCompany().getCurrencyCode())
                .companyTimezone(user.getCompany().getTimezone())
                .companyUtcOffsetMinutes(com.bosskin.core.CompanyZone.utcOffsetMinutes(com.bosskin.core.CompanyZone.parseOrDefault(user.getCompany().getTimezone())))
                .modules(com.bosskin.core.CompanyFeatures.modulesOf(user.getCompany().disabledFeatureSet()))
                .features(com.bosskin.core.CompanyFeatures.enabledOf(user.getCompany().disabledFeatureSet()))
                .fullName(user.getEmployee() != null ? user.getEmployee().getFullName() : null)
                .avatar(user.getEmployee() != null ? user.getEmployee().getAvatar() : null)
                .employeeId(user.getEmployee() != null ? user.getEmployee().getId() : null)
                .permissions(user.getPermissions())
                .departmentScope(deptScopeRepo.findScopesMap(user.getId()))
                .mustChangePassword(user.isMustChangePassword())
                .build())
            .build();
    }

    // ── Refresh token ───────────────────────────────────────────────────
    @Transactional
    public AuthDTO.LoginResponse refresh(AuthDTO.RefreshRequest req) {
        String token = req.getRefreshToken();

        Claims claims = jwtUtil.extractAllClaimsIgnoreExpiry(token);
        if (claims.getExpiration().before(new java.util.Date())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.auth.refresh_token_expired");
        }

        if (!"REFRESH".equals(claims.get("type"))) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.auth.invalid_refresh_token");
        }

        String jti      = (String) claims.get("jti");
        String deviceId = (String) claims.get("deviceId");
        String email    = claims.getSubject();

        UserSession session = userSessionRepository.findByJti(jti)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.auth.invalid_refresh_token"));

        if (session.isRevoked()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.auth.session_revoked");
        }
        if (req.getDeviceId() != null && !req.getDeviceId().equals(deviceId)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.auth.device_mismatch");
        }

        // Rotate: revoke old session, create new one
        session.setRevoked(true);
        userSessionRepository.save(session);

        User user = userRepository.findByEmail(email)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.user.not_found"));
        if (!user.isEnabled() || user.isDeleted()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.auth.account_disabled");
        }

        if (!companyRepository.existsByIdAndActiveTrue(user.getCompanyId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.company.inactive");
        }

        String newJti          = jwtUtil.newJti();
        String newAccessToken  = jwtUtil.generateToken(user, deviceId);
        String newRefreshToken = jwtUtil.generateRefreshToken(user, deviceId, newJti);

        LocalDateTime expiresAt = LocalDateTime.ofInstant(
            Instant.now().plusMillis(jwtUtil.getRefreshExpirationMs()), ZoneId.systemDefault());

        userSessionRepository.save(UserSession.builder()
            .user(user)
            .jti(newJti)
            .deviceId(deviceId)
            .expiresAt(expiresAt)
            .build());

        return AuthDTO.LoginResponse.builder()
            .accessToken(newAccessToken)
            .refreshToken(newRefreshToken)
            .tokenType("Bearer")
            .expiresIn(jwtUtil.getExpiration())
            .user(AuthDTO.UserInfo.builder()
                .id(user.getId())
                .email(user.getEmail())
                .type("COMPANY")
                .companyId(user.getCompany().getId())
                .companyName(user.getCompany().getName())
                .companyCode(user.getCompany().getCode())
                .companyDomain(user.getCompany().getDomain())
                .companyCurrency(user.getCompany().getCurrencyCode())
                .companyTimezone(user.getCompany().getTimezone())
                .companyUtcOffsetMinutes(com.bosskin.core.CompanyZone.utcOffsetMinutes(com.bosskin.core.CompanyZone.parseOrDefault(user.getCompany().getTimezone())))
                .modules(com.bosskin.core.CompanyFeatures.modulesOf(user.getCompany().disabledFeatureSet()))
                .features(com.bosskin.core.CompanyFeatures.enabledOf(user.getCompany().disabledFeatureSet()))
                .fullName(user.getEmployee() != null ? user.getEmployee().getFullName() : null)
                .avatar(user.getEmployee() != null ? user.getEmployee().getAvatar() : null)
                .employeeId(user.getEmployee() != null ? user.getEmployee().getId() : null)
                .permissions(user.getPermissions())
                .departmentScope(deptScopeRepo.findScopesMap(user.getId()))
                .mustChangePassword(user.isMustChangePassword())
                .build())
            .build();
    }

    // ── System admin login ──────────────────────────────────────────────
    /** Đăng xuất: thu hồi phiên refresh. Token sai/hết hạn thì bỏ qua (đăng xuất luôn thành công). */
    @org.springframework.transaction.annotation.Transactional
    public void logout(String refreshToken, String fcmToken) {
        if (fcmToken != null && !fcmToken.isBlank()) {
            userRepository.clearFcmToken(fcmToken);
        }
        if (refreshToken == null || refreshToken.isBlank()) return;
        try {
            Claims claims = jwtUtil.extractAllClaimsIgnoreExpiry(refreshToken);
            String jti = (String) claims.get("jti");
            if (jti == null) return;
            userSessionRepository.findByJti(jti).ifPresent(s -> {
                s.setRevoked(true);
                userSessionRepository.save(s);
            });
        } catch (Exception ignored) {
            // token hỏng: không có gì để thu hồi
        }
    }

    public AuthDTO.LoginResponse systemLogin(AuthDTO.LoginRequest req) {
        String attemptKey = "system:" + req.getEmail();
        loginAttemptService.checkNotLocked(attemptKey);
        SystemAdmin admin = systemAdminRepository.findByEmail(req.getEmail()).orElse(null);

        if (admin == null || !passwordEncoder.matches(req.getPassword(), admin.getPassword())) {
            loginAttemptService.recordFailure(attemptKey);
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.auth.bad_credentials");
        }
        loginAttemptService.recordSuccess(attemptKey);
        if (!admin.isEnabled()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.auth.account_disabled");
        }
        if (admin.isTotpEnabled()) {
            return challenge(admin.getEmail(), "SYSTEM", "VERIFY", null);
        }
        if (requireSysadmin2fa) {
            return challenge(admin.getEmail(), "SYSTEM", "SETUP", null);
        }
        return issueSystemTokens(admin);
    }

    private AuthDTO.LoginResponse issueSystemTokens(SystemAdmin admin) {
        return AuthDTO.LoginResponse.builder()
            .accessToken(jwtUtil.generateSystemToken(admin))
            .tokenType("Bearer")
            .expiresIn(jwtUtil.getExpiration())
            .user(AuthDTO.UserInfo.builder()
                .id(admin.getId())
                .email(admin.getEmail())
                .type("SYSTEM")
                .fullName(admin.getName())
                .build())
            .build();
    }

    // ── Bước C: bước 2 của đăng nhập ─────────────────────────────────────

    private io.jsonwebtoken.Claims requireChallenge(AuthDTO.TwoFactorRequest req, String account, String purpose) {
        io.jsonwebtoken.Claims c = req == null || req.getChallengeToken() == null
            ? null : jwtUtil.parseChallenge(req.getChallengeToken());
        if (c == null || !account.equals(c.get("account")) || !purpose.equals(c.get("purpose"))) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.2fa.challenge_invalid");
        }
        return c;
    }

    private User challengeUser(io.jsonwebtoken.Claims c) {
        User user = userRepository.findByEmail(c.getSubject())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.2fa.challenge_invalid"));
        if (!user.isEnabled() || user.isDeleted() || !companyRepository.existsByIdAndActiveTrue(user.getCompanyId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.auth.account_disabled");
        }
        return user;
    }

    private SystemAdmin challengeAdmin(io.jsonwebtoken.Claims c) {
        SystemAdmin admin = systemAdminRepository.findByEmail(c.getSubject())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.2fa.challenge_invalid"));
        if (!admin.isEnabled()) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.auth.account_disabled");
        return admin;
    }

    /** Nhập mã 2FA (hoặc mã dự phòng); sai nhiều lần bị khoá như sai mật khẩu. */
    @Transactional
    public AuthDTO.LoginResponse verifyCompany(AuthDTO.TwoFactorRequest req) {
        var c = requireChallenge(req, "COMPANY", "VERIFY");
        loginAttemptService.checkNotLocked(c.getSubject());
        User user = challengeUser(c);
        if (!twoFactorService.check(user, req.getCode())) {
            loginAttemptService.recordFailure(c.getSubject());
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.2fa.invalid_code");
        }
        loginAttemptService.recordSuccess(c.getSubject());
        userRepository.save(user);
        return issueCompanyTokens(user, (String) c.get("deviceId"));
    }

    @Transactional
    public AuthDTO.TwoFactorSetupResponse setupCompany(AuthDTO.TwoFactorRequest req) {
        User user = challengeUser(requireChallenge(req, "COMPANY", "SETUP"));
        var setup = twoFactorService.beginSetup(user);
        userRepository.save(user);
        return setup;
    }

    @Transactional
    public AuthDTO.LoginResponse enableCompany(AuthDTO.TwoFactorRequest req) {
        var c = requireChallenge(req, "COMPANY", "SETUP");
        User user = challengeUser(c);
        List<String> codes = twoFactorService.enable(user, req.getCode());
        userRepository.save(user);
        var res = issueCompanyTokens(user, (String) c.get("deviceId"));
        res.setRecoveryCodes(codes);
        return res;
    }

    @Transactional
    public AuthDTO.LoginResponse verifySystem(AuthDTO.TwoFactorRequest req) {
        var c = requireChallenge(req, "SYSTEM", "VERIFY");
        String key = "system:" + c.getSubject();
        loginAttemptService.checkNotLocked(key);
        SystemAdmin admin = challengeAdmin(c);
        if (!twoFactorService.check(admin, req.getCode())) {
            loginAttemptService.recordFailure(key);
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.2fa.invalid_code");
        }
        loginAttemptService.recordSuccess(key);
        systemAdminRepository.save(admin);
        return issueSystemTokens(admin);
    }

    @Transactional
    public AuthDTO.TwoFactorSetupResponse setupSystem(AuthDTO.TwoFactorRequest req) {
        SystemAdmin admin = challengeAdmin(requireChallenge(req, "SYSTEM", "SETUP"));
        var setup = twoFactorService.beginSetup(admin);
        systemAdminRepository.save(admin);
        return setup;
    }

    @Transactional
    public AuthDTO.LoginResponse enableSystem(AuthDTO.TwoFactorRequest req) {
        SystemAdmin admin = challengeAdmin(requireChallenge(req, "SYSTEM", "SETUP"));
        List<String> codes = twoFactorService.enable(admin, req.getCode());
        systemAdminRepository.save(admin);
        var res = issueSystemTokens(admin);
        res.setRecoveryCodes(codes);
        return res;
    }
}
