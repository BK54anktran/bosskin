package com.bosskin.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;
import java.time.ZoneId;

/**
 * Đồng hồ dùng chung cho nghiệp vụ chấm công. Code nghiệp vụ lấy giờ qua bean này
 * (LocalDateTime.now(clock)) thay vì gọi now() trực tiếp, để test giả lập được giờ
 * (ca đêm, đi muộn, khoá kỳ…).
 */
@Configuration
public class ClockConfig {

    /** Múi giờ mặc định (Việt Nam); múi giờ thực dùng theo công ty của request, xem {@link com.bosskin.core.CompanyZone}. */
    public static final ZoneId ZONE = com.bosskin.core.CompanyZone.DEFAULT;

    @Bean
    public Clock clock() {
        return com.bosskin.core.CompanyZone.clock();
    }
}
