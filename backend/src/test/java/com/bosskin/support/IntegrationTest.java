package com.bosskin.support;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;

/**
 * Lớp cha cho integration test: Spring context đầy đủ + MySQL 8 thật (Testcontainers)
 * + toàn bộ migration Flyway.
 *
 * Container được khởi động một lần cho cả lượt chạy test (singleton) để test nhanh.
 * Mỗi test tự tạo công ty riêng qua {@link Fixture}, nên các test không đụng dữ liệu nhau
 * và không cần dọn DB.
 *
 * Cần Docker. Trên GitHub Actions (ubuntu-latest) Docker có sẵn.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import({Fixture.class, Api.class, IntegrationTest.TestClockConfig.class})
public abstract class IntegrationTest {

    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
        .withDatabaseName("bosskin")
        .withUrlParam("serverTimezone", "Asia/Ho_Chi_Minh")
        .withUrlParam("allowPublicKeyRetrieval", "true")
        .withUrlParam("useSSL", "false");

    static {
        // Như BosskinApplication.main — máy chạy test (CI) thường để UTC, createdAt sẽ lệch 7 giờ so với clock nghiệp vụ
        java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
        MYSQL.start();
    }

    @Autowired
    protected Fixture fixture;

    @Autowired
    protected Api api;

    /** Giả lập giờ cho nghiệp vụ chấm công: {@code clock.set(LocalDateTime.of(...))}. */
    @Autowired
    protected MutableClock clock;

    @org.junit.jupiter.api.BeforeEach
    void resetClock() {
        clock.reset();
    }

    @org.springframework.boot.test.context.TestConfiguration
    static class TestClockConfig {
        @org.springframework.context.annotation.Bean
        @org.springframework.context.annotation.Primary
        MutableClock mutableClock() {
            return new MutableClock();
        }
    }
}
