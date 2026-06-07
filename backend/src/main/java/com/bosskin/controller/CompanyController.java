package com.bosskin.controller;

import com.bosskin.dto.AuthDTO;
import com.bosskin.dto.CompanyResponse;
import com.bosskin.dto.CreateCompanyRequest;
import com.bosskin.entity.User;
import com.bosskin.repository.UserRepository;
import com.bosskin.security.JwtUtil;
import com.bosskin.service.CompanyService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@RestController
@RequestMapping("/admin/companies")
@RequiredArgsConstructor
public class CompanyController {

    private final CompanyService companyService;
    private final UserRepository userRepository;
    private final JwtUtil        jwtUtil;

    @GetMapping
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<List<CompanyResponse>> getAll() {
        return ResponseEntity.ok(companyService.findAll());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<CompanyResponse> getById(@PathVariable Long id) {
        return ResponseEntity.ok(companyService.findById(id));
    }

    @PostMapping
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<CompanyResponse> create(@Valid @RequestBody CreateCompanyRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(companyService.create(req));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<CompanyResponse> update(@PathVariable Long id,
                                                   @Valid @RequestBody CreateCompanyRequest req) {
        return ResponseEntity.ok(companyService.update(id, req));
    }

    @PatchMapping("/{id}/toggle-active")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<Void> toggleActive(@PathVariable Long id) {
        companyService.toggleActive(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/impersonate")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<AuthDTO.LoginResponse> impersonate(@PathVariable Long id) {
        CompanyResponse company = companyService.findById(id);
        if (!company.isActive()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.company.inactive"); // frontend translates key
        }
        User admin = userRepository.findFirstByCompanyId(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Công ty chưa có user nào"));
        String token = jwtUtil.generateImpersonateToken(
            admin.getEmail(), id, admin.getPermissions());
        return ResponseEntity.ok(AuthDTO.LoginResponse.builder()
            .accessToken(token)
            .tokenType("Bearer")
            .expiresIn(jwtUtil.getExpiration())
            .user(AuthDTO.UserInfo.builder()
                .email(admin.getEmail())
                .type("COMPANY")
                .companyId(id)
                .companyName(companyService.findById(id).getName())
                .permissions(admin.getPermissions())
                .build())
            .build());
    }
}
