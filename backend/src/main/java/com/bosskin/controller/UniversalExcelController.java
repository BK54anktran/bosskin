package com.bosskin.controller;

import com.bosskin.service.ExcelModulePermissions;

import com.bosskin.entity.ExcelHistory;
import com.bosskin.entity.User;
import com.bosskin.repository.ExcelHistoryRepository;
import com.bosskin.service.S3Service;
import com.bosskin.service.UniversalExcelService;
import com.bosskin.util.ExcelEntityDescriptor;
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
import java.time.LocalDate;
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

    @GetMapping("/search")
    public ResponseEntity<List<ExcelEntityDescriptor.PickItem>> search(
            @RequestParam String module,
            @RequestParam(defaultValue = "") String q,
            @AuthenticationPrincipal User user) {
        if (!user.can("excel.export") && !user.can("excel.import")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return ResponseEntity.ok(
            universalExcelService.searchForPick(user.getCompanyId(), user.getId(), module, q,
                ExcelModulePermissions.exportableTypes(user)));
    }

    @GetMapping("/meta")
    public ResponseEntity<Map<String, UniversalExcelService.ExportMeta>> meta(
            @AuthenticationPrincipal User user) {
        if (!user.can("excel.export") && !user.can("excel.import")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        java.util.Set<String> visible = new java.util.HashSet<>(ExcelModulePermissions.exportableTypes(user));
        visible.addAll(ExcelModulePermissions.importableTypes(user));
        return ResponseEntity.ok(universalExcelService.getExportMeta(
                user.getCompanyId(), LocaleContextHolder.getLocale(), visible));
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
                LocaleContextHolder.getLocale(), req,
                ExcelModulePermissions.exportableTypes(user));
    }

    /** File mẫu để nhập dữ liệu ban đầu: chỉ tiêu đề cột nhập + sheet hướng dẫn. {@code types} trống = mọi module được nhập. */
    @GetMapping("/template")
    public ResponseEntity<byte[]> template(
            @RequestParam(required = false) List<String> types,
            @AuthenticationPrincipal User user) {
        if (!user.can("excel.import")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return universalExcelService.template(LocaleContextHolder.getLocale(), types,
            ExcelModulePermissions.importableTypes(user));
    }

    @PostMapping("/preview-import")
    public ResponseEntity<Map<String, List<UniversalImportDiff>>> previewImport(
            @RequestParam MultipartFile file,
            @AuthenticationPrincipal User user) throws IOException {
        if (!user.can("excel.import")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        Map<String, List<UniversalImportDiff>> diffs =
                universalExcelService.previewImport(user.getCompanyId(), user.getId(), file.getBytes(),
                    ExcelModulePermissions.importableTypes(user));
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
                LocaleContextHolder.getLocale(),
                ExcelModulePermissions.importableTypes(user));
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

    public record HistoryPageResponse(List<HistoryResponse> items, long total) {}

    @GetMapping("/history")
    public ResponseEntity<HistoryPageResponse> history(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String module,
            @RequestParam(required = false) String dateFrom,
            @RequestParam(required = false) String dateTo,
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal User user) {
        if (!user.can("excel.export") && !user.can("excel.import")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        LocalDate from = dateFrom != null && !dateFrom.isBlank() ? LocalDate.parse(dateFrom) : null;
        LocalDate to   = dateTo   != null && !dateTo.isBlank()   ? LocalDate.parse(dateTo)   : null;
        UniversalExcelService.HistoryPage result =
            universalExcelService.getHistoryPaged(user.getCompanyId(), type, module, from, to, page, size);
        List<HistoryResponse> items = result.items().stream()
            .map(hw -> HistoryResponse.from(hw.history(), hw.performedBy()))
            .toList();
        return ResponseEntity.ok(new HistoryPageResponse(items, result.total()));
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
