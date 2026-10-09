package com.bosskin.controller;

import com.bosskin.dto.TrialRequestDTO;
import com.bosskin.entity.SystemAdmin;
import com.bosskin.entity.TrialRequest;
import com.bosskin.service.trial.TrialRequestStore;
import com.bosskin.service.TrialRequestService;
import com.bosskin.util.ExcelI18n;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Yêu cầu dùng thử: form công khai trên trang giới thiệu gửi vào {@code POST /api/v1/public/trial-requests};
 * system admin xem/xử lý ở {@code /admin/trial-requests}.
 */
@RestController
@RequiredArgsConstructor
public class TrialRequestController {

    private final TrialRequestService service;
    private final TrialRequestStore store;
    private final ExcelI18n excelI18n;

    @PostMapping("/api/v1/public/trial-requests")
    public ResponseEntity<Map<String, Object>> submit(@RequestBody TrialRequestDTO.SubmitRequest body, HttpServletRequest req) {
        service.submit(body, req.getRemoteAddr());
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("received", true));
    }

    @GetMapping("/admin/trial-requests")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<Page<TrialRequestDTO.Response>> list(
            @RequestParam(required = false) TrialRequest.Status status,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(store.search(status, q, PageRequest.of(page, Math.min(size, 100)))
            .map(TrialRequestDTO.Response::of));
    }

    @GetMapping("/admin/trial-requests/count-new")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<Map<String, Object>> countNew() {
        return ResponseEntity.ok(Map.of("count", store.countNew(), "source", store.name()));
    }

    @PatchMapping("/admin/trial-requests/{id}")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<TrialRequestDTO.Response> update(@PathVariable Long id, @RequestBody TrialRequestDTO.UpdateRequest body,
                                                           @AuthenticationPrincipal SystemAdmin admin) {
        return ResponseEntity.ok(service.update(id, body, admin != null ? admin.getEmail() : null));
    }

    @GetMapping("/admin/trial-requests/export")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<byte[]> export(@RequestParam(required = false) TrialRequest.Status status, Locale locale) throws IOException {
        List<TrialRequest> rows = store.findAllForExport(status);
        String[] cols = {"createdAt", "fullName", "companyName", "phone", "email", "companySize", "need", "status", "adminNote", "handledBy"};
        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
        try (Workbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet sh = wb.createSheet(excelI18n.resolve("excel.trial.sheet", locale));
            CellStyle head = wb.createCellStyle(); Font bold = wb.createFont(); bold.setBold(true); head.setFont(bold);
            Row h = sh.createRow(0);
            for (int i = 0; i < cols.length; i++) {
                Cell c = h.createCell(i); c.setCellValue(excelI18n.resolve("excel.trial.col." + cols[i], locale)); c.setCellStyle(head);
            }
            int r = 1;
            for (TrialRequest t : rows) {
                Row row = sh.createRow(r++);
                Object[] v = {t.getCreatedAt() == null ? "" : t.getCreatedAt().format(dtf), t.getFullName(), t.getCompanyName(),
                    t.getPhone(), t.getEmail(), t.getCompanySize(), t.getNeed(),
                    excelI18n.resolve("excel.enum.trialStatus." + t.getStatus(), locale), t.getAdminNote(), t.getHandledBy()};
                for (int i = 0; i < v.length; i++) row.createCell(i).setCellValue(v[i] == null ? "" : v[i].toString());
            }
            for (int i = 0; i < cols.length; i++) sh.autoSizeColumn(i);
            sh.createFreezePane(0, 1);
            wb.write(out);
            return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"trial-requests.xlsx\"")
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(out.toByteArray());
        }
    }
}
