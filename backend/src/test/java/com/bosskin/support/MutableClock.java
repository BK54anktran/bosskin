package com.bosskin.support;

import com.bosskin.config.ClockConfig;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Đồng hồ cho test: mặc định chạy theo giờ thật; {@link #set} để đứng yên ở một thời điểm
 * (giờ Việt Nam), {@link #reset} để về giờ thật. IntegrationTest tự reset trước mỗi test.
 */
public class MutableClock extends Clock {

    private final AtomicReference<Instant> fixed = new AtomicReference<>();

    public void set(LocalDateTime vietnamTime) {
        fixed.set(vietnamTime.atZone(ClockConfig.ZONE).toInstant());
    }

    public void reset() {
        fixed.set(null);
    }

    @Override public ZoneId getZone() { return ClockConfig.ZONE; }
    @Override public Clock withZone(ZoneId zone) { return Clock.fixed(instant(), zone); }
    @Override public Instant instant() {
        Instant f = fixed.get();
        return f != null ? f : Instant.now();
    }
}
