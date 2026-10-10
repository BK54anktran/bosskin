package com.bosskin.service;

import com.bosskin.config.S3Properties;
import com.bosskin.dto.DocumentDTO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;

/**
 * Bước N — kho file tài liệu nhân sự, luôn riêng tư (không có URL công khai).
 * <ul>
 *   <li>{@code S3}: object không public, link = presigned GET hết hạn sau {@code app.documents.link-ttl-seconds}.</li>
 *   <li>{@code LOCAL} (dev / test, hoặc khi chưa cấu hình bucket): file trong {@code app.documents.local-dir},
 *       link = {@code /api/v1/public/document-files?t=} kèm token ký HMAC có hạn.</li>
 * </ul>
 * {@code app.documents.storage} = s3 | local; để trống thì có bucket → S3, không → LOCAL.
 */
@Slf4j
@Service
public class DocumentStorageService {

    public static final String LOCAL_PATH = "/api/v1/public/document-files";

    public enum Mode { S3, LOCAL }

    public record StoredFile(byte[] bytes, String fileName, String contentType) {}

    private final S3Client s3Client;
    private final S3Presigner presigner;
    private final S3Properties s3Props;
    private final Clock clock;
    private final Mode mode;
    private final Path localDir;
    private final Duration ttl;
    private final byte[] secret;

    public DocumentStorageService(S3Client s3Client, S3Presigner presigner, S3Properties s3Props, Clock clock,
                                  @Value("${app.documents.storage:}") String storage,
                                  @Value("${app.documents.local-dir:${java.io.tmpdir}/bosskin-documents}") String localDir,
                                  @Value("${app.documents.link-ttl-seconds:300}") long ttlSeconds,
                                  @Value("${app.jwt.secret:}") String jwtSecret) {
        this.s3Client = s3Client;
        this.presigner = presigner;
        this.s3Props = s3Props;
        this.clock = clock;
        boolean hasBucket = s3Props.getBucket() != null && !s3Props.getBucket().isBlank();
        this.mode = "local".equalsIgnoreCase(storage) ? Mode.LOCAL
            : "s3".equalsIgnoreCase(storage) ? Mode.S3
            : hasBucket ? Mode.S3 : Mode.LOCAL;
        this.localDir = Path.of(localDir);
        this.ttl = Duration.ofSeconds(ttlSeconds);
        this.secret = ("documents:" + jwtSecret).getBytes(StandardCharsets.UTF_8);
        log.info("Kho tài liệu nhân sự: {}{}", mode, mode == Mode.LOCAL ? " (" + this.localDir + ")" : "");
    }

    public Mode mode() { return mode; }

    /** Lưu file, trả khoá. */
    public String store(Long companyId, byte[] bytes, String fileName, String contentType) {
        String ext = fileName != null && fileName.contains(".") ? fileName.substring(fileName.lastIndexOf('.')).toLowerCase() : "";
        if (!ext.matches("\\.[a-z0-9]{1,8}")) ext = "";
        String key = "documents/" + companyId + "/" + UUID.randomUUID() + ext;
        if (mode == Mode.S3) {
            s3Client.putObject(PutObjectRequest.builder().bucket(s3Props.getBucket()).key(key)
                .contentType(contentType).contentLength((long) bytes.length).build(), RequestBody.fromBytes(bytes));
        } else {
            try {
                Path p = localDir.resolve(key);
                Files.createDirectories(p.getParent());
                Files.write(p, bytes);
            } catch (IOException e) {
                throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "error.s3.upload_failed");
            }
        }
        return key;
    }

    /** Link ký tạm để xem / tải. */
    public DocumentDTO.Link link(String key, String fileName, String contentType) {
        Instant expires = clock.instant().plus(ttl);
        if (mode == Mode.S3) {
            GetObjectRequest get = GetObjectRequest.builder().bucket(s3Props.getBucket()).key(key)
                .responseContentType(contentType)
                .responseContentDisposition("attachment; filename*=UTF-8''" + encode(fileName))
                .build();
            String url = presigner.presignGetObject(GetObjectPresignRequest.builder()
                .signatureDuration(ttl).getObjectRequest(get).build()).url().toString();
            return new DocumentDTO.Link(url, expires, fileName);
        }
        String payload = key + "\n" + expires.getEpochSecond() + "\n" + fileName + "\n" + contentType;
        String token = b64(payload.getBytes(StandardCharsets.UTF_8)) + "." + b64(hmac(payload));
        return new DocumentDTO.Link(LOCAL_PATH + "?t=" + token, expires, fileName);
    }

    /** Đọc file theo token của link LOCAL; sai chữ ký → 403, quá hạn → 410. */
    public StoredFile readLocal(String token) {
        if (mode != Mode.LOCAL || token == null || !token.contains(".")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.document.link_invalid");
        }
        int dot = token.indexOf('.');
        byte[] payloadBytes;
        byte[] sig;
        try {
            payloadBytes = Base64.getUrlDecoder().decode(token.substring(0, dot));
            sig = Base64.getUrlDecoder().decode(token.substring(dot + 1));
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.document.link_invalid");
        }
        String payload = new String(payloadBytes, StandardCharsets.UTF_8);
        if (!MessageDigest.isEqual(hmac(payload), sig)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.document.link_invalid");
        }
        String[] parts = payload.split("\n", 4);
        if (parts.length != 4) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.document.link_invalid");
        if (clock.instant().getEpochSecond() > Long.parseLong(parts[1])) {
            throw new ResponseStatusException(HttpStatus.GONE, "error.document.link_expired");
        }
        try {
            return new StoredFile(Files.readAllBytes(localDir.resolve(parts[0])), parts[2], parts[3]);
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.document.not_found");
        }
    }

    private byte[] hmac(String payload) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private static String b64(byte[] b) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }

    private static String encode(String s) {
        return URLEncoder.encode(s == null ? "file" : s, StandardCharsets.UTF_8).replace("+", "%20");
    }
}
