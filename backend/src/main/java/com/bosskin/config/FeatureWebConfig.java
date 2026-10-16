package com.bosskin.config;

import com.bosskin.security.FeatureRouteInterceptor;
import com.bosskin.security.UserLanguageInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** V26: gắn {@link FeatureRouteInterceptor} cho mọi API công ty. */
@Configuration
@RequiredArgsConstructor
public class FeatureWebConfig implements WebMvcConfigurer {

    private final FeatureRouteInterceptor featureRouteInterceptor;
    private final UserLanguageInterceptor userLanguageInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(featureRouteInterceptor).addPathPatterns("/api/v1/**");
        registry.addInterceptor(userLanguageInterceptor).addPathPatterns("/api/v1/**");
    }
}
