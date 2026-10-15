package com.bosskin.controller;

import com.bosskin.dto.CompanySettingDTO;
import com.bosskin.entity.User;
import com.bosskin.service.CompanySettingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@RestController
@RequestMapping("/api/v1/company-settings")
@RequiredArgsConstructor
public class CompanySettingController {

    private final CompanySettingService companySettingService;

    @GetMapping
    public ResponseEntity<CompanySettingDTO.Response> get(@AuthenticationPrincipal User user) {
        if (user == null || user.getCompany() == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        }
        var res = companySettingService.getByCompanyId(user.getCompany().getId());
        // Tỷ lệ bảo hiểm công ty đóng là số liệu lương: chỉ người xem lương hoặc quản lý cài đặt mới thấy
        if (res.getPayroll() != null && !user.hasPermission("PAYROLL_VIEW") && !user.hasPermission("COMPANY_SETTING_MANAGE")) {
            res.getPayroll().setEmployerSocialPercent(null);
            res.getPayroll().setEmployerHealthPercent(null);
            res.getPayroll().setEmployerUnemploymentPercent(null);
        }
        return ResponseEntity.ok(res);
    }

    @PutMapping
    public ResponseEntity<CompanySettingDTO.Response> update(
        @AuthenticationPrincipal User user,
        @Valid @RequestBody CompanySettingDTO.Upsert body
    ) {
        requirePermission(user, "COMPANY_SETTING_MANAGE");
        return ResponseEntity.ok(companySettingService.update(user.getCompany().getId(), body));
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }
}
