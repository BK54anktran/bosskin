package com.bosskin.controller;

import com.bosskin.entity.User;
import com.bosskin.service.MapLinkService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

/** Công cụ vị trí cho ô chọn toạ độ check-in (cài đặt công ty / phòng ban / vị trí nhân viên). */
@RestController
@RequestMapping("/api/v1/geo")
@RequiredArgsConstructor
public class GeoController {

    private final MapLinkService mapLinkService;

    @Getter @Setter
    public static class ResolveRequest {
        @NotBlank @Size(max = 2000)
        private String url;
    }

    /** Link Google Maps (hoặc "vĩ độ, kinh độ") → {latitude, longitude}. Cần một trong các quyền sửa vị trí check-in. */
    @PostMapping("/resolve-maps-link")
    public ResponseEntity<Map<String, Double>> resolveMapsLink(@AuthenticationPrincipal User user,
                                                               @Valid @RequestBody ResolveRequest body) {
        requireAnyPermission(user, "COMPANY_SETTING_MANAGE", "DEPARTMENT_MANAGE", "EMPLOYEE_UPDATE");
        var p = mapLinkService.resolve(user.getId(), body.getUrl());
        return ResponseEntity.ok(Map.of("latitude", p.lat(), "longitude", p.lng()));
    }

    private void requireAnyPermission(User user, String... perms) {
        if (user != null) for (String p : perms) if (user.hasPermission(p)) return;
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }
}
