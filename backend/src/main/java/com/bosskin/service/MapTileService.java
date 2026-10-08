package com.bosskin.service;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.*;
import java.nio.file.attribute.FileTime;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Stream;

/**
 * Proxy + cache ô bản đồ OpenStreetMap cho FE.
 *
 * <p>Trình duyệt không gọi thẳng tile.openstreetmap.org (một số mạng chặn) mà gọi BE.
 * BE chỉ tải từ OSM khi ô chưa có trong cache đĩa, và có các lớp chống spam:
 * <ul>
 *   <li>chỉ phục vụ vùng Việt Nam (gồm Hoàng Sa, Trường Sa) và zoom trong khoảng cho phép</li>
 *   <li>giới hạn số ô / phút cho mỗi người dùng</li>
 *   <li>giới hạn số lượt tải đồng thời sang OSM + gộp các yêu cầu trùng ô</li>
 *   <li>giới hạn tổng dung lượng cache (xoá ô cũ nhất khi đầy), tự tải lại ô quá hạn</li>
 * </ul>
 * Tuân thủ chính sách OSM: gửi User-Agent riêng, cache lâu, không tải hàng loạt.
 */
@Slf4j
@Service
public class MapTileService {

    /** Kết quả trả cho controller. */
    public enum Status { OK, OUT_OF_RANGE, RATE_LIMITED, BUSY, UPSTREAM_ERROR }

    public record TileResult(Status status, byte[] body) {
        static TileResult of(Status s) { return new TileResult(s, null); }
    }

    @Value("${app.map-tiles.upstream-url:https://tile.openstreetmap.org/{z}/{x}/{y}.png}")
    private String upstreamUrl;
    @Value("${app.map-tiles.user-agent:BossKin-HR/1.0 (map tile proxy)}")
    private String userAgent;
    @Value("${app.map-tiles.cache-dir:${user.home}/.bosskin/map-tiles}")
    private String cacheDirPath;
    @Value("${app.map-tiles.max-cache-mb:1024}")
    private long maxCacheMb;
    @Value("${app.map-tiles.refresh-after-days:30}")
    private long refreshAfterDays;
    @Value("${app.map-tiles.min-zoom:5}")
    private int minZoom;
    @Value("${app.map-tiles.max-zoom:18}")
    private int maxZoom;
    /** Khung Việt Nam: lat 6.0 → 23.6, lon 102.0 → 118.0 (bao cả Hoàng Sa, Trường Sa). */
    @Value("${app.map-tiles.bbox.min-lat:6.0}")  private double minLat;
    @Value("${app.map-tiles.bbox.max-lat:23.6}") private double maxLat;
    @Value("${app.map-tiles.bbox.min-lon:102.0}") private double minLon;
    @Value("${app.map-tiles.bbox.max-lon:118.0}") private double maxLon;
    @Value("${app.map-tiles.rate-limit-per-minute:600}")
    private int rateLimitPerMinute;
    @Value("${app.map-tiles.max-concurrent-upstream:4}")
    private int maxConcurrentUpstream;

    private Path cacheDir;
    private HttpClient http;
    private Semaphore upstreamSlots;
    private final AtomicLong cacheBytes = new AtomicLong();
    private final Map<String, CompletableFuture<byte[]>> inFlight = new ConcurrentHashMap<>();
    private final Map<String, Window> windows = new ConcurrentHashMap<>();
    private final Object evictLock = new Object();

    private static final class Window {
        volatile long minute;
        final AtomicInteger count = new AtomicInteger();
        Window(long minute) { this.minute = minute; }
    }

