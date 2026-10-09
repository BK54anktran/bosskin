package com.bosskin.service.trial;

import com.bosskin.repository.TrialRequestRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Chọn nơi lưu yêu cầu dùng thử: Supabase nếu đủ URL + khoá bí mật, ngược lại MySQL của BossKin. */
@Slf4j
@Configuration
public class TrialRequestStoreConfig {
    @Bean
    TrialRequestStore trialRequestStore(@Value("${app.supabase.url:}") String url,
                                        @Value("${app.supabase.secret-key:}") String key,
                                        TrialRequestRepository repository, ObjectMapper json) {
        if (!url.isBlank() && !key.isBlank()) {
            log.info("Yêu cầu dùng thử: đọc/ghi Supabase {}", url);
            return new SupabaseTrialRequestStore(url, key, json);
        }
        return new JpaTrialRequestStore(repository);
    }
}
