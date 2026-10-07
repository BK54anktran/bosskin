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

    // ── Company user login ──────────────────────────────────────────────
    @Transactional
    public AuthDTO.LoginResponse login(AuthDTO.LoginRequest req) {
        User user = userRepository.findByEmail(req.getEmail())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Email hoặc mật khẩu không đúng"));

        if (!passwordEncoder.matches(req.getPassword(), user.getPassword())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Email hoặc mật khẩu không đúng");
        }
        if (!user.isEnabled()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Tài khoản đã bị khóa");
        }
        if (!companyRepository.existsByIdAndActiveTrue(user.getCompanyId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.company.inactive");
        }

        String deviceId = req.getDeviceId() != null ? req.getDeviceId() : UUID.randomUUID().toString();
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
                .fullName(user.getEmployee() != null ? user.getEmployee().getFullName() : null)
                .avatar(user.getEmployee() != null ? user.getEmployee().getAvatar() : null)
                .employeeId(user.getEmployee() != null ? user.getEmployee().getId() : null)
                .permissions(user.getPermissions())
                .departmentScope(deptScopeRepo.findScopesMap(user.getId()))
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

        String jti      = (String) claims.get("jti");
        String deviceId = (String) claims.get("deviceId");
        String email    = claims.getSubject();

        UserSession session = userSessionRepository.findByJti(jti)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Session không hợp lệ"));

        if (session.isRevoked()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Session đã bị thu hồi");
        }
        if (req.getDeviceId() != null && !req.getDeviceId().equals(deviceId)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Thiết bị không khớp");
        }

        // Rotate: revoke old session, create new one
        session.setRevoked(true);
        userSessionRepository.save(session);

        User user = userRepository.findByEmail(email)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Người dùng không tồn tại"));

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
                .fullName(user.getEmployee() != null ? user.getEmployee().getFullName() : null)
                .avatar(user.getEmployee() != null ? user.getEmployee().getAvatar() : null)
                .employeeId(user.getEmployee() != null ? user.getEmployee().getId() : null)
                .permissions(user.getPermissions())
                .departmentScope(deptScopeRepo.findScopesMap(user.getId()))
                .build())
            .build();
    }

    // ── System admin login ──────────────────────────────────────────────
    public AuthDTO.LoginResponse systemLogin(AuthDTO.LoginRequest req) {
        SystemAdmin admin = systemAdminRepository.findByEmail(req.getEmail())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Email hoặc mật khẩu không đúng"));

        if (!passwordEncoder.matches(req.getPassword(), admin.getPassword())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Email hoặc mật khẩu không đúng");
        }
        if (!admin.isEnabled()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Tài khoản đã bị khóa");
        }

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
}