    @PostConstruct
    void init() throws IOException {
        cacheDir = Paths.get(cacheDirPath).toAbsolutePath();
        try {
            Files.createDirectories(cacheDir);
        } catch (IOException e) {
            // Không tạo được thư mục cấu hình (vd: user chạy app không có home ghi được trên server)
            // → dùng thư mục tạm của hệ thống, để app vẫn khởi động bình thường
            Path fallback = Paths.get(System.getProperty("java.io.tmpdir"), "bosskin-map-tiles");
            log.warn("Không tạo được {} ({}), dùng {}", cacheDir, e.getMessage(), fallback);
            cacheDir = fallback;
            Files.createDirectories(cacheDir);
        }
        http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .followRedirects(HttpClient.Redirect.NORMAL)
            .build();
        upstreamSlots = new Semaphore(Math.max(1, maxConcurrentUpstream));
        try (Stream<Path> s = Files.walk(cacheDir)) {
            cacheBytes.set(s.filter(Files::isRegularFile).mapToLong(MapTileService::sizeOf).sum());
        }
        log.info("Map tile cache: {} ({} MB / tối đa {} MB)", cacheDir, cacheBytes.get() / 1_048_576, maxCacheMb);
    }

    public TileResult getTile(int z, int x, int y, String clientKey) {
        if (!inRange(z, x, y)) return TileResult.of(Status.OUT_OF_RANGE);
        if (!allow(clientKey)) return TileResult.of(Status.RATE_LIMITED);

        Path file = cacheDir.resolve(z + "/" + x + "/" + y + ".png");
        byte[] cached = readIfPresent(file);
        boolean stale = cached != null && isStale(file);
        if (cached != null && !stale) {
            return new TileResult(Status.OK, cached);
        }

        String key = z + "/" + x + "/" + y;
        try {
            byte[] fresh = fetchDeduplicated(key, z, x, y, file);
            return new TileResult(Status.OK, fresh);
        } catch (BusyException e) {
            return cached != null ? new TileResult(Status.OK, cached) : TileResult.of(Status.BUSY);
        } catch (Exception e) {
            log.warn("Tải ô bản đồ {} thất bại: {}", key, e.getMessage());
            // Có bản cũ thì vẫn trả bản cũ thay vì lỗi
            return cached != null ? new TileResult(Status.OK, cached) : TileResult.of(Status.UPSTREAM_ERROR);
        }
    }

    // ── Kiểm tra vùng & zoom ─────────────────────────────────────────────
    boolean inRange(int z, int x, int y) {
        if (z < minZoom || z > maxZoom) return false;
        int n = 1 << z;
        if (x < 0 || y < 0 || x >= n || y >= n) return false;
        int xMin = lonToX(minLon, z), xMax = lonToX(maxLon, z);
        int yMin = latToY(maxLat, z), yMax = latToY(minLat, z); // y tăng về phía nam
        return x >= xMin && x <= xMax && y >= yMin && y <= yMax;
    }

    private static int lonToX(double lon, int z) {
        return (int) Math.floor((lon + 180.0) / 360.0 * (1 << z));
    }

