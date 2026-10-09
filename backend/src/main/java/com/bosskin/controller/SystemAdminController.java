package com.bosskin.controller;

import com.bosskin.entity.SystemAdmin;
import com.bosskin.service.SystemAdminService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Quản lý tài khoản system admin — chỉ system admin. Mật khẩu sinh tự động, chỉ trả về một lần. */
@RestController
@RequestMapping("/admin/system-admins")
@PreAuthorize("hasRole('SYSTEM_ADMIN')")
@RequiredArgsConstructor
public class SystemAdminController {

    private final SystemAdminService service;

    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> list(@AuthenticationPrincipal SystemAdmin me) {
        return ResponseEntity.ok(service.list().stream().sorted(Comparator.comparing(SystemAdmin::getId))
            .map(a -> view(a, me)).toList());
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> create(@RequestBody Map<String, String> body, @AuthenticationPrincipal SystemAdmin me) {
        var r = service.create(body.get("email"), body.get("name"));
        Map<String, Object> out = view(r.getKey(), me);
        out.put("password", r.getValue());
        return ResponseEntity.status(HttpStatus.CREATED).body(out);
    }

    @PatchMapping("/{id}/enabled")
    public ResponseEntity<Map<String, Object>> enabled(@PathVariable Long id, @RequestBody Map<String, Boolean> body,
                                                       @AuthenticationPrincipal SystemAdmin me) {
        return ResponseEntity.ok(view(service.setEnabled(id, Boolean.TRUE.equals(body.get("enabled")), me), me));
    }

    @PostMapping("/{id}/reset-password")
    public ResponseEntity<Map<String, String>> resetPassword(@PathVariable Long id, @AuthenticationPrincipal SystemAdmin me) {
        return ResponseEntity.ok(Map.of("password", service.resetPassword(id, me)));
    }

    @PostMapping("/{id}/reset-2fa")
    public ResponseEntity<Map<String, Object>> reset2fa(@PathVariable Long id, @AuthenticationPrincipal SystemAdmin me) {
        return ResponseEntity.ok(view(service.reset2fa(id, me), me));
    }

    private static Map<String, Object> view(SystemAdmin a, SystemAdmin me) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", a.getId()); m.put("email", a.getEmail()); m.put("name", a.getName());
        m.put("enabled", a.isEnabled()); m.put("totpEnabled", a.isTotpEnabled());
        m.put("createdAt", a.getCreatedAt()); m.put("self", me != null && a.getId().equals(me.getId()));
        return m;
    }
}
