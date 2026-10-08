package com.bosskin;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableJpaAuditing
@EnableScheduling
public class BosskinApplication {
    public static void main(String[] args) {
        // Mọi LocalDate.now()/LocalDateTime.now() và lịch @Scheduled chạy theo giờ Việt Nam,
        // không phụ thuộc múi giờ của máy chủ (EB mặc định UTC)
        java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
        SpringApplication.run(BosskinApplication.class, args);
    }
}
