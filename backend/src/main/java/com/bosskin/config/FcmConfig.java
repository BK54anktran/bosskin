package com.bosskin.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import jakarta.annotation.PostConstruct;

import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

/**
 * Khởi tạo Firebase Admin (gửi push FCM).
 *
 * Khoá service account không nằm trong git; đọc từ một trong hai nguồn:
 * <ol>
 *   <li>{@code FIREBASE_SERVICE_ACCOUNT_JSON} — nội dung JSON, hoặc base64 của JSON;</li>
 *   <li>{@code FIREBASE_SERVICE_ACCOUNT_PATH} — đường dẫn file trên máy chủ.</li>
 * </ol>
 * Không có cả hai thì app vẫn chạy, chỉ tắt push.
 */
@Configuration
@Slf4j
public class FcmConfig {

    @Value("${app.firebase.service-account-json:}")
    private String serviceAccountJson;

    @Value("${app.firebase.service-account-path:}")
    private String serviceAccountPath;

    @PostConstruct
    public void initFirebase() {
        if (!FirebaseApp.getApps().isEmpty()) return;
        try (InputStream in = openCredentials()) {
            if (in == null) {
                log.warn("Chưa cấu hình FIREBASE_SERVICE_ACCOUNT_JSON / FIREBASE_SERVICE_ACCOUNT_PATH — tắt push notification");
                return;
            }
            FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.fromStream(in))
                .build();
            FirebaseApp.initializeApp(options);
            log.info("Firebase initialized successfully");
        } catch (IOException | IllegalArgumentException e) {
            log.warn("Không đọc được khoá Firebase ({}) — tắt push notification", e.getMessage());
        }
    }

    private InputStream openCredentials() throws IOException {
        if (serviceAccountJson != null && !serviceAccountJson.isBlank()) {
            String raw = serviceAccountJson.trim();
            byte[] bytes = raw.startsWith("{")
                ? raw.getBytes(StandardCharsets.UTF_8)
                : Base64.getDecoder().decode(raw);
            return new ByteArrayInputStream(bytes);
        }
        if (serviceAccountPath != null && !serviceAccountPath.isBlank()) {
            return new FileInputStream(serviceAccountPath);
        }
        return null;
    }
}
