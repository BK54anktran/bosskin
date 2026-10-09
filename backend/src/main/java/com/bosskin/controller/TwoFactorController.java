package com.bosskin.controller;

import com.bosskin.audit.AuditService;
import com.bosskin.dto.AuthDTO;
import com.bosskin.entity.Company;
import com.bosskin.entity.User;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.UserRepository;
import com.bosskin.security.SysAdminImpersonateUser;
import com.bosskin.service.TwoFactorService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

/**
 * Bước C — quản lý 2FA của chính mình (hồ sơ), gỡ 2FA cho người khác (mất điện thoại),
 * và system admin bắt buộc 2FA với quản trị của một công ty.
 */
@RestController
@RequiredArgsConstructor
public class TwoFactorController {

    private final UserRepository userRepository;
    private final CompanyRepository companyRepository;
    private final TwoFactorService twoFactorService;
    private final PasswordEncoder passwordEncoder;
    private final AuditService audit;

    private User me(User principal) {
        if (principal == null || principal instanceof SysAdminImpersonateUser || principal.getId() == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return userRepository.findById(principal.getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.user.not_found"));
    }

    private static boolean requiredFor(User u) {
        return u.getCompany() != null && u.getCompany().isRequireAdmin2fa() && u.hasPermission("ROLE_MANAGE");
    }

    @GetMapping("/api/v1/profile/2fa")
    public ResponseEntity<AuthDTO.TwoFactorStatus> status(@AuthenticationPrincipal User principal) {
        User u = me(principal);
        return ResponseEntity.ok(AuthDTO.TwoFactorStatus.builder()
            .enabled(u.isTotpEnabled()).required(requiredFor(u))
            .recoveryCodesLeft(twoFactorService.recoveryCodesLeft(u)).build());
    }

    @PostMapping("/api/v1/profile/2fa/setup")
    @Transactional
    public ResponseEntity<AuthDTO.TwoFactorSetupResponse> setup(@AuthenticationPrincipal User principal) {
        User u = me(principal);
        var res = twoFactorService.beginSetup(u);
        userRepository.save(u);
        return ResponseEntity.ok(res);
    }

    @PostMapping("/api/v1/profile/2fa/enable")
    @Transactional
    public ResponseEntity<Map<String, List<String>>> enable(@AuthenticationPrincipal User principal,
                                                           @RequestBody AuthDTO.TwoFactorRequest req) {
        User u = me(principal);
        List<String> codes = twoFactorService.enable(u, req.getCode());
        userRepository.save(u);
        audit.log("2FA_ENABLE").entity("USER", u.getId()).summary(u.getEmail()).save();
        return ResponseEntity.ok(Map.of("recoveryCodes", codes));
    }

    /** Tắt 2FA: cần mật khẩu + mã hiện tại; công ty bắt buộc thì không tắt được. */
    @PostMapping("/api/v1/profile/2fa/disable")
    @Transactional
    public ResponseEntity<Void> disable(@AuthenticationPrincipal User principal,
                                        @RequestBody AuthDTO.TwoFactorRequest req) {
        User u = me(principal);
        if (requiredFor(u)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.2fa.required_by_company");
        if (req.getPassword() == null || !passwordEncoder.matches(req.getPassword(), u.getPassword())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.password.current_wrong");
        }
        if (!twoFactorService.check(u, req.getCode())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.2fa.invalid_code");
        }
        twoFactorService.disable(u);
        userRepository.save(u);
        audit.log("2FA_DISABLE").entity("USER", u.getId()).summary(u.getEmail()).save();
        return ResponseEntity.noContent().build();
    }

    /** Gỡ 2FA của nhân viên mất điện thoại (quyền USER_MANAGE, cùng công ty, không tự gỡ cho mình). */
    @DeleteMapping("/api/v1/users/{id}/2fa")
    @Transactional
    public ResponseEntity<Void> reset(@PathVariable Long id, @AuthenticationPrincipal User caller) {
        if (caller == null || !caller.hasPermission("USER_MANAGE")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        User u = userRepository.findById(id)
            .filter(x -> x.getCompanyId() != null && x.getCompanyId().equals(caller.getCompanyId()))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.user.not_found"));
        if (caller.getId() != null && caller.getId().equals(u.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.cannot_change_own");
        }
        twoFactorService.disable(u);
        userRepository.save(u);
        audit.log("2FA_RESET").entity("USER", u.getId()).summary(u.getEmail()).save();
        return ResponseEntity.noContent().build();
    }

    /** System admin bật/tắt bắt buộc 2FA với quản trị (ROLE_MANAGE) của một công ty. */
    @PutMapping("/admin/companies/{id}/require-admin-2fa")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    @Transactional
    public ResponseEntity<Map<String, Boolean>> requireAdmin2fa(@PathVariable Long id,
                                                                @RequestBody Map<String, Boolean> body) {
        Company c = companyRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));
        boolean required = Boolean.TRUE.equals(body.get("required"));
        c.setRequireAdmin2fa(required);
        companyRepository.save(c);
        audit.log("COMPANY_REQUIRE_2FA").company(id).entity("COMPANY", id)
            .summary(c.getName() + " · " + required).save();
        return ResponseEntity.ok(Map.of("required", required));
    }
}