    private static int latToY(double lat, int z) {
        double r = Math.toRadians(lat);
        return (int) Math.floor((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * (1 << z));
    }

    // ── Giới hạn số ô / phút cho mỗi người dùng (cửa sổ cố định 1 phút) ──
    private boolean allow(String clientKey) {
        long minute = System.currentTimeMillis() / 60_000;
        Window w = windows.computeIfAbsent(clientKey, k -> new Window(minute));
        synchronized (w) {
            if (w.minute != minute) { w.minute = minute; w.count.set(0); }
        }
        if (windows.size() > 10_000) {
            windows.entrySet().removeIf(e -> e.getValue().minute < minute - 1);
        }
        return w.count.incrementAndGet() <= rateLimitPerMinute;
    }

    // ── Tải từ OSM (gộp yêu cầu trùng ô + giới hạn đồng thời) ──────────
    private static final class BusyException extends RuntimeException {}

    private byte[] fetchDeduplicated(String key, int z, int x, int y, Path file) throws Exception {
        CompletableFuture<byte[]> mine = new CompletableFuture<>();
        CompletableFuture<byte[]> existing = inFlight.putIfAbsent(key, mine);
        if (existing != null) {
            try {
                return existing.get(20, TimeUnit.SECONDS);
            } catch (ExecutionException e) {
                throw (e.getCause() instanceof Exception ex) ? ex : e;
            }
        }
        try {
            byte[] data = fetchUpstream(z, x, y);
            store(file, data);
            mine.complete(data);
            return data;
        } catch (Exception e) {
            mine.completeExceptionally(e);
            throw e;
        } finally {
            inFlight.remove(key, mine);
        }
    }

    private byte[] fetchUpstream(int z, int x, int y) throws Exception {
        if (!upstreamSlots.tryAcquire(10, TimeUnit.SECONDS)) throw new BusyException();
        try {
            String url = upstreamUrl.replace("{z}", String.valueOf(z))
                .replace("{x}", String.valueOf(x))
                .replace("{y}", String.valueOf(y));
            HttpRequest req = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(10))
                .header("User-Agent", userAgent)
                .GET().build();
            HttpResponse<byte[]> res = http.send(req, HttpResponse.BodyHandlers.ofByteArray());
            String type = res.headers().firstValue("Content-Type").orElse("");
            if (res.statusCode() != 200 || !type.startsWith("image/")) {
                throw new IOException("HTTP " + res.statusCode() + " " + type);
            }
            return res.body();
        } finally {
            upstreamSlots.release();
        }
    }

    // ── Cache đĩa ────────────────────────────────────────────────────────
    private static byte[] readIfPresent(Path file) {
        try {
            return Files.isRegularFile(file) ? Files.readAllBytes(file) : null;
        } catch (IOException e) {
            return null;
        }
    }

    private boolean isStale(Path file) {
        try {
            Instant saved = Files.getLastModifiedTime(file).toInstant();
            return saved.isBefore(Instant.now().minus(Duration.ofDays(refreshAfterDays)));
        } catch (IOException e) {
            return false;
        }
    }

    private void store(Path file, byte[] data) {
        try {
            Files.createDirectories(file.getParent());
            long old = Files.exists(file) ? sizeOf(file) : 0;
            Path tmp = Files.createTempFile(file.getParent(), "tile", ".tmp");
            Files.write(tmp, data);
            try {
                Files.move(tmp, file, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
            } catch (AtomicMoveNotSupportedException e) {
                Files.move(tmp, file, StandardCopyOption.REPLACE_EXISTING);
            }
            if (cacheBytes.addAndGet(data.length - old) > maxCacheMb * 1_048_576) evict();
        } catch (IOException e) {
            log.warn("Không ghi được cache ô bản đồ {}: {}", file, e.getMessage());
        }
    }

    /** Xoá các ô tải về lâu nhất cho tới khi còn 90% dung lượng tối đa. */
    private void evict() {
        synchronized (evictLock) {
            long limit = maxCacheMb * 1_048_576;
            if (cacheBytes.get() <= limit) return;
            long target = limit * 9 / 10;
            List<Path> files;
            try (Stream<Path> s = Files.walk(cacheDir)) {
                files = s.filter(p -> Files.isRegularFile(p) && p.toString().endsWith(".png"))
                    .sorted(Comparator.comparing(MapTileService::lastModified))
                    .toList();
            } catch (IOException | UncheckedIOException e) {
                log.warn("Không quét được cache ô bản đồ: {}", e.getMessage());
                return;
            }
            for (Path p : files) {
                if (cacheBytes.get() <= target) break;
                long size = sizeOf(p);
                try {
                    Files.deleteIfExists(p);
                    cacheBytes.addAndGet(-size);
                } catch (IOException ignored) { }
            }
            log.info("Đã dọn cache ô bản đồ, còn {} MB", cacheBytes.get() / 1_048_576);
        }
    }

    private static long sizeOf(Path p) {
        try { return Files.size(p); } catch (IOException e) { return 0; }
    }

    private static FileTime lastModified(Path p) {
        try { return Files.getLastModifiedTime(p); } catch (IOException e) { return FileTime.fromMillis(0); }
    }
}
