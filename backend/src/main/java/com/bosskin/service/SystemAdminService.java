package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.entity.SystemAdmin;
import com.bosskin.repository.SystemAdminRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Quản lý tài khoản system admin (trang /admin). Mật khẩu do hệ thống sinh, chỉ trả về một lần;
 * tài khoản mới phải cài 2FA ở lần đăng nhập đầu (REQUIRE_SYSADMIN_2FA).
 */
@Service
@RequiredArgsConstructor
public class SystemAdminService {

    private static final Pattern EMAIL = Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$");

    private final SystemAdminRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final AuditService audit;

    public List<SystemAdmin> list() { return repository.findAll(); }

    /** @return [tài khoản, mật khẩu thô] */
    @Transactional
    public Map.Entry<SystemAdmin, String> create(String email, String name) {
        String e = email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
        if (!EMAIL.matcher(e).matches() || e.length() > 100) throw bad("error.sysadmin.email_invalid");
        if (repository.existsByEmail(e)) throw new ResponseStatusException(HttpStatus.CONFLICT, "error.email.in_use");
        String n = name == null || name.isBlank() ? e : name.trim();
        String pw = generatePassword();
        SystemAdmin a = repository.save(SystemAdmin.builder().email(e).name(n.length() > 100 ? n.substring(0, 100) : n)
            .password(passwordEncoder.encode(pw)).enabled(true).build());
        audit.log("SYSADMIN_CREATE").entity("SYSTEM_ADMIN", a.getId()).summary(e).save();
        return Map.entry(a, pw);
    }

    @Transactional
    public SystemAdmin setEnabled(Long id, boolean enabled, SystemAdmin caller) {
        SystemAdmin a = get(id);
        if (!enabled) {
            if (a.getId().equals(caller.getId())) throw bad("error.sysadmin.cannot_change_self");
            long active = repository.findAll().stream().filter(SystemAdmin::isEnabled).count();
            if (a.isEnabled() && active <= 1) throw bad("error.sysadmin.last_active");
        }
        a.setEnabled(enabled);
        repository.save(a);
        audit.log(enabled ? "SYSADMIN_ENABLE" : "SYSADMIN_DISABLE").entity("SYSTEM_ADMIN", a.getId()).summary(a.getEmail()).save();
        return a;
    }

    @Transactional
    public String resetPassword(Long id, SystemAdmin caller) {
        SystemAdmin a = get(id);
        if (a.getId().equals(caller.getId())) throw bad("error.sysadmin.cannot_change_self");
        String pw = generatePassword();
        a.setPassword(passwordEncoder.encode(pw));
        repository.save(a);
        audit.log("SYSADMIN_RESET_PASSWORD").entity("SYSTEM_ADMIN", a.getId()).summary(a.getEmail()).save();
        return pw;
    }

    /** Gỡ 2FA khi người đó mất điện thoại — lần đăng nhập tới phải cài lại. */
    @Transactional
    public SystemAdmin reset2fa(Long id, SystemAdmin caller) {
        SystemAdmin a = get(id);
        if (a.getId().equals(caller.getId())) throw bad("error.sysadmin.cannot_change_self");
        a.setTotpEnabled(false); a.setTotpSecret(null); a.setTotpRecoveryCodes(null);
        repository.save(a);
        audit.log("SYSADMIN_RESET_2FA").entity("SYSTEM_ADMIN", a.getId()).summary(a.getEmail()).save();
        return a;
    }

    /** 16 ký tự, đủ chữ thường/hoa/số/ký hiệu, bỏ ký tự dễ nhầm (l, 1, O, 0). */
    static String generatePassword() {
        return com.bosskin.core.PasswordPolicy.generate(16);
    }

    private SystemAdmin get(Long id) {
        return repository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.sysadmin.not_found"));
    }
    private static ResponseStatusException bad(String k) { return new ResponseStatusException(HttpStatus.BAD_REQUEST, k); }
}
