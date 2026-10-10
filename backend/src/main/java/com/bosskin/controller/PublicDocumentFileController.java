package com.bosskin.controller;

import com.bosskin.service.DocumentStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;

/**
 * Bước N — tải file tài liệu khi lưu cục bộ (dev / test). Không cần đăng nhập: quyền nằm ở token ký HMAC có hạn
 * do {@code GET /employee-documents/{id}/link} cấp (cùng cách presigned URL của S3).
 */
@RestController
@RequiredArgsConstructor
public class PublicDocumentFileController {

    private final DocumentStorageService storage;

    @GetMapping(DocumentStorageService.LOCAL_PATH)
    public ResponseEntity<byte[]> file(@RequestParam("t") String token) {
        DocumentStorageService.StoredFile f = storage.readLocal(token);
        return ResponseEntity.ok()
            .contentType(MediaType.parseMediaType(f.contentType()))
            .header(HttpHeaders.CONTENT_DISPOSITION,
                ContentDisposition.attachment().filename(f.fileName(), StandardCharsets.UTF_8).build().toString())
            .header(HttpHeaders.CACHE_CONTROL, "no-store")
            .body(f.bytes());
    }
}
