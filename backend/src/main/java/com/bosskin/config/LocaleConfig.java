package com.bosskin.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.LocaleResolver;
import org.springframework.web.servlet.i18n.AcceptHeaderLocaleResolver;

import java.util.List;
import java.util.Locale;

/**
 * Ngôn ngữ của request lấy từ header Accept-Language, chỉ nhận vi / en; thiếu hoặc ngôn ngữ khác → vi
 * (không để rơi về ngôn ngữ mặc định của JVM / container).
 */
@Configuration
public class LocaleConfig {

    public static final Locale VI = Locale.forLanguageTag("vi");
    public static final Locale EN = Locale.forLanguageTag("en");

    @Bean
    public LocaleResolver localeResolver() {
        AcceptHeaderLocaleResolver r = new AcceptHeaderLocaleResolver();
        r.setSupportedLocales(List.of(VI, EN));
        r.setDefaultLocale(VI);
        return r;
    }
}
