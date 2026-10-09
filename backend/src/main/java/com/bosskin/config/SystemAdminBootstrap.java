package com.bosskin.config;

import com.bosskin.entity.SystemAdmin;
import com.bosskin.repository.SystemAdminRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Tạo system admin đầu tiên khi DB chưa có ai, từ biến môi trường
 * BOOTSTRAP_SYSADMIN_EMAIL / BOOTSTRAP_SYSADMIN_PASSWORD.
 *
 * Thay cho tài khoản seed cũ trong migration (mật khẩu hash nằm công khai trong repo).
 * Đã có system admin thì không làm gì, nên có thể gỡ biến môi trường sau lần chạy đầu.
 *
 * Thêm một system admin ngay trong DB lúc khởi động (vd. mất quyền vào mọi tài khoản admin, hoặc thêm người mới
 * khi chưa vào được /admin): BOOTSTRAP_ADD_SYSADMIN_EMAIL / BOOTSTRAP_ADD_SYSADMIN_PASSWORD — chỉ tạo khi email
 * chưa có, không bao giờ sửa tài khoản đang có. Người đó phải cài 2FA ở lần đăng nhập đầu.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SystemAdminBootstrap implements ApplicationRunner {

    private static final int MIN_PASSWORD_LENGTH = 12;

    private final SystemAdminRepository systemAdminRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.bootstrap.sysadmin-email:}")
    private String email;

    @Value("${app.bootstrap.sysadmin-password:}")
    private String password;

    @Value("${app.bootstrap.add-sysadmin-email:}")
    private String addEmail;

    @Value("${app.bootstrap.add-sysadmin-password:}")
    private String addPassword;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        createFirst();
        addExtra();
    }

    private void addExtra() {
        if (addEmail == null || addEmail.isBlank()) return;
        String e = addEmail.trim().toLowerCase();
        if (systemAdminRepository.existsByEmail(e)) return;
        if (addPassword == null || addPassword.length() < MIN_PASSWORD_LENGTH) {
            throw new IllegalStateException(
                "BOOTSTRAP_ADD_SYSADMIN_PASSWORD phải dài ít nhất " + MIN_PASSWORD_LENGTH + " ký tự");
        }
        systemAdminRepository.save(SystemAdmin.builder()
            .email(e).password(passwordEncoder.encode(addPassword)).name(e).enabled(true).build());
        log.info("Đã thêm system admin từ BOOTSTRAP_ADD_SYSADMIN_EMAIL: {}", e);
    }

    private void createFirst() {
        if (systemAdminRepository.count() > 0) return;

        if (email == null || email.isBlank() || password == null || password.isBlank()) {
            log.warn("Chưa có system admin nào. Đặt BOOTSTRAP_SYSADMIN_EMAIL và "
                + "BOOTSTRAP_SYSADMIN_PASSWORD rồi khởi động lại để tạo tài khoản đầu tiên.");
            return;
        }
        if (password.length() < MIN_PASSWORD_LENGTH) {
            throw new IllegalStateException(
                "BOOTSTRAP_SYSADMIN_PASSWORD phải dài ít nhất " + MIN_PASSWORD_LENGTH + " ký tự");
        }

        systemAdminRepository.save(SystemAdmin.builder()
            .email(email.trim().toLowerCase())
            .password(passwordEncoder.encode(password))
            .name("System Administrator")
            .enabled(true)
            .build());
        log.info("Đã tạo system admin đầu tiên: {}", email);
    }
}
