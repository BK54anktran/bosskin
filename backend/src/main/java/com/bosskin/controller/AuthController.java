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

    // System admin login: POST /admin/auth/login
    @PostMapping("/admin/auth/login")
    public ResponseEntity<AuthDTO.LoginResponse> systemLogin(@Valid @RequestBody AuthDTO.LoginRequest request) {
        return ResponseEntity.ok(authService.systemLogin(request));
    }
}
