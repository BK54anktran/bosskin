package com.bosskin.i18n;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Properties;

import static org.assertj.core.api.Assertions.assertThat;

class AppTextTest {

    private static Properties load(String name) throws Exception {
        Properties p = new Properties();
        try (var in = AppTextTest.class.getResourceAsStream("/" + name)) {
            p.load(new InputStreamReader(in, StandardCharsets.UTF_8));
        }
        return p;
    }

    @Test
    @DisplayName("messages_vi và messages_en có đúng cùng tập khoá (thiếu khoá tiếng Anh sẽ rơi về tiếng Việt mà không ai biết)")
    void bundlesHaveSameKeys() throws Exception {
        var vi = load("messages_vi.properties").stringPropertyNames();
        var en = load("messages_en.properties").stringPropertyNames();
        assertThat(en).as("khoá thiếu ở en").containsAll(vi);
        assertThat(vi).as("khoá thiếu ở vi").containsAll(en);
    }

    @Test
    @DisplayName("Ngôn ngữ lạ hoặc rỗng dùng tiếng Việt; en dùng tiếng Anh")
    void resolvesLanguage() {
        AppText t = new AppText();
        assertThat(t.t("common.custom", Locale.forLanguageTag("en"))).isEqualTo("Custom");
        assertThat(t.t("common.custom", Locale.forLanguageTag("vi"))).isEqualTo("Tùy chỉnh");
        assertThat(t.t("common.custom", Locale.FRENCH)).isEqualTo("Tùy chỉnh");
        assertThat(t.t("common.custom", (Locale) null)).isEqualTo("Tùy chỉnh");
    }
}
