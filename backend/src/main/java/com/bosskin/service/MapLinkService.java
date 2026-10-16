package com.bosskin.service;

import com.bosskin.core.GoogleMapsLink;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Đổi link Google Maps (kể cả link rút gọn maps.app.goo.gl) thành toạ độ.
 * Link rút gọn: theo từng bước chuyển hướng bằng tay, mỗi bước phải là https + miền Google Maps trong danh sách cho phép,
 * không đọc nội dung trang — chỉ đọc tiêu đề Location. Mỗi người dùng tối đa 20 lượt / phút.
 */
@Service
public class MapLinkService {

    public record LatLng(double lat, double lng) {}

    private static final int MAX_HOPS = 5;
    private static final int MAX_PER_MINUTE = 20;
    private final HttpClient http = HttpClient.newBuilder()
        .followRedirects(HttpClient.Redirect.NEVER).connectTimeout(Duration.ofSeconds(5)).build();
    private final ConcurrentHashMap<Long, Deque<Long>> calls = new ConcurrentHashMap<>();

    public LatLng resolve(Long userId, String input) {
        if (input == null || input.isBlank() || input.length() > 2000) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.geo.link_invalid");
        }
        String text = input.trim();
        Optional<double[]> direct = GoogleMapsLink.parse(text);
        if (direct.isPresent()) return new LatLng(direct.get()[0], direct.get()[1]);

        if (!text.startsWith("https://") || !GoogleMapsLink.isAllowedHost(GoogleMapsLink.host(text))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.geo.link_invalid");
        }
        rateLimit(userId);
        String url = text;
        for (int hop = 0; hop < MAX_HOPS; hop++) {
            HttpResponse<Void> res;
            try {
                res = http.send(HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(6))
                    .header("User-Agent", "Mozilla/5.0").GET().build(), HttpResponse.BodyHandlers.discarding());
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "error.geo.link_unreachable");
            } catch (Exception e) {
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "error.geo.link_unreachable");
            }
            String loc = res.headers().firstValue("location").orElse(null);
            if (res.statusCode() / 100 != 3 || loc == null) break;
            String next = URI.create(url).resolve(loc).toString();
            Optional<double[]> p = GoogleMapsLink.parse(next);
            if (p.isPresent()) return new LatLng(p.get()[0], p.get()[1]);
            if (!next.startsWith("https://") || !GoogleMapsLink.isAllowedHost(GoogleMapsLink.host(next))) break;
            url = next;
        }
        throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "error.geo.link_not_resolved");
    }

    private void rateLimit(Long userId) {
        long now = System.currentTimeMillis();
        Deque<Long> q = calls.computeIfAbsent(userId == null ? 0L : userId, k -> new ArrayDeque<>());
        synchronized (q) {
            while (!q.isEmpty() && now - q.peekFirst() > 60_000) q.pollFirst();
            if (q.size() >= MAX_PER_MINUTE) throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "error.geo.rate_limited");
            q.addLast(now);
        }
    }
}
