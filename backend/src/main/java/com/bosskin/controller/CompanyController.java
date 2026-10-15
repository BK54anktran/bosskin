package com.bosskin.controller;

import com.bosskin.dto.AuthDTO;
import com.bosskin.dto.CompanyResponse;
import com.bosskin.dto.CreateCompanyRequest;
import com.bosskin.entity.Permission;
import com.bosskin.entity.SystemAdmin;
import com.bosskin.repository.PermissionRepository;
import com.bosskin.security.JwtUtil;
import com.bosskin.service.CompanyService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/admin/companies")
@RequiredArgsConstructor
public class CompanyController {

    private final CompanyService      companyService;
    private final PermissionRepository permissionRepository;
    private final JwtUtil             jwtUtil;
    private final com.bosskin.audit.AuditService audit;

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
        CompanyResponse created = companyService.create(req);
        audit.log("COMPANY_CREATE").company(created.getId()).entity("COMPANY", created.getId())
            .summary(created.getName() + " · admin " + req.getAdminEmail()).save();
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<CompanyResponse> update(@PathVariable Long id,
                                                   @RequestBody com.bosskin.dto.UpdateCompanyRequest req) {
        CompanyResponse updated = companyService.update(id, req);
        audit.log("COMPANY_UPDATE").company(id).entity("COMPANY", id).summary(updated.getName()).save();
        return ResponseEntity.ok(updated);
    }

    @PatchMapping("/{id}/toggle-active")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<Void> toggleActive(@PathVariable Long id) {
        companyService.toggleActive(id);
        audit.log("COMPANY_TOGGLE_ACTIVE").company(id).entity("COMPANY", id)
            .summary(String.valueOf(companyService.findById(id).isActive())).save();
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/impersonate")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<AuthDTO.LoginResponse> impersonate(
            @PathVariable Long id,
            @AuthenticationPrincipal SystemAdmin sysAdmin) {
        CompanyResponse company = companyService.findById(id);
        if (!company.isActive()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.company.inactive");
        }

        // Lấy toàn bộ permission codes của hệ thống → sysadmin có toàn quyền
        Set<String> allPermissions = permissionRepository.findAll().stream()
                .map(Permission::getCode)
                .collect(Collectors.toSet());

        // Token mang email sysadmin + companyId + toàn quyền
        String token = jwtUtil.generateImpersonateToken(sysAdmin.getEmail(), id, allPermissions);
        // Bước 2 — ghi nhật ký vào công ty bị impersonate để admin công ty cũng thấy
        audit.log("IMPERSONATE_START").company(id).entity("COMPANY", id)
            .summary(sysAdmin.getEmail() + " → " + company.getName()).save();

        return ResponseEntity.ok(AuthDTO.LoginResponse.builder()
                .accessToken(token)
                .tokenType("Bearer")
                .expiresIn(JwtUtil.IMPERSONATE_EXPIRATION_MS)
                .user(AuthDTO.UserInfo.builder()
                        .email(sysAdmin.getEmail())
                        .type("COMPANY")
                        .companyId(id)
                        .companyName(company.getName())
                        .companyCode(company.getCode())
                        .companyDomain(company.getDomain())
                        .modules(company.getModules())
                        .features(company.getFeatures())
                        .permissions(allPermissions)
                        .build())
                .build());
    }
}
