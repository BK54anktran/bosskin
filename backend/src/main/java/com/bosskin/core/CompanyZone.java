package com.bosskin.core;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;

/**
 * Múi giờ của công ty đang xử lý yêu cầu (V32). {@code CompanyZoneInterceptor} đặt múi giờ theo công ty của người dùng
 * ở đầu mỗi request API và xoá ở cuối; ngoài request (job nền) dùng múi giờ mặc định Việt Nam.
 * Mọi nghiệp vụ lấy "bây giờ / hôm nay" qua lớp này (hoặc bean {@link Clock}, cũng theo múi giờ này), không gọi {@code LocalDate.now()} trần.
 */
public final class CompanyZone {

    public static final ZoneId DEFAULT = ZoneId.of("Asia/Ho_Chi_Minh");
    public static final String DEFAULT_ID = "Asia/Ho_Chi_Minh";

    private static final ThreadLocal<ZoneId> CURRENT = new ThreadLocal<>();

    /** Đồng hồ hệ thống nhưng múi giờ đổi theo request hiện tại. */
    private static final Clock CLOCK = new Clock() {
        @Override public ZoneId getZone() { return current(); }
        @Override public Clock withZone(ZoneId zone) { return Clock.system(zone); }
        @Override public Instant instant() { return Instant.now(); }
    };

    private CompanyZone() {}

    public static ZoneId current() {
        ZoneId z = CURRENT.get();
        return z != null ? z : DEFAULT;
    }

    public static void set(ZoneId zone) { CURRENT.set(zone); }

    public static void clear() { CURRENT.remove(); }

    public static Clock clock() { return CLOCK; }

    public static LocalDate today() { return LocalDate.now(CLOCK); }

    public static LocalDateTime now() { return LocalDateTime.now(CLOCK); }

    public static LocalTime time() { return LocalTime.now(CLOCK); }

    /** Chuỗi múi giờ lưu ở công ty → ZoneId; sai / trống → mặc định. */
    public static ZoneId parseOrDefault(String id) {
        if (id == null || id.isBlank()) return DEFAULT;
        try { return ZoneId.of(id.trim()); } catch (Exception e) { return DEFAULT; }
    }

    /** Kiểm tra khi lưu cài đặt: phải là mã vùng IANA hợp lệ (vd. Asia/Bangkok). */
    public static String normalize(String id) {
        if (id == null || id.isBlank()) return DEFAULT_ID;
        try {
            return ZoneId.of(id.trim()).getId();
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.timezone_invalid|" + id);
        }
    }

    /** Độ lệch UTC hiện tại của múi giờ (phút), gửi cho app để hiển thị ngày giờ theo công ty. */
    public static int utcOffsetMinutes(ZoneId zone) {
        return zone.getRules().getOffset(Instant.now()).getTotalSeconds() / 60;
    }
}
