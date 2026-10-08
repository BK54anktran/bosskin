package com.bosskin.controller;

import com.bosskin.service.MapTileService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.concurrent.TimeUnit;

/**
 * Ô bản đồ OpenStreetMap đi qua BE (cần đăng nhập — nằm dưới /api/v1/**).
 * FE: TileLayer(urlTemplate: '{baseUrl}/map-tiles/{z}/{x}/{y}.png', headers: Authorization).
 */
@RestController
@RequestMapping("/api/v1/map-tiles")
@RequiredArgsConstructor
public class MapTileController {

    private final MapTileService mapTileService;

    @GetMapping(value = "/{z}/{x}/{y}.png", produces = MediaType.IMAGE_PNG_VALUE)
    public ResponseEntity<byte[]> tile(@PathVariable int z, @PathVariable int x, @PathVariable int y,
                                       Authentication auth, HttpServletRequest request) {
        String clientKey = auth != null ? "u:" + auth.getName() : "ip:" + request.getRemoteAddr();
        MapTileService.TileResult r = mapTileService.getTile(z, x, y, clientKey);
        return switch (r.status()) {
            case OK -> ResponseEntity.ok()
                .contentType(MediaType.IMAGE_PNG)
                // Trình duyệt tự giữ ô 30 ngày → mở lại cùng khu vực không gọi BE nữa
                .cacheControl(CacheControl.maxAge(30, TimeUnit.DAYS).cachePrivate())
                .body(r.body());
            case OUT_OF_RANGE -> ResponseEntity.notFound().build();
            case RATE_LIMITED -> ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                .header("Retry-After", "60").build();
            case BUSY -> ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .header("Retry-After", "5").build();
            case UPSTREAM_ERROR -> ResponseEntity.status(HttpStatus.BAD_GATEWAY).build();
        };
    }
}
