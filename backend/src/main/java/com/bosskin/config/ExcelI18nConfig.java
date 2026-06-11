package com.bosskin.config;

import com.bosskin.util.ExcelI18n;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.support.ResourceBundleMessageSource;

@Configuration
public class ExcelI18nConfig {

    @Bean
    public ResourceBundleMessageSource excelMessageSource() {
        ResourceBundleMessageSource source = new ResourceBundleMessageSource();
        source.setBasename("excel");
        source.setDefaultEncoding("UTF-8");
        source.setUseCodeAsDefaultMessage(true);
        return source;
    }

    @Bean
    public ExcelI18n excelI18n(ResourceBundleMessageSource excelMessageSource) {
        return new ExcelI18n(excelMessageSource);
    }
}
