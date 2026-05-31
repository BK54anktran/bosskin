package com.bosskin.service;

import com.bosskin.config.S3Properties;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class S3Service {

    private static final long MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB
    private static final Set<String> ALLOWED_IMAGE_TYPES = Set.of(
            "image/jpeg", "image/png", "image/webp", "image/gif"
    );
    private static final Set<String> ALLOWED_DOC_TYPES = Set.of(
            "application/pdf",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    );

    private final S3Client s3Client;
    private final S3Properties props;

    /**
     * Upload ảnh (avatar, hình đính kèm). Trả về public URL.
     */
    public String uploadImage(MultipartFile file, String folder) {
        validateFile(file, ALLOWED_IMAGE_TYPES);
        return upload(file, folder);
    }

    /**
     * Upload file tài liệu (PDF, Word, Excel). Trả về public URL.
     */
    public String uploadDocument(MultipartFile file, String folder) {
        validateFile(file, ALLOWED_DOC_TYPES);
        return upload(file, folder);
    }

    /**
     * Xóa object theo key (phần path sau bucket, vd: "avatars/abc.jpg").
     */
    public void delete(String key) {
        s3Client.deleteObject(DeleteObjectRequest.builder()
                .bucket(props.getBucket())
                .key(key)
                .build());
    }

    // ── private ──────────────────────────────────────────────────────────

    private String upload(MultipartFile file, String folder) {
        String ext = getExtension(file.getOriginalFilename());
        String key = folder + "/" + UUID.randomUUID() + ext;

        try {
            PutObjectRequest req = PutObjectRequest.builder()
                    .bucket(props.getBucket())
                    .key(key)
                    .contentType(file.getContentType())
                    .contentLength(file.getSize())
                    .build();

            s3Client.putObject(req, RequestBody.fromBytes(file.getBytes()));
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,
                    "error.s3.upload_failed");
        }

        return buildPublicUrl(key);
    }

    private String buildPublicUrl(String key) {
        String endpoint = props.getEndpoint();
        if (endpoint != null && !endpoint.isBlank()) {
            // MinIO hoặc custom endpoint
            return endpoint.stripTrailing() + "/" + props.getBucket() + "/" + key;
        }
        // AWS S3 standard URL
        return "https://" + props.getBucket() + ".s3." + props.getRegion() + ".amazonaws.com/" + key;
    }

    private void validateFile(MultipartFile file, Set<String> allowedTypes) {
        if (file == null || file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.s3.file_empty");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.s3.file_too_large");
        }
        if (!allowedTypes.contains(file.getContentType())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.s3.invalid_type");
        }
    }

    private String getExtension(String filename) {
        if (filename == null || !filename.contains(".")) return "";
        return filename.substring(filename.lastIndexOf('.'));
    }
}
