package com.bosskin.service;

import com.bosskin.core.Totp;
import com.bosskin.core.TwoFactorHolder;
import com.bosskin.dto.AuthDTO;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.security.SecureRandom;
import java.time.Clock;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/**
 * Bước C — xác thực 2 lớp TOTP dùng chung cho tài khoản công ty và system admin.
 * Lưu khoá TOTP (base32) và mã dự phòng đã băm; không lưu mã dự phòng dạng rõ.
 */
@Service
@RequiredArgsConstructor
public class TwoFactorService {

    public static final String ISSUER = "BossKin";
    private static final int RECOVERY_CODES = 8;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final PasswordEncoder passwordEncoder;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    /** Tạo khoá mới (chưa bật) — người dùng quét QR rồi nhập mã ở {@link #enable}. */
    public AuthDTO.TwoFactorSetupResponse beginSetup(TwoFactorHolder h) {
        if (h.isTotpEnabled()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.2fa.already_enabled");
        }
        String secret = Totp.generateSecret();
        h.setTotpSecret(secret);
        return AuthDTO.TwoFactorSetupResponse.builder()
            .secret(secret)
            .otpauthUri(Totp.uri(ISSUER, h.getEmail(), secret))
            .build();
    }

    /** Nhập đúng mã đầu tiên → bật 2FA, trả mã dự phòng (chỉ hiện một lần). */
    public List<String> enable(TwoFactorHolder h, String code) {
        if (h.isTotpEnabled()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.2fa.already_enabled");
        }
        if (h.getTotpSecret() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.2fa.setup_not_started");
        }
        if (!Totp.verify(h.getTotpSecret(), code, clock.instant())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.2fa.invalid_code");
        }
        h.setTotpEnabled(true);
        return newRecoveryCodes(h);
    }

    /** Kiểm mã khi đăng nhập: mã TOTP, hoặc mã dự phòng (dùng xong là mất). */
    public boolean check(TwoFactorHolder h, String code) {
        if (!h.isTotpEnabled() || code == null) return false;
        if (Totp.verify(h.getTotpSecret(), code, clock.instant())) return true;
        String norm = code.trim().toLowerCase();
        List<String> hashes = readHashes(h);
        for (Iterator<String> it = hashes.iterator(); it.hasNext(); ) {
            if (passwordEncoder.matches(norm, it.next())) {
                it.remove();
                writeHashes(h, hashes);
                return true;
            }
        }
        return false;
    }

    public void disable(TwoFactorHolder h) {
        h.setTotpEnabled(false);
        h.setTotpSecret(null);
        h.setTotpRecoveryCodes(null);
    }

    public int recoveryCodesLeft(TwoFactorHolder h) {
        return h.isTotpEnabled() ? readHashes(h).size() : 0;
    }

    private List<String> newRecoveryCodes(TwoFactorHolder h) {
        List<String> plain = new ArrayList<>();
        List<String> hashes = new ArrayList<>();
        String alphabet = "abcdefghjkmnpqrstuvwxyz23456789";
        for (int i = 0; i < RECOVERY_CODES; i++) {
            StringBuilder sb = new StringBuilder();
            for (int j = 0; j < 8; j++) {
                if (j == 4) sb.append('-');
                sb.append(alphabet.charAt(RANDOM.nextInt(alphabet.length())));
            }
            plain.add(sb.toString());
            hashes.add(passwordEncoder.encode(sb.toString()));
        }
        writeHashes(h, hashes);
        return plain;
    }

    private List<String> readHashes(TwoFactorHolder h) {
        if (h.getTotpRecoveryCodes() == null || h.getTotpRecoveryCodes().isBlank()) return new ArrayList<>();
        try {
            return new ArrayList<>(objectMapper.readValue(h.getTotpRecoveryCodes(), new TypeReference<List<String>>() {}));
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    private void writeHashes(TwoFactorHolder h, List<String> hashes) {
        try {
            h.setTotpRecoveryCodes(objectMapper.writeValueAsString(hashes));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
