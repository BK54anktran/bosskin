package com.bosskin.config;

import com.bosskin.security.CompanyZoneInterceptor;
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
    private final CompanyZoneInterceptor companyZoneInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(featureRouteInterceptor).addPathPatterns("/api/v1/**");
        registry.addInterceptor(userLanguageInterceptor).addPathPatterns("/api/v1/**");
        // V32: múi giờ theo công ty cho cả request (đặt trước các interceptor khác dùng giờ)
        registry.addInterceptor(companyZoneInterceptor).addPathPatterns("/api/v1/**").order(-1);
    }
}
