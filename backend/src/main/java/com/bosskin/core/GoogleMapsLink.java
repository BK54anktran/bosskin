package com.bosskin.core;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Đọc toạ độ từ link Google Maps / chuỗi "vĩ độ, kinh độ". Thuần chuỗi, không gọi mạng.
 * Thứ tự ưu tiên: !3d<lat>!4d<lng> (ghim địa điểm) → /search|place|dir/lat,lng (toạ độ trong đường dẫn) → @lat,lng (tâm bản đồ) → ?q= / ?ll= / ?query= / ?destination= → "lat,lng" trơn.
 */
public final class GoogleMapsLink {

    private static final String NUM = "-?\\d{1,3}(?:\\.\\d+)?";
    private static final Pattern PIN = Pattern.compile("!3d(" + NUM + ")!4d(" + NUM + ")");
    private static final Pattern AT = Pattern.compile("@(" + NUM + "),(" + NUM + ")");
    /** /maps/search/10.85,+106.63 · /maps/place/10.85,106.63 · /maps/dir//10.85,106.63 (toạ độ nằm trong đường dẫn). */
    private static final Pattern PATH_PAIR = Pattern.compile("/(" + NUM + "),(?:\\+|%2[Bb]|%20)?(" + NUM + ")(?=[/?#]|$)");
    private static final Pattern PAIR = Pattern.compile("^\\s*(" + NUM + ")\\s*[,; ]\\s*(" + NUM + ")\\s*$");
    private static final Pattern QUERY_PAIR = Pattern.compile("(?:^|[?&])(?:q|ll|query|destination|center|daddr)=([^&#]+)");

    /** Chỉ theo link rút gọn / chuyển hướng tới các miền Google Maps này (chặn SSRF). */
    public static boolean isAllowedHost(String host) {
        if (host == null) return false;
        String h = host.toLowerCase(Locale.ROOT);
        return h.equals("maps.app.goo.gl") || h.equals("goo.gl") || h.equals("maps.google.com")
            || h.equals("google.com") || h.equals("www.google.com") || h.equals("consent.google.com")
            || (h.startsWith("www.google.") && h.length() <= 20 && h.indexOf('/') < 0)
            || (h.startsWith("maps.google.") && h.length() <= 20);
    }

    /** Link rút gọn cần gọi mạng để biết đích. */
    public static boolean isShortLink(String url) {
        String h = host(url);
        return h != null && (h.equals("maps.app.goo.gl") || h.equals("goo.gl"));
    }

    public static String host(String url) {
        try {
            return URI.create(url.trim()).getHost();
        } catch (Exception e) {
            return null;
        }
    }

    /** {lat, lng} nếu tìm thấy và hợp lệ (|lat| ≤ 90, |lng| ≤ 180). */
    public static Optional<double[]> parse(String text) {
        if (text == null || text.isBlank()) return Optional.empty();
        String t = text.trim();
        Matcher m = PIN.matcher(t);
        if (m.find()) return valid(m.group(1), m.group(2));
        m = PATH_PAIR.matcher(t);
        if (m.find()) return valid(m.group(1), m.group(2));
        m = AT.matcher(t);
        if (m.find()) return valid(m.group(1), m.group(2));
        m = PAIR.matcher(t);
        if (m.matches()) return valid(m.group(1), m.group(2));
        m = QUERY_PAIR.matcher(t);
        while (m.find()) {
            String v = URLDecoder.decode(m.group(1), StandardCharsets.UTF_8).replace('+', ' ');
            Matcher p = PAIR.matcher(v);
            if (p.matches()) return valid(p.group(1), p.group(2));
        }
        return Optional.empty();
    }

    private static Optional<double[]> valid(String lat, String lng) {
        try {
            double a = Double.parseDouble(lat), b = Double.parseDouble(lng);
            if (Math.abs(a) > 90 || Math.abs(b) > 180) return Optional.empty();
            return Optional.of(new double[]{a, b});
        } catch (NumberFormatException e) {
            return Optional.empty();
        }
    }

    private GoogleMapsLink() {}
}
