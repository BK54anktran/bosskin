package com.bosskin.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * CHỈ DÙNG Ở MÁY DEV: xoá sạch schema rồi chạy lại toàn bộ migration khi khởi động.
 * Bật bằng BOSSKIN_DEV_RESET_DB=true và SPRING_FLYWAY_CLEAN_DISABLED=false
 * (dev\reset-db.cmd đặt sẵn hai biến này cho đúng một lần chạy).
 * Không có hai biến đó thì bean này không tồn tại; Flyway mặc định cấm clean.
 */
@Slf4j
@Configuration
@ConditionalOnProperty(name = "bosskin.dev.reset-db", havingValue = "true")
public class DevDbResetConfig {

    @Bean
    public FlywayMigrationStrategy cleanThenMigrate() {
        return flyway -> {
            log.warn("bosskin.dev.reset-db=true → XOÁ toàn bộ schema rồi chạy lại migration");
            flyway.clean();
            flyway.migrate();
        };
    }
}
