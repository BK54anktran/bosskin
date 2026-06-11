package com.bosskin.controller;

import com.bosskin.entity.User;
import com.bosskin.service.UniversalExcelService;
import com.bosskin.util.ExportRequest;
import com.bosskin.util.UniversalImportDiff;
import lombok.RequiredArgsConstructor;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/excel")
@RequiredArgsConstructor
public class UniversalExcelController {

    private final UniversalExcelService universalExcelService;

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
}
