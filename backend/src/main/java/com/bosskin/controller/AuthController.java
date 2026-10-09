package com.bosskin.controller;

import com.bosskin.dto.AuthDTO;
import com.bosskin.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    // Company user login: POST /api/v1/auth/login
    @PostMapping("/api/v1/auth/login")
    public ResponseEntity<AuthDTO.LoginResponse> login(@Valid @RequestBody AuthDTO.LoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    // Refresh token: POST /api/v1/auth/refresh
    @PostMapping("/api/v1/auth/refresh")
    public ResponseEntity<AuthDTO.LoginResponse> refresh(@RequestBody AuthDTO.RefreshRequest request) {
        return ResponseEntity.ok(authService.refresh(request));
    }

    // Đăng xuất: POST /api/v1/auth/logout  { "refreshToken": "...", "fcmToken": "..." }
    @PostMapping("/api/v1/auth/logout")
    public ResponseEntity<Void> logout(@RequestBody(required = false) AuthDTO.LogoutRequest request) {
        authService.logout(request != null ? request.getRefreshToken() : null,
                           request != null ? request.getFcmToken() : null);
        return ResponseEntity.noContent().build();
    }

    // System admin login: POST /admin/auth/login
    @PostMapping("/admin/auth/login")
    public ResponseEntity<AuthDTO.LoginResponse> systemLogin(@Valid @RequestBody AuthDTO.LoginRequest request) {
        return ResponseEntity.ok(authService.systemLogin(request));
    }

    // ── Bước C: bước 2 đăng nhập (2FA) — dùng challengeToken nhận từ /login ──
    @PostMapping("/api/v1/auth/2fa/verify")
    public ResponseEntity<AuthDTO.LoginResponse> verify2fa(@RequestBody AuthDTO.TwoFactorRequest req) {
        return ResponseEntity.ok(authService.verifyCompany(req));
    }

    @PostMapping("/api/v1/auth/2fa/setup")
    public ResponseEntity<AuthDTO.TwoFactorSetupResponse> setup2fa(@RequestBody AuthDTO.TwoFactorRequest req) {
        return ResponseEntity.ok(authService.setupCompany(req));
    }

    @PostMapping("/api/v1/auth/2fa/enable")
    public ResponseEntity<AuthDTO.LoginResponse> enable2fa(@RequestBody AuthDTO.TwoFactorRequest req) {
        return ResponseEntity.ok(authService.enableCompany(req));
    }

    @PostMapping("/admin/auth/2fa/verify")
    public ResponseEntity<AuthDTO.LoginResponse> verifySystem2fa(@RequestBody AuthDTO.TwoFactorRequest req) {
        return ResponseEntity.ok(authService.verifySystem(req));
    }

    @PostMapping("/admin/auth/2fa/setup")
    public ResponseEntity<AuthDTO.TwoFactorSetupResponse> setupSystem2fa(@RequestBody AuthDTO.TwoFactorRequest req) {
        return ResponseEntity.ok(authService.setupSystem(req));
    }

    @PostMapping("/admin/auth/2fa/enable")
    public ResponseEntity<AuthDTO.LoginResponse> enableSystem2fa(@RequestBody AuthDTO.TwoFactorRequest req) {
        return ResponseEntity.ok(authService.enableSystem(req));
    }
}
