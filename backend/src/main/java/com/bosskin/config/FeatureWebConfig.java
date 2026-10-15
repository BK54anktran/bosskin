package com.bosskin.config;

import com.bosskin.security.FeatureRouteInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** V26: gắn {@link FeatureRouteInterceptor} cho mọi API công ty. */
@Configuration
@RequiredArgsConstructor
public class FeatureWebConfig implements WebMvcConfigurer {

    private final FeatureRouteInterceptor featureRouteInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(featureRouteInterceptor).addPathPatterns("/api/v1/**");
    }
}
