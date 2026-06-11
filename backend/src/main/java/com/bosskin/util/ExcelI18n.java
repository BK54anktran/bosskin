package com.bosskin.util;

import org.springframework.context.support.ResourceBundleMessageSource;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Resolve tên cột / tên sheet Excel theo locale.
 * Inject vào service/controller cần export — không dùng static để Spring quản lý.
 */
public class ExcelI18n {

    private static final List<Locale> SUPPORTED_LOCALES = List.of(
            Locale.forLanguageTag("vi"),
            Locale.forLanguageTag("en")
    );

    private final ResourceBundleMessageSource messageSource;

    public ExcelI18n(ResourceBundleMessageSource messageSource) {
        this.messageSource = messageSource;
    }

    /** Resolve key theo locale request, fallback về vi nếu không có. */
    public String resolve(String key, Locale locale) {
        String result = messageSource.getMessage(key, null, locale);
        // useCodeAsDefaultMessage=true nên nếu không có thì trả key — fallback về vi
        if (result.equals(key)) {
            return messageSource.getMessage(key, null, Locale.forLanguageTag("vi"));
        }
        return result;
    }

    /** Resolve key với MessageFormat args (ví dụ: "excel.sheet.attendance.month", "05-2025"). */
    public String resolve(String key, Locale locale, Object... args) {
        String result = messageSource.getMessage(key, args, locale);
        if (result.equals(key)) {
            return messageSource.getMessage(key, args, Locale.forLanguageTag("vi"));
        }
        return result;
    }

    /** Trả về tất cả bản dịch của key (dùng khi import để match bất kỳ ngôn ngữ nào). */
    public List<String> allValues(String key) {
        List<String> values = new ArrayList<>();
        for (Locale locale : SUPPORTED_LOCALES) {
            String val = messageSource.getMessage(key, null, locale);
            if (!val.equals(key) && !values.contains(val)) {
                values.add(val);
            }
        }
        if (values.isEmpty()) values.add(key);
        return values;
    }
}
