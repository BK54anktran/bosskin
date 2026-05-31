package com.bosskin.controller;

import com.bosskin.entity.User;
import com.bosskin.service.S3Service;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/upload")
@RequiredArgsConstructor
public class UploadController {

    private final S3Service s3Service;

    /** Upload ảnh (avatar, hình đính kèm). Folder mặc định: "images" */
    @PostMapping("/image")
    public ResponseEntity<Map<String, String>> uploadImage(
            @AuthenticationPrincipal User user,
            @RequestParam MultipartFile file,
            @RequestParam(defaultValue = "images") String folder) {
        String url = s3Service.uploadImage(file, folder);
        return ResponseEntity.ok(Map.of("url", url));
    }

    /** Upload tài liệu PDF/Word/Excel. Folder mặc định: "documents" */
    @PostMapping("/document")
    public ResponseEntity<Map<String, String>> uploadDocument(
            @AuthenticationPrincipal User user,
            @RequestParam MultipartFile file,
            @RequestParam(defaultValue = "documents") String folder) {
        String url = s3Service.uploadDocument(file, folder);
        return ResponseEntity.ok(Map.of("url", url));
    }
}
