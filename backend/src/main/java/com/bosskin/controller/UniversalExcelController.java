package com.bosskin.controller;

import com.bosskin.entity.ExcelHistory;
import com.bosskin.entity.User;
import com.bosskin.repository.ExcelHistoryRepository;
import com.bosskin.service.S3Service;
import com.bosskin.service.UniversalExcelService;
import com.bosskin.util.ExportRequest;
import com.bosskin.util.UniversalImportDiff;
import lombok.RequiredArgsConstructor;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/excel")
@RequiredArgsConstructor
public class UniversalExcelController {

    private final UniversalExcelService universalExcelService;
    private final ExcelHistoryRepository historyRepo;
    private final S3Service s3Service;

    @GetMapping("/meta")
    public ResponseEntity<Map<String, UniversalExcelService.ExportMeta>> meta(
            @AuthenticationPrincipal User user) {
        if (!user.can("excel.export") && !user.can("excel.import")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return ResponseEntity.ok(universalExcelService.getExportMeta(
                user.getCompanyId(), LocaleContextHolder.getLocale()));
    }

    @PostMapping("/export")
    public ResponseEntity<byte[]> export(
            @RequestBody(required = false) ExportRequest req,
            @AuthenticationPrincipal User user) {
        if (!user.can("excel.export")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return universalExcelService.exportAll(
                user.getCompanyId(), user.getId(),
                LocaleContextHolder.getLocale(), req);
    }

    @PostMapping("/preview-import")
    public ResponseEntity<Map<String, List<UniversalImportDiff>>> previewImport(
            @RequestParam MultipartFile file,
            @AuthenticationPrincipal User user) throws IOException {
        if (!user.can("excel.import")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        Map<String, List<UniversalImportDiff>> diffs =
                universalExcelService.previewImport(user.getCompanyId(), user.getId(), file.getBytes());
        return ResponseEntity.ok(diffs);
    }

    @PostMapping("/import")
    public ResponseEntity<byte[]> importAll(
            @RequestParam MultipartFile file,
            @AuthenticationPrincipal User user) throws IOException {
        if (!user.can("excel.import")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return universalExcelService.importAll(
                user.getCompanyId(), user.getId(),
                file.getBytes(),
                LocaleContextHolder.getLocale());
    }

    @GetMapping("/history/{id}/download")
    public ResponseEntity<byte[]> downloadHistory(
            @PathVariable Long id,
            @AuthenticationPrincipal User user) {
        if (!user.can("excel.export") && !user.can("excel.import")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        ExcelHistory entry = historyRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.excel.history_not_found"));
        if (!user.getCompanyId().equals(entry.getCompanyId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        if (entry.getFileUrl() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.excel.history_no_file");
        }
        byte[] bytes = s3Service.downloadAsBytes(s3Service.keyFromUrl(entry.getFileUrl()));
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType(
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"));
        headers.setContentDisposition(ContentDisposition.attachment()
                .filename(entry.getFilename(), StandardCharsets.UTF_8)
                .build());
        return ResponseEntity.ok().headers(headers).body(bytes);
    }

    @GetMapping("/history")
    public ResponseEntity<List<HistoryResponse>> history(
            @AuthenticationPrincipal User user) {
        if (!user.can("excel.export") && !user.can("excel.import")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        List<HistoryResponse> list = universalExcelService.getHistory(user.getCompanyId())
                .stream()
                .map(hw -> HistoryResponse.from(hw.history(), hw.performedBy()))
                .toList();
        return ResponseEntity.ok(list);
    }

    public record HistoryResponse(
            Long id,
            String type,
            String module,
            String filename,
            String fileUrl,
            Integer okCount,
            Integer errorCount,
            Integer skipCount,
            String createdAt,
            String performedBy) {

        private static final DateTimeFormatter FMT =
                DateTimeFormatter.ISO_LOCAL_DATE_TIME;

        static HistoryResponse from(ExcelHistory h, String performedBy) {
            return new HistoryResponse(
                    h.getId(),
                    h.getType().name(),
                    h.getModule(),
                    h.getFilename(),
                    h.getFileUrl(),
                    h.getOkCount(),
                    h.getErrorCount(),
                    h.getSkipCount(),
                    h.getCreatedAt() != null ? h.getCreatedAt().format(FMT) : null,
                    performedBy);
        }
    }
}
