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
        String url = s3Service.uploadImage(file, companyFolder(user, folder));
        return ResponseEntity.ok(Map.of("url", url));
    }

    /** Upload tài liệu PDF/Word/Excel. Folder mặc định: "documents" */
    @PostMapping("/document")
    public ResponseEntity<Map<String, String>> uploadDocument(
            @AuthenticationPrincipal User user,
            @RequestParam MultipartFile file,
            @RequestParam(defaultValue = "documents") String folder) {
        String url = s3Service.uploadDocument(file, companyFolder(user, folder));
        return ResponseEntity.ok(Map.of("url", url));
    }

    /**
     * S12: file luôn nằm dưới thư mục riêng của công ty; tên thư mục client gửi
     * chỉ được chứa chữ thường, số, '-', '_' (chặn "../" hoặc ghi vào thư mục công ty khác).
     */
    private static String companyFolder(User user, String folder) {
        if (user == null || user.getCompany() == null) {
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.UNAUTHORIZED, "error.permission.denied");
        }
        String safe = folder == null ? "" : folder.trim().toLowerCase();
        if (!safe.matches("[a-z0-9_-]{1,40}")) {
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.BAD_REQUEST, "error.upload.invalid_folder");
        }
        return "company-" + user.getCompany().getId() + "/" + safe;
    }
}
