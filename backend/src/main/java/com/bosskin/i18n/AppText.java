package com.bosskin.i18n;

import com.bosskin.config.LocaleConfig;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.stereotype.Component;

import java.util.Locale;

/**
 * Chữ hiển thị do server sinh ra (nhãn biến lương, nhãn xem trước nhập, thông báo đẩy, dữ liệu mặc định…) theo ngôn ngữ.
 * Khoá trong {@code messages_vi.properties} / {@code messages_en.properties} (hai file phải đủ khoá như nhau — có test).
 * Thông báo lỗi cho app vẫn là mã {@code error.*} do app dịch, không đi qua đây.
 */
@Component
public class AppText {

    private final ResourceBundleMessageSource source = new ResourceBundleMessageSource();

    private static volatile AppText instance;

    public AppText() {
        instance = this;
        source.setBasename("messages");
        source.setDefaultEncoding("UTF-8");
        source.setUseCodeAsDefaultMessage(true);
        source.setFallbackToSystemLocale(false);
    }

    /**
     * Dùng ở chỗ không tiêm được bean (parser công thức tĩnh…): chữ theo ngôn ngữ của request đang xử lý.
     * Chạy ngoài Spring (test thuần) vẫn dùng được nhờ bản mặc định.
     */
    public static String msg(String key, Object... args) {
        AppText i = instance;
        if (i == null) { i = new AppText(); }
        return i.t(key, args);
    }

    /** Theo ngôn ngữ của request đang xử lý (Accept-Language; mặc định vi). */
    public String t(String key, Object... args) {
        return t(key, LocaleContextHolder.getLocale(), args);
    }

    public String t(String key, Locale locale, Object... args) {
        Locale l = locale != null && "en".equalsIgnoreCase(locale.getLanguage()) ? LocaleConfig.EN : LocaleConfig.VI;
        return source.getMessage(key, args.length == 0 ? null : args, l);
    }

    /** Ngôn ngữ lưu của người dùng (null / lạ → vi). */
    public static Locale localeOf(String language) {
        return "en".equalsIgnoreCase(language) ? LocaleConfig.EN : LocaleConfig.VI;
    }
}
